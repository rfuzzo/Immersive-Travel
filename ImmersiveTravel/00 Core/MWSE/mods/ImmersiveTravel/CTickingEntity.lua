local TrackingManager = require("ImmersiveTravel.CTrackingManager")
local CLocomotionStateMachine = require("ImmersiveTravel.Statemachine.locomotion.CLocomotionStateMachine")
local CAiStateMachine = require("ImmersiveTravel.Statemachine.ai.CAiStateMachine")

-- Define the base class CTickingEntity
---@class CTickingEntity
---@field referenceHandle mwseSafeObjectHandle
---@field id string?
---@field locomotionStateMachine CLocomotionStateMachine
---@field aiStateMachine CAiStateMachine
local CTickingEntity = {}

---Constructor for CTickingEntity
---@return CTickingEntity
function CTickingEntity:new()
    ---@type CTickingEntity
    local newObj = {
        referenceHandle = tes3.makeSafeObjectHandle(nil),
        locomotionStateMachine = CLocomotionStateMachine:new(),
        aiStateMachine = CAiStateMachine:new()
    }
    setmetatable(newObj, self)
    self.__index = self

    return newObj
end

---Create a new instance of CTickingEntity
---@param position tes3vector3
---@param orientation tes3vector3
---@param facing number
---@return CTickingEntity
function CTickingEntity:create(position, orientation, facing)
    -- create reference
    local reference = tes3.createReference {
        object = self.id,
        position = position,
        orientation = orientation
    }
    reference.facing = facing

    ---@type CTickingEntity
    local newObj = {
        referenceHandle = tes3.makeSafeObjectHandle(reference),
        id = reference.id,
        locomotionStateMachine = CLocomotionStateMachine:new(),
        aiStateMachine = CAiStateMachine:new()
    }
    setmetatable(newObj, self)
    self.__index = self

    -- register all ticking entities with the CTrackingManager
    TrackingManager.getInstance():AddEntity(newObj)
    return newObj
end

-- Define the base class CTickingEntity
function CTickingEntity:Delete()
    -- Release the reference handle
    if self.referenceHandle:valid() then
        self.referenceHandle:getObject():delete()
    end

    self:Detach()
end

---Called on each tick of the timer
---@param dt number
function CTickingEntity:OnTick(dt)
    self.locomotionStateMachine:update(dt, self)
    self.aiStateMachine:update(dt, self)
end

-- ---Register the entity with the CTrackingManager
-- ---@param reference tes3reference
-- function CTickingEntity:register(reference)
--     self.referenceHandle = tes3.makeSafeObjectHandle(reference)
--     self:Attach()
-- end

function CTickingEntity:Attach()
    -- register all ticking entities with the CTrackingManager
    TrackingManager.getInstance():AddEntity(self)
end

function CTickingEntity:Detach()
    -- remove the entity from the CTrackingManager
    TrackingManager.getInstance():RemoveEntity(self)
end

--#region events

function CTickingEntity:OnActivate()
    -- Override this method in the child class
end

--#endregion

return CTickingEntity
