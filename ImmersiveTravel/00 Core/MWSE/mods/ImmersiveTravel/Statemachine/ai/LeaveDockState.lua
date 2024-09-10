local CAiState              = require("ImmersiveTravel.Statemachine.ai.CAiState")
local GPlayerVehicleManager = require("ImmersiveTravel.GPlayerVehicleManager")
local lib                   = require("ImmersiveTravel.lib")
local interop               = require("ImmersiveTravel.interop")
local GRoutesManager        = require("ImmersiveTravel.GRoutesManager")

local log                   = lib.log

---@param ctx any
---@return boolean?
function ToOnSpline(ctx)
    local vehicle = ctx.scriptedObject ---@cast vehicle CVehicle
    if vehicle:isPlayerInGuideSlot() then
        return false
    end

    return vehicle.currentPort == nil and vehicle.routeId ~= nil
end

-- on spline state class
---@class LeaveDockState : CAiState
local LeaveDockState = {
    name = CAiState.LEAVEDOCK,
    transitions = {
        [CAiState.PLAYERSTEER] = CAiState.ToPlayerSteer,
        [CAiState.ONSPLINE] = ToOnSpline,
        [CAiState.NONE] = CAiState.ToNone,
    }
}
setmetatable(LeaveDockState, { __index = CAiState })

-- constructor for LeaveDockState
---@return LeaveDockState
function LeaveDockState:new()
    local newObj = CAiState:new()
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj LeaveDockState
    return newObj
end

function LeaveDockState:update(dt, scriptedObject)
    -- call super update
    CAiState.update(self, dt, scriptedObject)

    local vehicle = scriptedObject ---@cast vehicle CVehicle
    local spline = GRoutesManager.getInstance():GetRoute(vehicle.routeId)
    if spline == nil then
        return
    end

    -- handle player leaving and entering the vehicle
    local manager = GPlayerVehicleManager.getInstance()
    if manager.free_movement then
        if vehicle.playerRegistered and not vehicle:isPlayerInMountBounds() and manager:IsPlayerTraveling() then
            tes3.messageBox("You have left the vehicle")
            log:debug("[%s] Player left the vehicle on route %s", vehicle:Id(), vehicle.routeId)
            vehicle.playerRegistered = false
            manager:StopTraveling()
        elseif not vehicle.playerRegistered and vehicle:isPlayerInMountBounds() and not manager:IsPlayerTraveling() then
            tes3.messageBox("This is a regular service on route '%s'", vehicle.routeId)
            log:debug("[%s] Player entered the vehicle on route %s", vehicle:Id(), vehicle.routeId)
            vehicle.playerRegistered = true
            manager:StartTraveling(vehicle)
        end
    end

    if not vehicle.playerRegistered then
        if lib.IsColliding(vehicle) then
            log:debug("[%s] Collision", vehicle:Id())
            vehicle.current_speed = 0 -- this pops idle locomotion state
            vehicle.markForDelete = true
        end
    end
end

---@param scriptedObject CTickingEntity
function LeaveDockState:enter(scriptedObject)
    local vehicle = scriptedObject ---@cast vehicle CVehicle

    vehicle.speedChange = 0.5
    local service = GRoutesManager.services[vehicle.serviceId]
    if service then
        local port = service.ports[vehicle.currentPort]
        if port then
            if port.reverseStart then
                -- TODO check this
                vehicle.speedChange = -0.5
            end
        end
    end

    vehicle.current_turnspeed = vehicle.turnspeed * 2
end

-- Method to exit the state
---@param scriptedObject CTickingEntity
function LeaveDockState:exit(scriptedObject)
    local vehicle = scriptedObject ---@cast vehicle CVehicle

    vehicle.virtualDestination = nil

    -- get random destination
    local service = GRoutesManager.services[vehicle.serviceId]
    local destinations = service.routes[vehicle.currentPort]
    if destinations then
        local destination = destinations[math.random(#destinations)]
        vehicle.routeId = string.format("%s_%s", vehicle.currentPort, destination)
        vehicle.currentPort = nil
    end
end

return LeaveDockState
