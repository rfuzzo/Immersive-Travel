-- CAbstractState.lua

-- Define the CAbstractState class
---@class CAbstractState
---@field name? string
---@field transitions table<string, function>
local CAbstractState = {}

-- Constructor
---@return CAbstractState
function CAbstractState:new()
    -----@type CAbstractState
    local newObj = {

    }
    setmetatable(newObj, self)
    self.__index = self
    return newObj
end

-- Method to enter the state
---@param scriptedObject CTickingEntity
function CAbstractState:enter(scriptedObject)
    -- Add code to be executed when entering the state
end

-- Method to exit the state
---@param scriptedObject CTickingEntity
function CAbstractState:exit(scriptedObject)
    -- Add code to be executed when exiting the state
end

-- Method to update the state
---@param dt number
---@param scriptedObject CTickingEntity
function CAbstractState:update(dt, scriptedObject)
    -- Add code to update the state based on the elapsed time (dt)
end

--#region events

---@param scriptedObject CTickingEntity
function CAbstractState:OnActivate(scriptedObject)
    -- override in child classes
end

--#endregion

-- Return the CAbstractState class
return CAbstractState
