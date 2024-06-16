local CAiState       = require("ImmersiveTravel.Statemachine.ai.CAiState")
local GRoutesManager = require("ImmersiveTravel.GRoutesManager")
local lib            = require("ImmersiveTravel.lib")
local log            = lib.log

-- on spline state class
---@class OnSplineState : CAiState
local OnSplineState  = {
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

function OnSplineState:enter(scriptedObject)
end

function OnSplineState:update(dt, scriptedObject)
    local vehicle = scriptedObject ---@cast vehicle CVehicle

    local spline = GRoutesManager.getInstance().routes[vehicle.routeId]
    if spline == nil then
        return
    end
    if vehicle.splineIndex > #spline then
        -- reached end of route
        vehicle.routeId = nil
    end

    -- handle player entering vehicle
    if not vehicle.playerRegistered and vehicle:isPlayerInMountBounds() then
        tes3.messageBox("You have entered the vehicle")
        log:debug("Player entered vehicle")
        vehicle.playerRegistered = true
    end
end

function OnSplineState:exit(scriptedObject)
    -- delete vehicle if player not registered
    local vehicle = scriptedObject ---@cast vehicle CVehicle
    if not vehicle.playerRegistered then
        scriptedObject.markForDelete = true
    end
end

return OnSplineState
