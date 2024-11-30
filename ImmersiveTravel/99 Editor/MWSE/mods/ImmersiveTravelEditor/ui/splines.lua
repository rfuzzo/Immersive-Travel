local lib            = require("ImmersiveTravel.lib")
local interop        = require("ImmersiveTravel.interop")
local GRoutesManager = require("ImmersiveTravel.GRoutesManager")
local PositionRecord = require("ImmersiveTravel.models.PositionRecord")
local RouteId        = require("ImmersiveTravel.models.RouteId")
local elib           = require("ImmersiveTravelEditor.lib")

local config         = require("ImmersiveTravelEditor.config")
if not config then return end

local this                  = {}

local editMenuTeleportId    = tes3ui.registerID("it:MenuSplines_Teleport")
local editMenuTeleportEndId = tes3ui.registerID("it:MenuSplines_TeleportEnd")
local editMenuSearchId      = tes3ui.registerID("it:MenuSplines_Search")
local editMenuAllId         = tes3ui.registerID("it:MenuSplines_All")
local editMenuSaveId        = tes3ui.registerID("it:MenuSplines_Save")
local editMenuDumpId        = tes3ui.registerID("it:MenuSplines_Dump")

-- preview
local preview               = nil ---@type SPreviewData | nil

-- editor
local editmode              = false
local filter_text           = ""

-- usings
local EEditorMode           = elib.EEditorMode
local EMarkerType           = elib.EMarkerType
local log                   = elib.log

local function GetEditorData()
    return elib.editorData
end

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// EDITOR

---@param ignoreConnections boolean?
---@return number?
local function getClosestNodeIdx(ignoreConnections)
    if not GetEditorData() then return nil end
    if not GetEditorData().editorNodes then return nil end

    -- get closest marker
    local final_idx = 0
    local last_distance = nil
    for index, marker in ipairs(GetEditorData().editorNodes) do
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
    if final_idx == #GetEditorData().editorNodes then
        final_idx = #GetEditorData().editorNodes - 1
    end


    return nil
end


---@param startPort PortData?
---@param destinationPort PortData?
local function renderAdditionalMarkers(startPort, destinationPort)
    local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
    if not elib.portMarkerMesh then return nil end

    -- -- render start maneuvre
    if startPort then
        local child = elib.portMarkerMesh:clone()
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

---@param mountData CVehicle
local function calculatePositions(mountData)
    if not GetEditorData() then return end
    if not GetEditorData().mount then return end
    if not GetEditorData().editorNodes then return end

    GetEditorData().last_position = GetEditorData().mount.position
    GetEditorData().last_forwardDirection = GetEditorData().mount.forwardDirection
    GetEditorData().last_facing = GetEditorData().mount.facing

    local splineIndex = 2

    for idx = 1, config.tracemax * 1000, 1 do
        if splineIndex <= #GetEditorData().editorNodes then
            local nextPos = GetEditorData().editorNodes[splineIndex].translation

            local isBehind = elib.calculatePosition(mountData, nextPos)
            if isBehind then
                splineIndex = splineIndex + 1
            end
        else
            break
        end
    end
end


