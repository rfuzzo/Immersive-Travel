local config = require("ImmersiveTravelEditor.config")
if not config then return end

local lib            = require("ImmersiveTravel.lib")
local RouteId        = require("ImmersiveTravel.models.RouteId")
local PositionRecord = require("ImmersiveTravel.models.PositionRecord")

local this           = {}

local logger         = require("logging.logger")
this.log             = logger.new {
    name = config.mod,
    logLevel = config.logLevel,
    logToConsole = false,
    includeTimestamp = false
}

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// CLASSES

---@class SPreviewData
---@field mount tes3reference?

---@class SPreviewMarker
---@field node niNode?
---@field type EMarkerType
---@field segmentId string?
---@field routeId number?
---@field idx number?

---@class SPreviewMarker2
---@field position tes3vector3
---@field type EMarkerType
---@field segmentId string?
---@field routeId number?
---@field idx number?

---@class SEditorData
---@field service ServiceData
---@field start string?
---@field destination string?
---@field mount tes3reference?
---@field editorMarkers SPreviewMarker[]?
---@field currentMarker SPreviewMarker?
---@field lastMarker SPreviewMarker2?
---@field editorNodes niNode[]?
---@field currentNode niNode?
---@field pin1 number?
---@field pin2 number?
---@field last_position tes3vector3|nil
---@field last_forwardDirection tes3vector3|nil
---@field last_facing number|nil

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// ENUMS

---@enum EMarkerType
this.EMarkerType     = {
    PortStart = 1,       -- port marker
    PortEnd = 2,         -- port marker
    Port = 3,            -- port marker
    Route = 4,           -- inner segment
    RouteConnection = 5, -- segment connection
}

---@enum EEditorMode
this.EEditorMode     = {
    Routes = 1,
    Ports = 2,
    Segments = 3
}


---@param val EEditorMode
---@return string
function this.ToString(val)
    if val == this.EEditorMode.Routes then return "Splines" end
    if val == this.EEditorMode.Ports then return "Ports" end
    if val == this.EEditorMode.Segments then return "New Routes" end
    return "Unknown"
end

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// VARIABLES

this.destinations       = {} ---@type table<string,table<string, string[]>> -- start -> destination[] per service
this.splines            = {} ---@type table<string, tes3vector3[]> -- routeId -> spline

this.editorData         = nil ---@type SEditorData | nil
this.currentEditorMode  = this.EEditorMode.Segments ---@type EEditorMode
this.currentServiceName = nil ---@type string | nil


this.editorMarkerId   = "marker_travel.nif" -- for nodes
this.portMarkerId     = "marker_arrow.nif"  -- for ports
this.nodeMarkerId     = "marker_divine.nif" -- for connections
-- "marker_north.nif"

this.editorMarkerMesh = nil ---@type niNode?
this.portMarkerMesh   = nil ---@type niNode?
this.nodeMarkerMesh   = nil ---@type niNode?

this.arrows           = {} ---@type niNode[]
this.arrow            = nil ---@type niNode?
this.arrowz           = nil ---@type niNode?


-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// FUNCTIONS

---@param port PortData
---@param mountId string
---@param offset number
---@return tes3reference
function this.createMount(port, mountId, offset)
    local orientation = lib.radvec(port:StartRot())

    local mount = tes3.createReference {
        object = mountId,
        position = port:StartPos(),
        orientation = orientation
    }

    mount.facing = orientation.z

    return mount
end

---@param name string
---@param origin tes3vector3
---@param destination tes3vector3
function this.createLine(name, origin, destination)
    local root = tes3.worldController.vfxManager.worldVFXRoot

    local line = root:getObjectByName(name)

    if line == nil then
        -- we need to reload it here every time for some reason
        line = tes3.loadMesh("mwse\\widgets.nif", false)
            :getObjectByName("axisLines")
            :getObjectByName("z"):clone()

        line.name = name

        root:attachChild(line, true)
    end

    do
        line.data.vertices[1] = origin
        line.data.vertices[2] = destination
        line.data:markAsChanged()
        line.data:updateModelBound()
    end

    line:update()
    line:updateEffects()
    line:updateProperties()
end

--- @param from tes3vector3
--- @return number?
function this.getGroundZ(from)
    local rayhit = tes3.rayTest {
        position = from,
        direction = tes3vector3.new(0, 0, -1),
        returnNormal = true
    }

    if (rayhit) then
        local to = rayhit.intersection
        return to.z
    end

    return nil
end

--- Load all route splines for a given service
---@param service ServiceData
---@return table<string, string[]>
function this.loadRoutes(service)
    local map = {} ---@type table<string, table>

    local fullmodpath = "Data Files\\MWSE\\mods\\ImmersiveTravelEditor"
    for file in lfs.dir(fullmodpath .. "\\" .. service.class) do
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

                -- we don't need to resolve the ports properly, just the names
                local routeId = RouteId:new(service.class, start, destination)
                local mountId = service:ResolveMountId(routeId)
                local startPort = service:GetPort(start, mountId)
                local destinationPort = service:GetPort(destination, mountId)

                if not startPort then
                    this.log:warn("\t\t! Start port %s not found", start)
                end

                if not destinationPort then
                    this.log:warn("\t\t! Destination port %s not found", destination)
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
                end
            end
        end
    end

    local r = {} ---@type table<string, string[]>
    for key, value in pairs(map) do
        local v = {} ---@type string[]
        for d, _ in pairs(value) do
            table.insert(v, d)
        end
        r[key] = v
    end

    return r
end

