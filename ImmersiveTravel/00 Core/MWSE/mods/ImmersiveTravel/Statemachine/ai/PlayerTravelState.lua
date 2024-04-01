local CAiState = require("ImmersiveTravel.Statemachine.ai.CAiState")
local CPlayerVehicleManager = require("ImmersiveTravel.CPlayerVehicleManager")
local lib = require("ImmersiveTravel.lib")
local interop = require("ImmersiveTravel.interop")

-- on spline state class
---@class PlayerTravelState : CAiState
---@field cameraOffset tes3vector3?
local PlayerTravelState = {
    name = CAiState.PLAYERTRAVEL,
    transitions = {
        [CAiState.NONE] = CAiState.ToNone,
        [CAiState.ONSPLINE] = CAiState.ToOnSpline,
        [CAiState.PLAYERSTEER] = CAiState.ToPlayerSteer
    }
}
setmetatable(PlayerTravelState, { __index = CAiState })

-- constructor for PlayerTravelState
---@return PlayerTravelState
function PlayerTravelState:new()
    local newObj = CAiState:new()
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj PlayerTravelState
    return newObj
end

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

--- Disable tooltips while in travel
--- @param e uiObjectTooltipEventData
local function uiObjectTooltipCallback(e)
    e.tooltip.visible = false
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
                            tes3.fadeIn({ duration = 1 })

                            -- teleport to last marker
                            local mount = CPlayerVehicleManager.getInstance().trackedVehicle
                            if mount then
                                -- teleport to last position
                                tes3.positionCell({
                                    reference = tes3.mobilePlayer,
                                    position = lib.vec(mount.spline[#mount.spline])
                                })
                                -- then to destination
                                -- this pushes the AI statemachine
                                mount.spline = nil
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
    local vehicle = CPlayerVehicleManager.getInstance().trackedVehicle;
    if not vehicle then return end
    if CPlayerVehicleManager.getInstance().free_movement then return end

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
                    CPlayerVehicleManager.getInstance().free_movement = true
                    -- free animations
                    tes3.mobilePlayer.movementCollision = true;
                    tes3.loadAnimation({ reference = tes3.player })
                    tes3.playAnimation({ reference = tes3.player, group = 0 })
                end
            end
        end
    end
end

--- Disable all activate while in travel
--- @param e activateEventData
local function activateCallback(e)
    if (e.activator ~= tes3.player) then return end
    local vehicle = CPlayerVehicleManager.getInstance().trackedVehicle
    if not vehicle then return end

    if e.target.id == vehicle.guideSlot.handle:getObject().id and
        CPlayerVehicleManager.getInstance().free_movement then
        -- register player in slot
        tes3ui.showMessageMenu {
            message = "Do you want to sit down?",
            buttons = {
                {
                    text = "Yes",
                    callback = function()
                        CPlayerVehicleManager.getInstance().free_movement = false
                        lib.log:debug("register player")
                        tes3.player.facing = vehicle.referenceHandle:getObject().facing
                        vehicle:registerRefInRandomSlot(tes3.makeSafeObjectHandle(tes3.player))
                    end
                }
            },
            cancels = true
        }
    end

    return false
end

--#endregion

function PlayerTravelState:enter(scriptedObject)
    local vehicle = scriptedObject ---@cast vehicle CVehicle
    CPlayerVehicleManager.getInstance().trackedVehicle = vehicle
    CPlayerVehicleManager.getInstance().free_movement = false

    -- TODO register travel events
    event.register(tes3.event.mouseWheel, lib.mouseWheelCallback)
    event.register(tes3.event.damage, damageInvincibilityGate)
    event.register(tes3.event.combatStart, forcedPacifism)
    event.register(tes3.event.uiObjectTooltip, uiObjectTooltipCallback)
    event.register(tes3.event.save, saveCallback)
    event.register(tes3.event.preventRest, preventRestCallback)
    event.register(tes3.event.cellChanged, cellChangedCallback)

    event.register(tes3.event.activate, activateCallback)
    event.register(tes3.event.keyDown, keyDownCallback)
    event.register(tes3.event.uiShowRestMenu, uiShowRestMenuCallback)
end

function PlayerTravelState:update(dt, scriptedObject)
    -- call super update
    CAiState.update(self, dt, scriptedObject)

    -- Implement on spline state update logic here
    local vehicle = scriptedObject ---@cast vehicle CVehicle
    if vehicle.splineIndex > #vehicle.spline then
        -- reached end of spline
        vehicle.spline = nil
    end

    -- handle player leaving vehicle
    if not vehicle:isPlayerInMountBounds() then
        self.playerRegistered = false
    end
end

function PlayerTravelState:exit(scriptedObject)
    local vehicle = scriptedObject ---@cast vehicle CVehicle

    -- unregister events
    event.unregister(tes3.event.mouseWheel, lib.mouseWheelCallback)
    event.unregister(tes3.event.damage, damageInvincibilityGate)
    event.unregister(tes3.event.combatStart, forcedPacifism)
    event.unregister(tes3.event.uiObjectTooltip, uiObjectTooltipCallback)
    event.unregister(tes3.event.save, saveCallback)
    event.unregister(tes3.event.preventRest, preventRestCallback)
    event.unregister(tes3.event.cellChanged, cellChangedCallback)
    event.unregister(tes3.event.activate, activateCallback)
    event.unregister(tes3.event.keyDown, keyDownCallback)
    event.unregister(tes3.event.uiShowRestMenu, uiShowRestMenuCallback)

    tes3.fadeOut()

    timer.start({
        type = timer.simulate,
        duration = 1,
        callback = (function()
            tes3.fadeIn()

            lib.teleportToClosestMarker()

            vehicle:EndPlayerTravel()

            vehicle:Delete()
            CPlayerVehicleManager.getInstance().trackedVehicle = nil
        end)
    })
end

return PlayerTravelState
