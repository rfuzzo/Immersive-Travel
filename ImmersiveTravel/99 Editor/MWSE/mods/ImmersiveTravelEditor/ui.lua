local lib                = require("ImmersiveTravel.lib")
local interop            = require("ImmersiveTravel.interop")
local GRoutesManager     = require("ImmersiveTravel.GRoutesManager")
local PositionRecord     = require("ImmersiveTravel.models.PositionRecord")
local RouteId            = require("ImmersiveTravel.models.RouteId")
local elib               = require("ImmersiveTravelEditor.lib")

local routesui           = require("ImmersiveTravelEditor.ui.routes")
local portsui            = require("ImmersiveTravelEditor.ui.ports")
local splinesui          = require("ImmersiveTravelEditor.ui.splines")
local segmentsui         = require("ImmersiveTravelEditor.ui.segments")

local EEditorMode        = elib.EEditorMode
local EMarkerType        = elib.EMarkerType
local log                = elib.log

local this               = {}

local editMenuId         = tes3ui.registerID("it:MenuEdit")
local editMenuRoutesId   = tes3ui.registerID("it:MenuEdit_Routes")
local editMenuSplinesId  = tes3ui.registerID("it:MenuEdit_Splines")
local editMenuPortsId    = tes3ui.registerID("it:MenuEdit_Ports")
local editMenuSegmentsId = tes3ui.registerID("it:MenuEdit_Segments")
local editMenuServicesId = tes3ui.registerID("it:MenuEdit_Services")
local editMenuCancelId   = tes3ui.registerID("it:MenuEdit_Cancel")

local function Reload()
    GRoutesManager.getInstance():Init()
end

local function unregisterEvents()
    splinesui.unregisterEvents()
    portsui.unregisterEvents()
    routesui.unregisterEvents()
    segmentsui.unregisterEvents()
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
    if not elib.currentServiceName then
        elib.currentServiceName = table.keys(services)[1]
    end

    local menuTitle = "Editor"
    if elib.IsRouteMode() then
        local editorData = elib.editorData
        if editorData then
            elib.currentServiceName = editorData.service.class
            menuTitle = "Editor " .. editorData.start .. "_" .. editorData.destination
        end
    end

    if elib.IsSplineMode() then
        local editorData = elib.editorSplineData
        if editorData then
            elib.currentServiceName = editorData.service.class
            menuTitle = "Editor " .. editorData.start .. "_" .. editorData.destination
        end
    end

    local service = services[elib.currentServiceName]
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
    menu.text = menuTitle

    -- tabsBlock
    local tab_block = menu:createBlock {}
    tab_block.widthProportional = 1.0 -- width is 100% parent width
    tab_block.autoHeight = true

    -- Switch mode
    local button_routes = tab_block:createButton {
        id = editMenuRoutesId,
        text = "Routes"
    }
    local button_splines = tab_block:createButton {
        id = editMenuSplinesId,
        text = "Splines"
    }
    local button_ports = tab_block:createButton {
        id = editMenuPortsId,
        text = "Ports"
    }
    local button_segments = tab_block:createButton {
        id = editMenuSegmentsId,
        text = "Segments"
    }
    button_routes:register(tes3.uiEvent.mouseClick, function()
        if not elib.IsRouteMode() then
            elib.currentEditorMode = EEditorMode.Routes

            elib.cleanup()
            menu:destroy()
            this.createEditWindow()
        end
    end)
    button_splines:register(tes3.uiEvent.mouseClick, function()
        if not elib.IsSplineMode() then
            elib.currentEditorMode = EEditorMode.Splines

            elib.cleanup()
            menu:destroy()
            this.createEditWindow()
        end
    end)
    button_ports:register(tes3.uiEvent.mouseClick, function()
        if not elib.IsPortMode() then
            elib.currentEditorMode = EEditorMode.Ports

            elib.cleanup()
            menu:destroy()
            this.createEditWindow()
        end
    end)
    button_segments:register(tes3.uiEvent.mouseClick, function()
        if not elib.IsSegmentMode() then
            elib.currentEditorMode = EEditorMode.Segments

            elib.cleanup()
            menu:destroy()
            this.createEditWindow()
        end
    end)

    -- main panel
    if elib.IsRouteMode() then
        routesui.routesPanel(menu, this.createEditWindow)
    elseif elib.IsPortMode() then
        portsui.portsPanel(menu, this.createEditWindow)
    elseif elib.IsSplineMode() then
        splinesui.splinesPanel(menu, this.createEditWindow)
    elseif elib.IsSegmentMode() then
        segmentsui.segmentsPanel(menu, this.createEditWindow)
    end

    -- bottom panel
    -- buttons
    local button_block = menu:createBlock {}
    button_block.widthProportional = 1.0 -- width is 100% parent width
    button_block.autoHeight = true
    button_block.childAlignX = 1.0       -- right content alignment

    -- Switch service
    local button_service = button_block:createButton {
        id = editMenuServicesId,
        text = elib.currentServiceName
    }
    button_service:register(tes3.uiEvent.mouseClick, function()
        local m = tes3ui.findMenu(editMenuId)
        if (m) then
            -- go to next
            local idx = table.find(table.keys(services), elib.currentServiceName)
            local nextIdx = idx + 1
            if nextIdx > #table.keys(services) then nextIdx = 1 end
            elib.currentServiceName = table.keys(services)[nextIdx]

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
        tes3ui.leaveMenuMode()
        menu:destroy()
    end)

    -- layout
    menu:updateLayout()
    tes3ui.enterMenuMode(editMenuId)
end

return this
