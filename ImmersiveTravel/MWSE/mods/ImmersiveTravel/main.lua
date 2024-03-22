local TrackingManager = require("ImmersiveTravel.CTrackingManager")
local lib = require("ImmersiveTravel.lib")
local log = lib.log
local io = require("ImmersiveTravel.io")
local CPlayerTravelManager = require("ImmersiveTravel.CPlayerTravelManager")

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// GLOBALS

--- @type TrackingManager?
local trackingManager = nil
--- @type CPlayerTravelManager?
local travelManager = nil

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// CONFIGURATION
local config = require("rfuzzo.ImmersiveTravel.config")


-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// EVENTS

-- start tracking manager on mwse initialization
--- @param e initializedEventData
local function initializedCallback(e)
    trackingManager = TrackingManager:new()
    trackingManager:StartTimer()

    travelManager = CPlayerTravelManager:new()
end
event.register(tes3.event.initialized, initializedCallback)

--- Cleanup on save load
--- @param e loadEventData
local function loadCallback(e)
    if trackingManager then
        trackingManager:Cleanup()
    end
end
event.register(tes3.event.load, loadCallback)

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

        local services = io.loadServices()
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
        io.loadRoutes(service)
        local destinations = service.routes[ref.cell.id]
        if destinations == nil then return end
        if #destinations == 0 then return end

        log:debug("createTravelButton for %s", npc.id)
        CPlayerTravelManager.createTravelButton(menuDialog, ref, service)
        menuDialog:updateLayout()
    end
end
event.register("uiActivated", onMenuDialog, { filter = "MenuDialog" })

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// CONFIG
require("rfuzzo.ImmersiveTravel.mcm")
