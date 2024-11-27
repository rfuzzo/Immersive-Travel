local elib     = require("ImmersiveTravelEditor.lib")
local ui       = require("ImmersiveTravelEditor.ui")
local routesui = require("ImmersiveTravelEditor.ui.routes")

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// CONFIGURATION
local config   = require("ImmersiveTravelEditor.config")
if not config then return end

local EEditorMode = elib.EEditorMode
local EMarkerType = elib.EMarkerType
local log = elib.log

--[[
Current Usage (Debug)
- Open route editor 						... R-Ctrl
- move a marker 							... L-Ctrl
- delete a marker 							... Del
- exit edit mode 							... L-Ctrl
- add a marker								... >
- start traveling            		        ... <

--]]


-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// EVENTS

--- @param e simulatedEventData
local function simulatedCallback(e)
    if not editorData then return end
    if editmode == false then return end

    local service = editorData.service
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

    if IsSegmentsMode() then
        if not editorData.currentMarker then return end

        editorData.currentMarker.node.translation = from
        editorData.currentMarker.node:update()
    elseif IsRouteMode() then
        if not editorData.currentNode then return end

        editorData.currentNode.translation = from
        editorData.currentNode:update()
    end
end
event.register(tes3.event.simulated, simulatedCallback)

local function insertMarker()
    if not editorData then return end

    if IsSegmentsMode() then
        if not editorData.editorMarkers then return end
        if not nodeMarkerMesh then return end

        local idx = getClosestMarkerIdx(true)
        if idx then
            local instance = editorData.editorMarkers[idx]

            -- get segment
            local segment = editorData.service:GetSegment(instance.segmentId)
            assert(segment, "Segment not found")
            local route = segment:GetRoute(instance.routeId)
            assert(route, "Route not found")

            -- insert at index

            local from = tes3.getPlayerEyePosition() + tes3.getPlayerEyeVector() * 256
            table.insert(route, instance.idx, from)

            -- save affected segment to file
            saveSegment(editorData.service, segment)

            -- render again
            traceAllSegments(editorData.service)
            traceRouteNew(editorData.start, editorData.destination)

            editmode = true
        end
    elseif IsRouteMode() then
        if not editorData.editorNodes then return end
        if not editorMarkerMesh then return end

        local idx = getClosestNodeIdx()
        if not idx then
            return
        end

        -- new vfx node
        local from = tes3.getPlayerEyePosition() + tes3.getPlayerEyeVector() * 256
        local child = editorMarkerMesh:clone()
        child.translation = from
        child.appCulled = false
        local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
        vfxRoot:attachChild(child)
        vfxRoot:update()

        -- new index is +1 if not last idx, else last idx - 1
        local newIdx = idx
        if idx == #editorData.editorNodes then
            newIdx = idx - 1
        elseif idx == #editorData.editorNodes - 1 then
            newIdx = idx
        else
            newIdx = idx + 1
        end

        editorData.editorNodes[newIdx] = child

        editorData.currentNode = child
        editmode = true
    end
end

local function editMarker()
    if not editorData then return end

    if IsSegmentsMode() then
        if not editmode then
            -- start editing
            -- TODO get adjacent segments
            local idx = getClosestMarkerIdx(true)
            if not idx then
                return
            end

            debug.log(idx)

            editorData.currentMarker = editorData.editorMarkers[idx]
            tes3.messageBox("Marker index: " .. idx)
        else
            -- stop editing
            local currentMarker = editorData.currentMarker
            if not currentMarker then return end

            local segment = editorData.service:GetSegment(currentMarker.segmentId)
            assert(segment, "Segment not found")
            local route = segment:GetRoute(currentMarker.routeId)
            assert(route, "Route not found")

            -- edit in segment
            route[currentMarker.idx] = currentMarker.node.translation

            saveSegment(editorData.service, segment)

            -- render all again
            traceAllSegments(editorData.service)
            traceRouteNew(editorData.start, editorData.destination)
        end
    elseif IsRouteMode() then
        if not editmode then
            local idx = getClosestNodeIdx()
            if not idx then
                return
            end

            editorData.currentNode = editorData.editorNodes[idx]
            tes3.messageBox("Marker index: " .. idx)
        else
            updateMarkers()

            if config.traceOnSave then
                traceRoute(editorData.service)
            end
        end
    end

    tes3.worldController.vfxManager.worldVFXRoot:update()
    editmode = not editmode
end

local function pinMarker()
    if IsRouteMode() then
        if not editorData then return end
        if not editorData.editorNodes then return end

        local idx = getClosestMarkerIdx()
        local marker = editorData.editorNodes[idx]
        if marker then
            if marker == editorData.pin1 then
                marker.scale = 1
                marker:update()
                editorData.pin1 = nil
            elseif marker == editorData.pin2 then
                marker.scale = 1
                marker:update()
                editorData.pin2 = nil
            else
                if not editorData.pin1 then
                    editorData.pin1 = idx
                    marker.scale = 1.5
                    marker:update()
                elseif not editorData.pin2 then
                    editorData.pin2 = idx
                    marker.scale = 1.5
                    marker:update()
                end
            end
        end
    end
end

local function deleteMarker()
    if not editorData then return end

    if IsSegmentsMode() then
        if not editorData.editorMarkers then return end

        local idx = getClosestMarkerIdx(true)
        if not idx then
            return
        end
        local instance = editorData.editorMarkers[idx]

        -- get segment
        local segment = editorData.service:GetSegment(instance.segmentId)
        assert(segment, "Segment not found")
        local route = segment:GetRoute(instance.routeId)
        assert(route, "Route not found")

        -- find position in the route
        table.remove(route, instance.idx)

        -- save affected segment to file
        saveSegment(editorData.service, segment)

        -- render again
        traceAllSegments(editorData.service)
        traceRouteNew(editorData.start, editorData.destination)

        editorData.currentMarker = nil
    elseif IsRouteMode() then
        if not editorData.editorNodes then return end

        local idx = getClosestNodeIdx()
        if not idx then
            return
        end
        -- if the first then get the second
        if idx == 1 then
            idx = 2
        end
        -- if the last then get the second last
        if idx == #editorData.editorNodes then
            idx = #editorData.editorNodes - 1
        end

        updateMarkers()

        local instance = editorData.editorNodes[idx]
        local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
        vfxRoot:detachChild(instance)
        vfxRoot:update()

        table.remove(editorData.editorNodes, idx)

        if editorData and config.traceOnSave then
            traceRoute(editorData.service)
        end

        editorData.currentMarker = nil
    end
end

--- @param e keyDownEventData
local function editor_keyDownCallback(e)
    -- editor menu
    if e.keyCode == config.openkeybind.keyCode then
        ui.createEditWindow()
    end

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

    -- pin
    if e.keyCode == config.pinkeybind.keyCode then
        pinMarker()
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
    nodeMarkerMesh = tes3.loadMesh(nodeMarkerId)
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
