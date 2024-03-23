local lib = require("ImmersiveTravel.lib")
local interop = require("ImmersiveTravel.interop")
local log = lib.log

-- define the player travel manager class
---@class CPlayerTravelManager
---@field trackedVehicle CVehicle?
---@field npcMenu number?
---@field free_movement boolean
local CPlayerTravelManager = {
    trackedVehicle = nil,
    npcMenu = nil,
    free_movement = false
}

-- constructor
function CPlayerTravelManager:new()
    local newObj = {}
    self.__index = self
    setmetatable(newObj, self)
    return newObj
end

-- singleton instance
--- @type CPlayerTravelManager?
local travelManager = nil
--- @return CPlayerTravelManager
function CPlayerTravelManager.getInstance()
    if travelManager == nil then
        travelManager = CPlayerTravelManager:new()
    end
    return travelManager
end

-- //////////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// EVENTS ACTIVE WHILE TRAVELLING (DISABLED ON DESTINATION REACHED) //////////////
--#region events

--- @param e cellChangedEventData
local function cellChangedCallback(e)
    if not e.cell.isInterior then
        local cellKey = string.format("(%s, %s)", e.cell.gridX, e.cell.gridY)

        -- check if quips contain key
        if interop.quips[cellKey] then
            local quip = interop.quips[cellKey]
            tes3.messageBox(quip)
        end
    end
end

-- Disable damage on select characters in travel, thanks Null
--- @param e damageEventData
local function damageInvincibilityGate(e)
    if (e.reference.data and e.reference.data.rfuzzo_invincible) then
        return false
    end
end

--- Disable combat while in travel
--- @param e combatStartEventData
local function forcedPacifism(e)
    return false
end


--- Disable all activate while in travel
--- @param e activateEventData
local function activateCallback(e)
    if (e.activator ~= tes3.player) then return end

    local mount = CPlayerTravelManager.getInstance().trackedVehicle
    if not mount then return end

    if e.target.id == mount.guideSlot.handle:getObject().id and
        CPlayerTravelManager.getInstance().free_movement then
        -- register player in slot
        tes3ui.showMessageMenu {
            message = "Do you want to sit down?",
            buttons = {
                {
                    text = "Yes",
                    callback = function()
                        CPlayerTravelManager.getInstance().free_movement = false
                        log:debug("register player")
                        tes3.player.facing = mount.referenceHandle:getObject().facing
                        mount:registerRefInRandomSlot(tes3.makeSafeObjectHandle(tes3.player))
                    end
                }
            },
            cancels = true
        }

        return false
    end

    return false
end


--- Disable tooltips while in travel
--- @param e uiObjectTooltipEventData
local function uiObjectTooltipCallback(e)
    e.tooltip.visible = false
    return false
end

-- key down callbacks while in travel
--- @param e keyDownEventData
local function keyDownCallback(e)
    local mount = CPlayerTravelManager.getInstance().trackedVehicle
    if not mount then return end


    -- move
    if not CPlayerTravelManager.getInstance().free_movement and CPlayerTravelManager.getInstance():isTraveling() then
        if e.keyCode == tes3.scanCode["w"] or e.keyCode == tes3.scanCode["a"] or
            e.keyCode == tes3.scanCode["d"] then
            mount:incrementSlot()
        end

        if e.keyCode == tes3.scanCode["s"] then
            if mount.hasFreeMovement then
                -- remove from slot
                for index, slot in ipairs(mount.slots) do
                    if slot.handle and slot.handle:valid() and
                        slot.handle:getObject() == tes3.player then
                        slot.handle = nil
                        CPlayerTravelManager.getInstance().free_movement = true
                        -- free animations
                        tes3.mobilePlayer.movementCollision = true;
                        tes3.loadAnimation({ reference = tes3.player })
                        tes3.playAnimation({ reference = tes3.player, group = 0 })
                    end
                end
            end
        end
    end
end

-- prevent saving while travelling
--- @param e saveEventData
local function saveCallback(e)
    tes3.messageBox("You cannot save the game while travelling")
    return false
end

-- always allow resting on a mount even with enemies near
--- @param e preventRestEventData
local function preventRestCallback(e)
    return false
end

