local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
local function lrequire(name)
    local key = _dir .. name
    if not package.loaded[key] then
        package.loaded[key] = assert(loadfile(_dir .. name .. ".lua"))()
    end
    return package.loaded[key]
end

local Blitbuffer      = require("ffi/blitbuffer")
local Button          = require("ui/widget/button")
local CenterContainer = require("ui/widget/container/centercontainer")
local ConfirmBox      = require("ui/widget/confirmbox")
local Device          = require("device")
local Font            = require("ui/font")
local FrameContainer  = require("ui/widget/container/framecontainer")
local GestureRange    = require("ui/gesturerange")
local InputContainer  = require("ui/widget/container/inputcontainer")
local Geom            = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan  = require("ui/widget/horizontalspan")
local InfoMessage     = require("ui/widget/infomessage")
local InputDialog     = require("ui/widget/inputdialog")
local LeftContainer   = require("ui/widget/container/leftcontainer")
local Size            = require("ui/size")
local TextBoxWidget   = require("ui/widget/textboxwidget")
local TextWidget      = require("ui/widget/textwidget")
local UIManager       = require("ui/uimanager")
local VerticalGroup   = require("ui/widget/verticalgroup")
local VerticalSpan    = require("ui/widget/verticalspan")
local _               = require("i18n")
local T               = require("ffi/util").template

local MenuHelper = require("menu_helper")
local Party      = require("party")
local ScreenBase = require("screen_base")

local Belote     = lrequire("belote")
local NumEntry   = lrequire("numentry")
local Numpad     = lrequire("numpad")
local Rules      = lrequire("rules")
local ScoreTable = lrequire("score_table")
local Sheet      = lrequire("sheet")
local Tarot      = lrequire("tarot")

local DeviceScreen = Device.screen
local DPI_SCALE = DeviceScreen:scaleBySize(1000) / 1000

local function pxFace(px, bold)
    return Font:getFace(bold and "smallinfofontbold" or "cfont", math.max(8, math.floor(px / DPI_SCALE)))
end

local function vspan(h) return VerticalSpan:new{ width = math.floor(h) } end
local function hspan(w) return HorizontalSpan:new{ width = math.floor(w) } end

-- A line of the per-player form: tapping it selects that player.
local TapRow = InputContainer:extend{ callback = nil }

function TapRow:init()
    local sz = self[1]:getSize()
    self.dimen = Geom:new{ w = sz.w, h = sz.h }
    self.ges_events = {
        Tap = { GestureRange:new{ ges = "tap", range = function() return self.dimen end } },
    }
end

function TapRow:onTap()
    if self.callback then self.callback() end
    return true
end

-- ---------------------------------------------------------------------------
-- Labels
-- ---------------------------------------------------------------------------

local KIND_LABEL = {
    tarot  = _("Tarot"),
    belote = _("Belote / Coinche"),
    words  = _("Word tile game"),
    rummy  = _("Rummy"),
    free   = _("Free sheet"),
}

local CONTRACT_LABEL = {
    petite       = _("Petite"),
    garde        = _("Garde"),
    garde_sans   = _("Garde sans"),
    garde_contre = _("Garde contre"),
}
local CONTRACT_SHORT = { petite = "P", garde = "G", garde_sans = "GS", garde_contre = "GC" }

local function lang2(pair)
    return (_.lang() == "fr" and pair[2]) or pair[1]
end

-- ---------------------------------------------------------------------------
-- ScoreScreen
-- ---------------------------------------------------------------------------

local ScoreScreen = ScreenBase:extend{ vertical_align = "top" }

function ScoreScreen:init()
    local st = self.plugin:loadState()
    self.store = { sheets = {}, current = nil }
    if type(st) == "table" and type(st.sheets) == "table" then
        for _i, kind in ipairs(Sheet.KINDS) do
            local s = Sheet.restore(st.sheets[kind])
            if s and s.kind == kind then self.store.sheets[kind] = s end
        end
        if st.current and self.store.sheets[st.current] then self.store.current = st.current end
    end
    self.view = self.store.current and "sheet" or "home"
    self.back = 0      -- rounds scrolled back from the end of the table
    ScreenBase.init(self)
end

function ScoreScreen:serializeState()
    return self.store
end

function ScoreScreen:_save()
    self.plugin:saveState(self.store)
end

function ScoreScreen:_sheet()
    return self.store.current and self.store.sheets[self.store.current]
end

function ScoreScreen:_redraw()
    self:buildLayout()
    UIManager:setDirty(self, function() return "ui", self.dimen end)
end

function ScoreScreen:_title()
    local s = self:_sheet()
    if self.view == "home" or not s then return _("Score sheets") end
    if s.kind == "belote" then
        return s.opts.variant == "coinche" and _("Coinche") or _("Belote")
    end
    return KIND_LABEL[s.kind]
end

