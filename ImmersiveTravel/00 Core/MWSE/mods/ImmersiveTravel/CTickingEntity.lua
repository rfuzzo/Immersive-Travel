local TrackingManager         = require("ImmersiveTravel.GTrackingManager")
local CLocomotionStateMachine = require("ImmersiveTravel.Statemachine.locomotion.CLocomotionStateMachine")
local CAiStateMachine         = require("ImmersiveTravel.Statemachine.ai.CAiStateMachine")

local lib                     = require("ImmersiveTravel.lib")
local log                     = lib.log

-- Define the base class CTickingEntity
---@class CTickingEntity
---@field markForDelete boolean
---@field referenceHandle mwseSafeObjectHandle
---@field id string?
---@field refid number?
---@field locomotionStateMachine CLocomotionStateMachine
---@field aiStateMachine CAiStateMachine
local CTickingEntity          = {}

---Constructor for CTickingEntity
---@return CTickingEntity
function CTickingEntity:new()
    ---@type CTickingEntity
    local newObj = {
        markForDelete = false,
        referenceHandle = tes3.makeSafeObjectHandle(nil),
        locomotionStateMachine = CLocomotionStateMachine:new(),
        aiStateMachine = CAiStateMachine:new()
    }
    setmetatable(newObj, self)
    self.__index = self
    return newObj
end

---Get the id of the entity
---@return string
function CTickingEntity:Id()
    return self.id .. "_" .. tostring(self.refid)
end

-- Define the base class CTickingEntity
function CTickingEntity:Delete()
    log:trace("CTickingEntity Delete %s", self:Id())

    self:Detach()

    -- Release the reference handle
    if self.referenceHandle:valid() then
        self.referenceHandle:getObject():delete()
    end
    self.referenceHandle = nil
end

---Called on each tick of the timer
---@param dt number
function CTickingEntity:OnTick(dt)
    self.aiStateMachine:update(dt, self)
    self.locomotionStateMachine:update(dt, self)
end

function CTickingEntity:Attach()
    -- register all ticking entities with the GTrackingManager
    TrackingManager.getInstance():AddEntity(self)
end

function CTickingEntity:Detach()
    -- remove the entity from the GTrackingManager
    TrackingManager.getInstance():RemoveEntity(self)
end

--#region events

function CTickingEntity:OnActivate()
    -- Override this method in the child class
end

--#endregion

return CTickingEntity
