local lib      = require("ImmersiveTravel.lib")
local interop  = require("ImmersiveTravel.interop")
local SRoute   = require("ImmersiveTravel.models.SRoute")
local PortData = require("ImmersiveTravel.models.PortData")
local SSegment = require("ImmersiveTravel.models.SSegment")
local config   = require("ImmersiveTravel.config")
if not config then return end

local log           = lib.log

-- Define a class to manage the splines
---@class GRoutesManager
---@field services table<string, ServiceData>? service name -> ServiceData
---@field spawnPoints table<string, SPointDto[]> TODO
---@field routesPrice table<RouteId, number> TODO
---@field private segments table<string, SSegment> segment name -> SSegment
---@field private ports table<string, PortData> cell name -> PortData
---@field private routes table<RouteId, SRoute> routeId -> SRoute
local RoutesManager = {
    services    = {},
    spawnPoints = {},
    segments    = {},
    ports       = {},
    routes      = {},
    routesPrice = {},
}

function RoutesManager:new()
    local newObj = {}
    self.__index = self
    setmetatable(newObj, self)
    return newObj
end

-- singleton instance
--- @type GRoutesManager?
local instance = nil
--- @return GRoutesManager
function RoutesManager.getInstance()
    if instance == nil then
        instance = RoutesManager:new()
    end
    return instance
end

---@param service ServiceData
---@return table<string, PortData>
local function loadPorts(service)
    local map = {} ---@type table<string, PortData>

    local portPath = string.format("%s\\data\\%s\\ports", lib.fullmodpath, service.class)
    for file in lfs.dir(portPath) do
        if (string.endswith(file, ".toml")) then
            local filePath = string.format("%s\\%s", portPath, file)

            local portName = file:sub(0, -6)
            local result = toml.loadFile(filePath) ---@type PortDataDto?
            if result then
                map[portName] = PortData.fromDto(result)

                log:debug("\t\tAdding port %s", portName)
            else
                log:warn("\t\tFailed to load port %s", portName)
            end
        end
    end

    return map
end

---@param service ServiceData
---@return table<string, SSegment>
local function loadSegments(service)
    local map = {} ---@type table<string, SSegment>

    local segmentsPath = string.format("%s\\data\\%s\\segments", lib.fullmodpath, service.class)
    for file in lfs.dir(segmentsPath) do
        if (string.endswith(file, ".toml")) then
            local filePath = string.format("%s\\%s", segmentsPath, file)

            local result = toml.loadFile(filePath) ---@type SSegmentDto?
            if result then
                map[result.id] = SSegment.fromDto(result)

                log:debug("\t\tAdding segment %s", result.id)
            else
                log:warn("\t\tFailed to load segment %s", file)
            end
        end
    end

    return map
end

---@param service ServiceData
---@return table<RouteId, SRoute>
local function loadRoutes(service)
    local map = {} ---@type table<RouteId, SRoute>

    local portPath = string.format("%s\\data\\%s\\routes", lib.fullmodpath, service.class)
    for file in lfs.dir(portPath) do
        if (string.endswith(file, ".toml")) then
            local filePath = string.format("%s\\%s", portPath, file)

            local result = toml.loadFile(filePath) ---@type SRoute?
            if result then
                map[result.id] = SRoute:new(result)

                log:debug("\t\tAdding route %s", result.id)
            else
                log:warn("\t\tFailed to load route %s", file)
            end
        end
    end

    return map
end

---@param spline tes3vector3[]
---@return number
local function GetPrice(spline)
    local price = 0
    for i = 1, #spline - 1 do
        local p1 = spline[i]
        local p2 = spline[i + 1]

        local distance = p1:distance(p2)
        price = price + distance
    end

    -- divide by cell size
    price = price / 8192

    -- multiply by set number
    price = price * config.priceMult

    return price
end

-- init manager
--- @return boolean
function RoutesManager:Init()
    -- cleanup
    self.services = {}
    self.spawnPoints = {}
    self.segments = {}
    self.ports = {}
    self.routes = {}
    self.routesPrice = {}

    -- init services
    self.services = table.copy(interop.services)
    if not self.services then
        return false
    end

    -- load routes into memory
    log:info("Found %s services", table.size(self.services))
    for _, service in ipairs(self.services) do
        log:info("\tAdding %s service", service.class)

        ports = loadPorts(service)
        routes = loadRoutes(service)
        segments = loadSegments(service)
    end

    return true
end

---@param routeId string
---@return number?
function RoutesManager:GetRoutePrice(routeId)
    return self.routesPrice[routeId]
end

---@param serviceId string
---@param routeId string
---@return PortData?
function RoutesManager:GetDestinationPort(serviceId, routeId)
    local service = self.services[serviceId]

    if service then
        local split = string.split(routeId, "_")
        if #split == 2 then
            local destination = split[2]
            return table.get(service.ports, destination, nil)
        end
    end

    return nil
end

return RoutesManager