---@param service ServiceData
local function traceRoute(service)
    if not GetEditorData() then return end
    if not GetEditorData().editorNodes then return end
    if #GetEditorData().editorNodes < 2 then return end

    local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
    for _, value in ipairs(elib.arrows) do vfxRoot:detachChild(value) end
    elib.arrows = {}

    local routeId = RouteId:new(service.class, GetEditorData().start, GetEditorData().destination)
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
    calculatePositions(mountData)

    -- validation

    -- check if the last position is near the last marker
    local lastMarker = GetEditorData().editorNodes[#GetEditorData().editorNodes]
    local lastPos = GetEditorData().mount.position
    local distance = lastPos:distance(lastMarker.translation)
    log:debug("Last position is %d from the last marker", distance)
    if distance > 200 then
        log:warn("!!! Last position is too far from the last marker: %d", distance)
        tes3.messageBox("!!! Last position is too far from the last marker: %d", distance)
    end

    -- check if the last orientation does not have a big difference
    local lastOrientation = GetEditorData().mount.orientation
    local destinationPortOrientation = lib.radvec(destinationPort:EndRot())
    local diff = lastOrientation.z - destinationPortOrientation.z
    log:debug("Last orientation is %d from the last marker", diff)
    if diff > 0.1 then
        log:warn("!!! Last orientation is too far from the last marker: %d", diff)
        tes3.messageBox("!!! Last orientation is too far from the last marker: %d", diff)
    end

    -- check if the start and destination ports are in the correct cells
    local startCell = tes3.getCell({ id = GetEditorData().start }) ---@type tes3cell
    local isPointInCell = startCell:isPointInCell(startPort:StartPos().x, startPort:StartPos().y)
    if not isPointInCell then
        local portCell = tes3.getCell({ position = startPort:StartPos() })
        if portCell then
            log:warn("!!! Start port '%s' cell mismatch: '%s'", GetEditorData().start, portCell.id)
            tes3.messageBox("!!! Start port '%s' cell mismatch: '%s'", GetEditorData().start, portCell.id)
        else
            log:warn("!!! Could not find destination port cell")
        end
    end


    local destinationCell = tes3.getCell({ id = GetEditorData().destination }) ---@type tes3cell
    isPointInCell = destinationCell:isPointInCell(destinationPort:EndPos().x, destinationPort:EndPos().y)
    if not isPointInCell then
        local portCell = tes3.getCell({ position = destinationPort:EndPos() })
        if portCell then
            log:warn("!!! Destination port '%s' cell mismatch: '%s'", GetEditorData().destination, portCell.id)
            tes3.messageBox("!!! Destination port '%s' cell mismatch: '%s'", GetEditorData().destination,
                portCell.id)
        else
            log:warn("!!! Could not find destination port cell")
        end
    end

    -- cleanup
    GetEditorData().mount:delete()
    GetEditorData().mount = nil

    -- vfx
    for _, child in ipairs(elib.arrows) do
        vfxRoot:attachChild(child)
    end

    vfxRoot:update()
end

local function updateMarkers()
    if not GetEditorData() then return end
    local editorNodes = GetEditorData().editorNodes
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

local function renderMarkers()
    if not GetEditorData() then return nil end
    if not elib.editorMarkerMesh then return nil end
    if not elib.portMarkerMesh then return nil end

    GetEditorData().editorNodes = {}

    local routeId = RouteId:new(GetEditorData().service.class, GetEditorData().start, GetEditorData().destination)
    local mountId = GetEditorData().service:ResolveMountId(routeId)
    local startPort = GetEditorData().service:GetPort(GetEditorData().start, mountId)
    local destinationPort = GetEditorData().service:GetPort(GetEditorData().destination, mountId)

    -- add markers
    local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
    local spline = elib.splines[routeId:ToString()]
    for idx, v in ipairs(spline) do
        local child = elib.editorMarkerMesh:clone()

        -- first and last marker are ports with fixed markers
        if idx == 1 or idx == #spline then
            child = elib.portMarkerMesh:clone()

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

        GetEditorData().editorNodes[idx] = child
    end

    updateMarkers()

    renderAdditionalMarkers(startPort, destinationPort)

    if config.traceOnSave then
        traceRoute(GetEditorData().service)
    end
end

---@param service ServiceData
local function traceAll(service)
    elib.arrows = {}

    local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
    vfxRoot:detachAllChildren()

    for routeIdString, route in pairs(service.routes) do
        local spline = elib.splines[routeIdString]
        if spline then
            -- render points
            elib.editorData = {
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

    elib.editorData = nil

    vfxRoot:update()
end

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// EVENTS

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

    if not GetEditorData().currentNode then return end

    GetEditorData().currentNode.translation = from
    GetEditorData().currentNode:update()
end

local function insertMarker()
    if not GetEditorData() then return end

    if not GetEditorData().editorNodes then return end
    if not elib.editorMarkerMesh then return end

    local idx = getClosestNodeIdx()
    if not idx then
        return
    end

    -- new vfx node
    local from = tes3.getPlayerEyePosition() + tes3.getPlayerEyeVector() * 256
    local child = elib.editorMarkerMesh:clone()
    child.translation = from
    child.appCulled = false
    local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
    vfxRoot:attachChild(child)
    vfxRoot:update()

    -- new index is +1 if not last idx, else last idx - 1
    local newIdx = idx
    if idx == #GetEditorData().editorNodes then
        newIdx = idx - 1
    elseif idx == #GetEditorData().editorNodes - 1 then
        newIdx = idx
    else
        newIdx = idx + 1
    end

    GetEditorData().editorNodes[newIdx] = child

    GetEditorData().currentNode = child
    editmode = true
end

local function editMarker()
    if not GetEditorData() then return end
    if not editmode then
        local idx = getClosestNodeIdx()
        if not idx then
            return
        end

        GetEditorData().currentNode = GetEditorData().editorNodes[idx]
        tes3.messageBox("Marker index: " .. idx)
    else
        updateMarkers()

        if config.traceOnSave then
            traceRoute(GetEditorData().service)
        end
    end

    tes3.worldController.vfxManager.worldVFXRoot:update()
    editmode = not editmode
end

local function pinMarker()
    if not GetEditorData() then return end
    if not GetEditorData().editorNodes then return end

    local idx = getClosestNodeIdx()
    local marker = GetEditorData().editorNodes[idx]
    if marker then
        if marker == GetEditorData().pin1 then
            marker.scale = 1
            marker:update()
            GetEditorData().pin1 = nil
        elseif marker == GetEditorData().pin2 then
            marker.scale = 1
            marker:update()
            GetEditorData().pin2 = nil
        else
            if not GetEditorData().pin1 then
                GetEditorData().pin1 = idx
                marker.scale = 1.5
                marker:update()
            elseif not GetEditorData().pin2 then
                GetEditorData().pin2 = idx
                marker.scale = 1.5
                marker:update()
            end
        end
    end
end

local function deleteMarker()
    if not GetEditorData() then return end


    if not GetEditorData().editorNodes then return end

    local idx = getClosestNodeIdx()
    if not idx then
        return
    end
    -- if the first then get the second
    if idx == 1 then
        idx = 2
    end
    -- if the last then get the second last
    if idx == #GetEditorData().editorNodes then
        idx = #GetEditorData().editorNodes - 1
    end

    updateMarkers()

    local instance = GetEditorData().editorNodes[idx]
    local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
    vfxRoot:detachChild(instance)
    vfxRoot:update()

    table.remove(GetEditorData().editorNodes, idx)

    if GetEditorData() and config.traceOnSave then
        traceRoute(GetEditorData().service)
    end

    GetEditorData().currentMarker = nil
end

--#endregion


---@return PositionRecord[]|nil
local function GetSplineDto()
    if not GetEditorData() then return nil end
    if not GetEditorData().editorNodes then return nil end

    local tempSpline = {} ---@type PositionRecord[]
    for i, value in ipairs(GetEditorData().editorNodes) do
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
-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// EVENTS

--- @param e keyDownEventData
local function editor_keyDownCallback(e)
    -- pin
    if e.keyCode == config.pinkeybind.keyCode then
        pinMarker()
    end

    -- trace
    if e.keyCode == config.tracekeybind.keyCode then
        if GetEditorData() then traceRoute(GetEditorData().service) end
    end
end

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// UI

function this.splinesPanel(menu, reload)
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

    -- list all routes
    local serviceDestinations = elib.destinations[elib.currentServiceName]
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
                elib.editorData = {
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

    pane:getContentElement():sortChildren(function(a, b)
        return a.text < b.text
    end)

    -- additional
    -- display pins
    local block = menu:createBlock {}
    block.widthProportional = 1.0 -- width is 100% parent width
    block.autoHeight = true

    if GetEditorData() and GetEditorData().pin1 then
        block:createLabel { text = string.format("Pin 1: %s", GetEditorData().pin1) }
    end

    if GetEditorData() and GetEditorData().pin2 then
        block:createLabel { text = string.format("Pin 2: %s", GetEditorData().pin2) }
    end


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

    --- save to file
    local button_save = button_block:createButton {
        id = editMenuSaveId,
        text = "Save"
    }
    button_save:register(tes3.uiEvent.mouseClick, function()
        local tempSpline = GetSplineDto()

        local current_editor_route = GetEditorData().start .. "_" .. GetEditorData().destination
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
        if GetEditorData().pin1 and GetEditorData().pin2 then
            minPin = math.min(GetEditorData().pin1, GetEditorData().pin2)
            maxPin = math.max(GetEditorData().pin1, GetEditorData().pin2)
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

            local current_editor_route = GetEditorData().start .. "_" .. GetEditorData().destination
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
        traceAll(service)
    end)


    tes3ui.acquireTextInput(input)

    event.register(tes3.event.keyDown, editor_keyDownCallback)
    event.register(tes3.event.simulated, simulatedCallback)
end

return this
