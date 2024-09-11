local lib                  = require("ImmersiveTravel.lib")
local GRoutesManager       = require("ImmersiveTravel.GRoutesManager")
local log                  = lib.log

-- Define a class to manage the tracking list and timer
---@class GPlayerVehicleManager
---@field trackedVehicle CVehicle?
---@field free_movement boolean
---@field travelMarkerId  string
---@field travelMarkerMesh any?
---@field travelMarker     niNode?
local PlayerVehicleManager = {
    -- debug
    travelMarkerId = "marker_arrow.nif"
}

function PlayerVehicleManager:new()
    local newObj = {}
    self.__index = self
    setmetatable(newObj, self)
    return newObj
end

-- singleton instance
--- @type GPlayerVehicleManager?
local instance = nil
--- @return GPlayerVehicleManager
function PlayerVehicleManager.getInstance()
    if instance == nil then
        instance = PlayerVehicleManager:new()

        -- init
        instance.trackedVehicle = nil
        instance.free_movement = true
        instance.travelMarkerMesh = tes3.loadMesh(instance.travelMarkerId)
        instance.travelMarker = nil
    end
    return instance
end

function PlayerVehicleManager:IsPlayerTraveling()
    return self.trackedVehicle ~= nil
end

--#region events

--- @param reference tes3reference
---@return Clutter?
local function registerStatic(reference)
    local vehicle = PlayerVehicleManager.getInstance().trackedVehicle;
    if not vehicle then
        return nil
    end

    local rootBone = vehicle:GetRootBone()
    if not rootBone then
        return nil
    end

    ---@type Clutter
    local static = {
        position    = rootBone.worldTransform:invert() * reference.position,
        orientation = lib.toLocalOrientationDeg(reference.orientation, rootBone.worldTransform),
        id          = reference.object.id,
        isTemporary = true,
        handle      = tes3.makeSafeObjectHandle(reference)
    }

    -- add to clutter
    table.insert(vehicle.clutter, static)
    log:debug("registered %s in slot %s", static.id, #vehicle.clutter)

    return static
end

--- @param e itemDroppedEventData
local function itemDroppedCallback(e)
    local vehicle = PlayerVehicleManager.getInstance().trackedVehicle;
    if not vehicle then return end

    log:debug("item dropped %s", e.reference.object.id)
    registerStatic(e.reference)
end


local function CFStartPlacementCallback(e)
    -- disable position and orientation updates for the reference

    local vehicle = PlayerVehicleManager.getInstance().trackedVehicle;
    if not vehicle then return end

    for i, slot in ipairs(vehicle.clutter) do
        if slot.handle and slot.handle:valid() and slot.handle:getObject() == e.reference then
            slot.disableUpdates = true
            log:debug("CFStartPlacementCallback disabled %s", slot.id)
            break
        end
    end
end

local function CFEndPlacementCallback(e)
    local vehicle = PlayerVehicleManager.getInstance().trackedVehicle;
    if not vehicle then return end

    local rootBone = vehicle:GetRootBone()
    if not rootBone then return end

    for i, slot in ipairs(vehicle.clutter) do
        if slot.handle and slot.handle:valid() and slot.handle:getObject() == e.reference then
            slot.position = rootBone.worldTransform:invert() * e.reference.position
            slot.orientation = lib.toLocalOrientationDeg(e.reference.orientation, rootBone.worldTransform)
            slot.disableUpdates = false

            log:debug("CFEndPlacementCallback updated %s", slot.id)
            break
        end
    end
end

--- @param e referenceActivatedEventData
local function referenceActivatedCallback(e)
    local vehicle = PlayerVehicleManager.getInstance().trackedVehicle;
    if not vehicle then return end

    local config = require("mer.joyOfPainting.config")
    if config and config.easels then
        for key, easel in pairs(config.easels) do
            if e.reference.object.id:lower() == key then
                local found = false
                for i, slot in ipairs(vehicle.clutter) do
                    if slot.handle and slot.handle:valid() and slot.handle:getObject() == e.reference then
                        log:debug("reference updated %s", e.reference.object.id)
                        -- c.position = e.reference.position
                        -- c.orientation = e.reference.orientation:copy()
                        found = true
                        return
                    end
                end

                if not found then
                    log:debug("reference activated %s", e.reference.object.id)
                    registerStatic(e.reference)
                    return
                end
            end
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
                            -- teleport to last marker
                            local vehicle = PlayerVehicleManager.getInstance().trackedVehicle
                            if vehicle then
                                -- teleport to last position
                                local spline = GRoutesManager.getInstance():GetRoute(vehicle.routeId)
                                if spline ~= nil then
                                    tes3.positionCell({
                                        reference = tes3.mobilePlayer,
                                        position = spline[#spline]
                                    })
                                end

                                -- then to destination
                                -- this pushes the AI statemachine
                                vehicle.routeId = nil

                                tes3.fadeIn()

                                lib.teleportToClosestMarker()

                                PlayerVehicleManager.getInstance():StopTraveling()

                                vehicle:release()
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

-- key down callbacks while in travel
--- @param e keyDownEventData
local function keyDownCallback(e)
    local vehicle = PlayerVehicleManager.getInstance().trackedVehicle;
    if not vehicle then return end
    if PlayerVehicleManager.getInstance().free_movement then return end

    -- move
    if e.keyCode == tes3.scanCode["w"] or e.keyCode == tes3.scanCode["a"] or
        e.keyCode == tes3.scanCode["d"] then
        vehicle:incrementSlot()
    elseif e.keyCode == tes3.scanCode["s"] then
        if vehicle.hasFreeMovement then
            -- remove from slot
            for index, slot in ipairs(vehicle.slots) do
                if slot.handle and slot.handle:valid() and
                    slot.handle:getObject() == tes3.player then
                    slot.handle = nil
                    PlayerVehicleManager.getInstance().free_movement = true
                    -- free animations
                    tes3.mobilePlayer.movementCollision = true;
                    tes3.loadAnimation({ reference = tes3.player })
                    tes3.playAnimation({ reference = tes3.player, group = 0 })
                end
            end
        end
    end
end

--#endregion

function PlayerVehicleManager:StartTraveling(vehicle)
    self.trackedVehicle = vehicle
    -- check if player is slotted
    if not vehicle:isPlayerInPassengerSlot() then
        self.free_movement = true
    end

    -- register travel events
    event.register(tes3.event.mouseWheel, lib.mouseWheelCallback)
    event.register(tes3.event.damage, damageInvincibilityGate)
    event.register(tes3.event.combatStart, forcedPacifism)
    event.register(tes3.event.save, saveCallback)
    event.register(tes3.event.preventRest, preventRestCallback)
    event.register(tes3.event.keyDown, keyDownCallback)
    event.register(tes3.event.uiShowRestMenu, uiShowRestMenuCallback)
    event.register(tes3.event.itemDropped, itemDroppedCallback)
    event.register(tes3.event.referenceActivated, referenceActivatedCallback)
    event.register("CraftingFramework:EndPlacement", CFEndPlacementCallback)
    event.register("CraftingFramework:StartPlacement", CFStartPlacementCallback)
end

function PlayerVehicleManager:StopTraveling()
    self.trackedVehicle = nil

    -- unregister events
    event.unregister(tes3.event.mouseWheel, lib.mouseWheelCallback)
    event.unregister(tes3.event.damage, damageInvincibilityGate)
    event.unregister(tes3.event.combatStart, forcedPacifism)
    -- event.unregister(tes3.event.uiObjectTooltip, uiObjectTooltipCallback)
    event.unregister(tes3.event.save, saveCallback)
    event.unregister(tes3.event.preventRest, preventRestCallback)
    event.unregister(tes3.event.keyDown, keyDownCallback)
    event.unregister(tes3.event.uiShowRestMenu, uiShowRestMenuCallback)
    event.unregister(tes3.event.itemDropped, itemDroppedCallback)
    event.unregister(tes3.event.referenceActivated, referenceActivatedCallback)
    event.unregister("CraftingFramework:EndPlacement", CFEndPlacementCallback)
    event.unregister("CraftingFramework:StartPlacement", CFStartPlacementCallback)
end

return PlayerVehicleManager
