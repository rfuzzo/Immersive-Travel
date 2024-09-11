---@class ServiceData
---@field class string The npc class name
---@field mount string The mountid
---@field override_npc string[]? register specific npcs with the service
---@field override_mount table<string,string[]>? register specific mounts with the service
---@field ground_offset number DEPRECATED: editor marker offset
---@field guide string[]? guide npcs
---@field ports string[]? RUNTIME port list
---@field routes RouteId[]? RUNTIME routes list
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

---@return ServiceData
