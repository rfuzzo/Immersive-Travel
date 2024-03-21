-- Define the base class CTickingEntity
---@class CTickingEntity
---@field referenceHandle mwseSafeObjectHandle
local CTickingEntity = {
    -- Reference handle to the entity
    referenceHandle = tes3.makeSafeObjectHandle(nil)
}


---Constructor for CTickingEntity
---@param reference tes3reference
function CTickingEntity:new(reference)
    local newObj = {
        referenceHandle = tes3.makeSafeObjectHandle(reference)
    } ---@type CTickingEntity
    setmetatable(newObj, self)
    self.__index = self

    return newObj
end

---Called on each tick of the timer
function CTickingEntity:OnTick()
    -- Override this method in subclasses
end

-- Define the base class CTickingEntity
function CTickingEntity:Delete()
    -- Release the reference handle
    if self.referenceHandle:valid() then
        self.referenceHandle:getObject():delete()
    end
end

return CTickingEntity
