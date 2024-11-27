local lib            = require("ImmersiveTravel.lib")
local interop        = require("ImmersiveTravel.interop")
local GRoutesManager = require("ImmersiveTravel.GRoutesManager")
local PositionRecord = require("ImmersiveTravel.models.PositionRecord")
local RouteId        = require("ImmersiveTravel.models.RouteId")
local elib           = require("ImmersiveTravelEditor.lib")

local config         = require("ImmersiveTravelEditor.config")
if not config then return end

local this                  = {}

local EEditorMode           = elib.EEditorMode
local EMarkerType           = elib.EMarkerType
local log                   = elib.log

local editMenuSaveId        = tes3ui.registerID("it:MenuEdit_Display")
local editMenuModeId        = tes3ui.registerID("it:MenuEdit_Mode")
local editMenuRoutesId      = tes3ui.registerID("it:MenuEdit_Routes")
local editMenuCancelId      = tes3ui.registerID("it:MenuEdit_Cancel")
local editMenuTeleportId    = tes3ui.registerID("it:MenuEdit_Teleport")
local editMenuTeleportEndId = tes3ui.registerID("it:MenuEdit_TeleportEnd")
local editMenuDumpId        = tes3ui.registerID("it:MenuEdit_Dump")
local editMenuSearchId      = tes3ui.registerID("it:MenuEdit_Search")
local editMenuReloadId      = tes3ui.registerID("it:MenuEdit_Reload")
local editMenuAllId         = tes3ui.registerID("it:MenuEdit_All")

local editorMarkerId        = "marker_travel.nif" -- for nodes
local portMarkerId          = "marker_arrow.nif"  -- for ports
local nodeMarkerId          = "marker_divine.nif" -- for connections
-- "marker_north.nif"

local editorMarkerMesh      = nil ---@type niNode?
local portMarkerMesh        = nil ---@type niNode?
local nodeMarkerMesh        = nil ---@type niNode?

-- editor
local editmode              = false

-- preview
---@type SPreviewData | nil
local preview               = nil

-- tracing
local filter_text           = ""
local arrows                = {} ---@type niNode[]
local arrow                 = nil ---@type niNode?

local last_position         = nil ---@type tes3vector3|nil
local last_forwardDirection = nil ---@type tes3vector3|nil
local last_facing           = nil ---@type number|nil

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// EDITOR

--#region editor helpers



local function updateMarkers()
    if not editorData then return end
    local editorNodes = editorData.editorNodes
    if not editorNodes then return end

    -- update rotation
    for index, marker in ipairs(editorNodes) do
        -- ignore first and last
        if index > 1 and index < #editorNodes then
            local nextNode = editorNodes[index + 1]
            local direction = nextNode.translation - marker.translation
            local rotation_matrix = lib.rotationFromDirection(direction)
            marker.rotation = rotation_matrix
        end
    end

    tes3.worldController.vfxManager.worldVFXRoot:update()
end

---@param ignoreConnections boolean?
---@return number?
local function getClosestNodeIdx(ignoreConnections)
    if not editorData then return nil end
    if not editorData.editorNodes then return nil end

    if IsRouteMode() then
        -- get closest marker
        local final_idx = 0
        local last_distance = nil
        for index, marker in ipairs(editorData.editorNodes) do
            local distance_to_marker = tes3.player.position:distance(marker.translation)
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
        end

        -- nothing found
        if final_idx == 0 then
            return nil
        end

        -- if the first then get the second
        if final_idx == 1 then
            final_idx = 2
        end
        -- if the last then get the second last
        if final_idx == #editorData.editorNodes then
            final_idx = #editorData.editorNodes - 1
        end
    end

    return nil
end

