local PortData = require("ImmersiveTravel.models.PortData")

---@class SPort
---@field data table<string, PortData>
local SPort = {}

---@return SPort
function SPort:new()
    local o = {} -- create object if user does not provide one
    setmetatable(o, self)
    self.__index = self
    return o
end

---@param o SPortDto
---@return SPort
function SPort.fromDto(o)
    local newObj = SPort:new()

    newObj.data = {}
    if o.data then
        for k, v in pairs(o.data) do
            newObj.data[k] = PortData.fromDto(v)
        end
    end

    return newObj
end

return SPort
