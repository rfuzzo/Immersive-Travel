local CAbstractStateMachine = require("ImmersiveTravel.Statemachine.CAbstractStateMachine")
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
setmetatable(CLocomotionStateMachine, { __index = CAbstractStateMachine })

-- constructor for CLocomotionStateMachine
---@return CLocomotionStateMachine
function CLocomotionStateMachine:new()
    local newObj = CAbstractStateMachine:new()
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj CLocomotionStateMachine
    return newObj
end

return CLocomotionStateMachine
