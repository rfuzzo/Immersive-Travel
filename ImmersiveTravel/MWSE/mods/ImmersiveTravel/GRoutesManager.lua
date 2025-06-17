local lib      = require("ImmersiveTravel.lib")
local interop  = require("ImmersiveTravel.interop")
local SRoute   = require("ImmersiveTravel.models.SRoute")
local SPort    = require("ImmersiveTravel.models.SPort")
local SSegment = require("ImmersiveTravel.models.SSegment")
local config   = require("ImmersiveTravel.config")
if not config then return end

local log           = mwse.Logger.new()

-- Define a class to manage the splines
---@class GRoutesManager
---@field services table<string, ServiceData>? service name -> ServiceData
---@field spawnPoints table<string, SPointDto[]> spawn point data
---@field routesPrice table<string, number> route price
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
---@return table<string, SPort>
local function loadPorts(service)
    log:debug("\t  Adding ports:")

    local map = {} ---@type table<string, SPort>

    local portPath = string.format("%s\\data\\%s\\ports", lib.fullmodpath, service.class)
    for file in lfs.dir(portPath) do
        if (string.endswith(file, ".toml")) then
            local filePath = string.format("%s\\%s", portPath, file)

            local portName = file:sub(0, -6)
            local result = toml.loadFile(filePath) ---@type SPortDto?
            if result then
                map[portName] = SPort.fromDto(result)

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
    log:debug("\t  Adding segments:")

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
---@return table<string, SharedWaterway>
local function loadSharedWaterways(service)
    log:debug("\t  Adding shared waterways:")

    local waterways = {} ---@type table<string, SharedWaterway>

    local waterwaysPath = string.format("%s\\data\\%s\\shared", lib.fullmodpath, service.class)
    for file in lfs.dir(waterwaysPath) do
        if (string.endswith(file, ".toml")) then
            local filePath = string.format("%s\\%s", waterwaysPath, file)

            local waterwayName = file:sub(0, -6)
            local result = toml.loadFile(filePath) ---@type table?
            if result and result.segmentId then
                ---@type SharedWaterway
                local waterway = {
                    id = waterwayName,
                    segmentId = result.segmentId,
                    occupiedBy = nil,
                    queue = {}
                }
                waterways[waterwayName] = waterway

                log:debug("\t\tAdding shared waterway %s for segment %s", waterwayName, result.segmentId)
            else
                log:warn("\t\tFailed to load shared waterway %s", waterwayName)
            end
        end
    end

    return waterways
end

--#region intersections

---@param service ServiceData
---@return table<string, RouteIntersection>
local function loadIntersections(service)
    log:debug("\t  Adding route intersections:")

    local intersections = {} ---@type table<string, RouteIntersection>

    local intersectionsPath = string.format("%s\\data\\%s\\intersections", lib.fullmodpath, service.class)
    for file in lfs.dir(intersectionsPath) do
        if (string.endswith(file, ".toml")) then
            local filePath = string.format("%s\\%s", intersectionsPath, file)

            local intersectionName = file:sub(0, -6)
            local result = toml.loadFile(filePath) ---@type table?
            if result and result.segmentName and result.pointIndex and result.radius then
                ---@type RouteIntersection
                local intersection = {
                    id = intersectionName,
                    segmentName = result.segmentName,
                    pointIndex = result.pointIndex,
                    radius = result.radius,
                    occupiedBy = nil,
                    queue = {}
                }
                intersections[intersectionName] = intersection

                log:debug("\t\tAdding intersection %s at segment '%s' point %d with radius %.1f",
                    intersectionName, intersection.segmentName, intersection.pointIndex, intersection.radius)
            else
                log:warn("\t\tFailed to load intersection %s (missing segmentName, pointIndex or radius)",
                    intersectionName)
            end
        end
    end
    return intersections
end

