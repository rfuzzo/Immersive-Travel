local lib             = require("ImmersiveTravel.lib")
local TrackingManager = require("ImmersiveTravel.GTrackingManager")
local GRoutesManager  = require("ImmersiveTravel.GRoutesManager")
local ui              = require("ImmersiveTravel.ui")
local interop         = require("ImmersiveTravel.interop")

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// CONFIGURATION
local config          = require("ImmersiveTravel.config")
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
        lib.log:error("Failed to initialize %s", config.mod)
        return
    end

    lib.log:info("%s Initialized", config.mod)
end
event.register(tes3.event.initialized, initializedCallback)

--- Cleanup on save load
--- @param e loadedEventData
local function loadedCallback(e)
    TrackingManager.getInstance():Cleanup()
    TrackingManager.getInstance():StartTimer()
    lib.log:debug("TrackingManager started")

    -- found vehicles
    for id, _ in pairs(interop.vehicles) do
        lib.log:debug("\tregistered vehicle %s", id)
    end
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
            lib.log:debug("no service found for %s", npc.id)
            return
        end

        -- Return if no destinations
        local destinations = service.routes[ref.cell.id]
        if destinations == nil then return end
        if #destinations == 0 then return end

        lib.log:debug("createTravelButton for %s", npc.id)
        ui.createTravelButton(menuDialog, ref, service)
        menuDialog:updateLayout()
    end
end
event.register("uiActivated", onMenuDialog, { filter = "MenuDialog" })


-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// CONFIG
require("ImmersiveTravel.mcm")
