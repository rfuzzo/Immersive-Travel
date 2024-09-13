local PositionRecord = require("ImmersiveTravel.models.PositionRecord")

---@class PortData
---@field position tes3vector3 The port position
---@field rotation tes3vector3 The port orientation
---@field positionEnd tes3vector3? The docked orientation
---@field rotationEnd tes3vector3? The docked orientation
---@field positionStart tes3vector3? The start orientation
---@field rotationStart tes3vector3? The start orientation
---@field reverseStart boolean? reverse out of dock?
local PortData = {}

---@return PortData
function PortData:new()
    local o = {} -- create object if user does not provide one
    setmetatable(o, self)
    self.__index = self
    return o
end

---@param o PortDataDto
---@return PortData
function PortData.fromDto(o)
    local newObj = PortData:new()
    newObj.position = PositionRecord.ToVec(o.position)
    newObj.rotation = PositionRecord.ToVec(o.rotation)
    newObj.positionEnd = o.positionEnd and PositionRecord.ToVec(o.positionEnd) or nil
    newObj.rotationEnd = o.rotationEnd and PositionRecord.ToVec(o.rotationEnd) or nil
    newObj.positionStart = o.positionStart and PositionRecord.ToVec(o.positionStart) or nil
    newObj.rotationStart = o.rotationStart and PositionRecord.ToVec(o.rotationStart) or nil
    newObj.reverseStart = o.reverseStart
    return newObj
end

function PortData:StartPos()
    return self.positionStart or self.position
end

function PortData:EndPos()
    return self.positionEnd or self.position
end

return PortData
