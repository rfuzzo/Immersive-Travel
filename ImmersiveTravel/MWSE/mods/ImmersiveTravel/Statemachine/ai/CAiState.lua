local CAbstractState = require("ImmersiveTravel.Statemachine.CAbstractState")
local lib = require("ImmersiveTravel.lib")

-- Abstract AI state machine class
---@class CAiState : CAbstractState
local CAiState = {
}
setmetatable(CAiState, { __index = CAbstractState })

-- enum for AI states
CAiState.NONE = "NONE"
CAiState.DOCKED = "DOCKED"
CAiState.ONSPLINE = "ONSPLINE"
CAiState.PLAYERSTEER = "PLAYERSTEER"
CAiState.ENTERDOCK = "ENTERDOCK"
CAiState.LEAVEDOCK = "LEAVEDOCK"

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

---@param ctx table
---@return boolean
function CAiState.ToNone(ctx)
    local vehicle = ctx.scriptedObject ---@cast vehicle CVehicle
    if vehicle:isPlayerInGuideSlot() then
        return false
    end

    return not vehicle.routeId
end

---@param ctx any
---@return boolean
function CAiState.ToPlayerSteer(ctx)
    local vehicle = ctx.scriptedObject ---@cast vehicle CVehicle
    return vehicle:isPlayerInGuideSlot()
end

--#endregion

return CAiState