---@param ignoreConnections boolean?
---@return number?
local function getClosestMarkerIdx(ignoreConnections)
    if not editorData then return nil end
    if not editorData.editorMarkers then return nil end

    if IsRouteMode() then
        return nil
    end

    -- get closest marker
    local final_idx = 0
    local last_distance = nil
    for index, marker in ipairs(editorData.editorMarkers) do
        if IsSegmentsMode() then
            if ignoreConnections then
                if marker.type ~= EMarkerType.Route then
                    goto continue
                end
            else
                if marker.type ~= EMarkerType.Route and marker.type ~= EMarkerType.RouteConnection then
                    goto continue
                end
            end
        elseif IsPortMode() then
            if marker.type ~= EMarkerType.Port and marker.type ~= EMarkerType.PortStart and marker.type ~= EMarkerType.PortEnd then
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

---@param vehicle CVehicle
---@param nextPos tes3vector3
---@return boolean
local function calculatePosition(vehicle, nextPos)
    if not editorData then return false end
    if not editorData.mount then return false end
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

---@param mountData CVehicle
local function calculatePositions(mountData)
    if not editorData then return end
    if not editorData.mount then return end
    if not editorData.editorNodes then return end

    last_position = editorData.mount.position
    last_forwardDirection = editorData.mount.forwardDirection
    last_facing = editorData.mount.facing

    local splineIndex = 2

    for idx = 1, config.tracemax * 1000, 1 do
        if splineIndex <= #editorData.editorNodes then
            local nextPos = editorData.editorNodes[splineIndex].translation

            local isBehind = calculatePosition(mountData, nextPos)
            if isBehind then
                splineIndex = splineIndex + 1
            end
        else
            break
        end
    end
end

---@param mountData CVehicle
local function calculatePositionsNew(mountData)
    if not editorData then return end
    if not editorData.mount then return end
    if not editorData.service then return end

    last_position = editorData.mount.position
    last_forwardDirection = editorData.mount.forwardDirection
    last_facing = editorData.mount.facing

    local routeId = RouteId:new(editorData.service.class, editorData.start, editorData.destination)
    local route = editorData.service:GetRoute(routeId)
    assert(route, "Route not found")

    -- reset indeces
    local segmentIndex = 1
    local currentSpline = route:GetSegmentRoute(editorData.service, route.segments[segmentIndex])
    assert(currentSpline, "Route not found")

    local splineIndex = 1

    for idx = 1, config.tracemax * 1000, 1 do
        -- check if we are at the end of all segments
        if segmentIndex > #route.segments then
            break
        end

        -- check if we need to move to the next segment
        if splineIndex > #currentSpline then
            segmentIndex = segmentIndex + 1

            local nextSegment = editorData.service:GetSegment(route.segments[segmentIndex])
            -- check if we are at the end of all segments
            if not nextSegment then
                log:trace("No more segments")
                break
            end
            log:trace("Moving to the next segment: '%s'", nextSegment.id)

            -- new route in the new segment
            currentSpline = route:GetSegmentRoute(editorData.service, route.segments[segmentIndex])
            assert(currentSpline, "Route not found")

            splineIndex = 2 -- NOTE it needs to be 2 because we are already at the first position
        else
            -- move
            local nextPos = currentSpline[splineIndex]
            local isBehind = calculatePosition(mountData, nextPos)
            if isBehind then
                splineIndex = splineIndex + 1
            end
        end
    end
end

