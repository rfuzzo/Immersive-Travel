local CAbstractState = require("ImmersiveTravel.Statemachine.CAbstractState")
local lib = require("ImmersiveTravel.lib")

-- Abstract AI state machine class
---@class CAiState : CAbstractState
local CAiState = {
}
setmetatable(CAiState, { __index = CAbstractState })

-- enum for AI states
CAiState.NONE = "NONE"
CAiState.ONSPLINE = "ONSPLINE"
CAiState.PLAYERSTEER = "PLAYERSTEER"
CAiState.PLAYERTRAVEL = "PLAYERTRAVEL"

---Constructor for AI State
---@return CAiState
function CAiState:new()
    local newObj = CAbstractState:new()
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj CAiState
    return newObj
end

--#region methods

---transition to none state if routeId is nil
---@param ctx table
---@return boolean
function CAiState.ToNone(ctx)
    local vehicle = ctx.scriptedObject ---@cast vehicle CVehicle
    return not vehicle.routeId and not vehicle.playerRegistered and not vehicle:isPlayerInGuideSlot()
end

---transition to ONSPLINE state if routeId is not nil
---@param ctx any
---@return boolean?
function CAiState.ToOnSpline(ctx)
    local vehicle = ctx.scriptedObject ---@cast vehicle CVehicle
    return vehicle.routeId and not vehicle.playerRegistered and not vehicle:isPlayerInGuideSlot()
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
    return vehicle.routeId and vehicle.playerRegistered
end

--#endregion

return CAiState
