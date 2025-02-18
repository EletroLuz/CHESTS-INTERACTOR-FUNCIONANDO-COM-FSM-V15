local waypoint_loader = require("functions.waypoint_loader")
local explorer = require("data.explorer")

local Movement = {}

-- States
local States = {
    IDLE = "IDLE",
    MOVING = "MOVING",
    INTERACTING = "INTERACTING",
    EXPLORING = "EXPLORING",
    STUCK = "STUCK"
}

-- Local variables
local state = States.IDLE
local waypoints = {}
local current_waypoint_index = 1
local previous_player_pos = nil
local last_movement_time = 0
local stuck_check_time = 0
local force_move_cooldown = 0
local interaction_end_time = nil
local last_used_index = 1

-- Configuration
local stuck_threshold = 10
local move_threshold = 12

-- Helper functions
local function get_distance(point)
    return get_player_position():squared_dist_to_ignore_z(point)
end

local function update_waypoint_index()
    current_waypoint_index = current_waypoint_index + 1
    if current_waypoint_index > #waypoints then
        current_waypoint_index = 1
    end
end

local function handle_stuck_player(current_waypoint, current_time, teleport)
    if current_time - stuck_check_time > stuck_threshold and teleport.get_teleport_state() == "idle" then
        console.print("Player stuck for " .. stuck_threshold .. " seconds, activating explorer")
        if current_waypoint then
            explorer.set_target(current_waypoint)
            explorer.enable()
            return true
        else
            console.print("Error: No current waypoint set")
        end
    end
    return false
end

local function force_move_if_stuck(player_pos, current_time, current_waypoint)
    if previous_player_pos and player_pos:squared_dist_to_ignore_z(previous_player_pos) < 3 then
        if current_time - last_movement_time > 5 then
            console.print("Player stuck, using force_move_raw")
            local randomized_waypoint = waypoint_loader.randomize_waypoint(current_waypoint)
            pathfinder.force_move_raw(randomized_waypoint)
            last_movement_time = current_time
        end
    else
        previous_player_pos = player_pos
        last_movement_time = current_time
        stuck_check_time = current_time
    end
end

-- State handlers
local function handle_idle_state()
    -- Do nothing in idle state
end

local function handle_moving_state(current_time, teleport)
    local current_waypoint = waypoints[current_waypoint_index]
    if current_waypoint then
        local player_pos = get_player_position()
        local distance = get_distance(current_waypoint)
        
        if distance < 2 then
            update_waypoint_index()
            last_movement_time = current_time
            force_move_cooldown = 0
            previous_player_pos = player_pos
            stuck_check_time = current_time
        else
            if handle_stuck_player(current_waypoint, current_time, teleport) then
                state = States.EXPLORING
                return
            end
            
            force_move_if_stuck(player_pos, current_time, current_waypoint)

            if current_time > force_move_cooldown then
                local randomized_waypoint = waypoint_loader.randomize_waypoint(current_waypoint)
                pathfinder.request_move(randomized_waypoint)
            end
        end
    end
end

local function handle_interacting_state(current_time)
    if interaction_end_time and current_time > interaction_end_time then
        state = States.MOVING
        console.print("Interaction complete, transitioning to MOVING state")
    end
end

local function handle_exploring_state()
    if explorer.is_target_reached() then
        explorer.disable()
        state = States.MOVING
        console.print("Explorer reached target, transitioning to MOVING state")
    elseif not explorer.is_enabled() then
        state = States.MOVING
        console.print("Explorer failed or was disabled, transitioning to MOVING state")
    end
end

-- Main movement function
function Movement.pulse(plugin_enabled, loopEnabled, teleport)
    if not plugin_enabled then
        return
    end

    local current_time = os.clock()

    if state == States.IDLE then
        handle_idle_state()
    elseif state == States.MOVING then
        handle_moving_state(current_time, teleport)
    elseif state == States.INTERACTING then
        handle_interacting_state(current_time)
    elseif state == States.EXPLORING then
        handle_exploring_state()
    end
end

-- Configuration functions
function Movement.set_waypoints(new_waypoints)
    waypoints = new_waypoints
    if current_waypoint_index > #new_waypoints then
        current_waypoint_index = 1
    end
end

function Movement.set_moving(moving)
    if moving then
        state = States.MOVING
    else
        state = States.IDLE
    end
end

function Movement.set_interacting(interacting)
    if interacting then
        state = States.INTERACTING
    else
        state = States.MOVING
    end
end

function Movement.set_interaction_end_time(end_time)
    interaction_end_time = end_time
    state = States.INTERACTING
end

function Movement.reset()
    current_waypoint_index = last_used_index
    state = States.IDLE
    previous_player_pos = nil
    last_movement_time = 0
    stuck_check_time = os.clock()
    force_move_cooldown = 0
    interaction_end_time = nil
end

function Movement.save_last_index()
    last_used_index = current_waypoint_index
end

function Movement.get_last_index()
    return last_used_index
end

return Movement