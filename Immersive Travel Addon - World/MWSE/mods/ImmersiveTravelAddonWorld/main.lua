local lib                 = require("ImmersiveTravel.lib")
local GTrackingManager    = require("ImmersiveTravel.GTrackingManager")
local GRoutesManager      = require("ImmersiveTravel.GRoutesManager")
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

-- variables
local SPAWN_DRAW_DISTANCE = 1

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// FUNCTIONS

--- check if a node can spawn
---@param p SPointDto
---@return boolean
local function canSpawn(p)
    if table.size(GTrackingManager.getInstance().trackingList) >= config.budget then
        return false
    end

    for id, s in pairs(GTrackingManager.getInstance().trackingList) do
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
    if not GRoutesManager.getInstance().services then
        return
    end

    -- get service and route
    local serviceClass = GRoutesManager.getInstance().routesServices[point.routeId]
    if not serviceClass then
        return
    end
    local service = GRoutesManager.getInstance().services[serviceClass]
    if not service then
        return
    end
    local spline = GRoutesManager.getInstance().routes[point.routeId]
    if not spline then
        return
    end

    -- get orientation and facing
    local idx = point.splineIndex
    local startPoint = lib.vec(spline[idx])
    local nr = spline[idx + 1]
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

    if lib.IsLogLevelAtLeast("DEBUG") then
        local cx = math.floor(point.point.x / 8192)
        local cy = math.floor(point.point.y / 8192)
        local cell_key = tostring(cx) .. "," .. tostring(cy)
        log:debug("Spawning %s at: %s (#%s) on route %s", mountId, cell_key, idx, point.routeId)
    end

    local vehicle = interop.createVehicle(mountId, startPoint, orientation, facing)
    if not vehicle then
        return
    end

    -- start the vehicle
    log:trace("Trace doSpawn vehicle id: %s", vehicle.id)
    vehicle:StartOnSpline(point.routeId, service)
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
                local points = GRoutesManager.getInstance().spawnPoints[cellKey]
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

--- spawn on cell changed
--- @param e cellChangedEventData
local function cellChangedCallback(e)
    -- skip interior cells
    if e.cell.isInterior then
        return
    end

    if not config.modEnabled then
        -- delete all vehicles
        for id, s in pairs(GTrackingManager.getInstance().trackingList) do
            local vehicle = s ---@cast vehicle CVehicle
            -- only mark vehicles that are in onspline ai state
            if vehicle.aiStateMachine and vehicle:isOnSpline() then
                vehicle.markForDelete = true
            end
        end

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
