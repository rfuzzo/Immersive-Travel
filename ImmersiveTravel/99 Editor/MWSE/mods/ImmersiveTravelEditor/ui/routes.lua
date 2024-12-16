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

    local service = GetEditorData().service

    for _, value in ipairs(elib.arrows) do elib.editorRoot:detachChild(value) end
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

    for _, child in ipairs(elib.arrows) do
        elib.editorRoot:attachChild(child)
    end

    elib.editorRoot:update()
end

---@param service ServiceData
local function showAllRouteSegments(service)
    -- reset all
    elib.arrows = {}
    elib.editorData = {
        service = service,
        editorMarkers = {},
        currentMarker = nil
    }
    elib.editorRoot:detachAllChildren()

    local routeId = RouteId:new(GetEditorData().service.class, GetEditorData().start, GetEditorData().destination)
    local mountId = service:ResolveMountId(routeId)

    -- get all segment connections and internal nodes
    for _, route in pairs(service.routes) do
        if route.id:ToString() == routeId:ToString() then
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

                                local sphere = elib.sphereMarkerMesh:clone()
                                sphere.translation = from
                                sphere.appCulled = false
                                sphere.scale = 0.5
                                marker.node = sphere

                                marker.type = EMarkerType.Route
                            end

                            GetEditorData().editorMarkers[#GetEditorData().editorMarkers + 1] = marker
                        end
                    end
                end
            end
        end
    end

    -- get ports
    for key, sport in pairs(service.ports) do
        local isStartPort = key == routeId.start
        local isEndPort = key == routeId.destination

        if isStartPort or isEndPort then
            -- get correct port for mount
            local port = sport.data[mountId]
            if port then
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
        end
    end

    -- render nodes
    for _, node in ipairs(GetEditorData().editorMarkers) do
        elib.editorRoot:attachChild(node.node)
    end

    elib.editorRoot:update()
end

--#endregion


-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// UI

function this.routesPanel(menu, reload)
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
    local label        = menu:createLabel { text = "Routes (" .. elib.currentServiceName .. ")" }
    label.borderBottom = 5

    -- local main_panel = menu:createThinBorder({ id = "main_panel" })

    -- get destinations
    local pane         = menu:createVerticalScrollPane { id = "sortedPane" }
    -- list all segments

    for _, route in pairs(service.routes) do
        local start = route.id.start
        local destination = route.id.destination

        -- filter
        local filter = filter_text:lower()
        if filter_text ~= "" then
            if (not string.find(start:lower(), filter) and not string.find(destination:lower(), filter)) then
                goto continue
            end
        end

        local text = start .. "-" .. destination
        local button = pane:createButton {
            id = "button_route_" .. text,
            text = text
        }
        button:register(tes3.uiEvent.mouseClick, function()
            if not GetEditorData() then
                showAllRouteSegments(service)
            end

            traceRouteNew(start, destination)
        end)

        ::continue::
    end
    pane:getContentElement():sortChildren(function(a, b)
        return a.text < b.text
    end)

    -- buttons
    local button_block = menu:createBlock {}
    button_block.widthProportional = 1.0 -- width is 100% parent width
    button_block.autoHeight = true

    -- Teleport Start
    local button_teleport = button_block:createButton {
        id = editMenuTeleportId,
        text = "Start"
    }
    button_teleport:register(tes3.uiEvent.mouseClick, function()
        if not GetEditorData() then return end
        if not GetEditorData().editorMarkers then return end

        if #GetEditorData().editorMarkers > 1 then
            tes3.positionCell({
                reference = tes3.mobilePlayer,
                position = GetEditorData().editorMarkers[1].node.translation
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
        if not GetEditorData().editorMarkers then return end

        if #GetEditorData().editorMarkers > 1 then
            tes3.positionCell({
                reference = tes3.mobilePlayer,
                position = GetEditorData().editorMarkers[#GetEditorData().editorMarkers].node.translation
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
        showAllRouteSegments(service)
    end)

    tes3ui.acquireTextInput(input)
end

function this.unregisterEvents()

end

return this
