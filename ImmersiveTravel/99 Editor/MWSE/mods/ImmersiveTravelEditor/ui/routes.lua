local lib            = require("ImmersiveTravel.lib")
local interop        = require("ImmersiveTravel.interop")
local GRoutesManager = require("ImmersiveTravel.GRoutesManager")
local PositionRecord = require("ImmersiveTravel.models.PositionRecord")
local RouteId        = require("ImmersiveTravel.models.RouteId")
local elib           = require("ImmersiveTravelEditor.lib")

local config         = require("ImmersiveTravelEditor.config")
if not config then return end

local this                  = {}

local editMenuTeleportId    = tes3ui.registerID("it:MenuEdit_Teleport")
local editMenuTeleportEndId = tes3ui.registerID("it:MenuEdit_TeleportEnd")
local editMenuSearchId      = tes3ui.registerID("it:MenuEdit_Search")
local editMenuAllId         = tes3ui.registerID("it:MenuEdit_All")

-- editor
local editmode              = false
local filter_text           = ""

-- usings
local EMarkerType           = elib.EMarkerType
local log                   = elib.log

local function GetEditorData()
    return elib.editorData
end

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// EDITOR

--#region editor helpers

---@param ignoreConnections boolean?
---@return number?
local function getClosestMarkerIdx(ignoreConnections)
    if not GetEditorData() then return nil end
    if not GetEditorData().editorMarkers then return nil end

    -- get closest marker
    local final_idx = 0
    local last_distance = nil
    for index, marker in ipairs(GetEditorData().editorMarkers) do
        if ignoreConnections then
            if marker.type ~= EMarkerType.Route then
                goto continue
            end
        else
            if marker.type ~= EMarkerType.Route and marker.type ~= EMarkerType.RouteConnection then
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

---@param mountData CVehicle
local function calculatePositionsNew(mountData)
    if not GetEditorData() then return end
    if not GetEditorData().mount then return end
    if not GetEditorData().service then return end

    GetEditorData().last_position = GetEditorData().mount.position
    GetEditorData().last_forwardDirection = GetEditorData().mount.forwardDirection
    GetEditorData().last_facing = GetEditorData().mount.facing

    local routeId = RouteId:new(GetEditorData().service.class, GetEditorData().start, GetEditorData().destination)
    local route = GetEditorData().service:GetRoute(routeId)
    assert(route, "Route not found")

    -- reset indeces
    local segmentIndex = 1
    local currentSpline = route:GetSegmentRoute(GetEditorData().service, route.segments[segmentIndex])
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

            local nextSegment = GetEditorData().service:GetSegment(route.segments[segmentIndex])
            -- check if we are at the end of all segments
            if not nextSegment then
                log:trace("No more segments")
                break
            end
            log:trace("Moving to the next segment: '%s'", nextSegment.id)

            -- new route in the new segment
            currentSpline = route:GetSegmentRoute(GetEditorData().service, route.segments[segmentIndex])
            assert(currentSpline, "Route not found")

            splineIndex = 2 -- NOTE it needs to be 2 because we are already at the first position
        else
            -- move
            local nextPos = currentSpline[splineIndex]
            local isBehind = elib.calculatePosition(mountData, nextPos)
            if isBehind then
                splineIndex = splineIndex + 1
            end
        end
    end
end

---@param start string
---@param destination string
local function traceRouteNew(start, destination)
    if not GetEditorData() then return nil end

    GetEditorData().start = start
    GetEditorData().destination = destination
    GetEditorData().mount = nil
    GetEditorData().editorNodes = nil

    local service = GetEditorData().service

    local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
    for _, value in ipairs(elib.arrows) do vfxRoot:detachChild(value) end
    elib.arrows = {}

    local routeId = RouteId:new(GetEditorData().service.class, GetEditorData().start, GetEditorData().destination)
    local mountId = service:ResolveMountId(routeId)
    log:debug("[%s] Tracing %s > %s", mountId, GetEditorData().start, GetEditorData().destination)
    local mountData = interop.getVehicleStaticData(mountId)
    if not mountData then return end
    local startPort = service:GetPort(GetEditorData().start, mountId)
    if not startPort then return end
    local destinationPort = service:GetPort(GetEditorData().destination, mountId)
    if not destinationPort then return end

    -- create mount
    GetEditorData().mount = elib.createMount(startPort, mountId, mountData.offset)

    -- trace port
    mountData.current_turnspeed = mountData.turnspeed * 1.5
    mountData.current_speed = mountData.speed * -1
    elib.calculateLeavePort(mountData, startPort)

    -- trace route
    mountData.current_turnspeed = mountData.turnspeed
    mountData.current_speed = mountData.speed
    calculatePositionsNew(mountData)

    -- cleanup
    GetEditorData().mount:delete()
    GetEditorData().mount = nil

    -- vfx
    for _, child in ipairs(elib.arrows) do
        vfxRoot:attachChild(child)
    end

    vfxRoot:update()
