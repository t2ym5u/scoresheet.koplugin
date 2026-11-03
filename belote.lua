-- belote.lua — Belote and Coinche scoring, two teams (1 and 2).
-- Pure Lua, no KOReader dependency. The house rules chosen here are the
-- common French ones and are listed in README.md.
--
-- One hand:
--   h = {
--     taker   = 1 | 2           (the team that took / won the bidding),
--     points  = card points of the taker's team, 0..162 (incl. dix de der),
--     belote  = nil | 1 | 2     (team holding belote-rebelote: +20, always kept),
--     capot   = nil | "taker" | "defense"  (a team won every trick),
--     -- coinche only:
--     bid     = 80..160 (multiple of 10) or Belote.CAPOT_BID,
--     coinche = nil | "coinche" | "surcoinche",
--   }
--
-- Belote.classic(h, carry) / Belote.coinche(h) return
--   deltas = { team1, team2 }, detail = { made = bool, litige = bool, ... }
-- `carry` is the points left in dispute by a previous classic hand (litige);
-- they go to whichever team wins this hand. classic() also returns the new
-- carry in detail.carry.

local Belote = {}

Belote.TOTAL         = 162   -- 152 in the cards + 10 for the last trick
Belote.BELOTE        = 20
Belote.CAPOT_CLASSIC = 252
Belote.CAPOT_COINCHE = 250
Belote.CAPOT_BID     = 250
Belote.BIDS          = { 80, 90, 100, 110, 120, 130, 140, 150, 160, 250 }
Belote.COINCHE_MULT  = { coinche = 2, surcoinche = 4 }
Belote.TARGETS       = { 1000, 1500, 2000 }

local function other(t) return t == 1 and 2 or 1 end

local function beloteOf(h, team)
    return h.belote == team and Belote.BELOTE or 0
end

-- Classic belote: the taker's team must make more points than the other
-- (belote-rebelote counted on both sides). Made: each team scores what it
-- made. Failed ("dedans"): the defence scores all 162. A tie ("litige"):
-- the defence scores its half, the taker's half waits for the next hand.
function Belote.classic(h, carry)
    carry = carry or 0
    local t, d = h.taker, other(h.taker)
    local tp, dp
    if h.capot == "taker" then
        tp, dp = Belote.CAPOT_CLASSIC, 0
    elseif h.capot == "defense" then
        tp, dp = 0, Belote.CAPOT_CLASSIC
    else
        tp = math.max(0, math.min(Belote.TOTAL, h.points or 0))
        dp = Belote.TOTAL - tp
    end
    local t_total = tp + beloteOf(h, t)
    local d_total = dp + beloteOf(h, d)
    local deltas = { 0, 0 }
    local detail = { carry = 0 }
    if h.capot ~= "defense" and t_total > d_total then
        detail.made = true
        deltas[t] = t_total + carry
        deltas[d] = d_total
    elseif h.capot ~= "defense" and t_total == d_total then
        detail.litige = true
        deltas[d] = d_total
        deltas[t] = beloteOf(h, t)
        detail.carry = carry + tp
    else
        detail.made = false
        local all = h.capot == "defense" and Belote.CAPOT_CLASSIC or Belote.TOTAL
        deltas[d] = all + beloteOf(h, d) + carry
        deltas[t] = beloteOf(h, t)
    end
    return deltas, detail
end

-- Coinche ("points faits + contrat"): the taker's team must reach its bid
-- (belote-rebelote counts towards it) and beat the defence (82 or more); a
-- capot bid needs every trick.
--   made, not coinched: taker = bid + its points, defence = its points
--   made, coinched:     taker = bid × mult + 160, defence = 0
--   failed:             defence = bid × mult + 160, taker = 0
-- Belote-rebelote is always kept by the team that holds it. An unannounced
-- capot counts 250 card points.
function Belote.coinche(h)
    local t, d = h.taker, other(h.taker)
    local bid = h.bid or 80
    local mult = Belote.COINCHE_MULT[h.coinche] or 1
    local tp, dp
    if h.capot == "taker" then
        tp, dp = Belote.CAPOT_COINCHE, 0
    elseif h.capot == "defense" then
        tp, dp = 0, Belote.CAPOT_COINCHE
    else
        tp = math.max(0, math.min(Belote.TOTAL, h.points or 0))
        dp = Belote.TOTAL - tp
    end
    local made
    if bid >= Belote.CAPOT_BID then
        made = h.capot == "taker"
    else
        local reached = tp + beloteOf(h, t)
        made = reached >= bid and reached >= 82 and h.capot ~= "defense"
    end
    local deltas = { beloteOf(h, 1), beloteOf(h, 2) }
    if made then
        if mult == 1 then
            deltas[t] = deltas[t] + bid + tp
            deltas[d] = deltas[d] + dp
        else
            deltas[t] = deltas[t] + bid * mult + 160
        end
    else
        deltas[d] = deltas[d] + bid * mult + 160
    end
    return deltas, { made = made, multiplier = mult }
end

return Belote
