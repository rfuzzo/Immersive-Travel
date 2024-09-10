local lib                   = require("ImmersiveTravel.lib")
local TrackingManager       = require("ImmersiveTravel.GTrackingManager")
local GRoutesManager        = require("ImmersiveTravel.GRoutesManager")
local GPlayerVehicleManager = require("ImmersiveTravel.GPlayerVehicleManager")
local ui                    = require("ImmersiveTravel.ui")
local interop               = require("ImmersiveTravel.interop")

local log                   = lib.log

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// CONFIGURATION
local config                = require("ImmersiveTravel.config")
if not config then
    return
end

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// EVENTS

--- Init Mod
--- @param e initializedEventData
local function initializedCallback(e)
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
    local menuDialog = e.element
    local mobileActor = menuDialog:getPropertyObject("PartHyperText_actor") ---@cast mobileActor tes3mobileActor
    if mobileActor.actorType == tes3.actorType.npc then
        local ref = mobileActor.reference
        local obj = ref.baseObject
        local npc = obj ---@cast obj tes3npc

        if not lib.offersTraveling(npc) then return end

        local services = GRoutesManager.getInstance().services
        if not services then return end

        -- get npc class
        local class = npc.class.id
        local service = table.get(services, class)
        for key, value in pairs(services) do
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

        -- Return if no destinations
        local destinations = service.routes[ref.cell.id]
        if destinations == nil then return end
        if #destinations == 0 then return end

        log:debug("createTravelButton for %s", npc.id)
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

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// CONFIG
require("ImmersiveTravel.mcm")
