local TrackingManager = require("ImmersiveTravel.CTrackingManager")

-- Define the base class CTickingEntity
---@class CTickingEntity
---@field referenceHandle mwseSafeObjectHandle
---@field id string?
local CTickingEntity = {
    -- Reference handle to the entity
    referenceHandle = tes3.makeSafeObjectHandle(nil),
    id = nil
}


---Constructor for CTickingEntity
---@return CTickingEntity
function CTickingEntity:new()
    ---@type CTickingEntity
    local newObj = {
        referenceHandle = tes3.makeSafeObjectHandle(nil),
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
        id = reference.id
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
    -- Override this method in subclasses
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
