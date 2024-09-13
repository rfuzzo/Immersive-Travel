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
---@field private services table<string, ServiceData>? service name -> ServiceData
---@field spawnPoints table<string, SPointDto[]> TODO
---@field routesPrice table<string, number> TODO
local RoutesManager = {
    services    = {},
    spawnPoints = {},
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
---@return table<string, SRoute>
local function loadRoutes(service)
    local map = {} ---@type table<string, SRoute>

    local portPath = string.format("%s\\data\\%s\\routes", lib.fullmodpath, service.class)
    for file in lfs.dir(portPath) do
        if (string.endswith(file, ".toml")) then
            local filePath = string.format("%s\\%s", portPath, file)

            local result = toml.loadFile(filePath) ---@type SRoute?
            if result then
                local route = SRoute:new(result)
                map[route.id:ToString()] = route

                log:debug("\t\tAdding route %s", result.id)
            else
                log:warn("\t\tFailed to load route %s", file)
            end
        end
    end

    -- TODO construct splines

    return map
end

-- TODO price
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

---@class Node
---@field id string
---@field route number

---@class Edge
---@field from string
---@field to string


function RoutesManager:BuildGraph()
    local nodes = {} ---@class Node[]
    local edges = {} ---@class Edge[]

    local cursor = nil ---@type tes3vector3?

    -- build a graph
    for _, service in pairs(self.services) do
        for _, route in pairs(service.routes) do
            -- start and end port
            local startPort = service.ports[route.id.start]
            local startPos = startPort:StartPos()
            local endPort = service.ports[route.id.destination]
            local endPos = endPort:EndPos()

            cursor = startPos

            for _, segmentId in ipairs(route.segments) do
                local segment = service:GetSegment(segmentId)
                assert(segment)
                local conections = segment:GetConnections()
                -- check if we have a connection

                for _, connection in ipairs(conections) do
                    if connection.pos == cursor then
                        -- add node
                        ---@type Node
                        local node = {
                            id = segmentId,
                            route = connection.route
                        }
                        table.insert(nodes, node)

                        -- add edge
                    end
                end
            end
        end
    end
end

-- init manager
--- @return boolean
function RoutesManager:Init()
    -- cleanup
    self.services = {}
    self.spawnPoints = {}
    self.routesPrice = {}

    -- init services
    self.services = table.copy(interop.services)
    if not self.services then
        return false
    end

    -- load routes into memory
    log:info("Found %s services", table.size(self.services))
    for _, service in pairs(self.services) do
        log:info("\tAdding %s service", service.class)

        service.ports = loadPorts(service)
        service.routes = loadRoutes(service)
        service.segments = loadSegments(service)
    end

    self:BuildGraph()

    return true
end

---@param routeId RouteId
---@return number?
function RoutesManager:GetRoutePrice(routeId)
    return self.routesPrice[routeId]
end

---@param name string
---@return ServiceData?
function RoutesManager:GetService(name)
    return self.services[name]
end

function RoutesManager.GetServices()
    return RoutesManager.getInstance().services
end

return RoutesManager
