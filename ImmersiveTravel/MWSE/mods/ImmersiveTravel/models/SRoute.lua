local RouteId = require("ImmersiveTravel.models.RouteId")

---@class SRoute
---@field id RouteId The route id
---@field segments string[] The route segments
---@field nodes table<string,Node> NodeId -> Node (A -> Node)
---@field graph table<string, string[]> Adjacency graph (A, { B, B })
local SRoute  = {}

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
function SRoute:GetSegments(service)
    local segments = {}

    for _, segmentId in ipairs(self.segments) do
        local segment = service:GetSegment(segmentId)
        if segment then
            table.insert(segments, segment)
        end
    end

    return segments
end

---@param array any[]
local function reverse(array)
    local reversed = {}
    for i = #array, 1, -1 do
        table.insert(reversed, array[i])
    end
    return reversed
end

---@param service ServiceData
---@param segmentName string
---@return tes3vector3[]?
function SRoute:GetSegmentRoute(service, segmentName)
    local segment = service:GetSegment(segmentName)
    if not segment then return nil end

    local spline = segment:GetRoute()
    if not spline then return nil end

    -- reverse the spline if the route is backwards
    local node = self.nodes[segmentName]
    if node and node.reverse then
        spline = reverse(spline)
    end

    return spline
end

---@param service ServiceData
---@param segmentName string
---@return tes3vector3?
function SRoute:GetStartingPoint(service, segmentName)
    local segment = service:GetSegment(segmentName)
    if not segment then return nil end

    local spline = segment:GetRoute()
    if not spline then return nil end

    -- reverse the spline if the route is backwards
    local node = self.nodes[segmentName]
    if node and node.reverse then
        spline = reverse(spline)
    end

    return spline[1]
end

-- Function to get all nodes with a given name
---@param name string
---@return Node[]
function SRoute:getNodesByName(name)
    local nodes = {} ---@type Node[]

    local node = self.nodes[name]
    if node then
        table.insert(nodes, node)
    end

    return nodes
end

return SRoute
