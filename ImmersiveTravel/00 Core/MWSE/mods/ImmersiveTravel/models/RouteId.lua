---@class RouteId
---@field service string
---@field start string
---@field destination string
local RouteId = {}

---@return RouteId
function RouteId:new(service, start, destination)
    ---@type RouteId
    local o = {
        service = service,
        start = start,
        destination = destination
    } -- create object if user does not provide one

    setmetatable(o, self)
    self.__index = self
    return o
end

-- tostring
---@return string
function RouteId:ToString()
    return string.format("%s_%s_%s", self.service, self.start, self.destination)
end

-- tostring
---@return string
function RouteId:__tostring()
    return self:ToString()
end

-- equality
---@param other RouteId
---@return boolean
function RouteId:__eq(other)
    return self.service == other.service and self.start == other.start and self.destination == other.destination
end

return RouteId