---@param mountData CVehicle
---@param startPort PortData
local function calculateLeavePort(mountData, startPort)
    if not editorData then return end
    if not editorData.mount then return end

    -- position the vehicle in port
    editorData.mount.position = startPort:EndPos()
    editorData.mount.orientation = lib.radvec(startPort:EndRot())

    last_position = editorData.mount.position
    last_forwardDirection = editorData.mount.forwardDirection
    last_facing = editorData.mount.facing
    local nextPos = startPort:StartPos()

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
    if not editorData.editorNodes then return end
    if #editorData.editorNodes < 2 then return end

    local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
    for _, value in ipairs(arrows) do vfxRoot:detachChild(value) end
    arrows = {}

    local routeId = RouteId:new(service.class, editorData.start, editorData.destination)
    local mountId = service:ResolveMountId(routeId)
    log:debug("[%s] Tracing %s > %s", mountId, editorData.start, editorData.destination)
    local mountData = interop.getVehicleStaticData(mountId)
    if not mountData then return end
    local startPort = service:GetPort(editorData.start, mountId)
    if not startPort then return end
    local destinationPort = service:GetPort(editorData.destination, mountId)
    if not destinationPort then return end

    -- create mount
    editorData.mount = elib.createMount(startPort, mountId, mountData.offset)

    -- trace port
    mountData.current_turnspeed = mountData.turnspeed * 1.5
    mountData.current_speed = mountData.speed * -1
    calculateLeavePort(mountData, startPort)

    -- trace route
    mountData.current_turnspeed = mountData.turnspeed
    mountData.current_speed = mountData.speed
    calculatePositions(mountData)

    -- validation

    -- check if the last position is near the last marker
    local lastMarker = editorData.editorNodes[#editorData.editorNodes]
    local lastPos = editorData.mount.position
    local distance = lastPos:distance(lastMarker.translation)
    log:debug("Last position is %d from the last marker", distance)
    if distance > 200 then
        log:warn("!!! Last position is too far from the last marker: %d", distance)
        tes3.messageBox("!!! Last position is too far from the last marker: %d", distance)
    end

    -- check if the last orientation does not have a big difference
    local lastOrientation = editorData.mount.orientation
    local destinationPortOrientation = lib.radvec(destinationPort:EndRot())
    local diff = lastOrientation.z - destinationPortOrientation.z
    log:debug("Last orientation is %d from the last marker", diff)
    if diff > 0.1 then
        log:warn("!!! Last orientation is too far from the last marker: %d", diff)
        tes3.messageBox("!!! Last orientation is too far from the last marker: %d", diff)
    end

    -- check if the start and destination ports are in the correct cells
    local startCell = tes3.getCell({ id = editorData.start }) ---@type tes3cell
    local isPointInCell = startCell:isPointInCell(startPort:StartPos().x, startPort:StartPos().y)
    if not isPointInCell then
        local portCell = tes3.getCell({ position = startPort:StartPos() })
        if portCell then
            log:warn("!!! Start port '%s' cell mismatch: '%s'", editorData.start, portCell.id)
            tes3.messageBox("!!! Start port '%s' cell mismatch: '%s'", editorData.start, portCell.id)
        else
            log:warn("!!! Could not find destination port cell")
        end
    end


    local destinationCell = tes3.getCell({ id = editorData.destination }) ---@type tes3cell
    isPointInCell = destinationCell:isPointInCell(destinationPort:EndPos().x, destinationPort:EndPos().y)
    if not isPointInCell then
        local portCell = tes3.getCell({ position = destinationPort:EndPos() })
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

---@param startPort PortData?
---@param destinationPort PortData?
local function renderAdditionalMarkers(startPort, destinationPort)
    local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
    if not portMarkerMesh then return nil end

    -- -- render start maneuvre
    if startPort then
        local child = portMarkerMesh:clone()
        child.translation = startPort:StartPos()
        local m = tes3matrix33.new()
        local x = math.rad(startPort:StartRot().x)
        local y = math.rad(startPort:StartRot().y)
        local z = math.rad(startPort:StartRot().z)
        m:fromEulerXYZ(x, y, z)
        child.rotation = m
        child.appCulled = false
        vfxRoot:attachChild(child)
        tes3.worldController.vfxManager.worldVFXRoot:update()
    end
end

---@param start string
---@param destination string
local function traceRouteNew(start, destination)
    if not editorData then return nil end

    editorData.start = start
    editorData.destination = destination
    editorData.mount = nil
    editorData.editorNodes = nil

    local service = editorData.service

    local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
    for _, value in ipairs(arrows) do vfxRoot:detachChild(value) end
    arrows = {}

    local routeId = RouteId:new(editorData.service.class, editorData.start, editorData.destination)
    local mountId = service:ResolveMountId(routeId)
    log:debug("[%s] Tracing %s > %s", mountId, editorData.start, editorData.destination)
    local mountData = interop.getVehicleStaticData(mountId)
    if not mountData then return end
    local startPort = service:GetPort(editorData.start, mountId)
    if not startPort then return end
    local destinationPort = service:GetPort(editorData.destination, mountId)
    if not destinationPort then return end

    -- create mount
    editorData.mount = elib.createMount(startPort, mountId, mountData.offset)

    -- trace port
    mountData.current_turnspeed = mountData.turnspeed * 1.5
    mountData.current_speed = mountData.speed * -1
    calculateLeavePort(mountData, startPort)

    -- trace route
    mountData.current_turnspeed = mountData.turnspeed
    mountData.current_speed = mountData.speed
    calculatePositionsNew(mountData)

    -- cleanup
    editorData.mount:delete()
    editorData.mount = nil

    -- vfx
    for _, child in ipairs(arrows) do
        vfxRoot:attachChild(child)
    end

    vfxRoot:update()
end

local function renderMarkers()
    if not editorData then return nil end
    if not editorMarkerMesh then return nil end
    if not portMarkerMesh then return nil end

    editorData.editorNodes = {}

    local routeId = RouteId:new(editorData.service.class, editorData.start, editorData.destination)
    local mountId = editorData.service:ResolveMountId(routeId)
    local startPort = editorData.service:GetPort(editorData.start, mountId)
    local destinationPort = editorData.service:GetPort(editorData.destination, mountId)

    -- add markers
    local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
    local spline = splines[routeId:ToString()]
    for idx, v in ipairs(spline) do
        local child = editorMarkerMesh:clone()

        -- first and last marker are ports with fixed markers
        if idx == 1 or idx == #spline then
            child = portMarkerMesh:clone()

            -- start port
            if idx == 1 and startPort then
                type = EMarkerType.Port
                local m = tes3matrix33.new()

                local x = math.rad(startPort:StartRot().x)
                local y = math.rad(startPort:StartRot().y)
                local z = math.rad(startPort:StartRot().z)

                -- start from override instead
                if startPort:HasStartRot() then
                    type = EMarkerType.PortStart
                end

                m:fromEulerXYZ(x, y, z)
                child.rotation = m
            end

            -- destination port
            if idx == #spline and destinationPort then
                type = EMarkerType.Port
                local m = tes3matrix33.new()

                local x = math.rad(destinationPort:EndRot().x)
                local y = math.rad(destinationPort:EndRot().y)
                local z = math.rad(destinationPort:EndRot().z)

                m:fromEulerXYZ(x, y, z)
                child.rotation = m
            end
        end

        child.translation = tes3vector3.new(v.x, v.y, v.z)
        child.appCulled = false

        vfxRoot:attachChild(child)

        editorData.editorNodes[idx] = child
    end

    updateMarkers()

    renderAdditionalMarkers(startPort, destinationPort)

    if config.traceOnSave then
        traceRoute(editorData.service)
    end
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

    for routeIdString, route in pairs(service.routes) do
        local spline = splines[routeIdString]
        if spline then
            -- render points
            editorData = {
                service = service,
                destination = route.id.destination,
                start = route.id.start,
            }
            renderMarkers()

            -- simple line between the points
            for i = 1, #spline - 1 do
                local from = spline[i]
                local to = spline[i + 1]

                local id = string.format("rf_line_%s_%d", route.id, i)
                elib.createLine(id, from, to)
            end
        end
    end

    editorData = nil

    vfxRoot:update()
end

---@param service ServiceData
local function traceAllSegments(service)
    if not arrow then return end
    if not nodeMarkerMesh then return end
    if not editorMarkerMesh then return end
    if not portMarkerMesh then return end

    -- reset all
    arrows = {}
    editorData = {
        service = service,
        editorMarkers = {},
        currentMarker = nil
    }
    local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
    vfxRoot:detachAllChildren()

    -- get all segment connections and internal nodes
    for _, route in pairs(service.routes) do
        log:trace("Tracing route '%s'", route.id)
        -- for each route get the segments
        for n, segment in ipairs(route:GetSegmentsResolved(service)) do
            log:trace("\tTracing segment #%d '%s'", n, segment.id)
            -- routes
            for routeIdx = 1, 2, 1 do
                local spline = segment:GetRoute(routeIdx)
                if spline then
                    for i = 1, #spline do
                        local from = spline[i]

                        local node = nodeMarkerMesh:clone()
                        node.translation = from
                        node.appCulled = false

                        ---@type SPreviewMarker
                        local marker = {
                            node = node,
                            type = EMarkerType.RouteConnection,
                            segmentId = segment.id,
                            routeId = routeIdx,
                            idx = i
                        }

                        -- end connectiom
                        if i == #spline then
                            -- end, do nothing
                        elseif i == 1 then
                            local to = spline[i + 1]
                            elib.createLine(string.format("rf_line_%s_%d_%d", segment.id, routeIdx, i), from, to)
                        else
                            local to = spline[i + 1]
                            elib.createLine(string.format("rf_line_%s_%d_%d", segment.id, routeIdx, i), from, to)

                            node.scale = 0.5
                            marker.type = EMarkerType.Route
                        end

                        editorData.editorMarkers[#editorData.editorMarkers + 1] = marker
                    end
                end
            end
        end
    end

    -- get ports
    for key, sport in pairs(service.ports) do
        -- TODO just get the first one
        local port = sport.data[table.keys(sport.data)[1]]

        do
            local child = portMarkerMesh:clone()
            child.translation = port:GetPosition()
            local m = tes3matrix33.new()
            local x = math.rad(port:GetRot().x)
            local y = math.rad(port:GetRot().y)
            local z = math.rad(port:GetRot().z)
            m:fromEulerXYZ(x, y, z)
            child.rotation = m
            child.appCulled = false

            ---@type SPreviewMarker
            local marker = {
                node = child,
                type = EMarkerType.Port
            }
            editorData.editorMarkers[#editorData.editorMarkers + 1] = marker
        end


        if port:HasStart() then
            local child = portMarkerMesh:clone()
            child.translation = port:StartPos()
            local m = tes3matrix33.new()
            local x = math.rad(port:StartRot().x)
            local y = math.rad(port:StartRot().y)
            local z = math.rad(port:StartRot().z)
            m:fromEulerXYZ(x, y, z)
            child.rotation = m
            child.appCulled = false

            ---@type SPreviewMarker
            local marker = {
                node = child,
                type = EMarkerType.PortStart
            }
            editorData.editorMarkers[#editorData.editorMarkers + 1] = marker
        end
    end

    -- render nodes
    for _, node in ipairs(editorData.editorMarkers) do
        vfxRoot:attachChild(node.node)
    end

    vfxRoot:update()
end

---@param segment SSegment
local function saveSegment(service, segment)
    local filename = string.format("%s.toml", segment.id)
    local segmentsPath = string.format("%s\\data\\%s\\segments\\%s", lib.fullmodpath, service.class, filename)

    local route1 = nil
    if segment:GetRoute1() then
        route1 = PositionRecord.ToListInt(segment:GetRoute1())
    end

    local route2 = nil
    if segment:GetRoute2() then
        route2 = PositionRecord.ToListInt(segment:GetRoute2())
    end

    ---@type SSegmentDto
    local dto = {
        id = segment.id,
        route1 = route1,
        route2 = route2,
    }
    toml.saveFile(segmentsPath, dto)
end

--#endregion

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// UI

function this.createEditWindow()
    -- Return if window is already open
    if (tes3ui.findMenu(editMenuId) ~= nil) then return end

    Reload()

    -- load services
    local services = GRoutesManager.GetServices()
    if not services then return end

    -- get current service
    if not currentServiceName then
        currentServiceName = table.keys(services)[1]
    end
    if editorData then currentServiceName = editorData.service.class end
    local service = services[currentServiceName]
    if not service then return end

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

    -- list all ports
    if IsPortMode() then
        for _, portName in ipairs(service:GetPorts()) do
            -- filter
            local filter = filter_text:lower()
            if filter_text ~= "" then
                if (not string.find(portName:lower(), filter)) then
                    goto continue
                end
            end

            local portCount = table.size(service.ports[portName].data)

            local button = pane:createButton {
                id = "button_port" .. portName,
                text = portName .. " (" .. portCount .. ")"
            }
            button:register(tes3.uiEvent.mouseClick, function()
                -- teleport to port
                local portData = service:GetPort(portName, service.mount)
                if portData then
                    tes3.positionCell({
                        reference = tes3.mobilePlayer,
                        position  = portData:EndPos()
                    })
                else
                    elib.teleportToCell(portName)
                end
            end)

            ::continue::
        end
    end

    -- list all segments
    if IsSegmentsMode() then
        local serviceDestinations = destinations[currentServiceName]
        for start, routeDestinations in pairs(serviceDestinations) do
            for _, destination in ipairs(routeDestinations) do
                -- check if route exists
                local routeId = RouteId:new(service.class, start, destination)
                local route = service:GetRoute(routeId)
                if not route then
                    goto continue
                end

                -- filter
                local filter = filter_text:lower()
                if filter_text ~= "" then
                    if (not string.find(start:lower(), filter) and not string.find(destination:lower(), filter)) then
                        goto continue
                    end
                end

                local text = start .. " - " .. destination
                local button = pane:createButton {
                    id = "button_sspline" .. text,
                    text = text
                }
                button:register(tes3.uiEvent.mouseClick, function()
                    if not editorData then
                        traceAllSegments(service)
                    end

                    traceRouteNew(start, destination)
                end)

                ::continue::
            end
        end
    end

    -- list all routes
    if IsRouteMode() then
        local serviceDestinations = destinations[currentServiceName]
        for start, routeDestinations in pairs(serviceDestinations) do
            for _, destination in ipairs(routeDestinations) do
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
                    ---@type SEditorData
                    editorData = {
                        service = service,
                        start = start,
                        destination = destination,
                        mount = nil,
                        editorNodes = nil,
                        editorMarkers = nil,
                        currentMarker = nil
                    }

                    local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
                    vfxRoot:detachAllChildren()

                    renderMarkers()
                end)

                ::continue::
            end
        end
    end

    pane:getContentElement():sortChildren(function(a, b)
        return a.text < b.text
    end)

    -- additional
    if IsRouteMode() and editorData then
        -- display pins
        local block = menu:createBlock {}
        block.widthProportional = 1.0 -- width is 100% parent width
        block.autoHeight = true

        if editorData.pin1 then
            block:createLabel { text = string.format("Pin 1: %s", editorData.pin1) }
        end

        if editorData.pin2 then
            block:createLabel { text = string.format("Pin 2: %s", editorData.pin2) }
        end
    end

    -- buttons
    local button_block = menu:createBlock {}
    button_block.widthProportional = 1.0 -- width is 100% parent width
    button_block.autoHeight = true
    button_block.childAlignX = 1.0       -- right content alignment


    -- Switch service
    local button_service = button_block:createButton {
        id = editMenuRoutesId,
        text = currentServiceName
    }
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

    if IsRouteMode() or IsSegmentsMode() then
        -- Teleport Start
        local button_teleport = button_block:createButton {
            id = editMenuTeleportId,
            text = "Start"
        }
        button_teleport:register(tes3.uiEvent.mouseClick, function()
            if not editorData then return end
            if not editorData.editorNodes then return end

            local m = tes3ui.findMenu(editMenuId)
            if (m) then
                if #editorData.editorNodes > 1 then
                    tes3.positionCell({
                        reference = tes3.mobilePlayer,
                        position = editorData.editorNodes[1].translation
                    })

                    tes3ui.leaveMenuMode()
                    m:destroy()
                end
            end
        end)

        -- Teleport End
        local button_teleportEnd = button_block:createButton {
            id = editMenuTeleportEndId,
            text = "End"
        }
        button_teleportEnd:register(tes3.uiEvent.mouseClick, function()
            if not editorData then return end
            if not editorData.editorNodes then return end

            local m = tes3ui.findMenu(editMenuId)
            if (m) then
                if #editorData.editorNodes > 1 then
                    tes3.positionCell({
                        reference = tes3.mobilePlayer,
                        position = editorData.editorNodes[#editorData.editorNodes].translation
                    })

                    tes3ui.leaveMenuMode()
                    m:destroy()
                end
            end
        end)
    end

    if IsRouteMode() and editorData then
        --- save to file
        local button_save = button_block:createButton {
            id = editMenuSaveId,
            text = "Save"
        }
        button_save:register(tes3.uiEvent.mouseClick, function()
            local tempSpline = GetSplineDto()

            local current_editor_route = editorData.start .. "_" .. editorData.destination
            local localmodpath = "mods\\ImmersiveTravelEditor"
            local filename = string.format("%s\\%s\\%s", localmodpath, service.class, current_editor_route)
            json.savefile(filename, tempSpline)

            tes3.messageBox("saved spline: " .. current_editor_route)
        end)

        --- save to toml
        local button_dump = button_block:createButton {
            id = editMenuDumpId,
            text = "Dump Segment"
        }
        button_dump:register(tes3.uiEvent.mouseClick, function()
            -- pins
            local minPin = nil
            local maxPin = nil
            if editorData.pin1 and editorData.pin2 then
                minPin = math.min(editorData.pin1, editorData.pin2)
                maxPin = math.max(editorData.pin1, editorData.pin2)
            end


            local tempSpline = GetSplineDto()
            if tempSpline then
                -- construct segments
                local points = {} ---@type PositionRecord[]
                for index, point in ipairs(tempSpline) do
                    if minPin then
                        if index < minPin then
                            goto continue
                        end
                    end

                    if maxPin then
                        if index > maxPin then
                            goto continue
                        end
                    end

                    table.insert(points, point)

                    ::continue::
                end

                local current_editor_route = editorData.start .. "_" .. editorData.destination
                local localmodpath = "mods\\ImmersiveTravelEditor"
                local filename = string.format("%s\\%s\\%s", localmodpath, service.class, current_editor_route)
                local tfilename = "Data Files\\MWSE\\" .. filename .. ".toml"
                ---@type SSegmentDto
                local t = {
                    id = current_editor_route,
                    route1 = points
                }
                toml.saveFile(tfilename, t)

                tes3.messageBox("saved spline: " .. current_editor_route)
            end
        end)

        -- Display all splines and ports
        local button_all = button_block:createButton {
            id = editMenuAllId,
            text = "All"
        }
        button_all:register(tes3.uiEvent.mouseClick, function()
            local m = tes3ui.findMenu(editMenuId)
            if (m) then
                traceAll(service)
            end
        end)
    end

    -- Display all segments
    local button_segments = button_block:createButton {
        id = editMenuAllId,
        text = "Show"
    }
    button_segments:register(tes3.uiEvent.mouseClick, function()
        local m = tes3ui.findMenu(editMenuId)
        if (m) then
            traceAllSegments(service)
        end
    end)

    -- Leave Menu
    local button_exit = button_block:createButton {
        id = editMenuCancelId,
        text = "Exit"
    }
    button_exit:register(tes3.uiEvent.mouseClick, function()
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

---@return PositionRecord[]|nil
local function GetSplineDto()
    if not editorData then return nil end
    if not editorData.editorNodes then return nil end

    local tempSpline = {} ---@type PositionRecord[]
    for i, value in ipairs(editorData.editorNodes) do
        local t = value.translation

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

    return tempSpline
end

return this
