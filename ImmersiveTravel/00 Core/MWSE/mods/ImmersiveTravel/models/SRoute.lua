---@class SRoute
---@field start string The start cell name
---@field destination string The destination cell name
---@field service string The service class name
---@field segments string[] The route segments
---@field segmentsMetaData table<string, SSegmentMetaData> The route segments meta data
local SRoute = {}

---@return string
function SRoute:GetId()
    return self.start .. "_" .. self.destination
end

return SRoute
