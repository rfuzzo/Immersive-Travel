local AbstractStateMachine = require("ImmersiveTravel.Statemachine.CAbstractStateMachine")
local AiState              = require("ImmersiveTravel.Statemachine.ai.CAiState")

local NoneState            = require("ImmersiveTravel.Statemachine.ai.NoneState")
local OnSplineState        = require("ImmersiveTravel.Statemachine.ai.OnSplineState")
local PlayerSteerState     = require("ImmersiveTravel.Statemachine.ai.PlayerSteerState")
local PlayerTravelState    = require("ImmersiveTravel.Statemachine.ai.PlayerTravelState")

---@class CAiStateMachine : CAbstractStateMachine
local CAiStateMachine      = {
    currentState = NoneState:new(),
    states = {
        [AiState.NONE] = NoneState:new(),
        [AiState.ONSPLINE] = OnSplineState:new(),
        [AiState.PLAYERSTEER] = PlayerSteerState:new(),
        [AiState.PLAYERTRAVEL] = PlayerTravelState:new(),
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
