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

---@param node Node
---@return string
local function NodeId(node)
    return string.format("%s%d", node.id, node.route)
end

---@param service ServiceData
---@param route SRoute
---@return Node[]
local function BuildGraph(service, route)
    local cursor = {} ---@type Node[]
    local nodes = {} ---@type Node[]

    log:debug("Route '%s'", route.id:ToString())
    -- start and end port
    local startPort = service.ports[route.id.start]
    local startPos = startPort:StartPos()
    ---@type Node
    local startNode = {
        id = route.id.start,
        route = 1,
        position = startPos,
        to = {}
    }
    table.insert(nodes, startNode)

    -- start with port
    cursor = {}
    table.insert(cursor, startNode)

    for _, segmentId in ipairs(route.segments) do
        local segment = service:GetSegment(segmentId)
        assert(segment)

        -- check if we have a connection
        local newCursor = {} ---@type Node[]

        local conections = segment:GetConnections()
        log:trace("Segment '%s', conections %d", segmentId, #conections)
        for _, lastCursor in ipairs(cursor) do
            log:trace(" - Last cursor: %s - %s", NodeId(lastCursor), lastCursor.position)
            for i, connection in ipairs(conections) do
                -- log:trace(" - Connection %d - %s", i, connection.pos)
                if connection.pos == lastCursor.position then
                    -- add node
                    -- get end position of route
                    local croute = segment:GetRoute(connection.route)
                    assert(croute)
                    local routeEndPos = croute[#croute]
                    local routeStartPos = croute[1]
                    local routePos = nil
                    if connection.pos == routeEndPos then
                        routePos = routeStartPos
                    else
                        routePos = routeEndPos
                    end

                    ---@type Node
                    local node = {
                        id = segmentId,
                        route = connection.route,
                        position = routePos,
                        --from = NodeId(lastCursor),
                        to = {}
                    }

                    log:debug(" + Adding connection: '%s' (%s) -> '%s' (%s)", NodeId(lastCursor), lastCursor.position,
                        NodeId(node), routePos)

                    -- modify last node
                    for _, n in ipairs(nodes) do
                        if NodeId(n) == NodeId(lastCursor) then
                            table.insert(n.to, NodeId(node))
                            break
                        end
                    end

                    table.insert(nodes, node)
                    table.insert(newCursor, node)
                end
            end
        end

        cursor = newCursor
    end

    -- add end node
    local endPort = service.ports[route.id.destination]
    local endPos = endPort:EndPos()
    for _, lastCursor in ipairs(cursor) do
        log:trace(" - Last cursor: %s - %s", NodeId(lastCursor), lastCursor.position)
        if endPos == lastCursor.position then
            local node = {
                id = route.id.destination,
                route = 1,
                position = endPos,
                to = {}
                --from = NodeId(lastCursor),
            }

            log:debug(" + Adding connection: %s -> %s", NodeId(lastCursor), NodeId(node))

            -- modify last node
            -- find in nodes
            for _, n in ipairs(nodes) do
                if NodeId(n) == NodeId(lastCursor) then
                    table.insert(n.to, NodeId(node))
                    break
                end
            end

            table.insert(nodes, node)
        end
    end


    -- check that last node is a port
    do
        local lastNode = nodes[#nodes]
        if lastNode.id ~= route.id.destination then
            log:warn("Route '%s' is invalid", route.id:ToString())
            return {}
        end
    end

    -- prune dead branches
    for i = #nodes - 1, 1, -1 do
        local node = nodes[i]
        if #node.to == 0 then
            -- dead end
            log:debug("Dead end: '%s'", NodeId(node))
            table.remove(nodes, i)

            -- update all nodes to variable
            for _, n in ipairs(nodes) do
                if n.to then
                    for j = #n.to, 1, -1 do
                        if n.to[j] == NodeId(node) then
                            table.remove(n.to, j)
                        end
                    end
                end
            end
        end
    end

    return nodes
end

---@param service ServiceData
---@return table<string, SRoute>
local function loadRoutes(service)
    local routes = {} ---@type table<string, SRoute>

    local portPath = string.format("%s\\data\\%s\\routes", lib.fullmodpath, service.class)
    for file in lfs.dir(portPath) do
        if (string.endswith(file, ".toml")) then
            local filePath = string.format("%s\\%s", portPath, file)

            local result = toml.loadFile(filePath) ---@type SRoute?
            if result then
                local route = SRoute:new(result)
                routes[route.id:ToString()] = route
            else
                log:warn("\t\tFailed to load route '%s'", file)
            end
        end
    end

    -- build a graph
    for id, route in pairs(routes) do
        local nodes = BuildGraph(service, route)

        if #nodes > 0 then
            log:debug("\t\tAdding route '%s'", route.id:ToString())
            routes[id].nodes = nodes

            -- debug print graph
            if lib.IsLogLevelAtLeast("DEBUG") then
                local header = string.format("digraph \"%s\" {", route.id:ToString())
                print(header)
                for _, node in ipairs(nodes) do
                    for _, to in ipairs(node.to) do
                        local msg = string.format("\t\"%s\" -> \"%s\"", NodeId(node), to)
                        print(msg)
                    end
                end
                print("}")
            end
        else
            log:warn("Route '%s' is invalid", route.id:ToString())
            routes[id] = nil
        end
    end

    return routes
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

        service.segments = loadSegments(service)
        service.ports = loadPorts(service)
        service.routes = loadRoutes(service)
    end

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
