local TrackingManager = require("ImmersiveTravel.CTrackingManager")
local CLocomotionStateMachine = require("ImmersiveTravel.Statemachine.CLocomotionStateMachine")
local CAiStateMachine = require("ImmersiveTravel.Statemachine.CAiStateMachine")

-- Define the base class CTickingEntity
---@class CTickingEntity
---@field referenceHandle mwseSafeObjectHandle
---@field id string?
---@field locomotionStateMachine CLocomotionStateMachine
---@field aiStateMachine CAiStateMachine
local CTickingEntity = {
    -- Reference handle to the entity
    referenceHandle = tes3.makeSafeObjectHandle(nil),
    id = nil,
    locomotionStateMachine = CLocomotionStateMachine:new(),
    aiStateMachine = CAiStateMachine:new()
}


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
---@param reference tes3reference
---@return CTickingEntity
function CTickingEntity:create(reference)
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

---Register the entity with the CTrackingManager
---@param reference tes3reference
function CTickingEntity:register(reference)
    self.referenceHandle = tes3.makeSafeObjectHandle(reference)
    self:Attach()
end

function CTickingEntity:Attach()
    -- register all ticking entities with the CTrackingManager
    TrackingManager.getInstance():AddEntity(self)
end

---Called on each tick of the timer
---@param dt number
function CTickingEntity:OnTick(dt)
    self.locomotionStateMachine:update(dt)
    self.aiStateMachine:update(dt)
end

-- Define the base class CTickingEntity
function CTickingEntity:Delete()
    -- Release the reference handle
    if self.referenceHandle:valid() then
        self.referenceHandle:getObject():delete()
    end

    self:Detach()
end

function CTickingEntity:Detach()
    -- remove the entity from the CTrackingManager
    TrackingManager.getInstance():RemoveEntity(self)
end

return CTickingEntity
