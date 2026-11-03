local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
package.path = _dir .. "?.lua;" .. _dir .. "common/?.lua;" .. package.path

local function lrequire(name)
    local key = _dir .. name
    if not package.loaded[key] then
        package.loaded[key] = assert(loadfile(_dir .. name .. ".lua"))()
    end
    return package.loaded[key]
end

local GamesMenu  = require("games_menu")
local PluginBase = require("plugin_base")
local _          = require("i18n")

require("i18n").extend(lrequire("i18n_fr"))

local Screen = lrequire("screen")

local ScoreSheet = PluginBase:extend{
    name      = "scoresheet",
    menu_text = _("Score sheets"),
    menu_hint = "tools",
}

function ScoreSheet:createScreen()
    return Screen:new{ plugin = self }
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
