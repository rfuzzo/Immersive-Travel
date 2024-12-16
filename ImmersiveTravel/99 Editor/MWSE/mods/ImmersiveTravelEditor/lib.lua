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

---@class SPreviewMarker
---@field node niNode|nil
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
---@field last_position tes3vector3|nil
---@field last_forwardDirection tes3vector3|nil
---@field last_facing number|nil

---@class SEditorSplineData
---@field service ServiceData
---@field start string?
---@field destination string?
---@field mount tes3reference?
---@field editorNodes niNode[]?
---@field currentNode niNode?
---@field pin1 number?
---@field pin2 number?
-- ---@field last_position tes3vector3|nil
-- ---@field last_forwardDirection tes3vector3|nil
-- ---@field last_facing number|nil

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
    Splines = 1,
    Ports = 2,
    Routes = 3
}


---@param val EEditorMode
---@return string
function this.ToString(val)
    if val == this.EEditorMode.Splines then return "Splines" end
    if val == this.EEditorMode.Ports then return "Ports" end
    if val == this.EEditorMode.Routes then return "New Routes" end
    return "Unknown"
end

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// VARIABLES

this.editorData         = nil ---@type SEditorData | nil
this.editorSplineData   = nil ---@type SEditorSplineData | nil

this.currentEditorMode  = this.EEditorMode.Routes ---@type EEditorMode
this.currentServiceName = nil ---@type string | nil

-- nodes
this.editorMarkerId     = "marker_travel.nif" -- for nodes
this.portMarkerId       = "marker_arrow.nif"  -- for ports
this.nodeMarkerId       = "marker_divine.nif" -- for connections
this.sphereMarkerId     = "sphere.nif"        -- for connections
this.editorMarkerMesh   = nil ---@type niNode?
this.portMarkerMesh     = nil ---@type niNode?
this.nodeMarkerMesh     = nil ---@type niNode?
this.sphereMarkerMesh   = nil ---@type niNode?

this.arrows             = {} ---@type niNode[]
this.arrow              = nil ---@type niNode?
this.arrowz             = nil ---@type niNode?

this.debugRoot          = nil ---@type niNode?
this.editorRoot         = nil ---@type niNode?

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

---@param ignoreConnections boolean?
---@return number?
function this.getClosestMarkerIdx(ignoreConnections)
    if not this.editorData then return nil end
    if not this.editorData.editorMarkers then return nil end

    -- get closest marker
    local final_idx = 0
    local last_distance = nil
    for index, marker in ipairs(this.editorData.editorMarkers) do
        if ignoreConnections then
            if marker.type ~= this.EMarkerType.Route then
                goto continue
            end
        else
            if marker.type ~= this.EMarkerType.Route and marker.type ~= this.EMarkerType.RouteConnection then
                goto continue
            end
        end

        local distance_to_marker = tes3.player.position:distance(marker.node.translation)
        -- if distance_to_marker > 1024 then
        --     goto continue
        -- end

        -- first
        if last_distance == nil then
            last_distance = distance_to_marker
            final_idx = 1
        end
        -- last
        if distance_to_marker < last_distance then
            final_idx = index
            last_distance = distance_to_marker
        end

        ::continue::
    end

    return final_idx
end

function this.IsPortMode()
    return this.currentEditorMode == this.EEditorMode.Ports
end

function this.IsSplineMode()
    return this.currentEditorMode == this.EEditorMode.Splines
end

function this.IsRouteMode()
    return this.currentEditorMode == this.EEditorMode.Routes
end

return this
