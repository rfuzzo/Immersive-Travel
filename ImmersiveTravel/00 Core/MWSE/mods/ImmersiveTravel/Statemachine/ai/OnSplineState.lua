local CAiState              = require("ImmersiveTravel.Statemachine.ai.CAiState")
local GRoutesManager        = require("ImmersiveTravel.GRoutesManager")
local GPlayerVehicleManager = require("ImmersiveTravel.GPlayerVehicleManager")
local lib                   = require("ImmersiveTravel.lib")
local log                   = lib.log

-- on spline state class
---@class OnSplineState : CAiState
local OnSplineState         = {
    name = CAiState.ONSPLINE,
    transitions = {
        [CAiState.NONE] = CAiState.ToNone,
        [CAiState.PLAYERSTEER] = CAiState.ToPlayerSteer,
        [CAiState.PLAYERTRAVEL] = CAiState.ToPlayerTravel,
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
function OnSplineState:OnActivate(scriptedObject)
    local vehicle = scriptedObject ---@cast vehicle CVehicle

    -- get a message box with the vehicle id and the route id
    tes3.messageBox("This is a regular service on route '%s'", vehicle.routeId)
end

function OnSplineState:update(dt, scriptedObject)
    local vehicle = scriptedObject ---@cast vehicle CVehicle

    local spline = GRoutesManager.getInstance().routes[vehicle.routeId]
    if spline == nil then
        return
    end

    if lib.IsColliding(vehicle) then
        log:debug("[%s] Collision", vehicle:Id())
        vehicle.current_speed = 0    -- this pops idle locomotion state
        vehicle.markForDelete = true -- TODO on a timer?
    end

    -- reached end of route
    if vehicle.splineIndex > #spline then
        log:debug("[%s] Destination reached", vehicle:Id())
        vehicle.current_speed = 0 -- this pops idle locomotion state

        vehicle.lastRouteId = vehicle.routeId
        vehicle.routeId = nil -- this pops the none ai state
    end

    -- handle player entering vehicle
    if not vehicle.playerRegistered and vehicle:isPlayerInMountBounds() and not GPlayerVehicleManager.getInstance():IsPlayerTraveling() then
        tes3.messageBox("This is a regular service on route '%s'", vehicle.routeId)
        log:debug("[%s] Player entered the vehicle on route %s", vehicle:Id(), vehicle.routeId)
        vehicle.playerRegistered = true
    end
end

return OnSplineState
