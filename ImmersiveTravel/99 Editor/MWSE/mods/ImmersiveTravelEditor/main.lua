local lib            = require("ImmersiveTravel.lib")
local interop        = require("ImmersiveTravel.interop")
local GRoutesManager = require("ImmersiveTravel.GRoutesManager")

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// CONFIGURATION
local config         = require("ImmersiveTravelEditor.config")
-- config nil check
if not config then
    return
end

local logger      = require("logging.logger")
local log         = logger.new {
    name = config.mod,
    logLevel = config.logLevel,
    logToConsole = false,
    includeTimestamp = false
}

---@enum EMarkerType
local EMarkerType = {
    PortStart = 1,
    PortEnd = 2,
    Port = 3,
    Route = 4
}

---@enum EEditorMode
local EEditorMode = {
    Routes = 1,
    Ports = 2,
    Segments = 2
}

---@param val EEditorMode
---@return string
local function ToString(val)
    if val == EEditorMode.Routes then return "Routes" end
    if val == EEditorMode.Ports then return "Ports" end
    if val == EEditorMode.Segments then return "Segments" end
    return "Unknown"
end

---@class SPreviewData
---@field mount tes3reference?

---@class SPreviewMarker
---@field node niNode
---@field type EMarkerType

---@class SEditorData
---@field service ServiceData
---@field start string
---@field destination string
---@field mount tes3reference?
---@field splineIndex integer
---@field editorMarkers SPreviewMarker[]?
---@field currentMarker SPreviewMarker?

---@class SEditorPortData
---@field mount tes3reference?
---@field portData PortData?

--[[
Current Usage (Debug)
- Open route editor 						... R-Ctrl
- move a marker 							... L-Ctrl
- delete a marker 							... Del
- exit edit mode 							... L-Ctrl
- add a marker								... >
- start traveling            		        ... <

--]]
local editMenuId = tes3ui.registerID("it:MenuEdit")
local editMenuSaveId = tes3ui.registerID("it:MenuEdit_Display")
local editMenuModeId = tes3ui.registerID("it:MenuEdit_Mode")
local editMenuRoutesId = tes3ui.registerID("it:MenuEdit_Routes")
local editMenuCancelId = tes3ui.registerID("it:MenuEdit_Cancel")
local editMenuTeleportId = tes3ui.registerID("it:MenuEdit_Teleport")
local editMenuTeleportEndId = tes3ui.registerID("it:MenuEdit_TeleportEnd")
local editMenuPreviewId = tes3ui.registerID("it:MenuEdit_Preview")
local editMenuSearchId = tes3ui.registerID("it:MenuEdit_Search")
local editMenuReloadId = tes3ui.registerID("it:MenuEdit_Reload")
local editMenuAllId = tes3ui.registerID("it:MenuEdit_All")

local editorMarkerId = "marker_travel.nif"
local portMarkerId = "marker_arrow.nif"
-- "marker_divine.nif"
-- "marker_north.nif"

local editorMarkerMesh = nil ---@type niNode?
local portMarkerMesh = nil ---@type niNode?

-- editor
local currentEditorMode = EEditorMode.Routes ---@type EEditorMode
---@type string | nil
local currentServiceName = nil
---@type SEditorData | nil
local editorData = nil
local editmode = false

---@type SEditorPortData | nil
local editorPortData = nil

-- preview
---@type SPreviewData | nil
local preview = nil

-- tracing
local filter_text = ""
local arrows = {} ---@type niNode[]
local arrow = nil ---@type niNode?

local last_position = nil ---@type tes3vector3|nil
local last_forwardDirection = nil ---@type tes3vector3|nil
local last_facing = nil ---@type number|nil

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// FUNCTIONS

--#region general

