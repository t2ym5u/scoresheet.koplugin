-- tarot.lua — French Tarot scoring (Fédération Française de Tarot rules,
-- "donnes libres"). Pure Lua, no KOReader dependency.
--
-- One deal:
--   d = {
--     taker    = seat index,
--     partner  = seat index (5 players only; nil or == taker: taker alone),
--     contract = "petite" | "garde" | "garde_sans" | "garde_contre",
--     oudlers  = 0..3   (bouts in the taker's tricks),
--     points   = card points made by the taker's side (0..91, halves allowed),
--     petit    = nil | "attack" | "defense"  (petit au bout: who won it),
--     poignee  = nil | "simple" | "double" | "triple"  (shown by the taker's side),
--     poignee_def = same, shown by a defender (both sides may show one),
--     chelem   = nil | "announced" | "unannounced" | "failed" | "defense",
--   }
--
-- Tarot.score(d, nplayers) returns the per-seat deltas (zero-sum), plus a
-- detail table { base, won, diff, points, needed, unit } where `unit` is what
-- each defender pays (positive) or receives (negative).

local Tarot = {}

Tarot.CONTRACTS  = { "petite", "garde", "garde_sans", "garde_contre" }
Tarot.MULTIPLIER = { petite = 1, garde = 2, garde_sans = 4, garde_contre = 6 }
-- Points the taker needs, by number of oudlers.
Tarot.NEEDED     = { [0] = 56, [1] = 51, [2] = 41, [3] = 36 }
Tarot.POIGNEE    = { simple = 20, double = 30, triple = 40 }
-- Trumps a poignée needs, by number of players (shown in the rules).
Tarot.POIGNEE_TRUMPS = {
    [3] = { 13, 15, 18 },
    [4] = { 10, 13, 15 },
    [5] = { 8, 10, 13 },
}
Tarot.CHELEM     = { announced = 400, unannounced = 200, failed = -200, defense = -200 }
Tarot.TOTAL      = 91

-- FFT: a half point goes to the side that wins the deal. With 40½ and 41
-- needed the taker has 40 (one short); with 41½ he has 42.
function Tarot.roundPoints(points, needed)
    if points == math.floor(points) then return points end
    if math.floor(points) >= needed then return math.ceil(points) end
    return math.floor(points)
end

-- The value of the deal for one defender, signed from the taker's side:
-- positive when the taker's side wins it.
function Tarot.dealValue(d)
    local m = Tarot.MULTIPLIER[d.contract] or 1
    local needed = Tarot.NEEDED[d.oudlers or 0] or 56
    local points = Tarot.roundPoints(d.points or 0, needed)
    local diff = points - needed
    local won = diff >= 0
    local sign = won and 1 or -1
    local v = sign * (25 + math.abs(diff)) * m
    if d.petit == "attack" then
        v = v + 10 * m
    elseif d.petit == "defense" then
        v = v - 10 * m
    end
    -- A poignée always goes to the side that wins the deal, whoever showed
    -- it; each side may show one.
    for _i, p in ipairs({ d.poignee, d.poignee_def }) do
        if Tarot.POIGNEE[p] then v = v + sign * Tarot.POIGNEE[p] end
    end
    if d.chelem and Tarot.CHELEM[d.chelem] then
        v = v + Tarot.CHELEM[d.chelem]
    end
    return v, { won = won, diff = diff, points = points, needed = needed, multiplier = m }
end

-- Per-seat deltas for n players (3, 4 or 5), summing to zero.
--   3 players: taker 2×, each defender −1×
--   4 players: taker 3×, each defender −1×
--   5 players: taker 2× and partner 1× (taker alone: 4×), each defender −1×
function Tarot.score(d, n)
    local v, detail = Tarot.dealValue(d)
    local deltas = {}
    for i = 1, n do deltas[i] = -v end
    local alone = n ~= 5 or not d.partner or d.partner == d.taker
    if alone then
        deltas[d.taker] = (n - 1) * v
    else
        deltas[d.taker] = 2 * v
        deltas[d.partner] = v
    end
    detail.unit = v
    return deltas, detail
end

-- A deal is complete enough to score.
function Tarot.isValid(d, n)
    if type(d) ~= "table" or not d.taker or d.taker < 1 or d.taker > n then return false end
    if not Tarot.MULTIPLIER[d.contract] then return false end
    if not Tarot.NEEDED[d.oudlers] then return false end
    if type(d.points) ~= "number" or d.points < 0 or d.points > Tarot.TOTAL then return false end
    if n == 5 and d.partner and (d.partner < 1 or d.partner > n) then return false end
    return true
end

return Tarot
