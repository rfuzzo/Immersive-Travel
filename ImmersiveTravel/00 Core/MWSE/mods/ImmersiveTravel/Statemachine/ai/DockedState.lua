local CAiState       = require("ImmersiveTravel.Statemachine.ai.CAiState")
local lib            = require("ImmersiveTravel.lib")
local GRoutesManager = require("ImmersiveTravel.GRoutesManager")

local log            = lib.log

---@param ctx any
---@return boolean?
local function ToLeavePort(ctx)
    local vehicle = ctx.scriptedObject ---@cast vehicle CVehicle
    if vehicle:isPlayerInGuideSlot() then
        return false
    end

    return vehicle.currentPort and not vehicle.routeId and vehicle.virtualDestination
end

---@param ctx any
---@return boolean?
local function ToOnSpline(ctx)
    local vehicle = ctx.scriptedObject ---@cast vehicle CVehicle
    if vehicle:isPlayerInGuideSlot() then
        return false
    end

    return not vehicle.currentPort and vehicle.routeId
end

---@param ctx table
---@return boolean
local function ToNone(ctx)
    local vehicle = ctx.scriptedObject ---@cast vehicle CVehicle
    if vehicle:isPlayerInGuideSlot() then
        return false
    end

    return not vehicle.currentPort and not vehicle.routeId
end

-- Docked State class
---@class DockedState : CAiState
local DockedState = {
    name = CAiState.DOCKED,
    states = {
        CAiState.PLAYERSTEER,
        CAiState.ONSPLINE,
        CAiState.LEAVEDOCK,
        CAiState.NONE,
    },
    transitions = {
        CAiState.ToPlayerSteer,
        ToOnSpline,
        ToLeavePort,
        ToNone,
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
        vehicle:EndPlayerTravel()
    end

    local guide = vehicle:GetGuide()
    if vehicle.referenceHandle:valid() and guide then
        timer.start({
            type = timer.simulate,
            iterations = 1,
            duration = 5,
            callback = (function()
                log:trace("[%s] On new route in dock", vehicle:Id())

                -- start timer for new route
                local service = GRoutesManager.getInstance().services[vehicle.serviceId]
                local portId = vehicle.currentPort
                local port = service.ports[portId]
                if port then
                    if port.positionStart then
                        vehicle.virtualDestination = port.positionStart
                        vehicle.routeId = nil
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
