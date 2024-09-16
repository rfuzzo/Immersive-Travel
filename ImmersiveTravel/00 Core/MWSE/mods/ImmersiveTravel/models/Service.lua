---@class ServiceData
---@field class string The npc class name
---@field mount string The mountid
---@field override_npc string[]? register specific npcs with the service
---@field override_mount table<string,string[]>? register specific mounts with the service
---@field ground_offset number DEPRECATED: editor marker offset
---@field guide string[]? guide npcs
-- RUNTIME DATA
---@field segments table<string, SSegment>? segment name -> SSegment
---@field ports table<string, PortData>? cell name -> PortData
---@field routes table<string, SRoute>? routeId -> SRoute
local ServiceData = {}

---@return ServiceData
function ServiceData:new(o)
    o = o or {} -- create object if user does not provide one
    setmetatable(o, self)
    self.__index = self
    return o
end

---@param start string
---@return string[]
function ServiceData:GetDestinations(start)
    local destinations = {}
    for _, route in ipairs(self.routes) do
        if route.start == start then
            table.insert(destinations, route.destination)
        end
    end
    return destinations
end

---@return string[]
function ServiceData:GetStarts()
    return table.keys(self.routes)
end

---@return string[]
function ServiceData:GetPorts()
    return table.keys(self.ports)
end

---@return string[]
function ServiceData:GetSegments()
    return table.keys(self.segments)
end

---@param cell string
---@return PortData?
function ServiceData:GetPort(cell)
    return self.ports[cell]
end

---@param segment string
---@return SSegment?
function ServiceData:GetSegment(segment)
    return self.segments[segment]
end

---@param id RouteId
---@return SRoute?
function ServiceData:GetRoute(id)
    return self.routes[id:ToString()]
end

return ServiceData