end

---@param service ServiceData
local function traceAllSegments(service)
    -- reset all
    elib.arrows = {}
    elib.editorData = {
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

                        local node = elib.nodeMarkerMesh:clone()
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

                        GetEditorData().editorMarkers[#GetEditorData().editorMarkers + 1] = marker
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
            local child = elib.portMarkerMesh:clone()
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
            GetEditorData().editorMarkers[#GetEditorData().editorMarkers + 1] = marker
        end


        if port:HasStart() then
            local child = elib.portMarkerMesh:clone()
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
            GetEditorData().editorMarkers[#GetEditorData().editorMarkers + 1] = marker
        end
    end

    -- render nodes
    for _, node in ipairs(GetEditorData().editorMarkers) do
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

--#region route editor

--- @param e simulatedEventData
local function simulatedCallback(e)
    if not GetEditorData() then return end
    if editmode == false then return end

    local service = GetEditorData().service
    local from = tes3.getPlayerEyePosition() + tes3.getPlayerEyeVector() * 256
    if service.ground_offset == 0 then
        from.z = 0
    else
        local groundZ = elib.getGroundZ(from)
        if groundZ == nil then
            from.z = service.ground_offset
        else
            from.z = groundZ + service.ground_offset
        end
    end

    if not GetEditorData().currentMarker then return end

    GetEditorData().currentMarker.node.translation = from
    GetEditorData().currentMarker.node:update()
end

local function insertMarker()
    if not GetEditorData() then return end

    if not GetEditorData().editorMarkers then return end
    if not elib.nodeMarkerMesh then return end

    local idx = getClosestMarkerIdx(true)
    if idx then
        local instance = GetEditorData().editorMarkers[idx]

        -- get segment
        local segment = GetEditorData().service:GetSegment(instance.segmentId)
        assert(segment, "Segment not found")
        local route = segment:GetRoute(instance.routeId)
        assert(route, "Route not found")

        -- insert at index

        local from = tes3.getPlayerEyePosition() + tes3.getPlayerEyeVector() * 256
        table.insert(route, instance.idx, from)

        -- save affected segment to file
        saveSegment(GetEditorData().service, segment)

        -- render again
        traceAllSegments(GetEditorData().service)
        traceRouteNew(GetEditorData().start, GetEditorData().destination)

        editmode = true
    end
end

local function editMarker()
    if not GetEditorData() then return end

    if not editmode then
        -- start editing
        -- TODO get adjacent segments
        local idx = getClosestMarkerIdx(true)
        if not idx then
            return
        end

        debug.log(idx)

        GetEditorData().currentMarker = GetEditorData().editorMarkers[idx]
        tes3.messageBox("Marker index: " .. idx)
    else
        -- stop editing
        local currentMarker = GetEditorData().currentMarker
        if not currentMarker then return end

        local segment = GetEditorData().service:GetSegment(currentMarker.segmentId)
        assert(segment, "Segment not found")
        local route = segment:GetRoute(currentMarker.routeId)
        assert(route, "Route not found")

        -- edit in segment
        route[currentMarker.idx] = currentMarker.node.translation

        saveSegment(GetEditorData().service, segment)

        -- render all again
        traceAllSegments(GetEditorData().service)
        traceRouteNew(GetEditorData().start, GetEditorData().destination)
    end

    tes3.worldController.vfxManager.worldVFXRoot:update()
    editmode = not editmode
end

local function deleteMarker()
    if not GetEditorData() then return end

    if not GetEditorData().editorMarkers then return end

    local idx = getClosestMarkerIdx(true)
    if not idx then
        return
    end
    local instance = GetEditorData().editorMarkers[idx]

    -- get segment
    local segment = GetEditorData().service:GetSegment(instance.segmentId)
    assert(segment, "Segment not found")
    local route = segment:GetRoute(instance.routeId)
    assert(route, "Route not found")

    -- find position in the route
    table.remove(route, instance.idx)

    -- save affected segment to file
    saveSegment(GetEditorData().service, segment)

    -- render again
    traceAllSegments(GetEditorData().service)
    traceRouteNew(GetEditorData().start, GetEditorData().destination)

    GetEditorData().currentMarker = nil
end

--#endregion

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// EVENTS

--- @param e keyDownEventData
local function editor_keyDownCallback(e)
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

    -- -- pin
    -- if e.keyCode == config.pinkeybind.keyCode then
    --     pinMarker()
    -- end

    -- -- trace
    -- if e.keyCode == config.tracekeybind.keyCode then
    --     if GetEditorData() then traceRoute(GetEditorData().service) end
    -- end
end

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// UI

function this.routesPanel(menu, reload)
    event.unregister(tes3.event.keyDown, editor_keyDownCallback)
    event.unregister(tes3.event.simulated, simulatedCallback)

    -- load services
    local services = GRoutesManager.GetServices()
    if not services then return end

    -- get current service
    if not elib.currentServiceName then
        elib.currentServiceName = table.keys(services)[1]
    end
    if GetEditorData() then elib.currentServiceName = GetEditorData().service.class end
    local service = services[elib.currentServiceName]
    if not service then return end

    local input = menu:createTextInput { text = filter_text, id = editMenuSearchId }
    input.widget.lengthLimit = 31
    input.widget.eraseOnFirstKey = true
    input:register(tes3.uiEvent.keyEnter, function()
        local text = menu:findChild(editMenuSearchId).text
        filter_text = text
        elib.cleanup()
        menu:destroy()

        reload()
    end)

    -- Create layout
    local label = menu:createLabel { text = "Loaded routes (" .. elib.currentServiceName .. ")" }
    label.borderBottom = 5

    -- get destinations
    local pane = menu:createVerticalScrollPane { id = "sortedPane" }

    -- list all segments
    local serviceDestinations = elib.destinations[elib.currentServiceName]
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
                if not GetEditorData() then
                    traceAllSegments(service)
                end

                traceRouteNew(start, destination)
            end)

            ::continue::
        end
    end

    pane:getContentElement():sortChildren(function(a, b)
        return a.text < b.text
    end)

    -- buttons
    local button_block = menu:createBlock {}
    button_block.widthProportional = 1.0 -- width is 100% parent width
    button_block.autoHeight = true
    button_block.childAlignX = 1.0       -- right content alignment

    -- Teleport Start
    local button_teleport = button_block:createButton {
        id = editMenuTeleportId,
        text = "Start"
    }
    button_teleport:register(tes3.uiEvent.mouseClick, function()
        if not GetEditorData() then return end
        if not GetEditorData().editorNodes then return end

        if #GetEditorData().editorNodes > 1 then
            tes3.positionCell({
                reference = tes3.mobilePlayer,
                position = GetEditorData().editorNodes[1].translation
            })

            tes3ui.leaveMenuMode()
            menu:destroy()
        end
    end)

    -- Teleport End
    local button_teleportEnd = button_block:createButton {
        id = editMenuTeleportEndId,
        text = "End"
    }
    button_teleportEnd:register(tes3.uiEvent.mouseClick, function()
        if not GetEditorData() then return end
        if not GetEditorData().editorNodes then return end

        if #GetEditorData().editorNodes > 1 then
            tes3.positionCell({
                reference = tes3.mobilePlayer,
                position = GetEditorData().editorNodes[#GetEditorData().editorNodes].translation
            })

            tes3ui.leaveMenuMode()
            menu:destroy()
        end
    end)

    -- Display all segments
    local button_segments = button_block:createButton {
        id = editMenuAllId,
        text = "Show"
    }
    button_segments:register(tes3.uiEvent.mouseClick, function()
        traceAllSegments(service)
    end)

    tes3ui.acquireTextInput(input)

    event.register(tes3.event.keyDown, editor_keyDownCallback)
    event.register(tes3.event.simulated, simulatedCallback)
end

return this
