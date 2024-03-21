local this = {}



this.localmodpath = "mods\\rfuzzo\\ImmersiveTravel\\"
this.fullmodpath = "Data Files\\MWSE\\" .. this.localmodpath

local localmodpath = this.localmodpath
local fullmodpath = this.fullmodpath





-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// IO





--- load json spline from file
---@param start string
---@param destination string
---@param data ServiceData
---@return PositionRecord[]|nil
function this.loadSpline(start, destination, data)
    local fileName = start .. "_" .. destination
    local filePath = localmodpath .. data.class .. "\\" .. fileName
    if tes3.getFileExists("MWSE\\" .. filePath .. ".json") then
        local result = json.loadfile(filePath)
        if result ~= nil then
            -- log:debug("loaded spline: " .. fileName)
            return result
        else
            log:error("!!! failed to load spline: " .. fileName)
            return nil
        end
    else
        -- check if return route exists
        fileName = destination .. "_" .. start
        filePath = localmodpath .. data.class .. "\\" .. fileName
        if tes3.getFileExists("MWSE\\" .. filePath .. ".json") then
            local result = json.loadfile(filePath)
            if result ~= nil then
                -- log:debug("loaded spline: " .. fileName)

                -- reverse result
                local reversed = {}
                for i = #result, 1, -1 do
                    local val = result[i]
                    table.insert(reversed, val)
                end

                log:debug("reversed spline: " .. fileName)
                return reversed
            else
                log:error("!!! failed to load spline: " .. fileName)
                return nil
            end
        else
            log:error("!!! failed to find any file: " .. fileName)
        end
    end
end

--- load json static mount data
---@param id string
---@return MountData|nil
function this.loadMountData(id)
    local filePath = localmodpath .. "mounts\\" .. id .. ".json"
    local result = {} ---@type table<string, MountData>
    result = json.loadfile(filePath)
    if result then
        return result
    else
        log:error("!!! failed to load mount: " .. id)
        return nil
    end
end

--- Load all services
---@return table<string,ServiceData>|nil
function this.loadServices()
    log:debug("Loading travel services...")

    ---@type table<string,ServiceData>|nil
    local services = {}
    for fileName in lfs.dir(fullmodpath .. "services") do
        if (string.endswith(fileName, ".json")) then
            -- parse
            local fullpath = localmodpath .. "services\\" .. fileName
            local r = json.loadfile(fullpath)
            if r then
                services[fileName:sub(0, -6)] = r

                log:trace("Loaded " .. fullpath)
            else
                log:error("!!! failed to load " .. fileName)
            end
        end
    end
    return services
end

--- Load all route splines for a given service
---@param service ServiceData
function this.loadRoutes(service)
    local map = {} ---@type table<string, table>
    for file in lfs.dir(fullmodpath .. service.class) do
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
                result = table.get(map, destination, nil)
                if not result then
                    local v = {}
                    v[start] = 1
                    map[destination] = v
                else
                    result[start] = 1
                    map[destination] = result
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

return this
