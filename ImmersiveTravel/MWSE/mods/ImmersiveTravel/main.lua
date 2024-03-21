local TrackingManager = require("ImmersiveTravel.CTrackingManager")

-- start tracking manager on mwse initialization
--- @param e initializedEventData
local function initializedCallback(e)
    local trackingManager = TrackingManager:new()
    trackingManager:StartTimer()
end
event.register(tes3.event.initialized, initializedCallback)


-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// CONFIGURATION
local config = require("rfuzzo.ImmersiveTravel.config")


-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// CONFIG
require("rfuzzo.ImmersiveTravel.mcm")