-- resting while travelling skips to end
--- @param e uiShowRestMenuEventData
local function uiShowRestMenuCallback(e)
    -- always allow resting on a mount
    e.allowRest = true

    -- custom UI
    tes3ui.showMessageMenu {
        message = "Rest and skip to the end of the journey?",
        buttons = {
            {
                text = "Rest",
                callback = function()
                    tes3.fadeOut({ duration = 1 })

                    timer.start({
                        type = timer.simulate,
                        iterations = 1,
                        duration = 1,
                        callback = (function()
                            tes3.fadeIn({ duration = 1 })

                            -- teleport to last marker
                            local mount = CPlayerTravelManager.getInstance().trackedVehicle
                            if mount then
                                -- teleport to last position
                                tes3.positionCell({
                                    reference = tes3.mobilePlayer,
                                    position = lib.vec(mount.currentSpline[#mount.currentSpline])
                                })
                                -- then to destination
                                CPlayerTravelManager.getInstance():destinationReached(true)
                            end
                        end)
                    })
                end
            }
        },
        cancels = true
    }

    return false
end

--#endregion

-- //////////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// METHODS ///////////////////////////////////////////////////////////////////////
--#region methods

-- OnDestinationReached
function CPlayerTravelManager:OnDestinationReached()
    tes3.fadeOut()

    timer.start({
        type = timer.simulate,
        duration = 1,
        callback = (function()
            tes3.fadeIn()
            self:destinationReached(false)
        end)
    })
end

-- start the travel
-- what happens when we reach the destination
---@param force boolean
function CPlayerTravelManager:destinationReached(force)
    log:debug("destinationReached, force %s", force)

    -- unregister events
    event.unregister(tes3.event.mouseWheel, lib.mouseWheelCallback)
    event.unregister(tes3.event.damage, damageInvincibilityGate)
    event.unregister(tes3.event.activate, activateCallback)
    event.unregister(tes3.event.combatStart, forcedPacifism)
    event.unregister(tes3.event.uiObjectTooltip, uiObjectTooltipCallback)
    event.unregister(tes3.event.keyDown, keyDownCallback)
    event.unregister(tes3.event.save, saveCallback)
    event.unregister(tes3.event.preventRest, preventRestCallback)
    event.unregister(tes3.event.cellChanged, cellChangedCallback)

    -- reset player
    tes3.mobilePlayer.movementCollision = true;
    tes3.loadAnimation({ reference = tes3.player })
    tes3.playAnimation({ reference = tes3.player, group = 0 })

    if force then
        lib.teleportToClosestMarker()
    else
        if self:isTraveling() then lib.teleportToClosestMarker() end
    end

    if self.trackedVehicle then
        self.trackedVehicle:OnEndPlayerTravel()

        -- delete vehicle
        self.trackedVehicle:Delete()
    end
end

--- set up everything
---@param start string
---@param destination string
---@param service ServiceData
---@param guide tes3reference
function CPlayerTravelManager:startTravel(start, destination, service, guide)
    -- checks
    if guide == nil then return end

    local m = tes3ui.findMenu("it:travel_menu")
    if not m then return end

    -- leave dialogue
    tes3ui.leaveMenuMode()
    m:destroy()
    if self.npcMenu then
        local menu = tes3ui.findMenu(self.npcMenu)
        if menu then
            self.npcMenu = nil
            menu:destroy()
        end
    end

    local currentSpline = lib.loadSpline(start, destination, service)
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

            -- vehicle id
            local mountId = service.mount
            -- override mounts
            if service.override_mount then
                for _, o in ipairs(service.override_mount) do
                    if lib.is_in(o.points, start) and
                        lib.is_in(o.points, destination) then
                        mountId = o.id
                        break
                    end
                end
            end

            -- create vehicle
            local startPos = lib.vec(currentSpline[1])
            local nextPos = lib.vec(currentSpline[2])
            local d = nextPos - startPos
            d:normalize()
            local facing = math.atan2(d.x, d.y)
            local vehicle = interop.createVehicle(mountId, startPos, d, facing)
            if not vehicle then
                return
            end
            vehicle:OnStartPlayerTravel(currentSpline, guide.baseObject.id)
            self.trackedVehicle = vehicle
            self.free_movement = false

            -- register travel events
            event.register(tes3.event.mouseWheel, lib.mouseWheelCallback)
            event.register(tes3.event.damage, damageInvincibilityGate)
            event.register(tes3.event.activate, activateCallback)
            event.register(tes3.event.combatStart, forcedPacifism)
            event.register(tes3.event.uiObjectTooltip, uiObjectTooltipCallback)
            event.register(tes3.event.keyDown, keyDownCallback)
            event.register(tes3.event.save, saveCallback)
            event.register(tes3.event.preventRest, preventRestCallback)
            event.register(tes3.event.cellChanged, cellChangedCallback)
            event.register(tes3.event.uiShowRestMenu, uiShowRestMenuCallback)
        end)
    })
end

-- convenience method to check if player is currently travelling
function CPlayerTravelManager:isTraveling()
    if self.trackedVehicle then
        return self.trackedVehicle:isOnMount()
    end

    return false
end

--#endregion

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
function CPlayerTravelManager:createTravelButton(menu, guide, service)
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
        self.npcMenu = menu.id
        createTravelWindow(service, guide)
    end)
    menu:registerAfter("update", function()
        updateServiceButton(menu)
    end)
end

--#endregion

return CPlayerTravelManager
