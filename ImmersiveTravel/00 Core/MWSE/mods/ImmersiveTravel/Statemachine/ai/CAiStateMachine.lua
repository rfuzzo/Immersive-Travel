local CAbstractStateMachine = require("ImmersiveTravel.Statemachine.CAbstractStateMachine")
local AiState               = require("ImmersiveTravel.Statemachine.ai.CAiState")

local NoneState             = require("ImmersiveTravel.Statemachine.ai.NoneState")
local OnSplineState         = require("ImmersiveTravel.Statemachine.ai.OnSplineState")
local PlayerSteerState      = require("ImmersiveTravel.Statemachine.ai.PlayerSteerState")
local DockedState           = require("ImmersiveTravel.Statemachine.ai.DockedState")
local EnterDockState        = require("ImmersiveTravel.Statemachine.ai.EnterDockState")
local LeaveDockState        = require("ImmersiveTravel.Statemachine.ai.LeaveDockState")

---@class CAiStateMachine : CAbstractStateMachine
local CAiStateMachine       = {
    currentState = NoneState:new(),
    name = "AiStateMachine",
    states = {
        [AiState.NONE] = NoneState:new(),
        [AiState.ONSPLINE] = OnSplineState:new(),
        [AiState.PLAYERSTEER] = PlayerSteerState:new(),
        [AiState.DOCKED] = DockedState:new(),
        [AiState.ENTERDOCK] = EnterDockState:new(),
        [AiState.LEAVEDOCK] = LeaveDockState:new(),
    }
}
setmetatable(CAiStateMachine, { __index = CAbstractStateMachine })

-- constructor for CAiStateMachine
---@return CAiStateMachine
function CAiStateMachine:new()
    local newObj = CAbstractStateMachine:new()
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj CAiStateMachine
    return newObj
end

return CAiStateMachine
