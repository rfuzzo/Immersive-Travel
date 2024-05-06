local lib                 = require("ImmersiveTravel.lib")
local CTrackingManager    = require("ImmersiveTravel.CTrackingManager")
local interop             = require("ImmersiveTravel.interop")

---@class SPointDto
---@field point PositionRecord  the actual point
---@field splineIndex number    the index of the point in the spline
---@field routeId string        the route id

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// CONFIGURATION
---@type ITWAConfig
local config              = require("ImmersiveTravelAddonWorld.config")
local logger              = require("logging.logger")
local log                 = logger.new {
    name = config.mod,
    logLevel = config.logLevel,
    logToConsole = false,
    includeTimestamp = false
}

local services            = {} ---@type table<string, ServiceData>?
-- spawn data by cell
local spawnPoints         = {} ---@type table<string, SPointDto[]>
-- routes by routeId
local routes              = {} ---@type table<string, PositionRecord[]>
-- services by routeId
local routesServices      = {} ---@type table<string, string>

-- variables
local SPAWN_DRAW_DISTANCE = 1

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// FUNCTIONS

--- check if a node can spawn
---@param p SPointDto
---@return boolean
local function canSpawn(p)
    if table.size(CTrackingManager.getInstance().trackingList) >= config.budget then
        return false
    end

    for id, s in pairs(CTrackingManager.getInstance().trackingList) do
        local vehicle = s ---@cast vehicle CVehicle
        if vehicle.last_position then
            local d = lib.vec(p.point):distance(vehicle.last_position)
            if d < config.spawnExlusionRadius * 8192 then
                return false
            end
        end
    end

    return true
end

--- spawn an object on the vfx node and register it
---@param point SPointDto
local function doSpawn(point)
    log:trace("doSpawn")
    if not services then
        return
    end

    -- get service and route
    local serviceClass = routesServices[point.routeId]
    if not serviceClass then
        return
    end
    local service = services[serviceClass]
    if not service then
        return
    end
    local spline = routes[point.routeId]
    if not spline then
        return
    end

    -- get orientation and facing
    local idx = point.splineIndex
    local startPoint = lib.vec(spline[idx])

    -- get either next or previous point randomly
    if math.random(2) == 1 then
        idx = idx - 1
    else
        idx = idx + 1
    end
    local nr = spline[idx]
    if not nr then
        return
    end

    local nextPoint = lib.vec(nr)
    local orientation = nextPoint - startPoint
    orientation:normalize()
    local facing = math.atan2(orientation.x, orientation.y)

    -- create and register the vehicle
    local mountId = service.mount
    local split = string.split(point.routeId, "_")
    local start = split[1]
    local destination = split[2]
    if service.override_mount then
        for _, o in ipairs(service.override_mount) do
            if lib.is_in(o.points, start) and
                lib.is_in(o.points, destination) then
                mountId = o.id
                break
            end
        end
    end

    log:debug("Spawning %s at: %s", mountId, lib.vec(point.point))

    local vehicle = interop.createVehicle(mountId, startPoint, orientation, facing)
    if not vehicle then
        return
    end

    -- start the vehicle
    vehicle:StartOnSpline(spline, service)
end

--- get possible cells where objects can spawn
---@return SPointDto[]
local function getSpawnCandidates()
    local spawnCandidates = {} ---@type SPointDto[]
    local dd = config.spawnRadius
    local cx = tes3.player.cell.gridX
    local cy = tes3.player.cell.gridY
    local vplayer = tes3vector3.new(cx, cy, 0)

    for i = cx - dd, cx + dd, 1 do
        for j = cy - dd, cy + dd, 1 do
            local vtest = tes3vector3.new(i, j, 0)
            local d = vplayer:distance(vtest)

            if d > SPAWN_DRAW_DISTANCE then
                local cellKey = tostring(i) .. "," .. tostring(j)
                local points = spawnPoints[cellKey]
                if points then
                    for _, p in ipairs(points) do
                        table.insert(spawnCandidates, p)
                    end
                end
            end
        end
    end

    lib.shuffle(spawnCandidates)
    return spawnCandidates
end

--- try spawn an object in the world
---@param spawnCandidates SPointDto[]
local function trySpawn(spawnCandidates)
    for _, p in ipairs(spawnCandidates) do
        -- try spawn
        local roll = math.random(100)
        if roll < config.spawnChance then
            -- check if can spawn
            if canSpawn(p) then
                doSpawn(p)
            end
        end
    end
end

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// EVENTS

--- Init Mod
--- @param e initializedEventData
local function initializedCallback(e)
    if not config.modEnabled then return end

    services = lib.loadServices()
    if not services then
        config.modEnabled = false
        return
    end

    -- load routes into memory
    log:debug("Found %s services", table.size(services))
    for key, service in pairs(services) do
        log:info("\tAdding %s service", service.class)

        lib.loadRoutes(service)
        local destinations = service.routes
        if destinations then
            for _i, start in ipairs(table.keys(destinations)) do
                for _j, destination in ipairs(destinations[start]) do
                    local spline = lib.loadSpline(start, destination, service)
                    if spline then
                        -- save route in memory
                        local routeId = start .. "_" .. destination
                        routes[routeId] = spline
                        routesServices[routeId] = service.class

                        -- save points in memory
                        for idx, pos in ipairs(spline) do
                            -- ignore first and last point
                            if idx == 1 or idx == #spline then
                                goto continue
                            end

                            local cx = math.floor(pos.x / 8192)
                            local cy = math.floor(pos.y / 8192)

                            local cell_key = tostring(cx) .. "," .. tostring(cy)
                            if not spawnPoints[cell_key] then
                                spawnPoints[cell_key] = {}
                            end

                            ---@type SPointDto
                            local point = {
                                point = pos,
                                routeId = routeId,
                                splineIndex = idx
                            }
                            table.insert(spawnPoints[cell_key], point)

                            ::continue::
                        end
                    else
                        log:warn("No spline found for %s -> %s", start, destination)
                    end
                end
            end
        end
    end

    log:debug("Loaded %s splines", table.size(routes))
    log:debug("Loaded %s points", table.size(spawnPoints))

    log:info("%s Initialized", config.mod)
end
event.register(tes3.event.initialized, initializedCallback)

--- spawn on cell changed
--- @param e cellChangedEventData
local function cellChangedCallback(e)
    if not config.modEnabled then
        -- TODO delete all vehicles

        return
    end

    local spawnCandidates = getSpawnCandidates()
    trySpawn(spawnCandidates)

    -- log:debug("Spawn candidates: %s", #spawnCandidates)
end
event.register(tes3.event.cellChanged, cellChangedCallback)

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// CONFIG
require("ImmersiveTravelAddonWorld.mcm")
