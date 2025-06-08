local PositionRecord = require("ImmersiveTravel.models.PositionRecord")

---@class SSegment
---@field id string? unique id
---@field route1 tes3vector3[]?
local SSegment = {}

---@return SSegment
function SSegment:new()
    local o = {} -- create object if user does not provide one
    setmetatable(o, self)
    self.__index = self
    return o
end

---@param o SSegmentDto
---@return SSegment
function SSegment.fromDto(o)
    local newObj = SSegment:new()
    newObj.id = o.id

    -- convert routes
    if o.route1 then
        newObj.route1 = {}
        for _, pos in ipairs(o.route1) do
            table.insert(newObj.route1, PositionRecord.ToVec(pos))
        end
    end

    return newObj
end

---@return tes3vector3[]?
function SSegment:GetRoute()
    return self.route1
end

---@class SegmentConnection
---@field pos tes3vector3

---@return SegmentConnection[]
function SSegment:GetConnections()
    local connections = {} --@type SegmentConnection[]

    if self.route1 then
        ---@class SegmentConnection
        local first = {
            pos = self.route1[1]
        }
        table.insert(connections, first)

        ---@class SegmentConnection
        local last = {
            pos = self.route1[#self.route1]
        }
        table.insert(connections, last)
    end

    return connections
end

return SSegment
