local CAiState              = require("ImmersiveTravel.Statemachine.ai.CAiState")
local GRoutesManager        = require("ImmersiveTravel.GRoutesManager")
local GPlayerVehicleManager = require("ImmersiveTravel.GPlayerVehicleManager")
local lib                   = require("ImmersiveTravel.lib")
local log                   = lib.log

---@param ctx any
---@return boolean?
function ToEnterPort(ctx)
    local vehicle = ctx.scriptedObject ---@cast vehicle CVehicle
    if vehicle:isPlayerInGuideSlot() then
        return false
    end

    return vehicle.currentPort ~= nil and vehicle.routeId == nil and vehicle.virtualDestination ~= nil
end

---@param ctx any
---@return boolean?
function ToDocked(ctx)
    local vehicle = ctx.scriptedObject ---@cast vehicle CVehicle
    if vehicle:isPlayerInGuideSlot() then
        return false
    end

    return vehicle.currentPort ~= nil and vehicle.routeId == nil
end

-- on spline state class
---@class OnSplineState : CAiState
local OnSplineState = {
    name = CAiState.ONSPLINE,
    transitions = {
        [CAiState.PLAYERSTEER] = CAiState.ToPlayerSteer,
        [CAiState.ENTERDOCK] = ToEnterPort,
        [CAiState.DOCKED] = ToDocked,
        [CAiState.NONE] = CAiState.ToNone,
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

-- ---@param scriptedObject CTickingEntity
-- function OnSplineState:OnActivate(scriptedObject)
--     local vehicle = scriptedObject ---@cast vehicle CVehicle

--     -- get a message box with the vehicle id and the route id
--     tes3.messageBox("This is a regular service on route '%s'", vehicle.routeId)
-- end

---@param scriptedObject CTickingEntity
function OnSplineState:OnDestinationReached(scriptedObject)
    local vehicle     = scriptedObject ---@cast vehicle CVehicle

    local destination = nil
    local split       = string.split(vehicle.routeId, "_")
    if #split == 2 then
        destination = split[2]
        local service = GRoutesManager.getInstance().services[vehicle.serviceId]
        if service then
            local port = service.ports[destination]
            if port then
                vehicle.currentPort = destination

                -- now check if there is a route into dock
                if port.positionEnd then
                    -- get route into port
                    vehicle.virtualDestination = lib.vec(port.positionEnd)
                end
            end
        end
    end

    vehicle.routeId = nil -- this pops the none ai state
end

function OnSplineState:update(dt, scriptedObject)
    local vehicle = scriptedObject ---@cast vehicle CVehicle

    local spline = GRoutesManager.getInstance():GetRoute(vehicle.routeId)
    if spline == nil then
        return
    end

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
    if vehicle.splineIndex > #spline then
        self:OnDestinationReached(scriptedObject)
    end
end

function OnSplineState:enter(scriptedObject)
    local vehicle = scriptedObject ---@cast vehicle CVehicle
    vehicle.speedChange = 0.5
    vehicle.current_turnspeed = vehicle.turnspeed
end

return OnSplineState
