local CAiState              = require("ImmersiveTravel.Statemachine.ai.CAiState")
local GPlayerVehicleManager = require("ImmersiveTravel.GPlayerVehicleManager")
local lib                   = require("ImmersiveTravel.lib")
local RouteId               = require("ImmersiveTravel.models.RouteId")
local GRoutesManager        = require("ImmersiveTravel.GRoutesManager")

local log                   = lib.log

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

-- on spline state class
---@class LeaveDockState : CAiState
local LeaveDockState = {
    name = CAiState.LEAVEDOCK,
    states = {
        CAiState.PLAYERSTEER,
        CAiState.ONSPLINE,
        CAiState.NONE,
    },
    transitions = {
        CAiState.ToPlayerSteer,
        ToOnSpline,
        ToNone,
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

---@param scriptedObject CTickingEntity
function LeaveDockState:OnDestinationReached(scriptedObject)
    local vehicle = scriptedObject ---@cast vehicle CVehicle

    log:trace("[%s] LeaveDockState OnDestinationReached port: %s", vehicle:Id(), vehicle.currentPort)

    vehicle.virtualDestination = nil

    -- get random destination
    local service = GRoutesManager.getInstance():GetService(vehicle.serviceId)
    if service then
        local destinations = service:GetDestinations(vehicle.currentPort)
        if #destinations > 0 then
            local destination = destinations[math.random(#destinations)]
            vehicle.routeId = RouteId:new(vehicle.serviceId, vehicle.currentPort, destination)
            vehicle.currentPort = nil

            log:trace("[%s] LeaveDockState OnDestinationReached new destination: %s", vehicle:Id(), vehicle.routeId)
        end
    end
end

function LeaveDockState:update(dt, scriptedObject)
    -- call super update
    CAiState.update(self, dt, scriptedObject)

    local vehicle = scriptedObject ---@cast vehicle CVehicle

    -- handle player leaving and entering the vehicle
    local manager = GPlayerVehicleManager.getInstance()
    if manager.free_movement then
        if vehicle.playerRegistered and not vehicle:isPlayerInMountBounds() and manager:IsPlayerTraveling() then
            -- tes3.messageBox("You have left the vehicle")
            log:debug("[%s] Player left the vehicle on route %s", vehicle:Id(), vehicle.routeId)
            vehicle.playerRegistered = false
            manager:StopTraveling()
        elseif not vehicle.playerRegistered and vehicle:isPlayerInMountBounds() and not manager:IsPlayerTraveling() then
            -- tes3.messageBox("This is a regular service on route '%s'", vehicle.routeId)
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

    -- reached destination
    if vehicle.last_position:distance(vehicle.virtualDestination) < 100 then
        self:OnDestinationReached(scriptedObject)
    end
end

---@param scriptedObject CTickingEntity
function LeaveDockState:enter(scriptedObject)
    local vehicle = scriptedObject ---@cast vehicle CVehicle

    vehicle.changeSpeed = 0.5
    local service = GRoutesManager.getInstance():GetService(vehicle.serviceId)
    if service then
        local port = service:GetPort(vehicle.currentPort, vehicle.id)
        if port then
            if port:IsReverse() then
                vehicle.changeSpeed = -0.5
                vehicle.current_speed = vehicle.minSpeed
                debug.log(vehicle.current_speed)
            end
        end
    end

    vehicle.current_turnspeed = vehicle.turnspeed * 2
end

return LeaveDockState
