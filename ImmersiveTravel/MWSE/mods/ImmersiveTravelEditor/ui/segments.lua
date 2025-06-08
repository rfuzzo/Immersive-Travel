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
local log                   = mwse.Logger.new()

local function GetEditorData()
    return elib.editorData
end

local CLICK_RADIUS = 200

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// EVENTS

---@param segment SSegment
local function saveSegment(service, segment)
    local filename = string.format("%s.toml", segment.id)
    local segmentsPath = string.format("%s\\data\\%s\\segments\\%s", lib.fullmodpath, service.class, filename)

    local route1 = nil
    if segment.route1 then
        route1 = PositionRecord.ToListInt(segment.route1)
    end

    ---@type SSegmentDto
    local dto = {
        id = segment.id,
        route1 = route1,
    }
    toml.saveFile(segmentsPath, dto)
end

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

    local idx = elib.getClosestMarkerIdx(true)
    if idx then
        local instance = GetEditorData().editorMarkers[idx]

        -- get segment
        local segment = GetEditorData().service:GetSegment(instance.segmentId)
        assert(segment, "Segment not found")
        local route = segment:GetRoute()
        assert(route, "Route not found")

        -- insert at index

        local from = tes3.getPlayerEyePosition() + tes3.getPlayerEyeVector() * 256
        table.insert(route, instance.idx, from)

        -- save affected segment to file
        saveSegment(GetEditorData().service, segment)

        -- render again
        elib.showAllSegments(GetEditorData().service)

        editmode = true
    end
end

---@param idx number?
local function editMarker(idx)
    if not GetEditorData() then return end

    if not editmode then
        if not idx then
            idx = elib.getClosestMarkerIdx(false)
        end
        if not idx then
            return
        end

        GetEditorData().currentMarker = GetEditorData().editorMarkers[idx]
        GetEditorData().lastMarker = {
            position = GetEditorData().currentMarker.node.translation:copy(),
            type = GetEditorData().currentMarker.type,
            segmentId = GetEditorData().currentMarker.segmentId,
            idx = GetEditorData().currentMarker.idx
        }
    else
        -- stop editing
        local currentMarker = GetEditorData().currentMarker
        if not currentMarker then return end

        local lastMarker = GetEditorData().lastMarker
        if not lastMarker then return end

        -- update all segments
        for _, marker in ipairs(GetEditorData().editorMarkers) do
            if marker.node.translation:distance(lastMarker.position) == 0 then
                local segment = GetEditorData().service:GetSegment(marker.segmentId)
                assert(segment)
                segment:GetRoute()[marker.idx] = currentMarker.node.translation
                saveSegment(GetEditorData().service, segment)
            end
        end

        -- update current segment
        local segment = GetEditorData().service:GetSegment(currentMarker.segmentId)
        assert(segment)
        segment:GetRoute()[currentMarker.idx] = currentMarker.node.translation
        saveSegment(GetEditorData().service, segment)

        GetEditorData().lastMarker = nil

        -- render all again
        elib.showAllSegments(GetEditorData().service)
    end

    elib.editorRoot:update()
    editmode = not editmode
end

---@param idx number?
local function deleteMarker(idx)
    if not GetEditorData() then return end

    if not GetEditorData().editorMarkers then return end

    if not idx then
        -- TODO allow deleting connections?
        idx = elib.getClosestMarkerIdx(true)
    end
    if not idx then
        return
    end
    local instance = GetEditorData().editorMarkers[idx]

    -- get segment
    local segment = GetEditorData().service:GetSegment(instance.segmentId)
    assert(segment, "Segment not found")
    local route = segment:GetRoute()
    assert(route, "Route not found")

    -- find position in the route
    table.remove(route, instance.idx)

    -- save affected segment to file
    saveSegment(GetEditorData().service, segment)

    -- render again
    elib.showAllSegments(GetEditorData().service)

    GetEditorData().currentMarker = nil
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
            }
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
    if not GetEditorData().editorMarkers then return end

    -- find the marker under the mouse cursor
    local ray = tes3.rayTest({
        position = tes3.getPlayerEyePosition(),
        direction = tes3.getPlayerEyeVector(),
        root = elib.editorRoot,
        ignore = {}
    })

    if ray and ray.object then
        for idx, marker in ipairs(GetEditorData().editorMarkers) do
            local d = marker.node.translation:distance(ray.intersection)
            if d < CLICK_RADIUS then
                OnMarkerClick(idx)
                return
            end
        end
    end
end

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
end

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// UI

function this.segmentsPanel(menu, reload)
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
    local label        = menu:createLabel { text = "Segments (" .. elib.currentServiceName .. ")" }
    label.borderBottom = 5

    -- get destinations
    local pane         = menu:createVerticalScrollPane { id = "sortedPane" }
    -- list all segments

    for _, segment in pairs(service.segments) do
        local name = segment.id
        assert(name)

        -- filter
        local filter = filter_text:lower()
        if filter_text ~= "" then
            if (not string.find(name:lower(), filter)) then
                goto continue
            end
        end

        local button = pane:createButton {
            id = "button_segment_" .. name,
            text = name
        }
        button:register(tes3.uiEvent.mouseClick, function()
            if not GetEditorData() then
                elib.showAllSegments(service)
            end
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
        elib.showAllSegments(service)
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
