local menu = require("menu")

local menu_renderer = {}

function menu_renderer.render_menu(plugin_enabled, doorsEnabled, loopEnabled, revive_enabled, profane_mindcage_enabled, profane_mindcage_count, moveThreshold)
    if menu.main_tree:push("HellChest Farmer (EletroLuz)-V1.4") then
        menu.plugin_enabled:render("Enable Movement Plugin", "Enable or disable the movement plugin")
        menu.main_openDoors_enabled:render("Open Chests", "Enable or disable the chest plugin")
        menu.loop_enabled:render("Enable Loop", "Enable or disable looping waypoints")
        menu.revive_enabled:render("Enable Revive Module", "Enable or disable the revive module")

        if menu.profane_mindcage_tree:push("Profane Mindcage Settings") then
            menu.profane_mindcage_toggle:render("Enable Profane Mindcage Auto Use", "Enable or disable automatic use of Profane Mindcage")
            menu.profane_mindcage_slider:render("Profane Mindcage Count", "Number of Profane Mindcages to use")
            menu.profane_mindcage_tree:pop()
        end

        if menu.move_threshold_tree:push("Chest Move Range Settings") then
            menu.move_threshold_slider:render("Move Range", "maximum distance the player can detect and move towards a chest in the game")
            menu.move_threshold_tree:pop()
        end

        menu.main_tree:pop()
    end
end

return menu_renderer