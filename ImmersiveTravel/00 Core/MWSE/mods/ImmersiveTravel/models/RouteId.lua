---@class RouteId
---@field service string
---@field start string
---@field destination string
local RouteId = {}

---@return RouteId
function RouteId:new()
    local o = {} -- create object if user does not provide one
    setmetatable(o, self)
    self.__index = self
    return o
end

-- tostring
---@return string
function RouteId:__tostring()
    return string.format("%s_%s_%s", self.service, self.start, self.destination)
end

return RouteId
