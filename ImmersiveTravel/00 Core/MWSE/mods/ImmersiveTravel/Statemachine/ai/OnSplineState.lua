local CAiState              = require("ImmersiveTravel.Statemachine.ai.CAiState")
local GRoutesManager        = require("ImmersiveTravel.GRoutesManager")
local GPlayerVehicleManager = require("ImmersiveTravel.GPlayerVehicleManager")
local lib                   = require("ImmersiveTravel.lib")
local log                   = lib.log

---@param ctx any
---@return boolean?
local function ToEnterPort(ctx)
    local vehicle = ctx.scriptedObject ---@cast vehicle CVehicle
    if vehicle:isPlayerInGuideSlot() then
        return false
    end

    return vehicle.currentPort and not vehicle.routeId and vehicle.virtualDestination
end

---@param ctx any
---@return boolean?
local function ToDocked(ctx)
    local vehicle = ctx.scriptedObject ---@cast vehicle CVehicle
    if vehicle:isPlayerInGuideSlot() then
        return false
    end

    return vehicle.currentPort and not vehicle.routeId
end

-- on spline state class
---@class OnSplineState : CAiState
local OnSplineState = {
    name = CAiState.ONSPLINE,
    states = {
        CAiState.PLAYERSTEER,
        CAiState.ENTERDOCK,
        CAiState.DOCKED,
        CAiState.NONE,
    },
    transitions = {
        CAiState.ToPlayerSteer,
        ToEnterPort,
        ToDocked,
        CAiState.ToNone,
    }
}
setmetatable(OnSplineState, { __index = CAiState })

-- constructor for OnSplineState
---@return OnSplineState
function OnSplineState:new()
    local newObj = CAiState:new()
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj OnSplineState
    return newObj
end

---@param scriptedObject CTickingEntity
function OnSplineState:OnDestinationReached(scriptedObject)
    local vehicle = scriptedObject ---@cast vehicle CVehicle

    local service = GRoutesManager.getInstance():GetService(vehicle.serviceId)
    if service then
        local port = service:GetPort(vehicle.routeId.destination)
        if port then
            vehicle.currentPort = vehicle.routeId.destination

            log:trace("[%s] OnSplineState OnDestinationReached port: %s", vehicle:Id(), vehicle.currentPort)
            -- TODO port end
            -- if port.positionEnd then
            --     -- get route into port
            --     vehicle.virtualDestination = port.positionEnd
            -- end
        end
    end


    vehicle.routeId = nil -- this pops the none ai state
end

function OnSplineState:update(dt, scriptedObject)
    local vehicle = scriptedObject ---@cast vehicle CVehicle

    -- TODO new route system
    local spline = GRoutesManager.getInstance():GetRoute(vehicle.routeId)
    if spline == nil then
        return
    end

    -- handle player leaving and entering the vehicle
    local manager = GPlayerVehicleManager.getInstance()
    if manager.free_movement then
        if vehicle.playerRegistered and not vehicle:isPlayerInMountBounds() and manager:IsPlayerTraveling() then
            if lib.IsLogLevelAtLeast("DEBUG") then
                tes3.messageBox("You have left the vehicle")
            end
            log:debug("[%s] Player left the vehicle on route %s", vehicle:Id(), vehicle.routeId)
            vehicle.playerRegistered = false
            tes3.player.tempData.itpsl = nil
            manager:StopTraveling()
        elseif not vehicle.playerRegistered and vehicle:isPlayerInMountBounds() and not manager:IsPlayerTraveling() then
            if lib.IsLogLevelAtLeast("DEBUG") then
                tes3.messageBox("This is a regular service on route '%s'", vehicle.routeId)
            end
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
    if vehicle.splineIndex > #spline then
        self:OnDestinationReached(scriptedObject)
    end
end

function OnSplineState:enter(scriptedObject)
    local vehicle = scriptedObject ---@cast vehicle CVehicle
    vehicle.changeSpeed = 0.5
    vehicle.current_turnspeed = vehicle.turnspeed
end

return OnSplineState
