-- CAbstractState.lua

-- Define the CAbstractState class
---@class CAbstractState
---@field transitions table<string, function>
local CAbstractState = {
    transitions = {}
}
CAbstractState.__index = CAbstractState

-- Constructor
---@return CAbstractState
function CAbstractState:new()
    ---@type CAbstractState
    local newObj = {
        transitions = {}
    }
    setmetatable(newObj, CAbstractState)
    self.__index = self
    return newObj
end

-- Method to enter the state
function CAbstractState:enter()
    -- Add code to be executed when entering the state
end

-- Method to exit the state
function CAbstractState:exit()
    -- Add code to be executed when exiting the state
end

-- Method to update the state
function CAbstractState:update(dt)
    -- Add code to update the state based on the elapsed time (dt)
end

-- Return the CAbstractState class
return CAbstractState
