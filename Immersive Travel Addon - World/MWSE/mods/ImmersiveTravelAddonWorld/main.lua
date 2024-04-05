local lib = require("ImmersiveTravel.lib")
local CTrackingManager = require("ImmersiveTravel.CTrackingManager")
local interop = require("ImmersiveTravel.interop")

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// CONFIGURATION
---@type ITWAConfig
local config = require("ImmersiveTravelAddonWorld.config")
local logger = require("logging.logger")
local log = logger.new {
    name = config.mod,
    logLevel = config.logLevel,
    logToConsole = false,
    includeTimestamp = false
}

-- spawn data
local map = {} ---@type table<string, SPointDto[]>
local splines = {} ---@type table<string, table<string, PositionRecord[]>>
local services = {} ---@type table<string, ServiceData>?

local SPAWN_DRAW_DISTANCE = 1

---@class SPointDto
---@field point PositionRecord
---@field routeId string
---@field serviceId string
---@field splineIndex number

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// FUNCTIONS

--- check if a node can spawn
---@param p SPointDto
---@return boolean
local function canSpawn(p)
    if #CTrackingManager.getInstance().trackingList >= config.budget then
        return false
    end

    for _, s in ipairs(CTrackingManager.getInstance().trackingList) do
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
    log:debug("doSpawn")
    if not services then return end

    local split = string.split(point.routeId, "_")
    local start = split[1]
    local destination = split[2]
    local service = services[point.serviceId]
    local idx = point.splineIndex

    local spline = splines[service.class][point.routeId]
    local startPoint = lib.vec(spline[idx])
    local nr = spline[idx + 1]
    if not nr then return end
    local nextPoint = lib.vec(nr)
    local orientation = nextPoint - startPoint
    orientation:normalize()
    local facing = math.atan2(orientation.x, orientation.y)

    -- create vehicle and spawn
    -- vehicle id
    local mountId = service.mount
    -- override mounts
    if service.override_mount then
        for _, o in ipairs(service.override_mount) do
            if lib.is_in(o.points, start) and
                lib.is_in(o.points, destination) then
                mountId = o.id
                break
            end
        end
    end
    -- create and register the vehicle
    log:debug("Spawning %s at: %s", mountId, lib.vec(point.point))
    local vehicle = interop.createVehicle(mountId, startPoint, orientation, facing)
    if not vehicle then
        return
    end

    vehicle:StartOnSpline(spline, service)
end

local function shuffle(tbl)
    for i = #tbl, 2, -1 do
        local j = math.random(i)
        tbl[i], tbl[j] = tbl[j], tbl[i]
    end
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
                local points = map[cellKey]
                if points then
                    for _, p in ipairs(points) do
                        table.insert(spawnCandidates, p)
                    end
                end
            end
        end
    end

    shuffle(spawnCandidates)
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
                    local spline =
                        lib.loadSpline(start, destination, service)
                    if spline then
                        if not splines[service.class] then
                            splines[service.class] = {}
                        end

                        splines[service.class][start .. "_" .. destination] =
                            spline

                        for idx, pos in ipairs(spline) do
                            local cx = math.floor(pos.x / 8192)
                            local cy = math.floor(pos.y / 8192)

                            local cell_key = tostring(cx) .. "," .. tostring(cy)
                            if not map[cell_key] then
                                map[cell_key] = {}
                            end

                            ---@type SPointDto
                            local point = {
                                point = pos,
                                routeId = start .. "_" .. destination,
                                serviceId = service.class,
                                splineIndex = idx
                            }
                            table.insert(map[cell_key], point)
                        end
                    end
                end
            end
        end
    end

    log:debug("Loaded %s splines", table.size(splines))
    log:debug("Loaded %s points", table.size(map))
    log:info("%s Initialized", config.mod)
end
event.register(tes3.event.initialized, initializedCallback)

--- spawn on cell changed
--- @param e cellChangedEventData
local function cellChangedCallback(e)
    if not config.modEnabled then return end

    local spawnCandidates = getSpawnCandidates()

    -- log:debug("Spawn candidates: %s", #spawnCandidates)

    trySpawn(spawnCandidates)
end
event.register(tes3.event.cellChanged, cellChangedCallback)

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// CONFIG
require("ImmersiveTravelAddonWorld.mcm")
