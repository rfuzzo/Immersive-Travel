local AbstractStateMachine = require("ImmersiveTravel.Statemachine.CAbstractStateMachine")
local LocomotionState = require("ImmersiveTravel.Statemachine.locomotion.CLocomotionState")

---@class CLocomotionStateMachine : CAbstractStateMachine
local CLocomotionStateMachine = {
    currentState = LocomotionState.IdleState:new(),
    states = {
        [LocomotionState.IDLE] = LocomotionState.IdleState:new(),
        [LocomotionState.MOVING] = LocomotionState.MovingState:new(),
        [LocomotionState.ACCELERATE] = LocomotionState.AccelerateState:new(),
        [LocomotionState.DECELERATE] = LocomotionState.DecelerateState:new()
    }
}

-- constructor for CLocomotionStateMachine
---@return CLocomotionStateMachine
function CLocomotionStateMachine:new()
    ---@type CLocomotionStateMachine
    local newObj = AbstractStateMachine:new()
    self.__index = self
    setmetatable(newObj, self)
    return newObj
end

return CLocomotionStateMachine