---@param service ServiceData
---@return table<string, {segmentName: string, pointIndex: number, routes: string[]}>
local function precomputeIntersectionsFromRoutes(service)
    log:debug("Precomputing intersections from routes for service: %s", service.class)

    local intersectionCandidates = {} ---@type table<string, {segmentName: string, pointIndex: number, routes: string[]}>

    -- Collect all segment points with their route usage
    local segmentPoints = {} ---@type table<string, table<number, {position: tes3vector3, routes: string[]}>>

    for routeKey, route in pairs(service.routes) do
        for _, segmentName in ipairs(route.segments) do
            local segment = service:GetSegment(segmentName)
            if segment then
                local spline = segment:GetRoute()
                if spline then
                    if not segmentPoints[segmentName] then
                        segmentPoints[segmentName] = {}
                    end

                    for pointIndex, position in ipairs(spline) do
                        if not segmentPoints[segmentName][pointIndex] then
                            segmentPoints[segmentName][pointIndex] = {
                                position = position,
                                routes = {}
                            }
                        end
                        table.insert(segmentPoints[segmentName][pointIndex].routes, routeKey)
                    end
                end
            end
        end
    end

    -- Find points where multiple routes converge
    for segmentName, points in pairs(segmentPoints) do
        for pointIndex, pointData in pairs(points) do
            -- Check if multiple routes use this point (potential intersection)
            if #pointData.routes > 1 then
                local intersectionId = string.format("%s_pt%d", segmentName, pointIndex)
                intersectionCandidates[intersectionId] = {
                    segmentName = segmentName,
                    pointIndex = pointIndex,
                    routes = pointData.routes
                }

                log:debug("Found intersection candidate %s: segment '%s' point %d used by %d routes",
                    intersectionId, segmentName, pointIndex, #pointData.routes)
            end
        end
    end

    return intersectionCandidates
end

---@param service ServiceData
---@return table<string, RouteIntersection>
local function loadOrGenerateIntersections(service)
    local intersectionsPath = string.format("%s\\data\\%s\\intersections", lib.fullmodpath, service.class)
    local cacheFilePath = string.format("%s\\precomputed_intersections.toml", intersectionsPath)

    -- Calculate current service hash
    local currentHash = lib.calculateServiceHash(service)

    -- Try to load cached precomputed intersections
    local cachedIntersections = {}
    local needsRegeneration = true

    if lfs.attributes(cacheFilePath, "mode") == "file" then
        local cacheData = toml.loadFile(cacheFilePath)
        if cacheData and cacheData.hash == currentHash and cacheData.intersections then
            cachedIntersections = cacheData.intersections
            needsRegeneration = false
            log:debug("\t\tUsing cached precomputed intersections (hash: %s)", currentHash)
        else
            log:debug("\t\tCache invalidated, regenerating intersections (old hash: %s, new hash: %s)",
                cacheData and cacheData.hash or "none", currentHash)
        end
    else
        log:debug("\t\tNo cached intersections found, generating...")
    end

    local intersections = {} ---@type table<string, RouteIntersection>

    -- Load manual intersections first
    local manualIntersections = loadIntersections(service)
    for id, intersection in pairs(manualIntersections) do
        intersections[id] = intersection
    end
    -- Add precomputed intersections if cache is valid or generate new ones
    if needsRegeneration then
        local precomputed = precomputeIntersectionsFromRoutes(service)

        -- Convert to RouteIntersection format and save to cache
        local cacheData = {
            hash = currentHash,
            intersections = {}
        }

        for intersectionId, data in pairs(precomputed) do
            -- Only add if it's not already manually defined
            if not intersections[intersectionId] then
                local intersection = {
                    id = intersectionId,
                    segmentName = data.segmentName,
                    pointIndex = data.pointIndex,
                    radius = 2, -- default radius
                    occupiedBy = nil,
                    queue = {}
                }
                intersections[intersectionId] = intersection

                -- Save to cache data
                cacheData.intersections[intersectionId] = {
                    segmentName = data.segmentName,
                    pointIndex = data.pointIndex,
                    radius = 2
                }
            end
        end

        -- Create directory if it doesn't exist
        local dirExists = lfs.attributes(intersectionsPath, "mode") == "directory"
        if not dirExists then
            lfs.mkdir(intersectionsPath)
        end

        -- Save cache
        toml.saveFile(cacheFilePath, cacheData)
        log:debug("\t\tSaved precomputed intersections cache with %d intersections", table.size(cacheData.intersections))
    else
        -- Use cached intersections
        for intersectionId, data in pairs(cachedIntersections) do
            if not intersections[intersectionId] then
                local intersection = {
                    id = intersectionId,
                    segmentName = data.segmentName,
                    pointIndex = data.pointIndex,
                    radius = data.radius or 2,
                    occupiedBy = nil,
                    queue = {}
                }
                intersections[intersectionId] = intersection
            end
        end
    end

    return intersections
end

--#endregion

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

---@param service ServiceData
---@param route SRoute
---@return table<string,Node>, table<string,string[]>
local function BuildGraph(service, route)
    local cursor = {} ---@type Node[]

    local nodesMap = {} ---@type table<string,Node>
    local graph = {} ---@type table<string,string[]>

    ---@param node Node
    local function AddNode(node)
        local id = node.id
        -- add node
        graph[id] = {}
        -- storage
        nodesMap[id] = node
    end

    log:debug("Route '%s'", route.id:ToString())

    -- start and end port
    local mountId = service:ResolveMountId(route.id)
    local startPort = service:GetPort(route.id.start, mountId)
    assert(startPort)
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
    log:trace("Start node '%s', position: %s", startNode.id, startNode.position)

    for _, segmentId in ipairs(route.segments) do
        local segment = service:GetSegment(segmentId)
        assert(segment)

        -- check if we have a connection
        local newCursor = {} ---@type Node[]

        local conections = segment:GetConnections()
        log:trace("Segment '%s', conections: %d", segmentId, #conections)
        for _, lastCursor in ipairs(cursor) do
            log:trace(" - From: %s %s", lastCursor.id, lastCursor.position)
            for _, connection in ipairs(conections) do
                if connection.pos == lastCursor.position then
                    -- get end position of route
                    local croute = segment:GetRoute()
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
                        position = routePos,
                        reverse = reverse,
                    }

                    AddNode(node)
                    -- add edge
                    table.insert(graph[lastCursor.id], node.id)

                    table.insert(newCursor, node)

                    log:debug(" + Adding connection: '%s' (%s) -> '%s' (%s)", lastCursor.id, lastCursor.position,
                        node.id, routePos)
                end
            end
        end

        cursor = newCursor

        -- break if no connections
        if #cursor == 0 then
            log:error("No connections found for segment '%s'", segmentId)
            return {}, {}
        end
    end

    -- add end node
    local endNode = nil
    local endPort = service:GetPort(route.id.destination, mountId)
    assert(endPort)
    local endPos = endPort:EndPos()
    for _, lastCursor in ipairs(cursor) do
        log:trace(" ( Last cursor: %s - %s )", lastCursor.id, lastCursor.position)
        if endPos == lastCursor.position then
            endNode = {
                id = route.id.destination,
                route = 1,
                position = endPos,
                reverse = false,
            }

            AddNode(endNode)
            -- add edge
            table.insert(graph[lastCursor.id], endNode.id)

            log:debug(" + Adding connection: %s -> %s", lastCursor.id, endNode.id)
        end
    end

    -- TODO verification

    -- prune dead branches
    if endNode ~= nil then
        local to_remove = Prune(graph, startNode.id, endNode.id)
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

            to_remove = Prune(graph, startNode.id, endNode.id)
            found = #to_remove
        end
    end

    return nodesMap, graph
end

---@param graph table<string,string[]>
---@param title string
local function PrintGraph(graph, title)
    -- debug print graph
    local header = string.format("digraph \"%s\" {\n", title)
    for node, to in pairs(graph) do
        for _, t in ipairs(to) do
            local msg = string.format("\t\"%s\" -> \"%s\"", node, t)
            header = header .. msg .. "\n"
        end
    end

    header = header .. "}\n"

    -- write to file
    local path = string.format("%s\\%s.dot", lib.fullmodpath, title)
    local file = io.open(path, "w")
    if not file then
        log:warn("Failed to open file %s", path)
        return
    end
    file:write(header)
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
        local nodes, graph = BuildGraph(service, route)

        if table.size(nodes) > 0 then
            routes[id].nodes = nodes
            routes[id].graph = graph

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

---@param routeId RouteId
---@return number
local function GetPrice(routeId)
    -- get start port
    local service = RoutesManager.getInstance():GetService(routeId.service)
    assert(service)
    local mountId = service:ResolveMountId(routeId)
    local startPort = service:GetPort(routeId.start, mountId)
    assert(startPort)
    local p1 = startPort:StartPos()

    -- get end port
    local endPort = service:GetPort(routeId.destination, mountId)
    assert(endPort)
    local p2 = endPort:EndPos()

    local distance = p1:distance(p2)

    -- divide by cell size
    local price = distance / 8192

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
        service.shared = loadSharedWaterways(service)
        service.intersections = loadOrGenerateIntersections(service)

        -- get prices
        for _, route in pairs(service.routes) do
            local price = GetPrice(route.id)
            self.routesPrice[route.id:ToString()] = price
            log:debug("\t\tRoute '%s' price: %d", route.id:ToString(), price)
        end

        -- spawn points
        for _, route in pairs(service.routes) do
            for _, segmentName in ipairs(route.segments) do
                local pos = route:GetStartingPoint(service, segmentName)
                if pos then
                    local cell = tes3.getCell({
                        position = tes3vector3.new(pos.x, pos.y, 0)
                    })
                    if cell then
                        local cell_key = tostring(cell.gridX) .. "," .. tostring(cell.gridY)
                        if not self.spawnPoints[cell_key] then
                            self.spawnPoints[cell_key] = {}
                        end

                        ---@type SPointDto
                        local point = {
                            point = pos,
                            routeId = route.id,
                            segmentName = segmentName
                        }
                        table.insert(self.spawnPoints[cell_key], point)
                        log:debug("[%s] Spawn point %s ", route.id:ToString(), segmentName)
                    end
                end
            end
        end
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
