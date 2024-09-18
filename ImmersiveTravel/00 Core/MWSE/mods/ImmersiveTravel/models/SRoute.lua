local RouteId = require("ImmersiveTravel.models.RouteId")

---@class SRoute
---@field id RouteId The route id
---@field segments string[] The route segments
---@field nodes Node[] The route nodes TODO MAKE THIS A MAP
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

---@param idx number
---@return number?
function SRoute:GetSegmentRouteIdx(idx)
    local segment = self.segments[idx]
    if segment then
        -- check nodes
        for _, node in ipairs(self.nodes) do
            if node.id == segment then
                return node.route
            end
        end
    end

    return nil
end

return SRoute
