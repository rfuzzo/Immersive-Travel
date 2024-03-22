local lib = require("ImmersiveTravel.lib")
local interop = require("ImmersiveTravel.interop")
-- classes

local log = lib.log

-- define the player travel manager class
---@class CPlayerTravelManager
---@field trackedVehicle CVehicle?
local CPlayerTravelManager = {
    trackedVehicle = nil
}

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

local free_movement = false

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

--- @param e mouseWheelEventData
local function mouseWheelCallback(e)
    local isControlDown = tes3.worldController.inputController:isControlDown()
    if isControlDown then
        -- update fov
        if e.delta > 0 then
            tes3.set3rdPersonCameraOffset({ offset = tes3.get3rdPersonCameraOffset() + tes3vector3.new(0, 10, 0) })
        else
            tes3.set3rdPersonCameraOffset({ offset = tes3.get3rdPersonCameraOffset() - tes3vector3.new(0, 10, 0) })
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
        free_movement then
        -- register player in slot
        tes3ui.showMessageMenu {
            message = "Do you want to sit down?",
            buttons = {
                {
                    text = "Yes",
                    callback = function()
                        free_movement = false
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
    if not free_movement and CPlayerTravelManager.getInstance():isTraveling() then
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
                        free_movement = true
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
                                tes3.positionCell({
                                    reference = tes3.mobilePlayer,
                                    position = mount.currentSpline[#mount.currentSpline]
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
    -- body

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
    log:debug("destinationReached")

    -- unregister events
    event.unregister(tes3.event.mouseWheel, mouseWheelCallback)
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
    local npcMenu = nil
    if npcMenu then
        local menu = tes3ui.findMenu(npcMenu)
        if menu then
            npcMenu = nil
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
            -- TODO create correct vehicle type
            local CLongboat = require("ImmersiveTravel.CLongboat")
            local boat = CLongboat:new(startPos, d, facing)
            boat:OnStartPlayerTravel(currentSpline, guide.baseObject.id)
            self.trackedVehicle = boat

            -- TODO always start slotted
            free_movement = false

            -- register travel events
            event.register(tes3.event.mouseWheel, mouseWheelCallback)
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


return CPlayerTravelManager
