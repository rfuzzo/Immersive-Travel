---@class SRoute
---@field id RouteId The route id
---@field segments string[] The route segments
---@field segmentsMetaData table<string, SSegmentMetaData> The route segments meta data
local SRoute = {}

---@return SRoute
function SRoute:new(o)
    o = o or {} -- create object if user does not provide one
    setmetatable(o, self)
    self.__index = self
    return o
end

---@return string
function SRoute:GetId()
    return self.id:__tostring()
end

return SRoute
