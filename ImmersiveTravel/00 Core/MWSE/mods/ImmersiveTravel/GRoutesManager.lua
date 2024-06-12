local lib           = require("ImmersiveTravel.lib")
local log           = lib.log

-- Define a class to manage the splines
---@class GRoutesManager
---@field services table<string, ServiceData>?
---@field spawnPoints table<string, SPointDto[]>
---@field routes table<string, PositionRecord[]>
---@field routesServices table<string, string>
local RoutesManager = {
    services       = {},
    spawnPoints    = {},
    routes         = {},
    routesServices = {}
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

-- init manager
--- @return boolean
function RoutesManager:Init()
    self.services = lib.loadServices()
    if not self.services then
        return false
    end

    -- load routes into memory
    log:info("Found %s services", table.size(self.services))
    for key, service in pairs(self.services) do
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
                        log:debug("\t\tAdding route %s", routeId)

                        self.routes[routeId] = spline
                        self.routesServices[routeId] = service.class

                        -- save points in memory
                        for idx, pos in ipairs(spline) do
                            -- ignore first and last two points
                            if idx < 3 or idx > #spline - 2 then
                                goto continue
                            end


                            local cx = math.floor(pos.x / 8192)
                            local cy = math.floor(pos.y / 8192)

                            local cell_key = tostring(cx) .. "," .. tostring(cy)
                            if not self.spawnPoints[cell_key] then
                                self.spawnPoints[cell_key] = {}
                            end

                            ---@type SPointDto
                            local point = {
                                point = pos,
                                routeId = routeId,
                                splineIndex = idx
                            }
                            table.insert(self.spawnPoints[cell_key], point)

                            ::continue::
                        end
                    else
                        log:warn("No spline found for %s -> %s", start, destination)
                    end
                end
            end
        end
    end

    log:debug("Loaded %s splines", table.size(self.routes))
    log:debug("Loaded %s points", table.size(self.spawnPoints))


    return true
end

return RoutesManager
