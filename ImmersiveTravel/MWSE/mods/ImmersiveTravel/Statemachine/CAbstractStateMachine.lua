-- Define the CAbstractStateMachine class
---@class CAbstractStateMachine
---@field currentState CAbstractState
---@field states table<string, CAbstractState>
local CAbstractStateMachine = {}
CAbstractStateMachine.__index = CAbstractStateMachine

-- Constructor
function CAbstractStateMachine:new()
    local newObj = {}
    self.__index = self
    setmetatable(newObj, self)
    return newObj
end

-- update the current state
---@param dt number
function CAbstractStateMachine:update(dt)
    -- transition to the new state if needed
    -- go through the transitions of the current state
    for state, transition in pairs(self.currentState.transitions) do
        if transition() then
            self.currentState:exit()
            self.currentState = self.states[state]
            self.currentState:enter()
        end
    end

    -- update the current state
    self.currentState:update(dt)
end

return CAbstractStateMachine