---@param startPoint tes3vector3
---@param port PortData
---@param mountId string
---@param offset number
---@return tes3reference
local function createMount(startPoint, port, mountId, offset)
    local orientation = lib.radvec(lib.vec(port.rotation))
    if port.rotationStart then
        orientation = lib.radvec(lib.vec(port.rotationStart))
    end

    local mountOffset = tes3vector3.new(0, 0, offset)
    local mount = tes3.createReference {
        object = mountId,
        position = startPoint + mountOffset,
        orientation = orientation
    }

    mount.facing = orientation.z -- TODO needed?

    return mount
end

---@param name string
---@param origin tes3vector3
---@param destination tes3vector3
local function createLine(name, origin, destination)
    local root = tes3.worldController.vfxManager.worldVFXRoot

    local line = root:getObjectByName(name)

    if line == nil then
        line = tes3.loadMesh("mwse\\widgets.nif", false)
            :getObjectByName("axisLines")
            :getObjectByName("z")
            :clone()

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
local function getGroundZ(from)
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

--#endregion

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// EDITOR

local function updateMarkers()
    if not editorData then return end
    local editorMarkers = editorData.editorMarkers
    if not editorMarkers then return end

    -- update rotation
    for index, marker in ipairs(editorMarkers) do
        -- ignore first and last
        if index > 1 and index < #editorMarkers then
            local nextMarker = editorMarkers[index + 1]
            local direction = nextMarker.node.translation - marker.node.translation
            local rotation_matrix = lib.rotationFromDirection(direction)
            marker.node.rotation = rotation_matrix
        end
    end

    tes3.worldController.vfxManager.worldVFXRoot:update()
end

--#region editor helpers

---@return number?
local function getClosestMarkerIdx()
    if not editorData then return nil end
    local editorMarkers = editorData.editorMarkers
    if not editorMarkers then return nil end

    -- get closest marker
    local pp = tes3.player.position

    local final_idx = 0
    local last_distance = nil
    for index, marker in ipairs(editorMarkers) do
        local distance_to_marker = pp:distance(marker.node.translation)

        -- first
        if last_distance == nil then
            last_distance = distance_to_marker
            final_idx = 1
        end

        if distance_to_marker < last_distance then
            final_idx = index
            last_distance = distance_to_marker
        end
    end

    if final_idx == 0 then
        return nil
    end

    return final_idx
end

---@param startPort PortData?
---@param destinationPort PortData?
local function renderAdditionalMarkers(startPort, destinationPort)
    local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
    if not portMarkerMesh then return nil end

    -- TODO

    -- -- render start maneuvre
    if startPort then
        local child = portMarkerMesh:clone()
        child.translation = tes3vector3.new(startPort.position.x, startPort.position.y, startPort.position.z)
        local m = tes3matrix33.new()
        local x = math.rad(startPort.rotation.x)
        local y = math.rad(startPort.rotation.y)
        local z = math.rad(startPort.rotation.z)
        m:fromEulerXYZ(x, y, z)
        child.rotation = m
        child.appCulled = false
        vfxRoot:attachChild(child)
        tes3.worldController.vfxManager.worldVFXRoot:update()
    end

    -- additional position at the end
    -- if destinationPort and destinationPort.positionEnd then

    -- end
end

