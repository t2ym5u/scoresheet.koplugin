local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
package.path = _dir .. "?.lua;" .. _dir .. "common/?.lua;" .. package.path

local function lrequire(name)
    local key = _dir .. name
    if not package.loaded[key] then
        package.loaded[key] = assert(loadfile(_dir .. name .. ".lua"))()
    end
    return package.loaded[key]
end

-- The game screen -- and the boards, word lists and puzzle banks it pulls
-- in -- loads the first time the game is opened, not when KOReader starts:
-- KOReader loads every plugin at startup and keeps it all session, so a
-- top-level require here costs memory even if the game is never played.
-- KOReader has put package.path back by then, so our directories are added
-- again while the module loads (common/ stays as a fallback for the shared
-- modules the game requires later on).
local function lazyrequire(name)
    local saved = package.path
    package.path = _dir .. "?.lua;" .. _dir .. "common/?.lua;" .. saved
    local ok, mod = pcall(lrequire, name)
    package.path = saved
    if not package.path:find(_dir .. "common/?.lua", 1, true) then
        package.path = package.path .. ";" .. _dir .. "common/?.lua"
    end
    if not ok then error(mod, 0) end
    return mod
end

local GamesMenu  = require("games_menu")
local PluginBase = require("plugin_base")
local _          = require("i18n")

require("i18n").extend(lrequire("i18n_fr"))

local ScoreSheet = PluginBase:extend{
    name      = "scoresheet",
    menu_text = _("Score sheets"),
    menu_hint = "tools",
}

function ScoreSheet:createScreen()
    return lazyrequire("screen"):new{ plugin = self }
end

-- Listed under Party & quiz whatever game_categories.lua copy a device
-- loaded first: that table is one shared module, and an older copy from
-- another game would not know this plugin and file it under "Other".
function ScoreSheet:addToMainMenu(menu_items)
    GamesMenu.add(menu_items, {
        id       = self:getPluginId(),
        label    = self.menu_text,
        category = "party",
        launch   = function() self:showGame() end,
    })
end

return ScoreSheet
