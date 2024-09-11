local PositionRecord = require("ImmersiveTravel.models.PositionRecord")

---@class SSegment
---@field id string unique id
---@field routes tes3vector3[][]?
---@field segments SSegment[]?
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
    newObj.routes = {}
    if o.routes then
        for _, route in ipairs(o.routes) do
            local newRoute = {}
            for _, pos in ipairs(route) do
                table.insert(newRoute, PositionRecord.ToVec(pos))
            end
            table.insert(newObj.routes, newRoute)
        end
    end

    -- convert segments
    newObj.segments = {}
    if o.segments then
        for _, segment in ipairs(o.segments) do
            table.insert(newObj.segments, SSegment.fromDto(segment))
        end
    end

    return newObj
end

return SSegment
