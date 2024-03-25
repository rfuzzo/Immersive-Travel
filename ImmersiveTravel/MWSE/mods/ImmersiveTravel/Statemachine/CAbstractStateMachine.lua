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
---@param scriptedObject CTickingEntity
function CAbstractStateMachine:update(dt, scriptedObject)
    -- transition to the new state if needed
    -- go through the transitions of the current state
    for state, transition in pairs(self.currentState.transitions) do
        local ctx = {
            scriptedObject = scriptedObject
        }
        if transition(ctx) then
            self.currentState:exit(scriptedObject)
            self.currentState = self.states[state]
            self.currentState:enter(scriptedObject)
        end
    end

    -- update the current state
    self.currentState:update(dt, scriptedObject)
end

--#region events

---@param scriptedObject CTickingEntity
function CAbstractStateMachine:OnActivate(scriptedObject)
    self.currentState:OnActivate(scriptedObject)
end

--#endregion

return CAbstractStateMachine
