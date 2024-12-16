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
local destinations          = {} ---@type table<string,table<string, string[]>> -- start -> destination[] per service
local splines               = {} ---@type table<string, tes3vector3[]> -- routeId -> spline

-- editor
local editmode              = false
local filter_text           = ""

-- usings
local EEditorMode           = elib.EEditorMode
local EMarkerType           = elib.EMarkerType
local log                   = elib.log

local function GetEditorData()
    return elib.editorSplineData
end

local CLICK_RADIUS = 200
local SNAP_RADIUS = 500

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// EDITOR

--#region editor

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

    -- -- if the first then get the second
    -- if final_idx == 1 then
    --     final_idx = 2
    -- end
    -- -- if the last then get the second last
    -- if final_idx == #GetEditorData().editorNodes then
    --     final_idx = #GetEditorData().editorNodes - 1
    -- end

    return final_idx
end


---@param startPort PortData?
---@param destinationPort PortData?
local function renderAdditionalMarkers(startPort, destinationPort)
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
        elib.debugRoot:attachChild(child)
        elib.debugRoot:update()
    end
end

-- ---@param mountData CVehicle
-- local function calculatePositions(mountData)
--     if not GetEditorData() then return end
--     if not GetEditorData().mount then return end
--     if not GetEditorData().editorNodes then return end

--     GetEditorData().last_position = GetEditorData().mount.position
--     GetEditorData().last_forwardDirection = GetEditorData().mount.forwardDirection
--     GetEditorData().last_facing = GetEditorData().mount.facing

--     local splineIndex = 2

--     for idx = 1, config.tracemax * 1000, 1 do
--         if splineIndex <= #GetEditorData().editorNodes then
--             local nextPos = GetEditorData().editorNodes[splineIndex].translation

--             local isBehind = elib.calculatePosition(mountData, nextPos)
--             if isBehind then
--                 splineIndex = splineIndex + 1
--             end
--         else
--             break
--         end
--     end
-- end

-- ---@param service ServiceData
-- local function traceRoute(service)
--     if not GetEditorData() then return end
--     if not GetEditorData().editorNodes then return end
--     if #GetEditorData().editorNodes < 2 then return end

--     for _, value in ipairs(elib.arrows) do elib.debugRoot:detachChild(value) end
--     elib.arrows = {}

--     local routeId = RouteId:new(service.class, GetEditorData().start, GetEditorData().destination)
--     local mountId = service:ResolveMountId(routeId)

--     log:debug("[%s] Tracing %s", mountId, routeId)

--     local mountData = interop.getVehicleStaticData(mountId)
--     if not mountData then return end
--     local startPort = service:GetPort(GetEditorData().start, mountId)
--     if not startPort then return end
--     local destinationPort = service:GetPort(GetEditorData().destination, mountId)
--     if not destinationPort then return end

--     -- create mount
--     GetEditorData().mount = elib.createMount(startPort, mountId, mountData.offset)

--     -- trace port
--     mountData.current_turnspeed = mountData.turnspeed * 1.5
--     mountData.current_speed = mountData.speed * -1
--     elib.calculateLeavePort(mountData, startPort)

--     -- trace route
--     mountData.current_turnspeed = mountData.turnspeed
--     mountData.current_speed = mountData.speed
--     calculatePositions(mountData)

--     -- validation

