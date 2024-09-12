local PositionRecord = require("ImmersiveTravel.models.PositionRecord")

---@class SSegment
---@field id string unique id
---@field private route1 tes3vector3[]?
---@field private route2 tes3vector3[]?
---@field private segments SSegment[]?
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

    if o.route2 then
        newObj.route2 = {}
        for _, pos in ipairs(o.route2) do
            table.insert(newObj.route2, PositionRecord.ToVec(pos))
        end
    end

    -- convert segments
    newObj.segments = {}
    if o.segments then
        for _, segment in ipairs(o.segments) do
            -- create id if not exists
            if not segment.id then
                segment.id = string.format("%s_%d", newObj.id, #newObj.segments)
            end
            table.insert(newObj.segments, SSegment.fromDto(segment))
        end
    end

    return newObj
end

---@return boolean
function SSegment:IsSegmentSet()
    return self.segments and #self.segments > 0
end

---@return SSegment[]
function SSegment:GetSegmentsRecursive()
    local segments = {} --@type SSegment[]

    if self:IsSegmentSet() then
        for _, segment in ipairs(self.segments) do
            local subsegments = segment:GetSegmentsRecursive()
            for _, subsegment in ipairs(subsegments) do
                table.insert(segments, subsegment)
            end
        end
    else
        table.insert(segments, self)
    end

    return segments
end

---@return tes3vector3[]?
function SSegment:GetRoute(idx)
    if self:IsSegmentSet() then
        return nil
    end

    if idx == 1 then
        return self:GetRoute1()
    elseif idx == 2 then
        return self:GetRoute2()
    else
        return nil
    end
end

---@return tes3vector3[]?
function SSegment:GetRoute1()
    if self:IsSegmentSet() then
        return nil
    end

    return self.route1
end

---@return tes3vector3[]?
function SSegment:GetRoute2()
    if self:IsSegmentSet() then
        return nil
    end

    return self.route2
end

---@return tes3vector3[]
function SSegment:GetNodesRecursive()
    local nodes = {} --@type tes3vector3[]

    local segments = self:GetSegmentsRecursive()
    for _, segment in ipairs(segments) do
        if self.route1 then
            -- get first and last node
            local first = self.route1[1]
            if not table.find(nodes, first) then
                table.insert(nodes, first)
            end

            local last = self.route1[#self.route1]
            if not table.find(nodes, last) then
                table.insert(nodes, last)
            end
        end

        if self.route2 then
            -- get first and last node
            local first = self.route2[1]
            if not table.find(nodes, first) then
                table.insert(nodes, first)
            end

            local last = self.route2[#self.route2]
            if not table.find(nodes, last) then
                table.insert(nodes, last)
            end
        end
    end

    return nodes
end

return SSegment
