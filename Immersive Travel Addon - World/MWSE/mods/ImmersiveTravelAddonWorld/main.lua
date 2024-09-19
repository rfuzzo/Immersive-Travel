local lib                 = require("ImmersiveTravel.lib")
local GTrackingManager    = require("ImmersiveTravel.GTrackingManager")
local GRoutesManager      = require("ImmersiveTravel.GRoutesManager")
local interop             = require("ImmersiveTravel.interop")

---@class SPointDto
---@field point tes3vector3  the actual point
---@field routeId RouteId        the route id
---@field segmentIndex number    the index of the segment in the route

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
            local d = p.point:distance(vehicle.last_position)
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
    if not GRoutesManager.GetServices() then
        return
    end

    -- get service and route
    local service = GRoutesManager.getInstance():GetService(point.routeId.service)
    if not service then return end

    local route = service:GetRoute(point.routeId)
    if not route then return end

    local spline = route:GetSegmentRoute(service, route.segments[point.segmentIndex])
    if not spline then return end

    local startPoint = spline[0]
    local nr = spline[1]
    if not nr then
        return
    end
    local nextPoint = nr

    local orientation = nextPoint - startPoint
    orientation:normalize()
    local facing = math.atan2(orientation.x, orientation.y)

    -- create and register the vehicle
    local mountId = lib.ResolveMountId(service, point.routeId.start, point.routeId.destination)


    if lib.IsLogLevelAtLeast("DEBUG") then
        local cell = tes3.getCell({
            position = tes3vector3.new(point.point.x, point.point.y, 0)
        })
        if cell then
            local cell_key = tostring(cell.gridX) .. "," .. tostring(cell.gridY)
            log:debug("Spawning %s at: %s (segment %s) on route %s", mountId, cell_key,
                route.segments[point.segmentIndex], point.routeId)
        end
    end

    local vehicle = interop.createVehicle(mountId, startPoint, orientation, facing)
    if not vehicle then
        return
    end

    -- start the vehicle
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
        -- -- delete all vehicles
        -- for id, s in pairs(GTrackingManager.getInstance().trackingList) do
        --     local vehicle = s ---@cast vehicle CVehicle
        --     -- only mark vehicles that are in onspline ai state
        --     if vehicle.aiStateMachine and vehicle:isOnSpline() and not vehicle.playerRegistered then
        --         vehicle.markForDelete = true
        --     end
        -- end

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
