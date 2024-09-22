-- Import modules
local menu = require("menu")
menu.plugin_enabled:set(false)
local menu_renderer = require("graphics.menu_renderer")
local revive = require("data.revive")
local explorer = require("data.explorer")
local automindcage = require("data.automindcage")
local actors = require("data.actors")
local waypoint_loader = require("functions.waypoint_loader")
local interactive_patterns = require("enums.interactive_patterns")
local Movement = require("functions.movement")
local ChestsInteractor = require("functions.chests_interactor")
local teleport = require("data.teleport")
local GameStateChecker = require("functions.game_state_checker")

-- Initialize variables
local plugin_enabled = false
local doorsEnabled = false
local loopEnabled = false
local revive_enabled = false
local profane_mindcage_enabled = false
local profane_mindcage_count = 0
local graphics_enabled = false
local was_in_helltide = false
local last_cleanup_time = 0
local cleanup_interval = 300 -- 5 minutos

local function periodic_cleanup()
    local current_time = os.clock()
    if current_time - last_cleanup_time > cleanup_interval then
        collectgarbage("collect")
        ChestsInteractor.clearInteractedObjects()
        waypoint_loader.clear_cached_waypoints()
        last_cleanup_time = current_time
        console.print("Periodic cleanup performed")
    end
end

-- Function to update menu states
local function update_menu_states()
    local new_plugin_enabled = menu.plugin_enabled:get()
    if new_plugin_enabled ~= plugin_enabled then
        plugin_enabled = new_plugin_enabled
        console.print("Movement Plugin " .. (plugin_enabled and "enabled" or "disabled"))
        if plugin_enabled then
            local waypoints, _ = waypoint_loader.check_and_load_waypoints()
            Movement.set_waypoints(waypoints)
            Movement.set_moving(true)  -- Set the state to MOVING when plugin is enabled
        else
            Movement.save_last_index()
            Movement.set_moving(false)  -- Set the state to IDLE when plugin is disabled
        end
    end

    doorsEnabled = menu.main_openDoors_enabled:get()
    loopEnabled = menu.loop_enabled:get()
    revive_enabled = menu.revive_enabled:get()
    profane_mindcage_enabled = menu.profane_mindcage_toggle:get()
    profane_mindcage_count = menu.profane_mindcage_slider:get()
end

-- Main update function
on_update(function()
    update_menu_states()

    if plugin_enabled then
        periodic_cleanup()
        
        local game_state = GameStateChecker.check_game_state()

        if game_state == "loading_or_limbo" then
            console.print("Loading or in Limbo. Pausing operations.")
            return
        end

        if game_state == "no_player" then
            console.print("No player detected. Waiting for player.")
            return
        end

        local local_player = get_local_player()
        local world_instance = world.get_current_world()
        
        local teleport_state = teleport.get_teleport_state()

        if teleport_state ~= "idle" then
            if teleport.tp_to_next(ChestsInteractor, Movement) then
                console.print("Teleport completed. Loading new waypoints...")
                local waypoints, _ = waypoint_loader.check_and_load_waypoints()
                Movement.set_waypoints(waypoints)
                Movement.set_moving(true)
            end
        else
            if game_state == "helltide" then
                if not was_in_helltide then
                    console.print("Entered Helltide. Initializing Helltide operations.")
                    was_in_helltide = true
                end
                
                if profane_mindcage_enabled then
                    automindcage.update()
                end
                ChestsInteractor.interactWithObjects(doorsEnabled, interactive_patterns)
                Movement.pulse(plugin_enabled, loopEnabled, teleport)
                if revive_enabled then
                    revive.check_and_revive()
                end
                actors.update()
            else
                if was_in_helltide then
                    console.print("Helltide ended. Performing cleanup.")
                    Movement.reset()
                    ChestsInteractor.clearInteractedObjects()
                    ChestsInteractor.clearBlacklist()
                    was_in_helltide = false
                end

                console.print("Not in the Helltide zone. Attempting to teleport...")
                if teleport.tp_to_next(ChestsInteractor, Movement) then
                    console.print("Teleported successfully. Loading new waypoints...")
                    local waypoints, _ = waypoint_loader.check_and_load_waypoints()
                    Movement.set_waypoints(waypoints)
                    Movement.set_moving(true)
                else
                    local state = teleport.get_teleport_state()
                    console.print("Teleport in progress. Current state: " .. state)
                end
            end
        end
    end
end)

-- Render menu function
on_render_menu(function()
    menu_renderer.render_menu(plugin_enabled, doorsEnabled, loopEnabled, revive_enabled, profane_mindcage_enabled, profane_mindcage_count)
end)

console.print(">>Helltide Chests Farmer Eletroluz V1.5<<")