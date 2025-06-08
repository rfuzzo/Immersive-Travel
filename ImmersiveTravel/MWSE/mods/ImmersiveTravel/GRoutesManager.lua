local lib      = require("ImmersiveTravel.lib")
local interop  = require("ImmersiveTravel.interop")
local SRoute   = require("ImmersiveTravel.models.SRoute")
local SPort    = require("ImmersiveTravel.models.SPort")
local SSegment = require("ImmersiveTravel.models.SSegment")
local config   = require("ImmersiveTravel.config")
if not config then return end

local log           = mwse.Logger.new()

---@class SharedWaterway
---@field id string unique identifier for the shared segment
---@field segmentId string the segment ID that is shared
---@field occupiedBy string? vehicle ID currently using this waterway
---@field queue string[] list of vehicle IDs waiting to use this waterway

---@class RouteIntersection
---@field id string unique identifier for the intersection
---@field position tes3vector3 geographic position of the intersection
---@field radius number collision detection radius around the intersection
---@field occupiedBy string? vehicle ID currently in the intersection
---@field queue string[] list of vehicle IDs waiting to enter intersection

-- Define a class to manage the splines
---@class GRoutesManager
---@field private services table<string, ServiceData>? service name -> ServiceData
---@field spawnPoints table<string, SPointDto[]> spawn point data
---@field routesPrice table<string, number> route price
---@field sharedWaterways table<string, SharedWaterway> shared waterway data
---@field intersections table<string, RouteIntersection> route intersection data
local RoutesManager = {
    services       = {},
    spawnPoints    = {},
    routesPrice    = {},
    sharedWaterways = {},
    intersections   = {},
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
    
    -- Check if shared waterways directory exists
    local dirExists = lfs.attributes(waterwaysPath, "mode") == "directory"
    if not dirExists then
        log:debug("\t\tNo shared waterways directory found: %s", waterwaysPath)
        return waterways
    end

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

---@param service ServiceData
---@return table<string, RouteIntersection>
local function loadIntersections(service)
    log:debug("\t  Adding route intersections:")

    local intersections = {} ---@type table<string, RouteIntersection>

    local intersectionsPath = string.format("%s\\data\\%s\\intersections", lib.fullmodpath, service.class)
    
    -- Check if intersections directory exists
    local dirExists = lfs.attributes(intersectionsPath, "mode") == "directory"
    if not dirExists then
        log:debug("\t\tNo intersections directory found: %s", intersectionsPath)
        return intersections
    end

    for file in lfs.dir(intersectionsPath) do
        if (string.endswith(file, ".toml")) then
            local filePath = string.format("%s\\%s", intersectionsPath, file)

            local intersectionName = file:sub(0, -6)
            local result = toml.loadFile(filePath) ---@type table?
            if result and result.position and result.radius then
                ---@type RouteIntersection
                local intersection = {
                    id = intersectionName,
                    position = tes3vector3.new(result.position.x, result.position.y, result.position.z or 0),
                    radius = result.radius,
                    occupiedBy = nil,
                    queue = {}
                }
                intersections[intersectionName] = intersection

                log:debug("\t\tAdding intersection %s at position (%.1f, %.1f, %.1f) with radius %.1f", 
                         intersectionName, intersection.position.x, intersection.position.y, 
                         intersection.position.z, intersection.radius)
            else
                log:warn("\t\tFailed to load intersection %s (missing position or radius)", intersectionName)
            end
        end
    end

    return intersections
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
    self.sharedWaterways = {}
    self.intersections = {}

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
        
        -- load shared waterways
        local serviceWaterways = loadSharedWaterways(service)
        for id, waterway in pairs(serviceWaterways) do
            self.sharedWaterways[id] = waterway
        end

        -- load intersections
        local serviceIntersections = loadIntersections(service)
        for id, intersection in pairs(serviceIntersections) do
            self.intersections[id] = intersection
        end

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

---@param segmentId string
---@return SharedWaterway?
function RoutesManager:GetSharedWaterwayBySegment(segmentId)
    for _, waterway in pairs(self.sharedWaterways) do
        if waterway.segmentId == segmentId then
            return waterway
        end
    end
    return nil
end

---@param segmentId string
---@param vehicleId string
---@return boolean true if vehicle can enter the shared waterway
function RoutesManager:TryEnterSharedWaterway(segmentId, vehicleId)
    local waterway = self:GetSharedWaterwayBySegment(segmentId)
    if not waterway then
        return true -- not a shared waterway, allow entry
    end
    
    if waterway.occupiedBy == nil then
        -- waterway is free, occupy it
        waterway.occupiedBy = vehicleId
        log:info("Vehicle %s entered shared waterway %s (segment %s)", vehicleId, waterway.id, segmentId)
        return true
    elseif waterway.occupiedBy == vehicleId then
        -- already occupied by this vehicle
        return true
    else
        -- waterway is occupied by another vehicle, add to queue
        local isAlreadyQueued = false
        for _, queuedVehicleId in ipairs(waterway.queue) do
            if queuedVehicleId == vehicleId then
                isAlreadyQueued = true
                break
            end
        end
        
        if not isAlreadyQueued then
            table.insert(waterway.queue, vehicleId)
            log:info("Vehicle %s queued for shared waterway %s (segment %s), queue position %d", 
                     vehicleId, waterway.id, segmentId, #waterway.queue)
        end
        
        return false
    end
end

---@param segmentId string
---@param vehicleId string
function RoutesManager:ExitSharedWaterway(segmentId, vehicleId)
    local waterway = self:GetSharedWaterwayBySegment(segmentId)
    if not waterway then
        return -- not a shared waterway
    end
    
    if waterway.occupiedBy == vehicleId then
        waterway.occupiedBy = nil
        log:info("Vehicle %s exited shared waterway %s (segment %s)", vehicleId, waterway.id, segmentId)
        
        -- check if there's a vehicle waiting in queue
        if #waterway.queue > 0 then
            local nextVehicleId = table.remove(waterway.queue, 1)
            waterway.occupiedBy = nextVehicleId
            log:info("Vehicle %s from queue now occupies shared waterway %s (segment %s)", 
                     nextVehicleId, waterway.id, segmentId)
        end
    else
        -- remove from queue if present
        for i, queuedVehicleId in ipairs(waterway.queue) do
            if queuedVehicleId == vehicleId then
                table.remove(waterway.queue, i)
                log:info("Vehicle %s removed from queue for shared waterway %s (segment %s)", 
                         vehicleId, waterway.id, segmentId)
                break
            end
        end
    end
end

---@param segmentId string
---@param vehicleId string
---@return boolean true if this vehicle can proceed on this segment
function RoutesManager:CanProceedOnSegment(segmentId, vehicleId)
    local waterway = self:GetSharedWaterwayBySegment(segmentId)
    if not waterway then
        return true -- not a shared waterway, always allow
    end
    
    return waterway.occupiedBy == vehicleId or waterway.occupiedBy == nil
end

---@param position tes3vector3
---@param vehicleId string
---@return boolean true if vehicle can enter the intersection area
function RoutesManager:TryEnterIntersection(position, vehicleId)
    for _, intersection in pairs(self.intersections) do
        local distance = position:distance(intersection.position)
        if distance <= intersection.radius then
            -- Vehicle is approaching this intersection
            if intersection.occupiedBy == nil then
                -- Intersection is free, occupy it
                intersection.occupiedBy = vehicleId
                log:info("Vehicle %s entered intersection %s", vehicleId, intersection.id)
                return true
            elseif intersection.occupiedBy == vehicleId then
                -- Already occupied by this vehicle
                return true
            else
                -- Intersection is occupied by another vehicle, add to queue
                local isAlreadyQueued = false
                for _, queuedVehicleId in ipairs(intersection.queue) do
                    if queuedVehicleId == vehicleId then
                        isAlreadyQueued = true
                        break
                    end
                end
                
                if not isAlreadyQueued then
                    table.insert(intersection.queue, vehicleId)
                    log:info("Vehicle %s queued for intersection %s, queue position %d", 
                             vehicleId, intersection.id, #intersection.queue)
                end
                
                return false
            end
        end
    end
    
    return true -- No intersections nearby
end

---@param position tes3vector3
---@param vehicleId string
function RoutesManager:ExitIntersection(position, vehicleId)
    for _, intersection in pairs(self.intersections) do
        if intersection.occupiedBy == vehicleId then
            local distance = position:distance(intersection.position)
            -- Vehicle has moved outside the intersection radius
            if distance > intersection.radius + 100 then -- Add some buffer to avoid flickering
                intersection.occupiedBy = nil
                log:info("Vehicle %s exited intersection %s", vehicleId, intersection.id)
                
                -- Check if there's a vehicle waiting in queue
                if #intersection.queue > 0 then
                    local nextVehicleId = table.remove(intersection.queue, 1)
                    intersection.occupiedBy = nextVehicleId
                    log:info("Vehicle %s from queue now occupies intersection %s", 
                             nextVehicleId, intersection.id)
                end
                break
            end
        end
    end
end

---@param vehicleId string
function RoutesManager:ForceExitIntersection(vehicleId)
    for _, intersection in pairs(self.intersections) do
        if intersection.occupiedBy == vehicleId then
            intersection.occupiedBy = nil
            log:info("Vehicle %s force-exited intersection %s", vehicleId, intersection.id)
            
            -- Check if there's a vehicle waiting in queue
            if #intersection.queue > 0 then
                local nextVehicleId = table.remove(intersection.queue, 1)
                intersection.occupiedBy = nextVehicleId
                log:info("Vehicle %s from queue now occupies intersection %s", 
                         nextVehicleId, intersection.id)
            end
        else
            -- Remove from queue if present
            for i, queuedVehicleId in ipairs(intersection.queue) do
                if queuedVehicleId == vehicleId then
                    table.remove(intersection.queue, i)
                    log:info("Vehicle %s removed from queue for intersection %s", 
                             vehicleId, intersection.id)
                    break
                end
            end
        end
    end
end

return RoutesManager