---@param spline PositionRecord[]
local function renderMarkers(spline)
    if not editorData then return nil end
    if not editorMarkerMesh then return nil end
    if not portMarkerMesh then return nil end

    editorData.editorMarkers = {}
    editorData.currentMarker = nil

    local startPort = editorData.service.ports[editorData.start] ---@type PortData?
    local destinationPort = editorData.service.ports[editorData.destination] ---@type PortData?

    local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot

    -- add markers
    for idx, v in ipairs(spline) do
        local child = editorMarkerMesh:clone()
        local type = EMarkerType.Route

        -- first and last marker are ports with fixed markers
        if idx == 1 or idx == #spline then
            child = portMarkerMesh:clone()

            -- start port
            if idx == 1 and startPort then
                type = EMarkerType.Port
                local m = tes3matrix33.new()

                local x = math.rad(startPort.rotation.x)
                local y = math.rad(startPort.rotation.y)
                local z = math.rad(startPort.rotation.z)

                -- start from override instead
                if startPort.rotationStart then
                    x = math.rad(startPort.rotationStart.x)
                    y = math.rad(startPort.rotationStart.y)
                    z = math.rad(startPort.rotationStart.z)

                    type = EMarkerType.PortStart
                end

                m:fromEulerXYZ(x, y, z)
                child.rotation = m
            end

            -- destination port
            if idx == #spline and destinationPort then
                type = EMarkerType.Port
                local m = tes3matrix33.new()

                local x = math.rad(destinationPort.rotation.x)
                local y = math.rad(destinationPort.rotation.y)
                local z = math.rad(destinationPort.rotation.z)
                if destinationPort.rotationEnd then
                    -- TODO
                    -- x = math.rad(destinationPort.rotationEnd.x)
                    -- y = math.rad(destinationPort.rotationEnd.y)
                    -- z = math.rad(destinationPort.rotationEnd.z)

                    type = EMarkerType.PortEnd
                end

                m:fromEulerXYZ(x, y, z)
                child.rotation = m
            end
        end

        child.translation = tes3vector3.new(v.x, v.y, v.z)
        child.appCulled = false

        vfxRoot:attachChild(child)

        ---@type SPreviewMarker
        local object = {
            node = child,
            type = type
        }
        editorData.editorMarkers[idx] = object
    end

    updateMarkers()

    -- not needed for now
    renderAdditionalMarkers(startPort, destinationPort)
end

local function cleanup()
    if editorData then
        if editorData.mount ~= nil then editorData.mount:delete() end
    end
    editorData = nil
end

---@param service ServiceData
local function traceAll(service)
    if not arrow then return end

    arrows = {}

    local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
    vfxRoot:detachAllChildren()

    for start, destinations in pairs(service.routes) do
        for _i, destination in ipairs(destinations) do
            local routeId = start .. "_" .. destination
            local spline = GRoutesManager.getInstance():GetRoute(routeId)
            if spline then
                editorData = {
                    service = service,
                    destination = destination,
                    start = start,
                    splineIndex = 1,
                }

                log:trace("Drawing route '%s'", routeId)

                -- render points
                renderMarkers(spline)

                -- simple line between the points
                for i = 1, #spline - 1 do
                    local from = lib.vec(spline[i])
                    local to = lib.vec(spline[i + 1])

                    local id = string.format("rf_line_%s_%d", routeId, i)
                    createLine(id, from, to)
                end
            end
        end
    end

    vfxRoot:update()
end

-- TODO use method from locomotion state
---@param vehicle CVehicle
---@param nextPos tes3vector3
---@return boolean
local function calculatePosition(vehicle, nextPos)
    if not editorData then return false end
    if not last_forwardDirection then return false end

    local isReversing = vehicle.current_speed < 0

    local mountOffset = tes3vector3.new(0, 0, vehicle.offset)
    local currentPos = last_position - mountOffset

    local forwardDirection = last_forwardDirection
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
    -- TODO fix speed buffers
    local delta = forward * math.abs(vehicle.current_speed) * config.grain
    local mountPosition = currentPos + delta + mountOffset

    -- calculate heading
    local current_facing = last_facing
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
    last_position = editorData.mount.position
    last_forwardDirection = editorData.mount.forwardDirection
    last_facing = editorData.mount.facing

    -- draw vfx lines
    if arrow then
        local child = arrow:clone()
        child.translation = mountPosition - mountOffset
        child.appCulled = false
        child.rotation = lib.rotationFromDirection(editorData.mount.forwardDirection)
        table.insert(arrows, child)
    end

    -- move to next marker
    local isBehind = lib.isPointBehindObject(nextPos, mountPosition, forward)
    if isBehind then
        return true
    end

    return false
