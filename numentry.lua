-- numentry.lua — the text behind a number typed on the on-screen keypad.
-- Pure Lua: "" is empty, "-" a lone minus sign, "40.5" a half point.
--
--   s = NumEntry.press(s, key, opts)   -- key: "0".."9", "⌫", "C", "±", "½"
--   NumEntry.value(s)                  -- number, or nil while empty
--
-- opts.max_digits (default 5), opts.signed (allow ±), opts.half (allow ½).

local NumEntry = {}

local function digits(s)
    return #(s:gsub("[^%d]", ""))
end

function NumEntry.press(s, key, opts)
    opts = opts or {}
    s = s or ""
    local max = opts.max_digits or 5
    if key:match("^%d$") then
        if s:find("%.5$") then return s end           -- nothing after ½
        if digits(s) >= max then return s end
        if s == "0" then return key end
        if s == "-0" then return "-" .. key end
        return s .. key
    elseif key == "⌫" then
        if s:find("%.5$") then return s:sub(1, -3) end
        return s:sub(1, -2)
    elseif key == "C" then
        return ""
    elseif key == "±" then
        if not opts.signed then return s end
        if s:sub(1, 1) == "-" then return s:sub(2) end
        return "-" .. s
    elseif key == "½" then
        if not opts.half or s:find("%.5$") then return s end
        if s == "" or s == "-" then return s .. "0.5" end
        return s .. ".5"
    end
    return s
end

function NumEntry.value(s)
    if not s or s == "" or s == "-" then return nil end
    return tonumber(s)
end

-- How the entry reads on screen: "40½", "−12", "" (empty).
function NumEntry.display(s)
    if not s or s == "" then return "" end
    local out = s:gsub("%.5$", "½"):gsub("^%-", "−")
    return out
end

-- A number as shown in the tables: "+318", "−106", "0", "40½".
function NumEntry.signed(v)
    if v == nil then return "" end
    local a = math.abs(v)
    local txt = (a == math.floor(a)) and string.format("%d", a)
                or (string.format("%d", math.floor(a)) .. "½")
    if v > 0 then return "+" .. txt end
    if v < 0 then return "−" .. txt end
    return txt
end

function NumEntry.plain(v)
    if v == nil then return "" end
    local a = math.abs(v)
    local txt = (a == math.floor(a)) and string.format("%d", a)
                or (string.format("%d", math.floor(a)) .. "½")
    return (v < 0 and "−" or "") .. txt
end

return NumEntry
