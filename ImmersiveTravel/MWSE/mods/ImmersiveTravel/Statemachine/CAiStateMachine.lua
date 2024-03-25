local AbstractStateMachine = require("ImmersiveTravel.Statemachine.CAbstractStateMachine")
local AiState = require("ImmersiveTravel.Statemachine.CAiState")

---@class CAiStateMachine : CAbstractStateMachine
local CAiStateMachine = {
    currentState = AiState.NoneState:new(),
    states = {
        [AiState.NONE] = AiState.NoneState:new(),
        [AiState.ONSPLINE] = AiState.OnSplineState:new(),
        [AiState.PLAYERSTEER] = AiState.PlayerSteerState:new(),
    }
}

-- constructor for CAiStateMachine
---@return CAiStateMachine
function CAiStateMachine:new()
    ---@type CAiStateMachine
    local newObj = AbstractStateMachine:new()
    self.__index = self
    setmetatable(newObj, self)
    return newObj
end

return CAiStateMachine