--     -- check if the last position is near the last marker
--     local lastMarker = GetEditorData().editorNodes[#GetEditorData().editorNodes]
--     local lastPos = GetEditorData().mount.position
--     local distance = lastPos:distance(lastMarker.translation)
--     log:debug("Last position is %d from the last marker", distance)
--     if distance > 200 then
--         log:warn("!!! Last position is too far from the last marker: %d", distance)
--         tes3.messageBox("!!! Last position is too far from the last marker: %d", distance)
--     end

--     -- check if the last orientation does not have a big difference
--     local lastOrientation = GetEditorData().mount.orientation
--     local destinationPortOrientation = lib.radvec(destinationPort:EndRot())
--     local diff = lastOrientation.z - destinationPortOrientation.z
--     log:debug("Last orientation is %d from the last marker", diff)
--     if diff > 0.1 then
--         log:warn("!!! Last orientation is too far from the last marker: %d", diff)
--         tes3.messageBox("!!! Last orientation is too far from the last marker: %d", diff)
--     end

--     -- check if the start and destination ports are in the correct cells
--     local startCell = tes3.getCell({ id = GetEditorData().start }) ---@type tes3cell
--     local isPointInCell = startCell:isPointInCell(startPort:StartPos().x, startPort:StartPos().y)
--     if not isPointInCell then
--         local portCell = tes3.getCell({ position = startPort:StartPos() })
--         if portCell then
--             log:warn("!!! Start port '%s' cell mismatch: '%s'", GetEditorData().start, portCell.id)
--             tes3.messageBox("!!! Start port '%s' cell mismatch: '%s'", GetEditorData().start, portCell.id)
--         else
--             log:warn("!!! Could not find destination port cell")
--         end
--     end


--     local destinationCell = tes3.getCell({ id = GetEditorData().destination }) ---@type tes3cell
--     isPointInCell = destinationCell:isPointInCell(destinationPort:EndPos().x, destinationPort:EndPos().y)
--     if not isPointInCell then
--         local portCell = tes3.getCell({ position = destinationPort:EndPos() })
--         if portCell then
--             log:warn("!!! Destination port '%s' cell mismatch: '%s'", GetEditorData().destination, portCell.id)
--             tes3.messageBox("!!! Destination port '%s' cell mismatch: '%s'", GetEditorData().destination,
--                 portCell.id)
--         else
--             log:warn("!!! Could not find destination port cell")
--         end
--     end

--     -- cleanup
--     GetEditorData().mount:delete()
--     GetEditorData().mount = nil

--     for _, child in ipairs(elib.arrows) do
--         elib.debugRoot:attachChild(child)
--     end

--     elib.debugRoot:update()
-- end

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

    elib.debugRoot:update()
end

local function renderMarkers()
    if not GetEditorData() then return nil end
    if not elib.editorMarkerMesh then return nil end
    if not elib.portMarkerMesh then return nil end

    GetEditorData().editorNodes = {}

    local routeId = RouteId:new(GetEditorData().service.class, GetEditorData().start, GetEditorData().destination)
    --local mountId = GetEditorData().service:ResolveMountId(routeId)

    -- add markers
    local spline = splines[routeId:ToString()]
    for idx, v in ipairs(spline) do
        local child = elib.editorMarkerMesh:clone()

        child.translation = tes3vector3.new(v.x, v.y, v.z)
        child.appCulled = false
        child.name = string.format("rf_marker_%d", idx)

        elib.debugRoot:attachChild(child)

        GetEditorData().editorNodes[idx] = child
    end

    updateMarkers()

    -- renderAdditionalMarkers(startPort, destinationPort)

    -- if config.traceOnSave then
    --     traceRoute(GetEditorData().service)
    -- end
end

---@param service ServiceData
local function traceAll(service)
    elib.arrows = {}

    elib.debugRoot:detachAllChildren()

    for routeIdString, route in pairs(service.routes) do
        local spline = splines[routeIdString]
        if spline then
            -- render points
            elib.editorSplineData = {
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

    elib.editorSplineData = nil

    elib.debugRoot:update()
end

--- load json spline from file
---@param start string
---@param destination string
---@param service ServiceData
---@return tes3vector3[]|nil
local function loadSpline(start, destination, service)
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

            return result
        else
            log:error("!!! failed to find file: %s", filePath)
            return nil
        end
    else
        log:error("!!! failed to find any file: " .. fileName)
    end
end

--- Load all route splines for a given service
---@param service ServiceData
---@return table<string, string[]>
local function loadRoutes(service)
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


local function ReloadSplines()
    log:debug("Reloading debug splines")

    local services = GRoutesManager.GetServices()
    if not services then return end

    splines = {}
    destinations = {}

    for serviceName, service in pairs(services) do
        local serviceDestinations = loadRoutes(service)
        destinations[serviceName] = serviceDestinations

        for start, currentDestinations in pairs(serviceDestinations) do
            for _, destination in ipairs(currentDestinations) do
                local spline = loadSpline(start, destination, service)
                if spline then
                    -- save route in memory
                    local routeId = RouteId:new(service.class, start, destination)
                    splines[routeId:ToString()] = spline

                    -- log:debug("\t\tAdding spline '%s'", routeId)
                else
                    log:warn("No spline found for %s -> %s", start, destination)
                end
            end
        end
    end
end

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

---@param service ServiceData?
local function dumpSegment(service)
    if not service then
        return
    end

    -- pins
    local minPin = nil
    local maxPin = nil
    if GetEditorData().pin1 and GetEditorData().pin2 then
        minPin = math.min(GetEditorData().pin1, GetEditorData().pin2)
        maxPin = math.max(GetEditorData().pin1, GetEditorData().pin2)
    end

    local startName = GetEditorData().start
    if minPin then
        local pin = GetEditorData().editorNodes[minPin]
        local cell = tes3.getCell({ position = pin.translation })
        startName = cell.id
    end
    local endName = GetEditorData().destination
    if maxPin then
        local pin = GetEditorData().editorNodes[maxPin]
        local cell = tes3.getCell({ position = pin.translation })
        endName = cell.id
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
        local localmodpath = "mods\\ImmersiveTravel"
        local filename = string.format("%s\\%s\\%s-%s", localmodpath, service.class, startName, endName)

        -- todo check if file exists
        local exists = tes3.getFileExists("MWSE\\" .. filename)
        local msg = "File exists: " .. tostring(exists)
        tes3.messageBox(msg)

        tes3ui.showMessageMenu {
            message = startName .. " - " .. endName,
            buttons = {
                {
                    text = msg, --"Save",
                    callback = function(e)
                        -- save
                        local tfilename = "Data Files\\MWSE\\" .. filename .. ".toml"
                        ---@type SSegmentDto
                        local t = {
                            id = startName .. " - " .. endName,
                            route1 = points
                        }
                        toml.saveFile(tfilename, t)

                        tes3.messageBox("saved spline: " .. current_editor_route)
                    end,
                },
            },
            cancels = true
        }
    end
end

--#endregion

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

    local from = tes3.getPlayerEyePosition() + tes3.getPlayerEyeVector() * 256
    local child = elib.editorMarkerMesh:clone()
    child.translation = from
    child.appCulled = false
    elib.debugRoot:attachChild(child)
    elib.debugRoot:update()

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

local function snapToSegment()
    if not GetEditorData() then return end
    if not GetEditorData().currentNode then return end
    if not elib.editorData then return end

    local idx = elib.getClosestMarkerIdx(false)
    if not idx then return end

    log:trace("Trying to snap to segment %d", idx)

    -- get distance
    local nodePos = GetEditorData().currentNode.translation
    local markerPos = elib.editorData.editorMarkers[idx].node.translation
    local distance = nodePos:distance(markerPos)

    -- snap if close enough
    if distance < SNAP_RADIUS then
        log:trace("Snapping to segment %d", idx)

        GetEditorData().currentNode.translation = markerPos
        GetEditorData().currentNode:update()
    end
end

---@param idx number?
local function editMarker(idx)
    if not GetEditorData() then return end
    if not editmode then
        if not idx then
            idx = getClosestNodeIdx()
        end
        if not idx then
            return
        end

        GetEditorData().currentNode = GetEditorData().editorNodes[idx]
    else
        snapToSegment()
        updateMarkers()
    end

    elib.debugRoot:update()
    editmode = not editmode
end

---@param idx number?
local function deleteMarker(idx)
    if not GetEditorData() then return end
    if not GetEditorData().editorNodes then return end

    if not idx then
        idx = getClosestNodeIdx()
    end
    if not idx then
        return
    end

    local instance = GetEditorData().editorNodes[idx]
    elib.debugRoot:detachChild(instance)
    elib.debugRoot:update()

    table.remove(GetEditorData().editorNodes, idx)

    updateMarkers()
    GetEditorData().currentNode = nil
end

---@param i number
local function unpin(i)
    if not GetEditorData() then return end
    if not GetEditorData().editorNodes then return end

    if i == 1 then
        if GetEditorData().pin1 then
            -- unpin
            local marker = GetEditorData().editorNodes[GetEditorData().pin1]
            marker.scale = 1
            marker:update()
            GetEditorData().pin1 = nil

            local root = tes3.worldController.vfxManager.worldVFXRoot
            local line = root:getObjectByName("rf_pin1")
            if line then
                root:detachChild(line)
            end
        end
    end

    if i == 2 then
        if GetEditorData().pin2 then
            -- unpin
            local marker = GetEditorData().editorNodes[GetEditorData().pin2]
            marker.scale = 1
            marker:update()
            GetEditorData().pin2 = nil

            local root = tes3.worldController.vfxManager.worldVFXRoot
            local line = root:getObjectByName("rf_pin2")
            if line then
                root:detachChild(line)
            end
        end
    end
end

---@param idx number?
local function togglePinMarker(idx)
    if not idx then return end
    if not GetEditorData() then return end
    if not GetEditorData().editorNodes then return end

    local marker = GetEditorData().editorNodes[idx]
    if marker then
        if idx == GetEditorData().pin1 then
            unpin(1)
        elseif idx == GetEditorData().pin2 then
            unpin(2)
        else
            if not GetEditorData().pin1 then
                GetEditorData().pin1 = idx
                marker.scale = 1.5
                marker:update()

                -- draw line pointing up
                local id = "rf_pin1"
                local from = marker.translation
                local to = from + tes3vector3.new(0, 0, 1024 * 8)
                elib.createLine(id, from, to)
            elseif not GetEditorData().pin2 then
                GetEditorData().pin2 = idx
                marker.scale = 1.5
                marker:update()

                local id = "rf_pin2"
                local from = marker.translation
                local to = from + tes3vector3.new(0, 0, 1024 * 8)
                elib.createLine(id, from, to)
            else
                -- already pinned, unpin first
                unpin(1)
            end
        end
    end
end

--- @param e keyDownEventData
local function editor_keyDownCallback(e)
    -- pin
    if GetEditorData() and e.keyCode == config.pinkeybind.keyCode then
        local idx = getClosestNodeIdx()
        togglePinMarker(idx)
    end

    -- trace
    -- if GetEditorData() and e.keyCode == config.tracekeybind.keyCode then
    --     traceRoute(GetEditorData().service)
    -- end

    -- insert
    if e.keyCode == config.placekeybind.keyCode then
        insertMarker()
    end

    -- marker edit mode
    if e.keyCode == config.editkeybind.keyCode then
        editMarker(nil)
    end

    -- delete
    if e.keyCode == config.deletekeybind.keyCode then
        deleteMarker(nil)
    end
end

---@param idx number
local function OnMarkerClick(idx)
    if not GetEditorData() then return end

    -- menu
    tes3ui.showMessageMenu {
        message = "marker " .. idx,
        buttons = {
            {
                text = "Edit",
                callback = function()
                    editMarker(idx)
                end
            },
            {
                text = "Delete",
                callback = function()
                    deleteMarker(idx)
                end
            },
            {
                text = "Pin",
                callback = function()
                    togglePinMarker(idx)
                end
            },
            {
                text = "Dump Segment",
                callback = function()
                    local service = GetEditorData().service
                    dumpSegment(service)
                end
            },

        },
        cancels = true
    }
end

--- @param e mouseButtonDownEventData
local function mouseButtonUpCallback(e)
    if tes3.menuMode() then
        return
    end

    if e.button ~= 0 then
        return
    end

    if not GetEditorData() then return end
    if not GetEditorData().editorNodes then return end

    -- find the marker under the mouse cursor
    local ray = tes3.rayTest({
        position = tes3.getPlayerEyePosition(),
        direction = tes3.getPlayerEyeVector(),
        root = elib.debugRoot,
        ignore = {}
    })

    if ray and ray.object then
        for idx, marker in ipairs(GetEditorData().editorNodes) do
            local d = marker.translation:distance(ray.intersection)
            if d < CLICK_RADIUS then
                OnMarkerClick(idx)
                return
            end
        end
    end
end

--#endregion

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// UI

function this.splinesPanel(menu, reload)
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

    ReloadSplines()

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
    local label = menu:createLabel { text = "Splines (" .. elib.currentServiceName .. ")" }
    label.borderBottom = 5

    -- get destinations
    local pane = menu:createVerticalScrollPane { id = "sortedPane" }

    -- list all routes
    local serviceDestinations = destinations[elib.currentServiceName]
    for start, routeDestinations in pairs(serviceDestinations) do
        for _, destination in ipairs(routeDestinations) do
            -- filter
            local filter = filter_text:lower()
            if filter_text ~= "" then
                if (not string.find(start:lower(), filter) and not string.find(destination:lower(), filter)) then
                    goto continue
                end
            end

            local text = start .. "-" .. destination
            local button = pane:createButton {
                id = "button_spline_" .. text,
                text = text
            }
            button:register(tes3.uiEvent.mouseClick, function()
                -- start editor
                ---@type SEditorData
                elib.editorSplineData = {
                    service = service,
                    start = start,
                    destination = destination,
                    mount = nil,
                    editorNodes = nil,
                    currentNode = nil
                }

                elib.debugRoot:detachAllChildren()

                renderMarkers()
            end)

            ::continue::
        end
    end

    pane:getContentElement():sortChildren(function(a, b)
        return a.text < b.text
    end)

    -- display pins
    local block = menu:createBlock {}
    block.widthProportional = 1.0 -- width is 100% parent width
    block.autoHeight = true

    if GetEditorData() and GetEditorData().pin1 then
        local pin1button = block:createButton {
            text = string.format("Pin 1: %s", GetEditorData().pin1)
        }
        pin1button:register(tes3.uiEvent.mouseClick, function()
            unpin(1)
        end)
    end

    if GetEditorData() and GetEditorData().pin2 then
        local pin2button = block:createButton {
            text = string.format("Pin 2: %s", GetEditorData().pin2)
        }
        pin2button:register(tes3.uiEvent.mouseClick, function()
            unpin(2)
        end)
    end

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
        dumpSegment(service)
    end)

    -- Display all splines and ports
    local button_all = button_block:createButton {
        id = editMenuAllId,
        text = "Show all segments"
    }
    button_all:register(tes3.uiEvent.mouseClick, function()
        local routesui = require("ImmersiveTravelEditor.ui.routes")
        routesui.showAllSegments(service)
    end)


    tes3ui.acquireTextInput(input)

    event.register(tes3.event.keyDown, editor_keyDownCallback)
    event.register(tes3.event.simulated, simulatedCallback)
    event.register(tes3.event.mouseButtonUp, mouseButtonUpCallback)
end

function this.unregisterEvents()
    event.unregister(tes3.event.keyDown, editor_keyDownCallback)
    event.unregister(tes3.event.simulated, simulatedCallback)
    event.unregister(tes3.event.mouseButtonUp, mouseButtonUpCallback)
end

return this
