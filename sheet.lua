-- sheet.lua — one score sheet: who plays, the rounds entered so far, the
-- totals, who leads and when the game is over. Pure data (safe to save
-- with the plugin's settings), no KOReader dependency.
--
--   sheet = {
--     kind   = "tarot" | "belote" | "words" | "rummy" | "free",
--     names  = { "Alice", "Bob", ... }   (teams for belote),
--     rounds = { { deltas = { ... }, info = { ... } }, ... },
--     opts   = { variant = "classic"|"coinche", target = n, threshold = n,
--                low = bool },
--     finished = bool   (word game: leftover tiles entered),
--   }
--
-- A round's deltas has one number per seat; the word game stores one turn
-- per round, with only that player's seat set (the others are nil).

local Sheet = {}

Sheet.KINDS = { "tarot", "belote", "words", "rummy", "free" }

Sheet.LIMITS = {
    tarot  = { min = 3, max = 5, default = 4 },
    belote = { min = 2, max = 2, default = 2 },
    words  = { min = 2, max = 4, default = 2 },
    rummy  = { min = 2, max = 8, default = 4 },
    free   = { min = 1, max = 8, default = 4 },
}

Sheet.DEFAULT_OPTS = {
    tarot  = {},
    belote = { variant = "classic", target = 1000 },
    words  = { bonus = 50 },
    rummy  = { threshold = 100 },
    free   = { target = 0, low = false },
}

local function copy(t)
    if type(t) ~= "table" then return t end
    local c = {}
    for k, v in pairs(t) do c[k] = copy(v) end
    return c
end
Sheet.copy = copy

function Sheet.new(kind, names, opts)
    local o = copy(Sheet.DEFAULT_OPTS[kind] or {})
    for k, v in pairs(opts or {}) do o[k] = v end
    local n = {}
    for i, s in ipairs(names) do n[i] = s end
    return { kind = kind, names = n, rounds = {}, opts = o, finished = false }
end

-- Same players, same options, no rounds.
function Sheet.restart(sheet)
    return Sheet.new(sheet.kind, sheet.names, sheet.opts)
end

function Sheet.totals(sheet)
    local t = {}
    for i = 1, #sheet.names do t[i] = 0 end
    for _i, r in ipairs(sheet.rounds) do
        for i = 1, #sheet.names do
            t[i] = t[i] + (r.deltas[i] or 0)
        end
    end
    return t
end

-- Totals after each round: running[k][i].
function Sheet.running(sheet)
    local out, t = {}, {}
    for i = 1, #sheet.names do t[i] = 0 end
    for k, r in ipairs(sheet.rounds) do
        local row = {}
        for i = 1, #sheet.names do
            t[i] = t[i] + (r.deltas[i] or 0)
            row[i] = t[i]
        end
        out[k] = row
    end
    return out
end

function Sheet.lowestWins(sheet)
    if sheet.kind == "rummy" then return true end
    if sheet.kind == "free" then return sheet.opts.low and true or false end
    return false
end

-- ---------------------------------------------------------------------------
-- Rounds
-- ---------------------------------------------------------------------------

-- Points left in dispute by a belote "litige" (see belote.lua).
function Sheet.carry(sheet)
    local last = sheet.rounds[#sheet.rounds]
    return last and last.info and last.info.carry or 0
end

function Sheet.addRound(sheet, deltas, info)
    local d = {}
    for i = 1, #sheet.names do d[i] = deltas[i] end
    sheet.rounds[#sheet.rounds + 1] = { deltas = d, info = info or {} }
    return #sheet.rounds
end

-- Removes the last round (or the word game's final leftover deduction).
function Sheet.undo(sheet)
    local r = table.remove(sheet.rounds)
    if r and r.info and r.info.final then sheet.finished = false end
    return r
end

-- ---------------------------------------------------------------------------
-- Rummy: a player whose total goes over the threshold is out.
-- ---------------------------------------------------------------------------

function Sheet.isEliminated(sheet, i, totals)
    if sheet.kind ~= "rummy" then return false end
    totals = totals or Sheet.totals(sheet)
    return totals[i] > (sheet.opts.threshold or 100)
end

-- Seats still playing.
function Sheet.active(sheet)
    local totals = Sheet.totals(sheet)
    local out = {}
    for i = 1, #sheet.names do
        if not Sheet.isEliminated(sheet, i, totals) then out[#out + 1] = i end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Word tile game
-- ---------------------------------------------------------------------------

-- Whose turn it is: the seat after the last one that played.
function Sheet.nextPlayer(sheet)
    local n = #sheet.names
    for k = #sheet.rounds, 1, -1 do
        local p = sheet.rounds[k].info.player
        if p then return (p % n) + 1 end
    end
    return 1
end

-- End of game: every player loses the value of the tiles left on their
-- rack; a player who used all their tiles (0 left, while someone still had
-- some) gains the sum of the others' racks.
function Sheet.leftoverDeltas(left)
    local sum, out_players = 0, {}
    for i, v in ipairs(left) do
        sum = sum + v
        if v == 0 then out_players[#out_players + 1] = i end
    end
    local d = {}
    for i, v in ipairs(left) do d[i] = -v end
    if sum > 0 and #out_players == 1 then
        local i = out_players[1]
        d[i] = sum
    end
    return d
end

-- ---------------------------------------------------------------------------
-- Leaders and the end of the game
-- ---------------------------------------------------------------------------

-- Best seats right now (several on a tie). Rummy only ranks the players
-- still in, unless everyone is out.
function Sheet.leaders(sheet)
    local totals = Sheet.totals(sheet)
    local low = Sheet.lowestWins(sheet)
    local pool = {}
    if sheet.kind == "rummy" then pool = Sheet.active(sheet) end
    if #pool == 0 then
        for i = 1, #sheet.names do pool[i] = i end
    end
    local best
    for _i, i in ipairs(pool) do
        local v = totals[i]
        if best == nil or (low and v < best) or (not low and v > best) then best = v end
    end
    local out = {}
    for _i, i in ipairs(pool) do
        if totals[i] == best then out[#out + 1] = i end
    end
    return out, best
end

function Sheet.isOver(sheet)
    local kind = sheet.kind
    if #sheet.rounds == 0 then return false end
    if kind == "words" then return sheet.finished and true or false end
    if kind == "rummy" then return #Sheet.active(sheet) <= 1 end
    local target = sheet.opts.target or 0
    if (kind == "belote" or kind == "free") and target > 0 then
        for _i, v in ipairs(Sheet.totals(sheet)) do
            if v >= target then return true end
        end
    end
    return false
end

-- Seats ranked best first: { { index, total, rank }, ... }; ties share a rank.
function Sheet.ranking(sheet)
    local totals = Sheet.totals(sheet)
    local low = Sheet.lowestWins(sheet)
    local list = {}
    for i = 1, #sheet.names do
        list[i] = { index = i, total = totals[i], out = Sheet.isEliminated(sheet, i, totals) }
    end
    table.sort(list, function(a, b)
        if a.out ~= b.out then return not a.out end
        if a.total ~= b.total then
            if low then return a.total < b.total end
            return a.total > b.total
        end
        return a.index < b.index
    end)
    for k, e in ipairs(list) do
        local p = list[k - 1]
        if p and p.total == e.total and p.out == e.out then e.rank = p.rank else e.rank = k end
    end
    return list
end

-- ---------------------------------------------------------------------------
-- Table rows for display: { { cells = { ... }, rounds = { k, ... } }, ... }
-- Each cell is a number or nil (blank). The word game packs one turn of
-- every player per row; the other games show one round per row.
-- ---------------------------------------------------------------------------

function Sheet.rows(sheet)
    local n = #sheet.names
    local rows = {}
    if sheet.kind ~= "words" then
        for k, r in ipairs(sheet.rounds) do
            local cells = {}
            for i = 1, n do cells[i] = r.deltas[i] end
            rows[k] = { cells = cells, rounds = { k } }
        end
        return rows
    end
    local count = {}
    for i = 1, n do count[i] = 0 end
    local final
    for k, r in ipairs(sheet.rounds) do
        if r.info.final then
            final = { cells = {}, rounds = { k }, final = true }
            for i = 1, n do final.cells[i] = r.deltas[i] end
        else
            local p = r.info.player or 1
            count[p] = count[p] + 1
            local row = rows[count[p]]
            if not row then
                row = { cells = {}, rounds = {} }
                rows[count[p]] = row
            end
            row.cells[p] = r.deltas[p] or 0
            row.rounds[#row.rounds + 1] = k
        end
    end
    if final then rows[#rows + 1] = final end
    return rows
end

-- ---------------------------------------------------------------------------
-- Saved state
-- ---------------------------------------------------------------------------

function Sheet.restore(t)
    if type(t) ~= "table" or type(t.names) ~= "table" or type(t.rounds) ~= "table" then
        return nil
    end
    local lim = Sheet.LIMITS[t.kind]
    if not lim or #t.names < lim.min or #t.names > lim.max then return nil end
    for i = 1, #t.names do
        if type(t.names[i]) ~= "string" then return nil end
    end
    for _i, r in ipairs(t.rounds) do
        if type(r) ~= "table" or type(r.deltas) ~= "table" then return nil end
        r.info = type(r.info) == "table" and r.info or {}
    end
    local o = copy(Sheet.DEFAULT_OPTS[t.kind])
    for k, v in pairs(type(t.opts) == "table" and t.opts or {}) do o[k] = v end
    t.opts = o
    t.finished = t.finished and true or false
    return t
end

return Sheet
