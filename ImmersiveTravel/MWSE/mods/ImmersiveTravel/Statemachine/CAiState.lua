local AbstractState = require("ImmersiveTravel.Statemachine.CAbstractState")

-- Abstract AI state machine class
---@class CAiState : CAbstractState
local CAiState = {
    transitions = {}
}

-- enum for AI states
CAiState.NONE = "NONE"
CAiState.ONSPLINE = "ONSPLINE"
CAiState.PLAYERSTEER = "PLAYERSTEER"

---Constructor for AI State
---@return CAiState
function CAiState:new()
    local newObj = AbstractState:new()
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj CAiState
    return newObj
end

--#region NoneState

-- None State class
---@class NoneState : CAiState
CAiState.NoneState = {
    transitions = {
        [CAiState.ONSPLINE] = function()
            return false
        end,
        [CAiState.PLAYERSTEER] = function()
            return false
        end
    }
}

-- constructor for NoneState
---@return NoneState
function CAiState.NoneState:new()
    local newObj = CAiState:new()
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj NoneState
    return newObj
end

function CAiState.NoneState:enter()
    -- Implement idle state enter logic here
end

function CAiState.NoneState:update(dt)
    -- Implement idle state update logic here
end

function CAiState.NoneState:exit()
    -- Implement idle state exit logic here
end

--#endregion

--#region OnSplineState

-- on spline state class
---@class OnSplineState : CAiState
CAiState.OnSplineState = {
    transitions = {
        [CAiState.NONE] = function()
            return false
        end,
        [CAiState.PLAYERSTEER] = function()
            return false
        end
    }
}

-- constructor for OnSplineState
---@return OnSplineState
function CAiState.OnSplineState:new()
    local newObj = CAiState:new()
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj OnSplineState
    return newObj
end

function CAiState.OnSplineState:enter()
    -- Implement on spline state enter logic here
end

function CAiState.OnSplineState:update(dt)
    -- Implement on spline state update logic here
end

function CAiState.OnSplineState:exit()
    -- Implement on spline state exit logic here
end

--#endregion


--#region PlayerSteerState

-- player steer state class
---@class PlayerSteerState : CAiState
CAiState.PlayerSteerState = {
    transitions = {
        [CAiState.NONE] = function()
            return false
        end,
        [CAiState.ONSPLINE] = function()
            return false
        end
    }
}

-- constructor for PlayerSteerState
---@return PlayerSteerState
function CAiState.PlayerSteerState:new()
    local newObj = CAiState:new()
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj PlayerSteerState
    return newObj
end

function CAiState.PlayerSteerState:enter()
    -- Implement player steer state enter logic here
end

function CAiState.PlayerSteerState:update(dt)
    -- Implement player steer state update logic here
end

function CAiState.PlayerSteerState:exit()
    -- Implement player steer state exit logic here
end

--#endregion

return CAiState
