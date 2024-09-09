local lib                = require("ImmersiveTravel.lib")
local interop            = require("ImmersiveTravel.interop")
local GRoutesManager     = require("ImmersiveTravel.GRoutesManager")

local this               = {}

local travelMenuId       = tes3ui.registerID("it:travel_menu")
local travelMenuCancelId = tes3ui.registerID("it:travel_menu_cancel")

--- set up everything
---@param start string
---@param destination string
---@param service ServiceData
---@param guide tes3reference
local function StartTravel(start, destination, service, guide)
    -- checks
    if guide == nil then return end

    local m = tes3ui.findMenu("it:travel_menu")
    if not m then return end

    -- leave dialogue
    tes3ui.leaveMenuMode()
    m:destroy()

    local routeId = start .. "_" .. destination
    local currentSpline = GRoutesManager.getInstance():GetRoute(routeId)
    if currentSpline == nil then return end

    -- fade out
    tes3.fadeOut({ duration = 1 })

    -- fade back in
    timer.start({
        type = timer.simulate,
        iterations = 1,
        duration = 1,
        callback = (function()
            tes3.fadeIn({ duration = 1 })

            -- get spawn position
            local startPos = lib.vec(currentSpline[1])
            local nextPos = lib.vec(currentSpline[2])
            local orientation = nextPos - startPos
            orientation:normalize()
            local facing = math.atan2(orientation.x, orientation.y)

            -- vehicle id
            local mountId = lib.ResolveMountId(service, start, destination)

            -- create vehicle
            local vehicle = interop.createVehicle(mountId, startPos, orientation, facing)
            if not vehicle then
                return
            end

            vehicle:StartPlayerTravel(guide.baseObject.id, routeId)
        end)
    })
end

--- Start Travel window
-- Create window and layout. Called by onCommand.
---@param service ServiceData
---@param guide tes3reference
---@param npcMenu number
local function createTravelWindow(service, guide, npcMenu)
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
            StartTravel(tes3.player.cell.id, name, service, guide)
            local npc_menu = tes3ui.findMenu(npcMenu)
            if npc_menu then
                npc_menu:destroy()
            end
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
function this.createTravelButton(menu, guide, service)
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
        createTravelWindow(service, guide, menu.id)
    end)
    menu:registerAfter("update", function()
        updateServiceButton(menu)
    end)
end

return this
