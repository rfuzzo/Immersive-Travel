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

---@param graph table<string,string[]>
---@param start string
---@param destination string
---@return string[]
local function Prune(graph, start, destination)
    ---@type string[]
    local to_remove = {}
    for node_id, adj_list in pairs(graph) do
        -- ignore start and end nodes
        if node_id == start or node_id == destination then
            goto continue
        end

        if #adj_list == 0 then
            table.insert(to_remove, node_id)
        end

        ::continue::
    end
    return to_remove
end

---@param node Node
---@return string
local function NodeId(node)
    return string.format("%s#%d", node.id, node.route)
end

---@param service ServiceData
---@param route SRoute
---@return table<string,Node>, table<string,string[]>, table<string,number[]>
local function BuildGraph(service, route)
    local cursor = {} ---@type Node[]

    local nodesMap = {} ---@type table<string,Node>
    local graph = {} ---@type table<string,string[]>

    ---@param node Node
    local function AddNode(node)
        local id = NodeId(node)
        -- add node
        graph[id] = {}
        -- storage
        nodesMap[id] = node
    end

    log:debug("Route '%s'", route.id:ToString())

    -- start and end port
    local startPort = service.ports[route.id.start]
    local startPos = startPort:StartPos()
    ---@type Node
    local startNode = {
        id = route.id.start,
        route = 1,
        position = startPos,
        reverse = false,
    }
    AddNode(startNode)

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
            for _, connection in ipairs(conections) do
                if connection.pos == lastCursor.position then
                    -- get end position of route
                    local croute = segment:GetRoute(connection.route)
                    assert(croute)
                    local routeEndPos = croute[#croute]
                    local routeStartPos = croute[1]
                    local routePos = nil
                    local reverse = false
                    if connection.pos == routeEndPos then
                        routePos = routeStartPos
                        reverse = true
                    else
                        routePos = routeEndPos
                    end

                    ---@type Node
                    local node = {
                        id = segmentId,
                        route = connection.route,
                        position = routePos,
                        reverse = reverse,
                    }

                    AddNode(node)
                    -- add edge
                    table.insert(graph[NodeId(lastCursor)], NodeId(node))

                    table.insert(newCursor, node)

                    log:debug(" + Adding connection: '%s' (%s) -> '%s' (%s)", NodeId(lastCursor), lastCursor.position,
                        NodeId(node), routePos)
                end
            end
        end

        cursor = newCursor
    end

    -- add end node
    local endNode = nil
    local endPort = service.ports[route.id.destination]
    local endPos = endPort:EndPos()
    for _, lastCursor in ipairs(cursor) do
        log:trace(" - Last cursor: %s - %s", NodeId(lastCursor), lastCursor.position)
        if endPos == lastCursor.position then
            endNode = {
                id = route.id.destination,
                route = 1,
                position = endPos,
                reverse = false,
            }

            AddNode(endNode)
            -- add edge
            table.insert(graph[NodeId(lastCursor)], NodeId(endNode))

            log:debug(" + Adding connection: %s -> %s", NodeId(lastCursor), NodeId(endNode))
        end
    end

    -- TODO verification

    -- todo prune dead branches
    local to_remove = Prune(graph, NodeId(startNode), NodeId(endNode))
    local found = #to_remove
    while found > 0 do
        for _, node_id in ipairs(to_remove) do
            -- Remove from graph
            graph[node_id] = nil
            log:debug(" - Removing node %s", node_id)

            -- Remove from to lists
            for _, adj_list in pairs(graph) do
                for i, adj in ipairs(adj_list) do
                    if adj == node_id then
                        table.remove(adj_list, i)
                        break
                    end
                end
            end
        end

        to_remove = Prune(graph, NodeId(startNode), NodeId(endNode))
        found = #to_remove
    end

    -- generate name lookup
    local name_lookup = {} ---@type table<string,number[]>
    for node_id, adj_list in pairs(graph) do
        local node = nodesMap[node_id]
        if name_lookup[node.id] == nil then
            name_lookup[node.id] = {}
        end
        table.insert(name_lookup[node.id], node.route)
    end

    return nodesMap, graph, name_lookup
end

---@param graph table<string,string[]>
---@param title string
local function PrintGraph(graph, title)
    -- debug print graph
    local header = string.format("digraph \"%s\" {", title)
    print(header)

    for node, to in pairs(graph) do
        for _, t in ipairs(to) do
            local msg = string.format("\t\"%s\" -> \"%s\"", node, t)
            print(msg)
        end
    end

    print("}")
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
        local nodes, graph, lut = BuildGraph(service, route)

        if table.size(nodes) > 0 then
            routes[id].nodes = nodes
            routes[id].graph = graph
            routes[id].lut = lut

            log:debug("\t\tAdding route '%s'", route.id:ToString())
            if lib.IsLogLevelAtLeast("DEBUG") then
                PrintGraph(graph, route.id:ToString())
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
