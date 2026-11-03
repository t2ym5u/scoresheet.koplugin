-- score_table.lua — the score sheet itself: a header of names, one line per
-- round, a bold totals line. Drawn as one widget (text and rules painted in
-- place), so a new round costs one repaint of the table and nothing else.
--
--   ScoreTable:new{
--     width, max_height,              -- room given
--     names     = { "Alice", ... },
--     rows      = { { label = "3", cells = { "+318", "−106", ... } }, ... },
--     totals    = { "318", ... },
--     lead      = { [i] = true },     -- totals shown inverted (leader/winner)
--     out       = { [i] = true },     -- struck players (rummy)
--     marks     = { [row] = { [i] = true } } -- bold cells (the taker)
--     note      = "7 earlier rounds",  -- optional grey line above the rows
--     on_header = function(i) end,    -- tap on a name
--     on_row    = function(k) end,    -- tap on a round line (k = index in rows)
--     on_swipe  = function(dir) end,  -- "north" / "south"
--   }

local Blitbuffer     = require("ffi/blitbuffer")
local Device         = require("device")
local Font           = require("ui/font")
local Geom           = require("ui/geometry")
local GestureRange   = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local RenderText     = require("ui/rendertext")
local Size           = require("ui/size")
local TextWidget     = require("ui/widget/textwidget")

local DeviceScreen = Device.screen
local DPI_SCALE = DeviceScreen:scaleBySize(1000) / 1000

local function face(px, bold)
    return Font:getFace(bold and "smallinfofontbold" or "smallinfofont",
                        math.max(8, math.floor(px / DPI_SCALE)))
end

local function textWidth(f, s, bold)
    return RenderText:sizeUtf8Text(0, 10000, f, s, true, bold).x
end

local ScoreTable = InputContainer:extend{
    width = nil, max_height = nil,
    names = nil, rows = nil, totals = nil,
    lead = nil, out = nil, marks = nil, note = nil,
}

-- Rows that fit in `max_height` for `ncols` players at the nominal size.
function ScoreTable.rowHeight()
    return DeviceScreen:scaleBySize(30)
end

function ScoreTable.capacity(max_height)
    local rh = ScoreTable.rowHeight()
    -- header + totals take about 2.6 rows, the note line one more
    return math.max(1, math.floor(max_height / rh) - 4)
end

function ScoreTable:init()
    self.lead  = self.lead or {}
    self.out   = self.out or {}
    self.marks = self.marks or {}
    local n = #self.names
    local rh = ScoreTable.rowHeight()
    self.row_h = rh
    self.head_h = math.floor(rh * 1.3)
    self.total_h = math.floor(rh * 1.3)
    self.note_h = self.note and math.floor(rh * 0.9) or 0

    -- Label column: as wide as its widest label, at least "88".
    local px = math.floor(rh * 0.62)
    local lf = face(px * 0.85)
    local lw = textWidth(lf, "88", false)
    for _i, r in ipairs(self.rows) do
        lw = math.max(lw, textWidth(lf, r.label or "", false))
    end
    self.label_w = math.min(math.floor(self.width * 0.22), lw + 2 * Size.padding.default)
    self.col_w = math.floor((self.width - self.label_w) / math.max(1, n))

    -- Shrink the figures until the widest one fits its column.
    local widest = "−0000"
    for _i, r in ipairs(self.rows) do
        for i = 1, n do
            local s = r.cells[i] or ""
            if #s > #widest then widest = s end
        end
    end
    for i = 1, n do
        local s = self.totals[i] or ""
        if #s > #widest then widest = s end
    end
    while px > 10 and textWidth(face(px, true), widest, true) > self.col_w - 2 * Size.padding.small do
        px = px - 1
    end
    self.px = px
    self.label_face = lf
    self.face = face(px)
    self.bold_face = face(px, true)
    self.head_face = face(math.min(px, rh * 0.6), true)

    local h = self.head_h + self.note_h + #self.rows * rh + self.total_h + Size.line.thick
    self.dimen = Geom:new{ x = 0, y = 0, w = self.width, h = h }

    self.ges_events = {
        Tap   = { GestureRange:new{ ges = "tap",   range = function() return self.dimen end } },
        Swipe = { GestureRange:new{ ges = "swipe", range = function() return self.dimen end } },
    }
end

function ScoreTable:getSize()
    return Geom:new{ w = self.dimen.w, h = self.dimen.h }
