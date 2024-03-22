local lib = require("ImmersiveTravel.lib")
local TrackingManager = require("ImmersiveTravel.CTrackingManager")
local CPlayerTravelManager = require("ImmersiveTravel.CPlayerTravelManager")

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// CONFIGURATION
local config = require("ImmersiveTravel.config")


-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// EVENTS

-- start tracking manager on mwse initialization
--- @param e initializedEventData
local function initializedCallback(e)
    lib.log:debug("Initializing ImmersiveTravel")

    TrackingManager.getInstance():StartTimer()
    lib.log:debug("TrackingManager started")
end
event.register(tes3.event.initialized, initializedCallback)

--- Cleanup on save load
--- @param e loadEventData
local function loadCallback(e)
    TrackingManager.getInstance():Cleanup()
end
event.register(tes3.event.load, loadCallback)

-- //////////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// UI FUNCTIONS //////////////////////////////////////////////////////////////////
--#region ui functions

local travelMenuId = tes3ui.registerID("it:travel_menu")
local travelMenuCancelId = tes3ui.registerID("it:travel_menu_cancel")

--- Start Travel window
-- Create window and layout. Called by onCommand.
---@param service ServiceData
---@param guide tes3reference
local function createTravelWindow(service, guide)
    -- Return if window is already open
    if (tes3ui.findMenu(travelMenuId) ~= nil) then return end
    -- Return if no destinations
    local destinations = service.routes[guide.cell.id]
    if destinations == nil then return end
    if #destinations == 0 then return end

    -- Create window and frame
    local menu = tes3ui.createMenu {
        id = travelMenuId,
        fixedFrame = false,
        dragFrame = true
    }
    menu.alpha = 1.0
    menu.text = tes3.player.cell.id
    menu.width = 350
    menu.height = 350

    -- Create layout
    local label = menu:createLabel { text = "Destinations" }
    label.borderBottom = 5

    local pane = menu:createVerticalScrollPane { id = "sortedPane" }
    for _key, name in ipairs(destinations) do
        local button = pane:createButton {
            id = "button_spline_" .. name,
            text = name
        }

        button:register(tes3.uiEvent.mouseClick, function()
            CPlayerTravelManager:getInstance():startTravel(tes3.player.cell.id, name, service, guide)
        end)
    end
    pane:getContentElement():sortChildren(function(a, b)
        return a.text < b.text
    end)
    pane.height = 400

    local button_block = menu:createBlock {}
    button_block.widthProportional = 1.0 -- width is 100% parent width
    button_block.autoHeight = true
    button_block.childAlignX = 1.0       -- right content alignment

    local button_cancel = button_block:createButton {
        id = travelMenuCancelId,
        text = "Cancel"
    }

    -- Events
    button_cancel:register(tes3.uiEvent.mouseClick, function()
        local m = tes3ui.findMenu(travelMenuId)
        if (m) then
            tes3ui.leaveMenuMode()
            m:destroy()
        end
    end)

    -- Final setup
    menu:updateLayout()
    tes3ui.enterMenuMode(travelMenuId)
end

---@param menu tes3uiElement
local function updateServiceButton(menu)
    timer.frame.delayOneFrame(function()
        if not menu then return end
        local serviceButton = menu:findChild("rf_id_travel_button")
        if not serviceButton then return end
        serviceButton.visible = true
        serviceButton.disabled = false
    end)
end

---@param menu tes3uiElement
---@param guide tes3reference
---@param service ServiceData
local function createTravelButton(menu, guide, service)
    local divider = menu:findChild("MenuDialog_divider")
    local topicsList = divider.parent
    local button = topicsList:createTextSelect({
        id = "rf_id_travel_button",
        text = "Take me to..."
    })
    button.widthProportional = 1.0
    button.visible = true
    button.disabled = false

    topicsList:reorderChildren(divider, button, 1)

    button:register("mouseClick", function()
        createTravelWindow(service, guide)
    end)
    menu:registerAfter("update", function() updateServiceButton(menu) end)
end

--#endregion

-- upon entering the dialog menu, create the travel menu
---@param e uiActivatedEventData
local function onMenuDialog(e)
    local menuDialog = e.element
    local mobileActor = menuDialog:getPropertyObject("PartHyperText_actor") ---@cast mobileActor tes3mobileActor
    if mobileActor.actorType == tes3.actorType.npc then
        local ref = mobileActor.reference
        local obj = ref.baseObject
        local npc = obj ---@cast obj tes3npc

        if not lib.offersTraveling(npc) then return end

        local services = lib.loadServices()
        if not services then return end

        -- get npc class
        local class = npc.class.id
        local service = table.get(services, class)
        for key, value in pairs(services) do
            if value.override_npc ~= nil then
                if lib.is_in(value.override_npc, npc.id) then
                    service = value
                    break
                end
            end
        end

        if service == nil then
            lib.log:debug("no service found for %s", npc.id)
            return
        end

        -- Return if no destinations
        lib.loadRoutes(service)
        local destinations = service.routes[ref.cell.id]
        if destinations == nil then return end
        if #destinations == 0 then return end

        lib.log:debug("createTravelButton for %s", npc.id)
        createTravelButton(menuDialog, ref, service)
        menuDialog:updateLayout()
    end
end
event.register("uiActivated", onMenuDialog, { filter = "MenuDialog" })

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// CONFIG
require("ImmersiveTravel.mcm")
