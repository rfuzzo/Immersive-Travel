local TrackingManager = require("ImmersiveTravel.CTrackingManager")

-- Define the base class CTickingEntity
---@class CTickingEntity
---@field referenceHandle mwseSafeObjectHandle
---@field id string?
---@field locomotionState CLocomotionState
---@field aiState CAiState
local CTickingEntity = {
    -- Reference handle to the entity
    referenceHandle = tes3.makeSafeObjectHandle(nil),
    id = nil,
    locomotionState = CLocomotionState.IDLE,
    aiState = CAiState.NONE
}


---Constructor for CTickingEntity
---@return CTickingEntity
function CTickingEntity:new()
    ---@type CTickingEntity
    local newObj = {
        referenceHandle = tes3.makeSafeObjectHandle(nil),
        locomotionState = CLocomotionState.IDLE,
        aiState = CAiState.NONE
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
        locomotionState = CLocomotionState.IDLE,
        aiState = CAiState.NONE
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

function CTickingEntity:UpdateState()
    -- Update state based on conditions, e.g., speed, user input, etc.
    -- Override this method in subclasses
end

---Called on each tick of the timer
---@param dt number
function CTickingEntity:OnTick(dt)
    -- Override this method in subclasses
    self:UpdateState()

    self.locomotionState:OnTick(dt)
    self.aiState:OnTick(dt)
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