end

---@param startpos tes3vector3
---@param mountData CVehicle
local function calculatePositions(startpos, mountData)
    if not editorData then return end
    if not editorData.editorMarkers then return end

    editorData.splineIndex = 2
    last_position = editorData.mount.position
    last_forwardDirection = editorData.mount.forwardDirection
    last_facing = editorData.mount.facing

    for idx = 1, config.tracemax * 1000, 1 do
        if editorData.splineIndex <= #editorData.editorMarkers then
            local point = editorData.editorMarkers[editorData.splineIndex].node.translation
            local nextPos = tes3vector3.new(point.x, point.y, point.z)

            local isBehind = calculatePosition(mountData, nextPos)
            if isBehind then
                editorData.splineIndex = editorData.splineIndex + 1
            end
        else
            break
        end
    end
end

---@param service ServiceData
---@param mountData CVehicle
---@param startPort PortData
local function calculateLeavePort(service, mountData, startPort)
    if not editorData then return end

    -- position the vehicle in port
    -- TODO get the proper position
    editorData.mount.position = lib.vec(startPort.position)
    editorData.mount.orientation = lib.radvec(lib.vec(startPort.rotation))

    last_position = editorData.mount.position
    last_forwardDirection = editorData.mount.forwardDirection
    last_facing = editorData.mount.facing
    local nextPos = lib.vec(startPort.positionStart)

    for idx = 1, config.tracemax * 1000, 1 do
        local arrived = calculatePosition(mountData, nextPos)
        if arrived then
            break
        end
    end
end

