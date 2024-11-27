local lib               = require("ImmersiveTravel.lib")
local interop           = require("ImmersiveTravel.interop")
local GRoutesManager    = require("ImmersiveTravel.GRoutesManager")
local PositionRecord    = require("ImmersiveTravel.models.PositionRecord")
local RouteId           = require("ImmersiveTravel.models.RouteId")
local elib              = require("ImmersiveTravelEditor.lib")

local EEditorMode       = elib.EEditorMode
local EMarkerType       = elib.EMarkerType
local log               = elib.log

local this              = {}

local editMenuId        = tes3ui.registerID("it:MenuEdit")

local currentEditorMode = EEditorMode.Segments ---@type EEditorMode


local function IsPortMode()
    return currentEditorMode == EEditorMode.Ports
end

local function IsRouteMode()
    return currentEditorMode == EEditorMode.Routes
end

local function IsSegmentsMode()
    return currentEditorMode == EEditorMode.Segments
end

local function Reload()
    GRoutesManager.getInstance():Init()

    log:debug("Reloading debug splines")
    local services = GRoutesManager.GetServices()
    if not services then return end

    elib.splines = {}
    elib.destinations = {}

    for serviceName, service in pairs(services) do
        local serviceDestinations = elib.loadRoutes(service)
        elib.destinations[serviceName] = serviceDestinations

        for start, currentDestinations in pairs(serviceDestinations) do
            for _, destination in ipairs(currentDestinations) do
                local spline = elib.loadSpline(start, destination, service)
                if spline then
                    -- save route in memory
                    local routeId = RouteId:new(service.class, start, destination)
                    elib.splines[routeId:ToString()] = spline

                    log:debug("\t\tAdding spline '%s'", routeId)
                else
                    log:warn("No spline found for %s -> %s", start, destination)
                end
            end
        end
    end
end

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

    -- Switch mode
    local button_mode = button_block:createButton {
        id = editMenuModeId,
        text = "Mode: " .. elib.ToString(currentEditorMode)
    }
    button_mode:register(tes3.uiEvent.mouseClick, function()
        local m = tes3ui.findMenu(editMenuId)
        if (m) then
            if IsRouteMode() then
                currentEditorMode = EEditorMode.Segments
            elseif IsPortMode() then
                currentEditorMode = EEditorMode.Routes
            elseif IsSegmentsMode() then
                currentEditorMode = EEditorMode.Ports
            end

            cleanup()
            m:destroy()
            createEditWindow()
        end
    end)

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

return this
