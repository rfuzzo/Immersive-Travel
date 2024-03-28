local AbstractState = require("ImmersiveTravel.Statemachine.CAbstractState")
local lib = require("ImmersiveTravel.lib")

-- Abstract AI state machine class
---@class CAiState : CAbstractState
local CAiState = {
    transitions = {}
}

-- enum for AI states
CAiState.NONE = "NONE"
CAiState.ONSPLINE = "ONSPLINE"
CAiState.PLAYERSTEER = "PLAYERSTEER"
CAiState.PLAYERTRAVEL = "PLAYERTRAVEL"

---Constructor for AI State
---@return CAiState
function CAiState:new()
    local newObj = AbstractState:new()
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj CAiState
    return newObj
end

--#region methods

---transition to none state if spline is nil
---@param ctx table
---@return boolean
function CAiState.ToNone(ctx)
    local vehicle = ctx.scriptedObject ---@cast vehicle CVehicle
    return not vehicle.spline
end

---transition to on spline state if spline is not nil
---@param ctx any
---@return boolean?
function CAiState.ToOnSpline(ctx)
    local vehicle = ctx.scriptedObject ---@cast vehicle CVehicle
    return vehicle.spline and not vehicle.playerRegistered
end

---transition to player steer state if player is in guide slot
---@param ctx any
---@return boolean
function CAiState.ToPlayerSteer(ctx)
    local vehicle = ctx.scriptedObject ---@cast vehicle CVehicle
    return vehicle:isPlayerInGuideSlot()
end

---transition to player steer state if player is in guide slot
---@param ctx any
---@return boolean
function CAiState.ToPlayerTravel(ctx)
    local vehicle = ctx.scriptedObject ---@cast vehicle CVehicle
    return vehicle.spline and vehicle.playerRegistered
end

--#endregion

return CAiState
