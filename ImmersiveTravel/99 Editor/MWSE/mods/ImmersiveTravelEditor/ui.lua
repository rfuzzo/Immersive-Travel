local lib                = require("ImmersiveTravel.lib")
local interop            = require("ImmersiveTravel.interop")
local GRoutesManager     = require("ImmersiveTravel.GRoutesManager")
local PositionRecord     = require("ImmersiveTravel.models.PositionRecord")
local RouteId            = require("ImmersiveTravel.models.RouteId")
local elib               = require("ImmersiveTravelEditor.lib")
local routesui           = require("ImmersiveTravelEditor.ui.routes")
local portsui            = require("ImmersiveTravelEditor.ui.ports")
local splinesui          = require("ImmersiveTravelEditor.ui.splines")

local EEditorMode        = elib.EEditorMode
local EMarkerType        = elib.EMarkerType
local log                = elib.log
local currentServiceName = elib.currentServiceName
local currentEditorMode  = elib.currentEditorMode

local this               = {}

local editMenuId         = tes3ui.registerID("it:MenuEdit")
local editMenuModeId     = tes3ui.registerID("it:MenuEdit_Mode")
local editMenuRoutesId   = tes3ui.registerID("it:MenuEdit_Routes")
local editMenuCancelId   = tes3ui.registerID("it:MenuEdit_Cancel")

local function IsPortMode()
    return currentEditorMode == EEditorMode.Ports
end

local function IsSplineMode()
    return currentEditorMode == EEditorMode.Routes
end

local function IsRoutesMode()
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

local function unregisterEvents()
    if IsSplineMode() then
        splinesui.unregisterEvents()
    elseif IsPortMode() then
        portsui.unregisterEvents()
    elseif IsRoutesMode() then
        routesui.unregisterEvents()
    end
end

function this.createEditWindow()
    -- Return if window is already open
    if (tes3ui.findMenu(editMenuId) ~= nil) then return end

    unregisterEvents()
    Reload()

    -- load services
    local services = GRoutesManager.GetServices()
    if not services then return end

    -- get current service
    if not currentServiceName then
        currentServiceName = table.keys(services)[1]
    end

    local editorData = elib.editorData
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
        if IsSplineMode() then
            menu.text = "Editor " .. editorData.start .. "_" ..
                editorData.destination
        end
    end

    -- main panel
    if IsRoutesMode() then
        routesui.routesPanel(menu, this.createEditWindow)
    elseif IsPortMode() then
        portsui.portsPanel(menu, this.createEditWindow)
    elseif IsSplineMode() then
        splinesui.splinesPanel(menu, this.createEditWindow)
    end

    -- bottom panel
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
            unregisterEvents()

            if IsSplineMode() then
                currentEditorMode = EEditorMode.Segments
            elseif IsPortMode() then
                currentEditorMode = EEditorMode.Routes
            elseif IsRoutesMode() then
                currentEditorMode = EEditorMode.Ports
            end

            elib.cleanup()
            m:destroy()
            this.createEditWindow()

            -- unregister all keydown events
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

            elib.cleanup()
            m:destroy()
            this.createEditWindow()
        end
    end)

    -- Leave Menu
    local button_exit = button_block:createButton {
        id = editMenuCancelId,
        text = "Exit"
    }
    button_exit:register(tes3.uiEvent.mouseClick, function()
        unregisterEvents()
        tes3ui.leaveMenuMode()
        menu:destroy()
    end)

    -- layout
    menu:updateLayout()
    tes3ui.enterMenuMode(editMenuId)
end

return this
