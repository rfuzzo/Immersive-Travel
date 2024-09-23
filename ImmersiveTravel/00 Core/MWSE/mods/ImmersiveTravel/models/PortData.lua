local PositionRecord = require("ImmersiveTravel.models.PositionRecord")

---@class PortData
---@field private position tes3vector3 The port position
---@field private rotation tes3vector3 The port orientation
---@field private positionEnd tes3vector3? The docked orientation
---@field private rotationEnd tes3vector3? The docked orientation
---@field private positionStart tes3vector3? The start orientation
---@field private rotationStart tes3vector3? The start orientation
---@field private reverseStart boolean? reverse out of dock?
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

---@return boolean
function PortData:HasStart()
    return self.positionStart ~= nil
end

---@return boolean
function PortData:IsReverse()
    return self.reverseStart
end

---@return tes3vector3?
function PortData:GetPosition()
    return self.position
end

---@return tes3vector3
function PortData:StartPos()
    return self.positionStart or self.position
end

---@return tes3vector3
function PortData:EndPos()
    return self.positionEnd or self.position
end

---@return boolean
function PortData:HasStartRot()
    return self.rotationStart ~= nil
end

---@return tes3vector3
function PortData:GetRot()
    return self.rotation
end

---@return tes3vector3
function PortData:StartRot()
    return self.rotationStart or self.rotation
end

---@return tes3vector3
function PortData:EndRot()
    return self.rotationEnd or self.rotation
end

return PortData
