local RouteId = require("ImmersiveTravel.models.RouteId")

---@class SRoute
---@field id RouteId The route id
---@field segments string[] The route segments
---@field nodes table<string,Node> NodeId -> Node (A#1 -> Node)
---@field graph table<string, string[]> Adjacency graph (A#1, { B#1, B#2 })
---@field lut table<string,number[]> Segment to route number lookup (A -> { 1, 2 }
local SRoute = {}

---@return SRoute
function SRoute:new(o)
    ---@type SRoute
    o = o or {} -- create object if user does not provide one

    if o.id then
        o.id = RouteId:new(o.id.service, o.id.start, o.id.destination)
    end

    if not o.nodes then
        o.nodes = {}
    end
    if not o.segments then
        o.segments = {}
    end

    setmetatable(o, self)
    self.__index = self
    return o
end

---@param service ServiceData
---@return SSegment[]
function SRoute:GetSegmentsResolved(service)
    local segments = {}

    for _, segmentId in ipairs(self.segments) do
        local segment = service:GetSegment(segmentId)
        if segment then
            local subsegments = segment:GetSegmentsRecursive()
            for _, subsegment in ipairs(subsegments) do
                table.insert(segments, subsegment)
            end
        end
    end

    return segments
end

---@param service ServiceData
---@param segmentName string
---@return tes3vector3[]?
function SRoute:GetSegmentRoute(service, segmentName)
    local segment = service:GetSegment(segmentName)

    if segment then
        local nodes = self.lut[segmentName]
        return segment:GetRoute(table.choice(nodes))
    end

    return nil
end

-- Function to get all nodes with a given name
---@param name string
---@return Node[]
function SRoute:getNodesByName(name)
    local nodes = {} ---@type Node[]
    if self.lut[name] then
        for _, number in ipairs(self.lut[name]) do
            local id = string.format("%s#%d", name, number)
            local node = self.nodes[id]
            if node then
                table.insert(nodes, node)
            end
        end
    end
    return nodes
end

return SRoute
