local CAiState              = require("ImmersiveTravel.Statemachine.ai.CAiState")
local lib                   = require("ImmersiveTravel.lib")
local GRoutesManager        = require("ImmersiveTravel.GRoutesManager")
local GPlayerVehicleManager = require("ImmersiveTravel.GPlayerVehicleManager")

local log                   = lib.log

---@param ctx any
---@return boolean?
function ToLeavePort(ctx)
    local vehicle = ctx.scriptedObject ---@cast vehicle CVehicle
    if vehicle:isPlayerInGuideSlot() then
        return false
    end

    return vehicle.currentPort ~= nil and vehicle.routeId ~= nil
end

---@param ctx any
---@return boolean?
function ToOnSpline(ctx)
    local vehicle = ctx.scriptedObject ---@cast vehicle CVehicle
    if vehicle:isPlayerInGuideSlot() then
        return false
    end

    return vehicle.currentPort == nil and vehicle.routeId ~= nil
end

-- Docked State class
---@class DockedState : CAiState
local DockedState = {
    name = CAiState.DOCKED,
    transitions = {
        [CAiState.PLAYERSTEER] = CAiState.ToPlayerSteer,
        [CAiState.ONSPLINE] = ToOnSpline,
        [CAiState.LEAVEDOCK] = ToLeavePort,
        [CAiState.NONE] = CAiState.ToNone,
    }
}
setmetatable(DockedState, { __index = CAiState })

-- constructor for DockedState
---@return DockedState
function DockedState:new()
    local newObj = CAiState:new()
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj DockedState
    return newObj
end

---@comment when we enter this state, the ship is docked in port
function DockedState:enter(scriptedObject)
    local vehicle = scriptedObject ---@cast vehicle CVehicle

    vehicle.current_speed = 0 -- this pops idle locomotion state

    if vehicle.playerRegistered then
        GPlayerVehicleManager.getInstance():StopTraveling()
    end

    -- TODO unregister passengers?

    local guide = vehicle:GetGuide()
    if vehicle.referenceHandle:valid() and guide then
        timer.start({
            type = timer.simulate,
            iterations = 1,
            duration = 5,
            callback = (function()
                -- start timer for new route
                local service = GRoutesManager.services[vehicle.serviceId]
                local portId = vehicle.currentPort
                local port = service.ports[portId]
                if port then
                    if port.positionStart then
                        -- TODO get route out of port
                    else
                        -- get random destination
                        local destinations = service.routes[portId]
                        if destinations then
                            local destination = destinations[math.random(#destinations)]
                            vehicle.routeId = string.format("%s_%s", portId, destination)
                            vehicle.currentPort = nil
                        end
                    end
                end
            end)
        })
    end
end

return DockedState