---@param service ServiceData
local function traceRoute(service)
    if not editorData then return end
    if not editorData.editorMarkers then return end
    if #editorData.editorMarkers < 2 then return end


    local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
    for _, value in ipairs(arrows) do vfxRoot:detachChild(value) end

    -- trace the route
    local start_point = editorData.editorMarkers[1].node.translation
    local start_pos = tes3vector3.new(start_point.x, start_point.y, start_point.z)
    local mountId = lib.ResolveMountId(service, editorData.start, editorData.destination)

    log:debug("[%s] Tracing %s > %s", mountId, editorData.start, editorData.destination)

    local mountData = interop.getVehicleStaticData(mountId)
    if not mountData then return end

    local startPort = service.ports[editorData.start]
    local destinationPort = service.ports[editorData.destination]
    editorData.mount = createMount(start_point, startPort, mountId, mountData.offset)

    arrows = {}

    mountData.current_turnspeed = mountData.turnspeed * 1.5
    mountData.current_speed = mountData.speed * -1
    calculateLeavePort(service, mountData, startPort)

    mountData.current_turnspeed = mountData.turnspeed
    mountData.current_speed = mountData.speed
    calculatePositions(start_pos, mountData)

    -- validation

    -- check if the last position is near the last marker
    local lastMarker = editorData.editorMarkers[#editorData.editorMarkers]
    local lastPos = editorData.mount.position
    local distance = lastPos:distance(lastMarker.node.translation)
    log:debug("Last position is %d from the last marker", distance)
    if distance > 200 then
        log:warn("!!! Last position is too far from the last marker: %d", distance)
        tes3.messageBox("!!! Last position is too far from the last marker: %d", distance)
    end

    -- check if the last orientation does not have a big difference

    local lastOrientation = editorData.mount.orientation
    local destinationPortOrientation = lib.radvec(lib.vec(destinationPort.rotation))
    local diff = lastOrientation.z - destinationPortOrientation.z
    log:debug("Last orientation is %d from the last marker", diff)
    if diff > 0.1 then
        log:warn("!!! Last orientation is too far from the last marker: %d", diff)
        tes3.messageBox("!!! Last orientation is too far from the last marker: %d", diff)
    end

    -- check if the start and destination ports are in the correct cells
    local startCell = tes3.getCell({ id = editorData.start }) ---@type tes3cell
    local isPointInCell = startCell:isPointInCell(startPort.position.x, startPort.position.y)
    if not isPointInCell then
        local portCell = tes3.getCell({ position = lib.vec(startPort.position) })
        if portCell then
            log:warn("!!! Start port '%s' cell mismatch: '%s'", editorData.start, portCell.id)
            tes3.messageBox("!!! Start port '%s' cell mismatch: '%s'", editorData.start, portCell.id)
        else
            log:warn("!!! Could not find destination port cell")
        end
    end


    local destinationCell = tes3.getCell({ id = editorData.destination }) ---@type tes3cell
    isPointInCell = destinationCell:isPointInCell(destinationPort.position.x, destinationPort.position.y)
    if not isPointInCell then
        local portCell = tes3.getCell({ position = lib.vec(destinationPort.position) })
        if portCell then
            log:warn("!!! Destination port '%s' cell mismatch: '%s'", editorData.destination, portCell.id)
            tes3.messageBox("!!! Destination port '%s' cell mismatch: '%s'", editorData.destination,
                portCell.id)
        else
            log:warn("!!! Could not find destination port cell")
        end
    end

    -- cleanup
    editorData.mount:delete()
    editorData.mount = nil

    -- vfx
    for _, child in ipairs(arrows) do
        vfxRoot:attachChild(child)
    end

    vfxRoot:update()
end

---@param service ServiceData
---@return string[]
local function getAllPortNames(service)
    ---@type string[]
    local result = {}


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

                -- insert start
                if not table.find(result, start) then
                    table.insert(result, start)
                end

                -- insert destination
                if not table.find(result, destination) then
                    table.insert(result, destination)
                end
            end
        end
    end


    return result
end

local function IsPortMode()
    return currentEditorMode == EEditorMode.Ports
end

local function IsRouteMode()
    return currentEditorMode == EEditorMode.Routes
end

local function IsSegmentsMode()
    return currentEditorMode == EEditorMode.Segments
end

---@param name string
local function teleportToCell(name)
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

--#endregion

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// UI

local function createEditWindow()
    -- Return if window is already open
    if (tes3ui.findMenu(editMenuId) ~= nil) then return end

    GRoutesManager.getInstance():Init()

    -- load services
    local services = GRoutesManager.getInstance().services
    if not services then return end

    -- Create window and frame
    local menu = tes3ui.createMenu {
        id = editMenuId,
        fixedFrame = false,
        dragFrame = true
    }

    -- To avoid low contrast, text input windows should not use menu transparency settings
    menu.alpha = 1.0
    menu.width = 700
    menu.height = 500


    -- get current service
    if not currentServiceName then
        currentServiceName = table.keys(services)[1]
    end
    if editorData then currentServiceName = editorData.service.class end

    local service = services[currentServiceName]

    menu.text = "Editor"
    if editorData then
        if IsRouteMode() then
            menu.text = "Editor " .. editorData.start .. "_" ..
                editorData.destination
        end
    end

    local input = menu:createTextInput { text = filter_text, id = editMenuSearchId }
    input.widget.lengthLimit = 31
    input.widget.eraseOnFirstKey = true
    input:register(tes3.uiEvent.keyEnter, function()
        local m = tes3ui.findMenu(editMenuId)
        if (m) then
            local text = menu:findChild(editMenuSearchId).text
            filter_text = text
            cleanup()
            m:destroy()
            createEditWindow()
        end
    end)

    -- Create layout
    local label = menu:createLabel { text = "Loaded routes (" .. currentServiceName .. ")" }
    label.borderBottom = 5

    -- get destinations
    local pane = menu:createVerticalScrollPane { id = "sortedPane" }

    -- list all routes
    if IsRouteMode() then
        local destinations = service.routes
        if destinations then
            for _i, start in ipairs(table.keys(destinations)) do
                for _j, destination in ipairs(destinations[start]) do
                    -- filter
                    local filter = filter_text:lower()
                    if filter_text ~= "" then
                        if (not string.find(start:lower(), filter) and not string.find(destination:lower(), filter)) then
                            goto continue
                        end
                    end

                    local text = start .. " - " .. destination
                    local button = pane:createButton {
                        id = "button_spline" .. text,
                        text = text
                    }
                    button:register(tes3.uiEvent.mouseClick, function()
                        -- start editor
                        editorData = {
                            service = service,
                            destination = destination,
                            start = start,
                            mount = nil,
                            splineIndex = 1,
                            editorMarkers = nil,
                            currentMarker = nil
                        }

                        -- render markers
                        local routeId = start .. "_" .. destination
                        local spline = GRoutesManager.getInstance():GetRoute(routeId)
                        tes3.messageBox("loaded spline: %s > %s", start, destination)

                        local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
                        vfxRoot:detachAllChildren()

                        renderMarkers(spline)

                        if config.traceOnSave then
                            traceRoute(service)
                        end
                    end)

                    ::continue::
                end
            end
        end
    end

    -- list all ports
    if IsPortMode() then
        local ports = getAllPortNames(service)
        for _i, port in ipairs(ports) do
            -- filter
            local filter = filter_text:lower()
            if filter_text ~= "" then
                if (not string.find(port:lower(), filter)) then
                    goto continue
                end
            end

            local button = pane:createButton {
                id = "button_port" .. port,
                text = port
            }
            button:register(tes3.uiEvent.mouseClick, function()
                -- teleport to port
                local portData = table.get(service.ports, port, nil) ---@class PortData?
                if portData then
                    tes3.positionCell({
                        reference = tes3.mobilePlayer,
                        position  = lib.vec(portData.position),
                    })
                else
                    teleportToCell(port)
                end

                editorPortData = {
                    portData = portData,
                    mount = nil
                }
            end)

            ::continue::
        end
    end

    pane:getContentElement():sortChildren(function(a, b)
        return a.text < b.text
    end)

    local button_block = menu:createBlock {}
    button_block.widthProportional = 1.0 -- width is 100% parent width
    button_block.autoHeight = true
    button_block.childAlignX = 1.0       -- right content alignment

    local button_mode = button_block:createButton {
        id = editMenuModeId,
        text = "Mode: " .. ToString(currentEditorMode)
    }

    local button_service = button_block:createButton {
        id = editMenuRoutesId,
        text = currentServiceName
    }

    if IsRouteMode() then
        local button_teleport = button_block:createButton {
            id = editMenuTeleportId,
            text = "Start"
        }
        local button_teleportEnd = button_block:createButton {
            id = editMenuTeleportEndId,
            text = "End"
        }
        local button_save = button_block:createButton {
            id = editMenuSaveId,
            text = "Save"
        }


        -- Teleport Start
        button_teleport:register(tes3.uiEvent.mouseClick, function()
            if not editorData then return end
            if not editorData.editorMarkers then return end

            local m = tes3ui.findMenu(editMenuId)
            if (m) then
                if #editorData.editorMarkers > 1 then
                    tes3.positionCell({
                        reference = tes3.mobilePlayer,
                        position = editorData.editorMarkers[1].node.translation
                    })

                    tes3ui.leaveMenuMode()
                    m:destroy()
                end
            end
        end)
        -- Teleport End
        button_teleportEnd:register(tes3.uiEvent.mouseClick, function()
            if not editorData then return end
            if not editorData.editorMarkers then return end

            local m = tes3ui.findMenu(editMenuId)
            if (m) then
                if #editorData.editorMarkers > 1 then
                    tes3.positionCell({
                        reference = tes3.mobilePlayer,
                        position = editorData.editorMarkers[#editorData.editorMarkers].node.translation
                    })

                    tes3ui.leaveMenuMode()
                    m:destroy()
                end
            end
        end)
        --- save to file
        button_save:register(tes3.uiEvent.mouseClick, function()
            if not editorData then return end
            if not editorData.editorMarkers then return end

            local tempSpline = {}
            for i, value in ipairs(editorData.editorMarkers) do
                local t = value.node.translation

                -- save currently edited markers back to spline
                table.insert(tempSpline, i, {
                    x = math.round(t.x),
                    y = math.round(t.y),
                    z = math.round(t.z)
                })
            end

            -- remove first and last marker (these are the ports)
            table.remove(tempSpline, 1)
            table.remove(tempSpline, #tempSpline)

            -- save to file
            local current_editor_route = editorData.start .. "_" ..
                editorData.destination
            local filename = string.format("%s\\%s\\%s", lib.localmodpath, service.class, current_editor_route)
            json.savefile(filename, tempSpline)

            tes3.messageBox("saved spline: " .. current_editor_route)
        end)
    end

    local button_all = button_block:createButton {
        id = editMenuAllId,
        text = "All"
    }

    local button_cancel = button_block:createButton {
        id = editMenuCancelId,
        text = "Exit"
    }

    -- Display all routes and ports
    button_all:register(tes3.uiEvent.mouseClick, function()
        local m = tes3ui.findMenu(editMenuId)
        if (m) then
            traceAll(service)
        end
    end)


    -- Switch service
    button_service:register(tes3.uiEvent.mouseClick, function()
        local m = tes3ui.findMenu(editMenuId)
        if (m) then
            -- go to next
            local idx = table.find(table.keys(services), currentServiceName)
            local nextIdx = idx + 1
            if nextIdx > #table.keys(services) then nextIdx = 1 end
            currentServiceName = table.keys(services)[nextIdx]

            cleanup()
            m:destroy()
            createEditWindow()
        end
    end)

    -- Switch mode
    button_mode:register(tes3.uiEvent.mouseClick, function()
        local m = tes3ui.findMenu(editMenuId)
        if (m) then
            if currentEditorMode == EEditorMode.Routes then
                currentEditorMode = EEditorMode.Ports
            elseif currentEditorMode == EEditorMode.Ports then
                currentEditorMode = EEditorMode.Segments
            elseif currentEditorMode == EEditorMode.Segments then
                currentEditorMode = EEditorMode.Routes
            end

            cleanup()
            m:destroy()
            createEditWindow()
        end
    end)

    -- Leave Menu
    button_cancel:register(tes3.uiEvent.mouseClick, function()
        local m = tes3ui.findMenu(editMenuId)
        if (m) then
            tes3ui.leaveMenuMode()
            m:destroy()
        end
    end)

    tes3ui.acquireTextInput(input)
    menu:updateLayout()
    tes3ui.enterMenuMode(editMenuId)
end

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// EVENTS

--- @param e simulatedEventData
local function simulatedCallback(e)
    if editorData and editorData.currentMarker then
        if editmode == false then return end

        local service = editorData.service
        local from = tes3.getPlayerEyePosition() + tes3.getPlayerEyeVector() * 256

        if service.ground_offset == 0 then
            from.z = 0
        else
            local groundZ = getGroundZ(from)
            if groundZ == nil then
                from.z = service.ground_offset
            else
                from.z = groundZ + service.ground_offset
            end
        end

        editorData.currentMarker.node.translation = from
        editorData.currentMarker.node:update()
    end

    if editorPortData and editorPortData.mount then
        if editmode == false then return end

        local from = tes3.getPlayerEyePosition() + tes3.getPlayerEyeVector() * 256
        editorPortData.mount.position = from
    end
end
event.register(tes3.event.simulated, simulatedCallback)

local function insertMarker()
    if IsPortMode() then
        -- TODO it can bei either start or destination
    elseif IsRouteMode() then
        if not editorData then return end
        if not editorMarkerMesh then return end
        if not editorData.editorMarkers then return end

        local idx = getClosestMarkerIdx()
        if not idx then
            return
        end

        local from = tes3.getPlayerEyePosition() + tes3.getPlayerEyeVector() * 256

        local child = editorMarkerMesh:clone()
        child.translation = tes3vector3.new(from.x, from.y, from.z)
        child.appCulled = false

        local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
        vfxRoot:attachChild(child)
        vfxRoot:update()

        -- new index is +1 if not last idx, else last idx - 1
        local newIdx = idx
        if idx == #editorData.editorMarkers then
            newIdx = idx - 1
        elseif idx == #editorData.editorMarkers - 1 then
            newIdx = idx
        else
            newIdx = idx + 1
        end

        local type = EMarkerType.Route
        ---@type SPreviewMarker
        local struct = {
            node = child,
            type = type
        }

        table.insert(editorData.editorMarkers, newIdx, struct)

        editorData.currentMarker = struct
        editmode = true
    end
end

local function editMarker()
    if IsPortMode() then
        -- TODO
    elseif IsRouteMode() then
        if not editorData then return end

        local idx = getClosestMarkerIdx()
        if not idx then
            return
        end

        -- if the first then get the second
        if idx == 1 then
            idx = 2
        end
        -- if the last then get the second last
        if idx == #editorData.editorMarkers then
            idx = #editorData.editorMarkers - 1
        end

        editorData.currentMarker = editorData.editorMarkers[idx]
        updateMarkers()

        editmode = not editmode

        tes3.messageBox("Marker index: " .. idx)

        if not editmode and config.traceOnSave then
            traceRoute(editorData.service)
        end
    end
end

local function deleteMarker()
    if IsPortMode() then
        -- TODO
    elseif IsRouteMode() then
        if not editorData then return end
        if not editorData.editorMarkers then return end

        local idx = getClosestMarkerIdx()
        if idx then
            -- if the first then get the second
            if idx == 1 then
                idx = 2
            end
            -- if the last then get the second last
            if idx == #editorData.editorMarkers then
                idx = #editorData.editorMarkers - 1
            end

            editorData.currentMarker = editorData.editorMarkers[idx]
            updateMarkers()

            local instance = editorData.editorMarkers[idx]
            local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
            vfxRoot:detachChild(instance.node)
            vfxRoot:update()

            table.remove(editorData.editorMarkers, idx)

            if editorData and config.traceOnSave then
                traceRoute(editorData.service)
            end
        end
    end
end

--- @param e keyDownEventData
local function editor_keyDownCallback(e)
    -- editor menu
    if e.keyCode == config.openkeybind.keyCode then createEditWindow() end

    -- insert
    if e.keyCode == config.placekeybind.keyCode then
        insertMarker()
    end

    -- marker edit mode
    if e.keyCode == config.editkeybind.keyCode then
        editMarker()
    end

    -- delete
    if e.keyCode == config.deletekeybind.keyCode then
        deleteMarker()
    end

    -- trace
    if e.keyCode == config.tracekeybind.keyCode then
        if editorData then traceRoute(editorData.service) end
    end
end
event.register(tes3.event.keyDown, editor_keyDownCallback)

--- Cleanup on save load
--- @param e loadEventData
local function editloadCallback(e)
    editorMarkerMesh = tes3.loadMesh(editorMarkerId)
    portMarkerMesh = tes3.loadMesh(portMarkerId)
    -- divineMarkerMesh = tes3.loadMesh(divineMarkerId)
    -- arrowMarkerMesh = tes3.loadMesh(arrowMarkerId)

    -- widgets.nif
    arrow = tes3.loadMesh("mwse\\widget_arrow_y.nif"):clone()
    arrow.scale = 70

    cleanup()
end
event.register(tes3.event.load, editloadCallback)

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// CONFIG
require("ImmersiveTravelEditor.mcm")
