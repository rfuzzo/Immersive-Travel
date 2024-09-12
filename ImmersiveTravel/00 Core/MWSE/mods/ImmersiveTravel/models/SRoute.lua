local RouteId = require("ImmersiveTravel.models.RouteId")

---@class SRoute
---@field id RouteId The route id
---@field segments string[] The route segments
---@field segmentsMetaData table<string, SSegmentMetaData> The route segments meta data
local SRoute = {}

---@return SRoute
function SRoute:new(o)
    ---@type SRoute
    o = o or {} -- create object if user does not provide one

    if o.id then
        o.id = RouteId:new(o.id.service, o.id.start, o.id.destination)
    end

    setmetatable(o, self)
    self.__index = self
    return o
end

return SRoute