--- load json spline from file
---@param start string
---@param destination string
---@param service ServiceData
---@return tes3vector3[]|nil
function this.loadSpline(start, destination, service)
    local fileName = start .. "_" .. destination

    local localmodpath = "mods\\ImmersiveTravelEditor"
    local filePath = string.format("%s\\%s\\%s", localmodpath, service.class, fileName)

    if tes3.getFileExists("MWSE\\" .. filePath .. ".json") then
        local dto = json.loadfile(filePath) ---@type PositionRecord[]?
        if dto ~= nil then
            -- convert to tes3vector3[]
            local result = {} ---@type tes3vector3[]
            for i, pos in ipairs(dto) do
                result[i] = PositionRecord.ToVec(pos)
            end

            -- get ports
            local routeId = RouteId:new(service.class, start, destination)
            local mountId = service:ResolveMountId(routeId)
            local startPort = service:GetPort(start, mountId)
            local destinationPort = service:GetPort(destination, mountId)

            if startPort and destinationPort then
                -- add start and end ports
                table.insert(result, 1, startPort:StartPos())
                table.insert(result, destinationPort:EndPos())

                return result
            else
                this.log:error("!!! failed to find start or destination port for route %s - %s", start, destination)
                return nil
            end
        else
            this.log:error("!!! failed to find file: %s", filePath)
            return nil
        end
    else
        this.log:error("!!! failed to find any file: " .. fileName)
    end
end

---@param name string
function this.teleportToCell(name)
    -- get cell
    local cell = tes3.getCell({ id = name })
    if not cell then return end

    -- get first doormarker
    local marker = nil ---@type tes3reference?
    for ref in cell:iterateReferences(tes3.objectType["static"]) do
        if ref.id == "DoorMarker" then
            marker = ref
            break
        end
    end

    -- teleport
    if marker then
        tes3.positionCell({
            reference = tes3.mobilePlayer,
            position  = marker.position,
        })
    end
end

function this.cleanup()
    if this.editorData then
        if this.editorData.mount ~= nil then this.editorData.mount:delete() end
    end
    this.editorData = nil
end

---@param vehicle CVehicle
---@param nextPos tes3vector3
---@return boolean
function this.calculatePosition(vehicle, nextPos)
    local editorData = this.editorData

    if not editorData then return false end
    if not editorData.mount then return false end
    if not editorData.last_forwardDirection then return false end

    local isReversing = vehicle.current_speed < 0

    local mountOffset = tes3vector3.new(0, 0, vehicle.offset)
    local currentPos = editorData.last_position - mountOffset

    local forwardDirection = editorData.last_forwardDirection
    assert(forwardDirection) --TODO disable this?

    if isReversing then
        forwardDirection = tes3vector3.new(-forwardDirection.x, -forwardDirection.y, forwardDirection.z)
    end

    -- if idx > 1 then v = currentPos - positions[idx - 1] end
    forwardDirection:normalize()
    local d = (nextPos - currentPos):normalized()
    local lerp = forwardDirection:lerp(d, vehicle.current_turnspeed / 10):normalized()
    local f = editorData.mount.forwardDirection
    local forward = tes3vector3.new(f.x, f.y, lerp.z):normalized()
    if isReversing then
        forward = tes3vector3.new(-f.x, -f.y, lerp.z):normalized()
    end

    local delta = forward * math.abs(vehicle.current_speed) * config.grain
    local mountPosition = currentPos + delta + mountOffset

    -- calculate heading
    local current_facing = editorData.last_facing
    local new_facing = math.atan2(d.x, d.y)
    local facing = new_facing
    local diff = new_facing - current_facing
    if diff < -math.pi then diff = diff + 2 * math.pi end
    if diff > math.pi then diff = diff - 2 * math.pi end
    local angle = vehicle.current_turnspeed / 10000 * config.grain
    if diff > 0 and diff > angle then
        facing = current_facing + angle
        if isReversing then
            facing = current_facing - angle
        end
    elseif diff < 0 and diff < -angle then
        facing = current_facing - angle
        if isReversing then
            facing = current_facing + angle
        end
    else
        facing = new_facing
    end

    -- calculate position
    editorData.mount.facing = facing
    editorData.mount.position = mountPosition

    -- save
    editorData.last_position = editorData.mount.position
    editorData.last_forwardDirection = editorData.mount.forwardDirection
    editorData.last_facing = editorData.mount.facing

    -- draw vfx lines
    local child = this.arrow:clone()
    child.translation = mountPosition - mountOffset
    child.appCulled = false
    child.rotation = lib.rotationFromDirection(editorData.mount.forwardDirection)
    table.insert(this.arrows, child)

    -- move to next marker
    local isBehind = lib.isPointBehindObject(nextPos, mountPosition, forward)
    if isBehind then
        return true
    end

    return false
end

---@param mountData CVehicle
---@param startPort PortData
function this.calculateLeavePort(mountData, startPort)
    local editorData = this.editorData

    if not editorData then return end
    if not editorData.mount then return end

    -- position the vehicle in port
    editorData.mount.position = startPort:EndPos()
    editorData.mount.orientation = lib.radvec(startPort:EndRot())

    editorData.last_position = editorData.mount.position
    editorData.last_forwardDirection = editorData.mount.forwardDirection
    editorData.last_facing = editorData.mount.facing
    local nextPos = startPort:StartPos()

    for idx = 1, config.tracemax * 1000, 1 do
        local arrived = this.calculatePosition(mountData, nextPos)
        if arrived then
            break
        end
    end
end

return this
