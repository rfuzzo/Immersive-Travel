local AbstractState = require("ImmersiveTravel.Statemachine.CAbstractState")

-- Abstract locomotion state machine class
---@class CLocomotionState : CAbstractState
local CLocomotionState = {
    transitions = {}
}

-- enum for locomotion states
CLocomotionState.IDLE = "IDLE"
CLocomotionState.MOVING = "MOVING"
CLocomotionState.ACCELERATE = "ACCELERATE"
CLocomotionState.DECELERATE = "DECELERATE"

---Constructor for LocomotionState
---@return CLocomotionState
function CLocomotionState:new()
    local newObj = AbstractState:new()
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj CLocomotionState
    return newObj
end

--#region IdleState

-- Idle state class
---@class IdleState : CLocomotionState
CLocomotionState.IdleState = {
    transitions = {
        [CLocomotionState.MOVING] = function()
            return false
        end,
        [CLocomotionState.ACCELERATE] = function()
            return false
        end,
        [CLocomotionState.DECELERATE] = function()
            return false
        end
    }
}

-- constructor for IdleState
---@return IdleState
function CLocomotionState.IdleState:new()
    local newObj = CLocomotionState:new()
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj IdleState
    return newObj
end

function CLocomotionState.IdleState:enter()
    -- Implement idle state enter logic here
end

function CLocomotionState.IdleState:update(dt)
    -- Implement idle state update logic here
end

function CLocomotionState.IdleState:exit()
    -- Implement idle state exit logic here
end

--#endregion

--#region MovingState

-- Moving state class
---@class MovingState : CLocomotionState
CLocomotionState.MovingState = {
    transitions = {
        [CLocomotionState.IDLE] = function()
            return false
        end,
        [CLocomotionState.ACCELERATE] = function()
            return false
        end,
        [CLocomotionState.DECELERATE] = function()
            return false
        end
    }
}

-- constructor for MovingState
---@return MovingState
function CLocomotionState.MovingState:new()
    local newObj = CLocomotionState:new()
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj MovingState
    return newObj
end

function CLocomotionState.MovingState:enter()
    -- Implement moving state enter logic here
end

function CLocomotionState.MovingState:update(dt)
    -- Implement moving state update logic here
end

function CLocomotionState.MovingState:exit()
    -- Implement moving state exit logic here
end

--#endregion

--#region AccelerateState

-- Accelerate state class
---@class AccelerateState : CLocomotionState
CLocomotionState.AccelerateState = {
    transitions = {
        [CLocomotionState.IDLE] = function()
            return false
        end,
        [CLocomotionState.MOVING] = function()
            return false
        end,
        [CLocomotionState.DECELERATE] = function()
            return false
        end
    }
}

-- constructor for MovingState
---@return AccelerateState
function CLocomotionState.AccelerateState:new()
    local newObj = CLocomotionState:new()
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj AccelerateState
    return newObj
end

function CLocomotionState.AccelerateState:enter()
    -- Implement accelerate state enter logic here
end

function CLocomotionState.AccelerateState:update(dt)
    -- Implement accelerate state update logic here
end

function CLocomotionState.AccelerateState:exit()
    -- Implement accelerate state exit logic here
end

--#endregion

--#region DecelerateState

-- Decelerate state class
---@class DecelerateState : CLocomotionState
CLocomotionState.DecelerateState = {
    transitions = {
        [CLocomotionState.IDLE] = function()
            return false
        end,
        [CLocomotionState.MOVING] = function()
            return false
        end,
        [CLocomotionState.ACCELERATE] = function()
            return false
        end
    }
}

-- constructor for MovingState
---@return DecelerateState
function CLocomotionState.DecelerateState:new()
    local newObj = CLocomotionState:new()
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj DecelerateState
    return newObj
end

function CLocomotionState.DecelerateState:enter()
    -- Implement decelerate state enter logic here
end

function CLocomotionState.DecelerateState:update(dt)
    -- Implement decelerate state update logic here
end

function CLocomotionState.DecelerateState:exit()
    -- Implement decelerate state exit logic here
end

--#endregion

return CLocomotionState