-- ---------------------------------------------------------------------------
-- Names (remembered through game-common's party.lua)
-- ---------------------------------------------------------------------------

local function nameOpts(kind)
    return kind == "belote" and { teams = true } or nil
end

function ScoreScreen:_countFor(kind)
    local lim = Sheet.LIMITS[kind]
    local n = tonumber(self.plugin:getSetting("count_" .. kind, lim.default)) or lim.default
    return math.max(lim.min, math.min(lim.max, n))
end

function ScoreScreen:_newSheet(kind, n)
    n = n or self:_countFor(kind)
    local names = Party.loadPlayers(self.plugin, n, nameOpts(kind))
    local opts = self.plugin:getSetting("opts_" .. kind, nil)
    return Sheet.new(kind, names, type(opts) == "table" and opts or nil)
end

function ScoreScreen:_saveOpts()
    local s = self:_sheet()
    if s then self.plugin:saveSetting("opts_" .. s.kind, Sheet.copy(s.opts)) end
end

function ScoreScreen:openSheet(kind)
    if not self.store.sheets[kind] then
        self.store.sheets[kind] = self:_newSheet(kind)
    end
    self.store.current = kind
    self.view = "sheet"
    self.back = 0
    self:_save()
    self:_redraw()
end

function ScoreScreen:goHome()
    self.store.current = nil
    self.view = "home"
    self:_save()
    self:_redraw()
end

function ScoreScreen:renamePlayer(i)
    local s = self:_sheet()
    if not s then return end
    Party.renamePlayer(self.plugin, s.names, i, function(changed)
        if changed then
            self:_save()
            self:_redraw()
        end
    end, nameOpts(s.kind))
end

function ScoreScreen:onNewGame()
    local s = self:_sheet()
    if not s then return end
    local function go()
        self.store.sheets[s.kind] = Sheet.restart(s)
        self.back = 0
        self.view = "sheet"
        self:_save()
        self:_redraw()
    end
    if #s.rounds == 0 then return go() end
    UIManager:show(ConfirmBox:new{
        text = _("Start a new game with the same names? The current scores will be cleared."),
        ok_text = _("New game"),
        ok_callback = go,
    })
end

function ScoreScreen:_setCount(n)
    local s = self:_sheet()
    local function go()
        self.plugin:saveSetting("count_" .. s.kind, n)
        local fresh = self:_newSheet(s.kind, n)
        fresh.opts = s.opts
        self.store.sheets[s.kind] = fresh
        self.back = 0
        self:_save()
        self:_redraw()
    end
    if #s.rounds == 0 then return go() end
    UIManager:show(ConfirmBox:new{
        text = _("Changing the number of players starts a new game. Continue?"),
        ok_callback = go,
    })
end

-- ---------------------------------------------------------------------------
-- Rounds: add, undo, details
-- ---------------------------------------------------------------------------

function ScoreScreen:onAddRound()
    local s = self:_sheet()
    if not s or Sheet.isOver(s) then return end
    self.form = self:_newForm(s)
    self.view = "entry"
    self:_redraw()
end

function ScoreScreen:onEndWords()
    local s = self:_sheet()
    if not s or s.kind ~= "words" or s.finished then return end
    self.form = self:_newForm(s, true)
    self.view = "entry"
    self:_redraw()
end

function ScoreScreen:onCancelEntry()
    self.form = nil
    self.view = "sheet"
    self:_redraw()
end

function ScoreScreen:onUndo()
    local s = self:_sheet()
    if not s or #s.rounds == 0 then return end
    local what = s.kind == "words" and _("Remove the last turn?") or _("Remove the last round?")
    UIManager:show(ConfirmBox:new{
        text = what,
        ok_text = _("Remove the last round"),
        ok_callback = function()
            Sheet.undo(s)
            self.back = 0
            self:_save()
            self:_redraw()
        end,
    })
end

function ScoreScreen:_signedList(s, deltas)
    local parts = {}
    for i = 1, #s.names do
        if deltas[i] ~= nil then
            parts[#parts + 1] = T(_("%1: %2"), s.names[i], NumEntry.signed(deltas[i]))
        end
    end
    return table.concat(parts, "\n")
end

-- A few words on one round, for the details popup.
function ScoreScreen:_describe(s, k)
    local r = s.rounds[k]
    local info = r.info or {}
    local lines = {}
    if s.kind == "tarot" and info.taker then
        lines[#lines + 1] = T(_("Deal %1"), k)
        local who = s.names[info.taker]
        if info.partner and info.partner ~= info.taker and #s.names == 5 then
            who = who .. " + " .. s.names[info.partner]
        end
        lines[#lines + 1] = who .. " · " .. (CONTRACT_LABEL[info.contract] or "")
        lines[#lines + 1] = T(_("Oudlers: %1 · %2 points (%3 needed)"), info.oudlers,
                              NumEntry.plain(info.points), Tarot.NEEDED[info.oudlers] or "")
        local diff = info.diff or 0
        lines[#lines + 1] = diff >= 0 and T(_("Made by %1"), diff) or T(_("Failed by %1"), -diff)
        local extra = {}
        if info.petit == "attack" then extra[#extra + 1] = _("Petit au bout: taker")
        elseif info.petit == "defense" then extra[#extra + 1] = _("Petit au bout: defence") end
        if info.poignee then extra[#extra + 1] = T(_("Poignée (taker): %1"), self:_poigneeLabel(info.poignee)) end
        if info.poignee_def then
            extra[#extra + 1] = T(_("Poignée (defence): %1"), self:_poigneeLabel(info.poignee_def))
        end
        if info.chelem then extra[#extra + 1] = T(_("Chelem: %1"), self:_chelemLabel(info.chelem)) end
        for _i, e in ipairs(extra) do lines[#lines + 1] = e end
    elseif s.kind == "belote" and info.taker then
        lines[#lines + 1] = T(_("Hand %1"), k)
        local take = T(_("Taken by %1"), s.names[info.taker])
        if info.bid then
            take = take .. " · " .. (info.bid >= Belote.CAPOT_BID and _("Capot") or tostring(info.bid))
            if info.coinche == "coinche" then take = take .. " · " .. _("Coinche") end
            if info.coinche == "surcoinche" then take = take .. " · " .. _("Surcoinche") end
        end
        lines[#lines + 1] = take
        if info.capot == "taker" then lines[#lines + 1] = _("Capot by the takers")
        elseif info.capot == "defense" then lines[#lines + 1] = _("Capot by the defence")
        else lines[#lines + 1] = T(_("Card points: %1 / %2"), info.points or 0, Belote.TOTAL - (info.points or 0)) end
        if info.belote then lines[#lines + 1] = T(_("Belote-rebelote: %1"), s.names[info.belote]) end
        if info.litige then lines[#lines + 1] = T(_("Tie: %1 points carried to the next hand"), info.carry or 0)
        elseif info.made == false then lines[#lines + 1] = _("Contract failed (dedans)")
        else lines[#lines + 1] = _("Contract made") end
    elseif info.final then
        lines[#lines + 1] = _("Tiles left at the end")
    elseif s.kind == "words" then
        local p = info.player or 1
        lines[#lines + 1] = T(_("Turn %1 · %2"), k, s.names[p])
        if info.pass then lines[#lines + 1] = _("Passed") end
        if info.bonus then lines[#lines + 1] = T(_("Including the +%1 bonus"), info.bonus) end
    else
        lines[#lines + 1] = T(_("Round %1"), k)
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = self:_signedList(s, r.deltas)
    return table.concat(lines, "\n")
end

function ScoreScreen:showRound(row)
    local s = self:_sheet()
    if not s or not row then return end
    local texts = {}
    for _i, k in ipairs(row.rounds) do texts[#texts + 1] = self:_describe(s, k) end
    UIManager:show(InfoMessage:new{
        text = table.concat(texts, "\n\n"),
        show_icon = false,
    })
end

function ScoreScreen:_finalText(s)
    local lines = {}
    local leaders = Sheet.leaders(s)
    if #leaders == 1 then
        lines[1] = T(_("%1 wins!"), s.names[leaders[1]])
    else
        lines[1] = _("It's a tie!")
    end
    lines[2] = ""
    for _i, e in ipairs(Sheet.ranking(s)) do
        local line = T(_("%1. %2 — %3"), e.rank, s.names[e.index], NumEntry.plain(e.total))
        if e.out then line = line .. "  ✗" end
        lines[#lines + 1] = line
    end
    return table.concat(lines, "\n")
end

-- ---------------------------------------------------------------------------
-- The entry form
-- ---------------------------------------------------------------------------

function ScoreScreen:_newForm(s, leftover)
    local kind = s.kind
    if kind == "tarot" then
        return { kind = "tarot", pts = "" }
    elseif kind == "belote" then
        return { kind = "belote", pts = "", coinche_v = s.opts.variant == "coinche" }
    elseif kind == "words" and not leftover then
        return { kind = "words", pts = "", player = Sheet.nextPlayer(s), bonus = false }
    end
    -- One value per player: rummy, free sheet, word game leftovers.
    local f = { kind = "values", vals = {}, sel = nil, leftover = leftover,
                signed = kind == "free", skip = {} }
    if kind == "rummy" then
        local totals = Sheet.totals(s)
        for i = 1, #s.names do
            if Sheet.isEliminated(s, i, totals) then f.skip[i] = true end
        end
    end
    for i = 1, #s.names do
        f.vals[i] = ""
        if not f.sel and not f.skip[i] then f.sel = i end
    end
    return f
end

-- Deltas for the form, or nil and what is missing.
function ScoreScreen:_compute()
    local s, f = self:_sheet(), self.form
    local n = #s.names
    if f.kind == "tarot" then
        if not f.taker then return nil, _("Choose the taker.") end
        if n == 5 and not f.partner then return nil, _("Choose the called partner (or the taker if alone).") end
        if not f.contract then return nil, _("Choose the contract.") end
        if not f.oudlers then return nil, _("How many oudlers?") end
        local pts = NumEntry.value(f.pts)
        if not pts then return nil, _("Type the taker's points on the keypad.") end
        if pts > Tarot.TOTAL then return nil, T(_("At most %1 points."), Tarot.TOTAL) end
        local d = { taker = f.taker, partner = f.partner, contract = f.contract, oudlers = f.oudlers,
                    points = pts, petit = f.petit, poignee = f.poignee, poignee_def = f.poignee_def,
                    chelem = f.chelem }
        local deltas, det = Tarot.score(d, n)
        d.diff = det.diff
        return deltas, d
    elseif f.kind == "belote" then
        if not f.taker then return nil, _("Which team took?") end
        if f.coinche_v and not f.bid then return nil, _("Choose the bid.") end
        local pts = NumEntry.value(f.pts)
        if not f.capot and not pts then return nil, _("Type the takers' card points on the keypad.") end
        if pts and pts > Belote.TOTAL then return nil, T(_("At most %1 points."), Belote.TOTAL) end
        local h = { taker = f.taker, points = pts or 0, belote = f.belote, capot = f.capot,
                    bid = f.bid, coinche = f.coinche }
        local deltas, det
        if f.coinche_v then
            deltas, det = Belote.coinche(h)
        else
            deltas, det = Belote.classic(h, Sheet.carry(s))
            h.carry = det.carry
            h.litige = det.litige
        end
        h.made = det.made
        return deltas, h
    elseif f.kind == "words" then
        local pts = NumEntry.value(f.pts)
        if not pts then return nil, _("Type the word score on the keypad.") end
        local bonus = f.bonus and (s.opts.bonus or 50) or nil
        local deltas = {}
        deltas[f.player] = pts + (bonus or 0)
        return deltas, { player = f.player, bonus = bonus }
    end
    local vals = {}
    for i = 1, n do vals[i] = f.skip[i] and 0 or (NumEntry.value(f.vals[i]) or 0) end
    if f.leftover then
        return Sheet.leftoverDeltas(vals), { final = true }
    end
    local deltas = {}
    for i = 1, n do deltas[i] = (not f.skip[i]) and vals[i] or nil end
    return deltas, {}
end

function ScoreScreen:onValidate()
    local s = self:_sheet()
    local deltas, info = self:_compute()
    if not deltas then
        self:updateStatus(info)
        return
    end
    Sheet.addRound(s, deltas, info)
    if info.final then s.finished = true end
    self.form = nil
    self.view = "sheet"
    self.back = 0
    self:_save()
    self:_redraw()
    if Sheet.isOver(s) then
        UIManager:show(InfoMessage:new{ text = self:_finalText(s), show_icon = false })
    end
end

function ScoreScreen:onPass()
    local f = self.form
    if not f or f.kind ~= "words" then return end
    local s = self:_sheet()
    local deltas = {}
    deltas[f.player] = 0
    Sheet.addRound(s, deltas, { player = f.player, pass = true })
    self.form = nil
    self.view = "sheet"
    self:_save()
    self:_redraw()
end

function ScoreScreen:onKey(key)
    local f = self.form
    if not f then return end
    if f.kind == "values" then
        if key == "next" then
            self:_nextValue()
        elseif f.sel then
            f.vals[f.sel] = NumEntry.press(f.vals[f.sel], key, { signed = f.signed, max_digits = 4 })
        end
    else
        local opts = { half = f.kind == "tarot", max_digits = 3 }
        f.pts = NumEntry.press(f.pts, key, opts)
    end
    self:_redraw()
end

function ScoreScreen:_nextValue()
    local f = self.form
    local n = #f.vals
    local i = f.sel or 0
    for _k = 1, n do
        i = i % n + 1
        if not f.skip[i] then f.sel = i; return end
    end
end

function ScoreScreen:_set(field, value)
    local f = self.form
    f[field] = value
    -- A Tarot taker alone with 5 players: the partner is himself.
    if field == "taker" and f.partner and f.partner == f.taker then f.partner = value end
    self:_redraw()
end

-- ---------------------------------------------------------------------------
-- Menus
-- ---------------------------------------------------------------------------

function ScoreScreen:_askNumber(title, current, on_value)
    local dialog
    dialog = InputDialog:new{
        title = title,
        input = current and tostring(current) or "",
        input_type = "number",
        buttons = { {
            { text = _("Cancel"), id = "close", callback = function() UIManager:close(dialog) end },
            { text = _("OK"), is_enter_default = true, callback = function()
                local v = tonumber(dialog:getInputText())
                UIManager:close(dialog)
                if v and v >= 0 then on_value(math.floor(v)) end
            end },
        } },
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

function ScoreScreen:openCountMenu()
    local s = self:_sheet()
    local lim = Sheet.LIMITS[s.kind]
    local items = {}
    for n = lim.min, lim.max do items[#items + 1] = { id = n, text = tostring(n) } end
    MenuHelper.openPickerMenu{
        title = _("Number of players"), items = items, current_id = #s.names, parent = self,
        on_select = function(n) if n ~= #s.names then self:_setCount(n) end end,
    }
end

function ScoreScreen:openTargetMenu()
    local s = self:_sheet()
    local items = {}
    if s.kind == "free" then items[1] = { id = 0, text = _("No target") } end
    for _i, v in ipairs(Belote.TARGETS) do items[#items + 1] = { id = v, text = tostring(v) } end
    items[#items + 1] = { id = "custom", text = _("Other…") }
    MenuHelper.openPickerMenu{
        title = _("Target score"), items = items, current_id = s.opts.target, parent = self,
        on_select = function(v)
            local function apply(x)
                s.opts.target = x
                self:_saveOpts(); self:_save(); self:_redraw()
            end
            if v == "custom" then
                self:_askNumber(_("Target score"), s.opts.target, apply)
            else
                apply(v)
            end
        end,
    }
end

function ScoreScreen:_menuItems()
    local items = {}
    local s = self:_sheet()
    if self.view == "home" or not s then
        items[#items + 1] = { text = _("Rules"), callback = function() self:showRules(lang2(Rules.home)) end }
        return items
    end
    if self.view == "entry" then
        items[#items + 1] = { text = _("Cancel this round"), callback = function() self:onCancelEntry() end }
    else
        items[#items + 1] = { text = _("New game"), callback = function() self:onNewGame() end }
    end
    local lim = Sheet.LIMITS[s.kind]
    if lim.min ~= lim.max and self.view == "sheet" then
        items[#items + 1] = { text = T(_("Players: %1"), #s.names), callback = function() self:openCountMenu() end }
    end
    items[#items + 1] = { text = s.kind == "belote" and _("Team names") or _("Player names"),
        callback = function()
            Party.editPlayers(self.plugin, s.names, function()
                self:_save(); self:_redraw()
            end, self, nameOpts(s.kind))
        end }
    if s.kind == "belote" and self.view == "sheet" then
        local coinche = s.opts.variant == "coinche"
        items[#items + 1] = {
            text = T(_("Variant: %1"), coinche and _("Coinche") or _("Belote")),
            callback = function()
                if #s.rounds > 0 then
                    self:showMessage(_("Change the variant before the first hand, or start a new game."))
                    return
                end
                s.opts.variant = coinche and "classic" or "coinche"
                self:_saveOpts(); self:_save(); self:_redraw()
            end }
    end
    if (s.kind == "belote" or s.kind == "free") and self.view == "sheet" then
        local t = s.opts.target or 0
        items[#items + 1] = { text = T(_("Target score: %1"), t > 0 and t or _("No target")),
                              callback = function() self:openTargetMenu() end }
    end
    if s.kind == "free" and self.view == "sheet" then
        items[#items + 1] = {
            text = s.opts.low and _("Winner: lowest total") or _("Winner: highest total"),
            callback = function()
                s.opts.low = not s.opts.low
                self:_saveOpts(); self:_save(); self:_redraw()
            end }
    end
    if s.kind == "rummy" and self.view == "sheet" then
        items[#items + 1] = { text = T(_("Elimination over: %1"), s.opts.threshold or 100),
            callback = function()
                self:_askNumber(_("Elimination over"), s.opts.threshold or 100, function(v)
                    if v < 1 then return end
                    s.opts.threshold = v
                    self:_saveOpts(); self:_save(); self:_redraw()
                end)
            end }
    end
    if self.view == "sheet" then
        items[#items + 1] = { text = _("All score sheets"), callback = function() self:goHome() end }
    end
    items[#items + 1] = { text = _("Rules"), callback = function() self:showRules(lang2(Rules[s.kind])) end }
    return items
end

-- ---------------------------------------------------------------------------
-- Layout
-- ---------------------------------------------------------------------------

function ScoreScreen:buildLayout()
    local s = self:_sheet()
    if not s then self.view = "home" end
    self.title_bar = self:buildTitleBar(self:_title(), function() return self:_menuItems() end)
    if self.view == "home" then
        self:_layoutHome()
    elseif self.view == "entry" and self.form then
        self:_layoutEntry()
    else
        self.view = "sheet"
        self:_layoutSheet()
    end
end

-- Places content + controls: below each other in portrait, side by side in
-- landscape.
function ScoreScreen:_place(content, controls, content_w, content_h, top)
    if top then
        -- Pinned under the title bar: a sheet grows downwards, round by round.
        local g = self:getGutter()
        local tb_h = self.title_bar:getSize().h
        if self:isLandscape() then
            local avail = self.dimen.h - tb_h
            local ch = controls:getSize().h
            local cpad = math.max(0, math.floor((avail - ch) / 2))
            self.layout = VerticalGroup:new{
                align = "left",
                self.title_bar,
                HorizontalGroup:new{
                    align = "top",
                    hspan(g),
                    VerticalGroup:new{ align = "left", vspan(g), content },
                    hspan(math.max(0, self.dimen.w - 3 * g - content_w - controls:getSize().w + g)),
                    VerticalGroup:new{ align = "center", vspan(cpad), controls },
                },
            }
        else
            local free = self.dimen.h - tb_h - g - content:getSize().h - controls:getSize().h - g
            self.layout = VerticalGroup:new{
                align = "center",
                self.title_bar,
                vspan(g),
                content,
                vspan(math.max(0, free)),
                controls,
                vspan(g),
            }
        end
        self[1] = self.layout
        return
    end
    if self:isLandscape() then
        local g = self:getGutter()
        self:buildLandscapeLayout(self.title_bar, HorizontalGroup:new{
            align = "center",
            CenterContainer:new{ dimen = Geom:new{ w = content_w, h = content_h }, content },
            hspan(g),
            controls,
        })
    else
        self:buildPortraitLayout(self.title_bar, content,
            VerticalGroup:new{ align = "center", controls, vspan(self:getGutter()) })
    end
end

function ScoreScreen:_controls(rows, extra)
    local w = self:getControlsWidth()
    self.status_text:setMaxWidth(w)
    local g = VerticalGroup:new{ align = "center" }
    if extra then
        g[#g + 1] = extra
        g[#g + 1] = vspan(Size.span.vertical_large)
    end
    g[#g + 1] = self.status_text
    g[#g + 1] = vspan(Size.span.vertical_large)
    g[#g + 1] = self:buildActionBar(rows, w)
    return g
end

-- Room for the content once the title bar and controls are placed.
function ScoreScreen:_budget(controls)
    local w, h = self:getBoardBudget(self.title_bar, controls)
    return w, h
end

-- Home: one big button per sheet.
function ScoreScreen:_layoutHome()
    self.home_status = _("A game in progress resumes where you left it.")
    local controls = self:_controls({})
    local bw, bh = self:_budget(controls)
    local rows = {}
    for _i, kind in ipairs(Sheet.KINDS) do
        local s = self.store.sheets[kind]
        local text = KIND_LABEL[kind]
        if s and #s.rounds > 0 then
            text = text .. "  ·  " .. (Sheet.isOver(s) and _("finished")
                   or T(_("%1 rounds played"), #s.rounds))
        end
        local k = kind
        rows[#rows + 1] = { { text = text, callback = function() self:openSheet(k) end } }
    end
    local vg = VerticalGroup:new{ align = "center" }
    local btn_h = math.min(DeviceScreen:scaleBySize(64), math.floor(bh / (#rows * 1.35)))
    for i, row in ipairs(rows) do
        if i > 1 then vg[#vg + 1] = vspan(btn_h * 0.3) end
        vg[#vg + 1] = Button:new{
            text = row[1].text, width = bw, height = btn_h, text_font_size = 24,
            radius = Size.radius.button, bordersize = Size.border.thick, callback = row[1].callback,
        }
    end
    self:_place(vg, controls, bw, bh)
    self:updateStatus()
end

function ScoreScreen:_sheetStatus(s)
    local leaders, best = Sheet.leaders(s)
    local names = {}
    for _i, i in ipairs(leaders) do names[#names + 1] = s.names[i] end
    if #s.rounds == 0 then
        if s.kind == "words" then return _("Tap a name to rename it · + Turn to enter a word.") end
        return _("Tap a name to rename it · + Round to enter the first round.")
    end
    if Sheet.isOver(s) then
        if #leaders == 1 then return T(_("%1 wins!"), names[1]) end
        return T(_("Tie: %1"), table.concat(names, ", "))
    end
    local parts = {}
    if #leaders == 1 then
        parts[#parts + 1] = T(_("Leader: %1 (%2)"), names[1], NumEntry.plain(best))
    else
        parts[#parts + 1] = T(_("Tie: %1"), table.concat(names, ", "))
    end
    if s.kind == "words" then
        parts[#parts + 1] = T(_("Next: %1"), s.names[Sheet.nextPlayer(s)])
    elseif s.kind == "rummy" then
        parts[#parts + 1] = T(_("Out over %1"), s.opts.threshold or 100)
    elseif (s.opts.target or 0) > 0 then
        parts[#parts + 1] = T(_("Target %1"), s.opts.target)
    end
    if s.kind == "belote" and Sheet.carry(s) > 0 then
        parts[#parts + 1] = T(_("%1 in dispute"), Sheet.carry(s))
    end
    return self:joinStatus((table.unpack or unpack)(parts))
end

function ScoreScreen:_layoutSheet()
    local s = self:_sheet()
    local over = Sheet.isOver(s)
    local add_text = s.kind == "words" and _("+ Turn") or (s.kind == "tarot" and _("+ Deal")
                     or (s.kind == "belote" and _("+ Hand") or _("+ Round")))
    local rows
    if over then
        rows = { { text = _("Remove the last round"), callback = function() self:onUndo() end },
                 { text = _("New game"), callback = function() self:onNewGame() end } }
    elseif s.kind == "words" then
        rows = { { text = _("Remove the last round"), enabled = #s.rounds > 0, callback = function() self:onUndo() end },
                 { text = _("End of game"), enabled = #s.rounds > 0, callback = function() self:onEndWords() end },
                 { text = add_text, callback = function() self:onAddRound() end } }
    else
        rows = { { text = _("Remove the last round"), enabled = #s.rounds > 0, callback = function() self:onUndo() end },
                 { text = add_text, callback = function() self:onAddRound() end } }
    end
    self.home_status = nil
    local controls = self:_controls(rows)
    local bw, bh = self:_budget(controls)

    local all = Sheet.rows(s)
    local cap = ScoreTable.capacity(bh)
    local total_rows = #all
    local max_back = math.max(0, total_rows - cap)
    self.back = math.max(0, math.min(self.back or 0, max_back))
    local last = total_rows - self.back
    local first = math.max(1, last - cap + 1)
    local shown, marks = {}, {}
    for k = first, last do
        local row = all[k]
        local cells = {}
        for i = 1, #s.names do
            local v = row.cells[i]
            cells[i] = v ~= nil and (s.kind == "tarot" and NumEntry.signed(v) or NumEntry.plain(v)) or nil
        end
        local label = row.final and "−" or tostring(k)
        local info = s.rounds[row.rounds[1]].info or {}
        local mk = {}
        if s.kind == "tarot" and info.contract then
            label = label .. " " .. CONTRACT_SHORT[info.contract]
            mk[info.taker] = true
            if info.partner then mk[info.partner] = true end
        elseif s.kind == "belote" and info.taker then
            mk[info.taker] = true
            if info.made == false then label = label .. " ✗" elseif info.litige then label = label .. " =" end
        end
        shown[#shown + 1] = { label = label, cells = cells, src = row }
        marks[#shown] = mk
    end
    local totals, tt = Sheet.totals(s), {}
    for i, v in ipairs(totals) do tt[i] = NumEntry.plain(v) end
    local lead = {}
    if #s.rounds > 0 then
        for _i, i in ipairs((Sheet.leaders(s))) do lead[i] = true end
    end
    local out = {}
    for i = 1, #s.names do out[i] = Sheet.isEliminated(s, i, totals) end
    local note
    if first > 1 or self.back > 0 then
        local after = total_rows - last
        if after > 0 then
            note = T(_("Rounds %1–%2 of %3 · swipe to scroll"), first, last, total_rows)
        else
            note = T(_("%1 earlier rounds · swipe down to see them"), first - 1)
        end
    end
    local tbl = ScoreTable:new{
        width = bw, max_height = bh, names = s.names, rows = shown, totals = tt,
        lead = lead, out = out, marks = marks, note = note,
        next_seat = (s.kind == "words" and not over) and Sheet.nextPlayer(s) or nil,
        on_header = function(i) self:renamePlayer(i) end,
        on_row = function(k) self:showRound(shown[k] and shown[k].src) end,
        on_swipe = function(dir)
            -- swipe down shows earlier rounds
            local step = math.max(1, cap - 2)
            self.back = (self.back or 0) + (dir == "south" and step or -step)
            self:_redraw()
        end,
    }
    self:_place(tbl, controls, bw, bh, true)
    self:updateStatus()
end

-- ---------------------------------------------------------------------------
-- Entry layout
-- ---------------------------------------------------------------------------

-- One labelled row of choice buttons; the chosen one is inverted. More than
-- `per_line` options wrap onto several lines.
function ScoreScreen:_choiceRow(label, options, selected, on_pick, m)
    local per_line = m.per_line or 5
    local count = #options
    local cols = count > per_line and math.ceil(count / math.ceil(count / per_line)) or count
    local gap = Size.span.horizontal_small
    local btn_w = math.floor((m.field_w - gap * (cols - 1)) / cols)
    local lines = VerticalGroup:new{ align = "left" }
    local line
    for k, o in ipairs(options) do
        if (k - 1) % cols == 0 then
            if line then lines[#lines + 1] = line; lines[#lines + 1] = vspan(gap) end
            line = HorizontalGroup:new{ align = "center" }
        else
            line[#line + 1] = hspan(gap)
        end
        local id = o.id
        line[#line + 1] = Button:new{
            text = o.text, width = btn_w, height = m.btn_h, text_font_size = m.font,
            preselect = (selected == id), bordersize = Size.border.button,
            radius = Size.radius.button, margin = 0, padding = Size.padding.small,
            callback = function() on_pick(id) end,
        }
    end
    if line then lines[#lines + 1] = line end
    return self:_labelled(label, lines, m)
end

function ScoreScreen:_labelled(label, widget, m)
    local lbl = TextBoxWidget:new{ text = label, face = pxFace(m.label_px, true), width = m.label_w - Size.padding.small }
    local h = math.max(lbl:getSize().h, widget:getSize().h)
    return HorizontalGroup:new{
        align = "center",
        LeftContainer:new{ dimen = Geom:new{ w = m.label_w, h = h }, lbl },
        widget,
    }
end

-- A framed number: the value being typed. `active` draws it thicker.
function ScoreScreen:_valueBox(text, w, h, active, hint)
    local face = pxFace(h * 0.6, true)
    local txt = TextWidget:new{ text = text ~= "" and text or " ", face = face, bold = true,
                                max_width = w - 2 * Size.padding.default }
    local inner = HorizontalGroup:new{ align = "center", txt }
    if hint then
        inner[#inner + 1] = hspan(Size.padding.large)
        inner[#inner + 1] = TextWidget:new{ text = hint, face = pxFace(h * 0.38),
                                            fgcolor = Blitbuffer.COLOR_DARK_GRAY }
    end
    return FrameContainer:new{
        bordersize = active and Size.border.thick * 2 or Size.border.thin,
        padding = 0, margin = 0,
        radius = Size.radius.button,
        LeftContainer:new{ dimen = Geom:new{ w = w - 2 * (active and Size.border.thick * 2 or Size.border.thin), h = h },
            HorizontalGroup:new{ hspan(Size.padding.large), inner } },
    }
end

local function playerOptions(names, first)
    local o = {}
    if first then o[1] = first end
    for i, s in ipairs(names) do o[#o + 1] = { id = i, text = s } end
    return o
end

function ScoreScreen:_poigneeLabel(id)
    return ({ simple = _("Single handful"), double = _("Double handful"), triple = _("Triple handful") })[id] or ""
end

function ScoreScreen:_chelemLabel(id)
    return ({ announced = _("Announced"), unannounced = _("Not announced"),
              failed = _("Failed"), defense = _("Defence") })[id] or ""
end

function ScoreScreen:_formContent(m)
    local s, f = self:_sheet(), self.form
    local g = VerticalGroup:new{ align = "left" }
    local function add(w)
        if #g > 0 then g[#g + 1] = vspan(m.row_gap) end
        g[#g + 1] = w
    end
    local function pick(field) return function(v) self:_set(field, v) end end
    local NO = { id = false, text = _("No") }
    local function opt(field) return f[field] == nil and false or f[field] end

    if f.kind == "tarot" then
        local n = #s.names
        add(self:_choiceRow(_("Taker"), playerOptions(s.names), f.taker, pick("taker"), m))
        if n == 5 then
            add(self:_choiceRow(_("Partner"), playerOptions(s.names), f.partner, pick("partner"), m))
        end
        add(self:_choiceRow(_("Contract"), {
            { id = "petite", text = CONTRACT_LABEL.petite }, { id = "garde", text = CONTRACT_LABEL.garde },
            { id = "garde_sans", text = CONTRACT_LABEL.garde_sans },
            { id = "garde_contre", text = CONTRACT_LABEL.garde_contre } }, f.contract, pick("contract"), m))
        add(self:_choiceRow(_("Oudlers"), {
            { id = 0, text = "0" }, { id = 1, text = "1" }, { id = 2, text = "2" }, { id = 3, text = "3" } },
            f.oudlers, pick("oudlers"), m))
        local hint = f.oudlers and T(_("/ %1 needed"), Tarot.NEEDED[f.oudlers]) or _("/ 91")
        add(self:_labelled(_("Points"), self:_valueBox(NumEntry.display(f.pts), m.field_w, m.btn_h, true, hint), m))
        add(self:_choiceRow(_("Petit au bout"), { NO, { id = "attack", text = _("Taker") },
            { id = "defense", text = _("Defence") } }, opt("petit"), function(v) self:_set("petit", v or nil) end, m))
        for _i, side in ipairs({ { key = "poignee", label = _("Poignée (taker)") },
                                 { key = "poignee_def", label = _("Poignée (defence)") } }) do
            add(self:_choiceRow(side.label, { NO, { id = "simple", text = _("Single handful") },
                { id = "double", text = _("Double handful") }, { id = "triple", text = _("Triple handful") } },
                opt(side.key), function(v) self:_set(side.key, v or nil) end, m))
        end
        add(self:_choiceRow(_("Chelem"), { NO, { id = "announced", text = _("Announced") },
            { id = "unannounced", text = _("Not announced") }, { id = "failed", text = _("Failed") },
            { id = "defense", text = _("Defence") } }, opt("chelem"),
            function(v) self:_set("chelem", v or nil) end, m))
    elseif f.kind == "belote" then
        add(self:_choiceRow(_("Taken by"), playerOptions(s.names), f.taker, pick("taker"), m))
        if f.coinche_v then
            local bids = {}
            for _i, b in ipairs(Belote.BIDS) do
                bids[#bids + 1] = { id = b, text = b >= Belote.CAPOT_BID and _("Capot") or tostring(b) }
            end
            add(self:_choiceRow(_("Contract"), bids, f.bid, pick("bid"), m))
            add(self:_choiceRow(_("Coinche"), { NO, { id = "coinche", text = _("Coinche ×2") },
                { id = "surcoinche", text = _("Surcoinche ×4") } }, opt("coinche"),
                function(v) self:_set("coinche", v or nil) end, m))
        end
        local p = NumEntry.value(f.pts)
        local hint = p and p <= Belote.TOTAL and T(_("other team: %1"), Belote.TOTAL - p) or _("/ 162")
        add(self:_labelled(_("Takers' points"), self:_valueBox(NumEntry.display(f.pts), m.field_w, m.btn_h, true, hint), m))
        add(self:_choiceRow(_("Belote-rebelote"), playerOptions(s.names, NO), opt("belote"),
            function(v) self:_set("belote", v or nil) end, m))
        add(self:_choiceRow(_("Capot"), { NO, { id = "taker", text = _("Takers") },
            { id = "defense", text = _("Defence") } }, opt("capot"),
            function(v) self:_set("capot", v or nil) end, m))
    elseif f.kind == "words" then
        add(self:_choiceRow(_("Player"), playerOptions(s.names), f.player, pick("player"), m))
        add(self:_labelled(_("Word score"), self:_valueBox(NumEntry.display(f.pts), m.field_w, m.btn_h, true), m))
        add(self:_choiceRow(_("Bonus"), { NO, { id = true, text = T(_("+%1 (all tiles)"), s.opts.bonus or 50) } },
            f.bonus, function(v) self:_set("bonus", v) end, m))
    else
        if f.leftover then
            add(TextBoxWidget:new{ text = _("Value of the tiles left on each rack:"),
                                   face = pxFace(m.label_px), width = m.label_w + m.field_w })
        end
        local totals = Sheet.totals(s)
        for i, name in ipairs(s.names) do
            local text = f.skip[i] and _("out") or NumEntry.display(f.vals[i])
            local box = self:_valueBox(text, m.field_w, m.btn_h, f.sel == i,
                                       T(_("total %1"), NumEntry.plain(totals[i])))
            local idx = i
            local row = self:_labelled(name, box, m)
            if not f.skip[i] then
                -- Tapping a player's line selects it for the keypad.
                row = TapRow:new{ row, callback = function()
                    f.sel = idx
                    self:_redraw()
                end }
            end
            add(row)
        end
    end
    return g
end

function ScoreScreen:_previewText()
    local s, f = self:_sheet(), self.form
    local deltas, info = self:_compute()
    if not deltas then return info end
    if f.kind == "tarot" then
        local d = info
        local res = d.diff >= 0 and T(_("Made by %1"), d.diff) or T(_("Failed by %1"), -d.diff)
        local def
        for i = 1, #s.names do
            if i ~= d.taker and not (#s.names == 5 and i == d.partner) then def = i; break end
        end
        return self:joinStatus(res, T(_("%1: %2"), s.names[d.taker], NumEntry.signed(deltas[d.taker])),
                               T(_("each defender %1"), NumEntry.signed(deltas[def])))
    elseif f.kind == "belote" then
        local tag = info.litige and _("Tie (litige)") or (info.made and _("Made") or _("Dedans"))
        return self:joinStatus(tag, T(_("%1: %2"), s.names[1], NumEntry.signed(deltas[1])),
                               T(_("%1: %2"), s.names[2], NumEntry.signed(deltas[2])))
    elseif f.kind == "words" then
        return T(_("%1: %2"), s.names[f.player], NumEntry.signed(deltas[f.player]))
    end
    if f.leftover then
        local parts = {}
        for i = 1, #s.names do parts[i] = T(_("%1: %2"), s.names[i], NumEntry.signed(deltas[i])) end
        return self:joinStatus((table.unpack or unpack)(parts))
    end
    return _("Tap a player, type the points; → goes to the next one.")
end

function ScoreScreen:_layoutEntry()
    local s, f = self:_sheet(), self.form
    local land = self:isLandscape()
    local cw = self:getControlsWidth()
    local rows = { { text = _("Cancel"), callback = function() self:onCancelEntry() end } }
    if f.kind == "words" then
        rows[#rows + 1] = { text = _("Pass"), callback = function() self:onPass() end }
    end
    rows[#rows + 1] = { text = _("OK"), callback = function() self:onValidate() end }

    local scale = 1
    local content, controls, bw, bh
    while true do
        local key_h = math.floor(DeviceScreen:scaleBySize(52) * scale)
        local pad = Numpad.build{
            width = cw, key_height = key_h, font_size = math.floor(26 * math.max(scale, 0.8)),
            sign = f.kind == "values" and f.signed, half = f.kind == "tarot",
            next_key = f.kind == "values" and "→" or nil,
            onKey = function(k) self:onKey(k) end,
        }
        controls = self:_controls(rows, pad)
        bw, bh = self:_budget(controls)
        local m = {
            label_w  = math.floor(bw * (land and 0.24 or 0.25)),
            btn_h    = math.floor(DeviceScreen:scaleBySize(42) * scale),
            font     = math.max(14, math.floor(19 * scale)),
            label_px = math.floor(DeviceScreen:scaleBySize(17) * scale),
            row_gap  = math.floor(Size.span.vertical_large * scale),
            per_line = 5,
        }
        m.field_w = bw - m.label_w
        content = self:_formContent(m)
        if content:getSize().h <= bh or scale < 0.6 then break end
        scale = scale * 0.9
    end
    self:_place(content, controls, bw, bh, true)
    self:updateStatus()
end

function ScoreScreen:updateStatus(msg)
    if msg then return ScreenBase.updateStatus(self, msg) end
    local s = self:_sheet()
    local text
    if self.view == "home" or not s then
        text = self.home_status or ""
    elseif self.view == "entry" and self.form then
        text = self:_previewText()
    else
        text = self:_sheetStatus(s)
    end
    ScreenBase.updateStatus(self, text)
end

function ScoreScreen:isRoundOver()
    return false
end

return ScoreScreen
