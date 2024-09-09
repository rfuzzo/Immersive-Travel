local interop       = require("ImmersiveTravel.interop")
local lib           = require("ImmersiveTravel.lib")
local log           = lib.log

-- Define a class to manage the splines
---@class GRoutesManager
---@field services table<string, ServiceData>? -- serviceId -> ServiceData
---@field spawnPoints table<string, SPointDto[]>
---@field private routes table<string, PositionRecord[]> -- routeId -> spline
---@field routesServices table<string, string> -- routeId -> serviceId
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

--- Load all route splines for a given service
---@param service ServiceData
local function loadRoutes(service)
    local map = {} ---@type table<string, table>

    for file in lfs.dir(lib.fullmodpath .. "\\" .. service.class) do
        if (string.endswith(file, ".json")) then
            local split = string.split(file:sub(0, -6), "_")
            if #split == 2 then
                local start = ""
                local destination = ""

                for i, id in ipairs(split) do
                    if i == 1 then
                        start = id
                    else
                        destination = id
                    end
                end

                local startPort = table.get(service.ports, start, nil)
                local destinationPort = table.get(service.ports, destination, nil)

                if not startPort then
                    log:debug("\t\t! Start port %s not found", start)
                end

                if not destinationPort then
                    log:debug("\t\t! Destination port %s not found", destination)
                end

                -- check if both ports exist
                if startPort and destinationPort then
                    local result = table.get(map, start, nil)
                    if not result then
                        local v = {}
                        v[destination] = 1
                        map[start] = v
                    else
                        result[destination] = 1
                        map[start] = result
                    end

                    -- add return trip
                    -- result = table.get(map, destination, nil)
                    -- if not result then
                    --     local v = {}
                    --     v[start] = 1
                    --     map[destination] = v
                    -- else
                    --     result[start] = 1
                    --     map[destination] = result
                    -- end
                end
            end
        end
    end

    local r = {}
    for key, value in pairs(map) do
        local v = {}
        for d, _ in pairs(value) do table.insert(v, d) end
        r[key] = v
    end
    service.routes = r
end

---@param service ServiceData
local function loadPorts(service)
    local map = {} ---@type table<string, PortData>

    for file in lfs.dir(lib.fullmodpath .. "\\data\\" .. service.class) do
        if (string.endswith(file, ".toml")) then
            local filePath = string.format("%s\\data\\%s\\%s", lib.fullmodpath, service.class, file)

            local portName = file:sub(0, -6)
            local result = toml.loadFile(filePath)
            if result then
                map[portName] = result

                log:debug("\t\tAdding port %s", portName)
            else
                log:warn("\t\tFailed to load port %s", portName)
            end
        end
    end

    service.ports = map
end

--- load json spline from file
---@param start string
---@param destination string
---@param data ServiceData
---@return PositionRecord[]|nil
local function loadSpline(start, destination, data)
    local fileName = start .. "_" .. destination
    local filePath = string.format("%s\\%s\\%s", lib.localmodpath, data.class, fileName)

    if tes3.getFileExists("MWSE\\" .. filePath .. ".json") then
        local result = json.loadfile(filePath) ---@type PositionRecord[]?
        if result ~= nil then
            -- get ports
            local startPort = table.get(data.ports, start, nil) ---@type PortData?
            local destinationPort = table.get(data.ports, destination, nil) ---@type PortData?

            if startPort and destinationPort then
                -- add start and end points
                table.insert(result, 1, startPort.position)
                table.insert(result, destinationPort.position)

                return result
            else
                log:error("!!! failed to find start or destination port for route %s - %s", start, destination)
                return nil
            end
        else
            log:error("!!! failed to find file: %s", filePath)
            return nil
        end
    else
        -- -- check if return route exists
        -- fileName = destination .. "_" .. start
        -- filePath = lib.localmodpath .. data.class .. "\\" .. fileName
        -- if tes3.getFileExists("MWSE\\" .. filePath .. ".json") then
        --     local result = json.loadfile(filePath)
        --     if result ~= nil then
        --         -- log:debug("loaded spline: " .. fileName)

        --         -- reverse result
        --         local reversed = {}
        --         for i = #result, 1, -1 do
        --             local val = result[i]
        --             table.insert(reversed, val)
        --         end

        --         log:debug("reversed spline: " .. fileName)
        --         return reversed
        --     else
        --         log:error("!!! failed to load spline: " .. fileName)
        --         return nil
        --     end
        -- else
        log:error("!!! failed to find any file: " .. fileName)
        -- end
    end
end

-- init manager
--- @return boolean
function RoutesManager:Init()
    -- cleanup
    table.clear(self.services)
    table.clear(self.routes)
    table.clear(self.routesServices)
    table.clear(self.spawnPoints)

    -- init services
    self.services = table.copy(interop.services)
    if not self.services then
        return false
    end

    -- load routes into memory
    log:info("Found %s services", table.size(self.services))
    for key, service in pairs(self.services) do
        log:info("\tAdding %s service", service.class)

        loadPorts(service)
        loadRoutes(service)

        local destinations = service.routes
        if destinations then
            for _i, start in ipairs(table.keys(destinations)) do
                for _j, destination in ipairs(destinations[start]) do
                    local spline = loadSpline(start, destination, service)
                    if spline then
                        -- save route in memory
                        local routeId = start .. "_" .. destination
                        self.routes[routeId] = spline
                        self.routesServices[routeId] = service.class

                        log:debug("\t\tAdding route '%s' (%s)", routeId, service.class)

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

---@param routeId string
---@return PositionRecord[]?
function RoutesManager:GetRoute(routeId)
    return self.routes[routeId]
end

return RoutesManager
