-- numpad.lua — a big on-screen numeric keypad (phone layout, four columns):
--
--     1 2 3 ⌫
--     4 5 6 C
--     7 8 9 ±
--     ½ 0 0 →        (the last row's side keys are optional)
--
--   Numpad.build{ width = px, key_height = px, onKey = function(key) end,
--                 sign = bool, half = bool, next_key = "text" or nil }
--
-- Keys with no use on the current entry are left out (blank space), so a
-- player never taps a key that does nothing.

local Button          = require("ui/widget/button")
local Geom            = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan  = require("ui/widget/horizontalspan")
local Size            = require("ui/size")
local VerticalGroup   = require("ui/widget/verticalgroup")
local VerticalSpan    = require("ui/widget/verticalspan")
local Widget          = require("ui/widget/widget")

local Numpad = {}

function Numpad.build(opts)
    local gap   = Size.span.horizontal_small
    local w     = opts.width
    local key_w = math.floor((w - 3 * gap) / 4)
    local key_h = opts.key_height
    local font  = opts.font_size or 26
    local rows = {
        { "1", "2", "3", "⌫" },
        { "4", "5", "6", "C" },
        { "7", "8", "9", opts.sign and "±" or "" },
        { opts.half and "½" or "", "0", "", opts.next_key or "" },
    }
    local vg = VerticalGroup:new{ align = "center" }
    for r, row in ipairs(rows) do
        if r > 1 then vg[#vg + 1] = VerticalSpan:new{ width = gap } end
        local hg = HorizontalGroup:new{ align = "center" }
        local c = 1
        while c <= 4 do
            local k = row[c]
            local span = 1
            -- "0" takes the empty cell to its right: a wide 0, like a phone.
            if k == "0" and row[c + 1] == "" then span = 2 end
            local kw = key_w * span + gap * (span - 1)
            if k == "" then
                hg[#hg + 1] = Widget:new{ dimen = Geom:new{ w = kw, h = key_h } }
            else
                local key = k
                local is_next = (r == 4 and c == 4)
                hg[#hg + 1] = Button:new{
                    text           = k,
                    width          = kw,
                    height         = key_h,
                    text_font_size = is_next and math.floor(font * 0.75) or font,
                    bordersize     = Size.border.thick,
                    radius         = Size.radius.button,
                    margin         = 0,
                    padding        = Size.padding.tiny,
                    callback       = function() opts.onKey(is_next and "next" or key) end,
                }
            end
            c = c + span
            if c <= 4 then hg[#hg + 1] = HorizontalSpan:new{ width = gap } end
        end
        vg[#vg + 1] = hg
    end
    return vg
end

return Numpad
