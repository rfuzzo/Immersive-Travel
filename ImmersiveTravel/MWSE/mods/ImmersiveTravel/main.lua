local lib = require("ImmersiveTravel.lib")
local TrackingManager = require("ImmersiveTravel.CTrackingManager")
local CPlayerTravelManager = require("ImmersiveTravel.CPlayerTravelManager")

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// CONFIGURATION
local config = require("ImmersiveTravel.config")


-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// EVENTS

--- Cleanup on save load
--- @param e loadedEventData
local function loadedCallback(e)
    TrackingManager.getInstance():Cleanup()
    TrackingManager.getInstance():StartTimer()
    lib.log:debug("TrackingManager started")
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

        local services = lib.loadServices()
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
            lib.log:debug("no service found for %s", npc.id)
            return
        end

        -- Return if no destinations
        lib.loadRoutes(service)
        local destinations = service.routes[ref.cell.id]
        if destinations == nil then return end
        if #destinations == 0 then return end

        lib.log:debug("createTravelButton for %s", npc.id)
        CPlayerTravelManager.getInstance():createTravelButton(menuDialog, ref, service)
        menuDialog:updateLayout()
    end
end
event.register("uiActivated", onMenuDialog, { filter = "MenuDialog" })


-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// CONFIG
require("ImmersiveTravel.mcm")