end

local function paintText(bb, f, s, bold, x, y, w, h, align, color)
    local tw = TextWidget:new{ text = s, face = f, bold = bold, max_width = w - 2 * Size.padding.small,
                               fgcolor = color or Blitbuffer.COLOR_BLACK }
    local sz = tw:getSize()
    local tx
    if align == "left" then
        tx = x + Size.padding.small
    elseif align == "right" then
        tx = x + w - sz.w - Size.padding.small
    else
        tx = x + math.floor((w - sz.w) / 2)
    end
    tw:paintTo(bb, tx, y + math.floor((h - sz.h) / 2))
    tw:free()
end

function ScoreTable:paintTo(bb, x, y)
    self.dimen.x, self.dimen.y = x, y
    local n = #self.names
    local W = self.width
    local thin, thick = Size.line.thin, Size.line.thick
    local black, grey = Blitbuffer.COLOR_BLACK, Blitbuffer.COLOR_DARK_GRAY
    local lx = x + self.label_w

    -- Header: names, centred, bold; a struck player is grey with a cross.
    local cy = y
    for i = 1, n do
        local cx = lx + (i - 1) * self.col_w
        local name = self.names[i]
        if self.out[i] then name = "✗ " .. name end
        if self.next_seat == i then name = "▸ " .. name end
        paintText(bb, self.head_face, name, true, cx, cy, self.col_w, self.head_h, "center",
                  self.out[i] and grey or black)
    end
    cy = cy + self.head_h
    bb:paintRect(x, cy - thick, W, thick, black)

    if self.note then
        paintText(bb, self.label_face, self.note, false, x, cy, W, self.note_h, "center", grey)
        cy = cy + self.note_h
    end

    -- Rounds.
    for k, r in ipairs(self.rows) do
        paintText(bb, self.label_face, r.label or "", false, x, cy, self.label_w, self.row_h, "left", grey)
        local mk = self.marks[k] or {}
        for i = 1, n do
            local s = r.cells[i]
            if s and s ~= "" then
                local cx = lx + (i - 1) * self.col_w
                paintText(bb, mk[i] and self.bold_face or self.face, s, mk[i], cx, cy,
                          self.col_w, self.row_h, "right")
            end
        end
        cy = cy + self.row_h
        if k < #self.rows then
            bb:paintRect(x, cy - thin, W, thin, Blitbuffer.COLOR_LIGHT_GRAY)
        end
    end

    -- Totals: a thick rule, then bold figures; the leaders' cells inverted.
    bb:paintRect(x, cy, W, thick, black)
    cy = cy + thick
    for i = 1, n do
        local cx = lx + (i - 1) * self.col_w
        local s = self.totals[i] or ""
        if self.lead[i] then
            bb:paintRect(cx + thin, cy + thin, self.col_w - 2 * thin, self.total_h - 2 * thin, black)
            paintText(bb, self.bold_face, s, true, cx, cy, self.col_w, self.total_h, "right",
                      Blitbuffer.COLOR_WHITE)
        else
            paintText(bb, self.bold_face, s, true, cx, cy, self.col_w, self.total_h, "right",
                      self.out[i] and grey or black)
        end
    end
    paintText(bb, self.label_face, "Σ", true, x, cy, self.label_w, self.total_h, "left")

    -- Column rules.
    local top, bottom = y, y + self.dimen.h
    for i = 0, n - 1 do
        local cx = lx + i * self.col_w
        bb:paintRect(cx, top, thin, bottom - top, i == 0 and black or grey)
    end
end

function ScoreTable:onTap(_arg, ges)
    local p = ges and ges.pos
    if not p then return false end
    local ry = p.y - self.dimen.y
    if ry < self.head_h then
        local i = math.floor((p.x - self.dimen.x - self.label_w) / self.col_w) + 1
        if i >= 1 and i <= #self.names and self.on_header then self.on_header(i) end
        return true
    end
    ry = ry - self.head_h - self.note_h
    local k = math.floor(ry / self.row_h) + 1
    if ry >= 0 and k >= 1 and k <= #self.rows and self.on_row then
        self.on_row(k)
    end
    return true
end

function ScoreTable:onSwipe(_arg, ges)
    if self.on_swipe and ges and (ges.direction == "north" or ges.direction == "south") then
        self.on_swipe(ges.direction)
        return true
    end
    return false
end

return ScoreTable
