local lib                   = require("ImmersiveTravel.lib")
local TrackingManager       = require("ImmersiveTravel.GTrackingManager")
local GRoutesManager        = require("ImmersiveTravel.GRoutesManager")
local GPlayerVehicleManager = require("ImmersiveTravel.GPlayerVehicleManager")
local ui                    = require("ImmersiveTravel.ui")
local interop               = require("ImmersiveTravel.interop")

local log                   = lib.log

--[[

- travel

    -[ ] refactor routes with segments
    -[x] fix locomotion in reverse
    -[x] add NPCs
    -[x] add payment
    -[ ] slow down in port

    -[ ] proper class and name randomization for passengers
    -[ ] fix all todos
    -[ ] add new animated boat
    -[ ] refactor ports for different vehicles

    -[ ] maybe start travel from the port start
    -[ ] add a deck interior cell


- editor
    -[ ] add port mode
    -[ ] add segment mode
    -[ ] display vehicles in real time

- vehicles
    -[ ] fix vehicles steer

]] --

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// CONFIGURATION
local config = require("ImmersiveTravel.config")
if not config then
    return
end

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// EVENTS

--- Init Mod
--- @param e initializedEventData
local function initializedCallback(e)
    -- TODO debug
    -- ---@type SSegment
    -- local d1 = {
    --     id = "test1",
    --     routes = {
    --         {
    --             { x = 1, y = 0, z = 0 },
    --             { x = 2, y = 0, z = 0 },
    --         },
    --     }
    -- }

    -- ---@type SSegment
    -- local d2 = {
    --     id = "test2",
    --     routes = {
    --         {
    --             { x = 2, y = 0, z = 0 },
    --             { x = 3, y = 0, z = 0 },
    --         },
    --     }
    -- }

    -- ---@type SSegment
    -- local d3 = {
    --     id = "Inner Sea",
    --     segments = { d1, d2 }
    -- }

    -- toml.saveFile("Data Files\\_segment_test.toml", d3)

    -- init routes manager
    if not GRoutesManager.getInstance():Init() then
        config.modEnabled = false
        log:error("Failed to initialize %s", config.mod)
        return
    end

    log:info("%s Initialized", config.mod)
end
event.register(tes3.event.initialized, initializedCallback)

local TRIP_TOPIC = "this trip"

--- Cleanup on save load
--- @param e loadedEventData
local function loadedCallback(e)
    TrackingManager.getInstance():Cleanup()
    TrackingManager.getInstance():StartTimer()
    log:debug("TrackingManager started")

    -- found vehicles
    for id, _ in pairs(interop.vehicles) do
        log:debug("\tregistered vehicle %s", id)
    end

    -- add topics
    local result = tes3.addTopic({
        topic = TRIP_TOPIC
    })
    log:debug("addTopic %s: %s", TRIP_TOPIC, result)
end
event.register(tes3.event.loaded, loadedCallback)

-- upon entering the dialog menu, create the travel menu
---@param e uiActivatedEventData
local function onMenuDialog(e)
    local actor = tes3ui.getServiceActor()
    if actor and actor.actorType == tes3.actorType.npc then
        local ref = actor.reference
        local obj = ref.baseObject
        local npc = obj ---@cast obj tes3npc

        if not lib.offersTraveling(npc) then return end

        local services = GRoutesManager.getInstance().services
        if not services then return end

        -- get npc class
        local class = npc.class.id
        local service = services[class]
        for _, value in pairs(services) do
            if value.override_npc ~= nil then
                if lib.is_in(value.override_npc, npc.id) then
                    service = value
                    break
                end
            end
        end

        if service == nil then
            log:debug("no service found for %s", npc.id)
            return
        end

        -- TODO Return if no destinations
        local destinations = service:GetDestinations(ref.cell.id)
        if #destinations == 0 then return end

        log:debug("createTravelButton for %s", npc.id)
        local menuDialog = e.element
        ui.createTravelButton(menuDialog, ref, service)
        menuDialog:updateLayout()
    end
end
event.register("uiActivated", onMenuDialog, { filter = "MenuDialog" })

local function onDialogueEnvironmentCreated(e)
    -- Cache the environment variables outside the function for easier access.
    -- Dialogue scripters shouldn't have to constantly pass these to the functions anyway.
    local env = e.environment

    -- Define the "global" function.
    function env.GuideDialogueContext()
        -- activate the guide
        local manager = GPlayerVehicleManager.getInstance()
        local vehicle = manager.trackedVehicle
        if vehicle and manager.free_movement then
            local start, destination = lib.SplitRouteId(vehicle.routeId)
            tes3.messageBox("This is a regular service on route to %s. Would you like to sit down?", destination)

            tes3ui.choice("Yes", 2)
            tes3ui.choice("No", 1)
        elseif vehicle and manager:IsPlayerTraveling() then
            local start, destination = lib.SplitRouteId(vehicle.routeId)
            tes3.messageBox("This is a regular service on route to %s", destination)
        else
            tes3.messageBox("I'm a shipmaster. I can transport you by ship to various destinations for a modest fee.")
        end
    end

    function env.GuideSitDown()
        local manager = GPlayerVehicleManager.getInstance()
        local vehicle = manager.trackedVehicle
        if vehicle then
            manager.free_movement = false
            tes3.player.facing = vehicle.referenceHandle:getObject().facing
            vehicle:registerRefInRandomSlot(tes3.makeSafeObjectHandle(tes3.player))
        end
    end
end
event.register(tes3.event.dialogueEnvironmentCreated, onDialogueEnvironmentCreated)

--- @param e infoFilterEventData
local function infoFilterCallback(e)
    -- This early check will make sure our function
    -- isn't executing unnecesarily
    if (not e.passes) then
        return
    end

    if e.dialogue.id == TRIP_TOPIC then
        if not GPlayerVehicleManager.getInstance():IsPlayerTraveling() then
            e.passes = false
        end
    end
end
event.register(tes3.event.infoFilter, infoFilterCallback)

--- @param e uiObjectTooltipEventData
local function uiObjectTooltipCallback(e)
    if e.reference and e.reference.tempData.it_name then
        local label = e.tooltip:findChild("HelpMenu_name")
        if label then
            label.text = e.reference.tempData.it_name
        end
    end
end
event.register(tes3.event.uiObjectTooltip, uiObjectTooltipCallback)

--- @param e uiActivatedEventData
local function uiActivatedCallback(e)
    local actor = tes3ui.getServiceActor()
    if actor and actor.reference.tempData.it_name then
        local title = e.element:findChild("PartDragMenu_title")
        if title then
            title.text = actor.reference.tempData.it_name
        end
    end
end
event.register(tes3.event.uiActivated, uiActivatedCallback, { filter = "MenuDialog" })

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// CONFIG
require("ImmersiveTravel.mcm")
