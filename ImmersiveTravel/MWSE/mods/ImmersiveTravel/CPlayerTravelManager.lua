local lib = require("ImmersiveTravel.lib")
local log = lib.log

-- define the player travel manager class
---@class CPlayerTravelManager
---@field currentSpline tes3vector3[]?
---@field splineIndex number
---@field swayTime number
local CPlayerTravelManager = {
    currentSpline = nil,
    splineIndex = 2,
    swayTime = 0
}

local free_movement = false


--#region constants

--#endregion

--#region methods

-- start the travel
-- what happens when we reach the destination
---@param force boolean
function CPlayerTravelManager.destinationReached(force)
    if not mountData then return end

    log:debug("destinationReached")

    -- reset player
    tes3.mobilePlayer.movementCollision = true;
    tes3.loadAnimation({ reference = tes3.player })
    tes3.playAnimation({ reference = tes3.player, group = 0 })

    if force then
        teleportToClosestMarker()
    else
        if isTraveling() then teleportToClosestMarker() end
    end

    -- teleport followers
    for index, slot in ipairs(mountData.slots) do
        if slot.handle and slot.handle:valid() then
            local ref = slot.handle:getObject()
            if ref ~= tes3.player and ref.mobile and
                common.isFollower(ref.mobile) then
                log:debug("teleporting follower %s", ref.id)

                ref.mobile.movementCollision = true;
                tes3.loadAnimation({ reference = ref })
                tes3.playAnimation({ reference = ref, group = 0 })

                local f = tes3.player.forwardDirection
                f:normalize()
                local offset = f * 60.0
                tes3.positionCell({
                    reference = ref,
                    position = tes3.player.position + offset
                })

                slot.handle = nil
            end
        end
    end

    if mountData.hiddenSlot.handles then
        for index, handle in ipairs(mountData.hiddenSlot.handles) do
            if handle and handle:valid() then
                local ref = handle:getObject()
                if ref ~= tes3.player and ref.mobile and
                    common.isFollower(ref.mobile) then
                    log:debug("teleporting follower %s", ref.id)

                    ref.mobile.movementCollision = true;
                    tes3.loadAnimation({ reference = ref })
                    tes3.playAnimation({ reference = ref, group = 0 })

                    local f = tes3.player.forwardDirection
                    f:normalize()
                    local offset = f * 60.0
                    tes3.positionCell({
                        reference = ref,
                        position = tes3.player.position + offset
                    })
                end
            end
        end
        mountData.hiddenSlot.handles = nil
    end

    cleanup()
end

--- set up everything
---@param start string
---@param destination string
---@param service ServiceData
---@param guide tes3reference
function CPlayerTravelManager.startTravel(start, destination, service, guide)
    -- if guide == nil then return end

    local m = tes3ui.findMenu(travelMenuId)
    if not m then return end

    -- leave dialogue
    tes3ui.leaveMenuMode()
    m:destroy()

    if npcMenu then
        local menu = tes3ui.findMenu(npcMenu)
        if menu then
            npcMenu = nil
            menu:destroy()
        end
    end

    currentSpline = common.loadSpline(start, destination, service)
    if currentSpline == nil then return end

    local mountId = service.mount
    -- override mounts
    if service.override_mount then
        for _, o in ipairs(service.override_mount) do
            if common.is_in(o.points, start) and
                common.is_in(o.points, destination) then
                mountId = o.id
                break
            end
        end
    end

    -- load mount data
    mountData = common.loadMountData(mountId)
    if mountData == nil then return end
    -- fade out
    tes3.fadeOut({ duration = 1 })

    -- fade back in
    timer.start({
        type = timer.simulate,
        iterations = 1,
        duration = 1,
        callback = (function()
            tes3.fadeIn({ duration = 1 })

            -- calculate positions
            local startPoint = currentSpline[1]
            local startPos = tes3vector3.new(startPoint.x, startPoint.y,
                startPoint.z)
            local next_point = currentSpline[2]
            local next_pos = tes3vector3.new(next_point.x, next_point.y,
                next_point.z)
            local d = next_pos - startPos
            d:normalize()
            local new_facing = math.atan2(d.x, d.y)
            local mountOffset = tes3vector3.new(0, 0, mountData.offset)

            -- create mount
            mount = tes3.createReference {
                object = mountId,
                position = startPos + mountOffset,
                orientation = d
            }
            mount.facing = new_facing
            if mountData.forwardAnimation then
                tes3.loadAnimation({ reference = mount })

                -- TODO make this generalized
                local forwardAnimation = mountData.forwardAnimation
                if mountId == "a_siltstrider" and config.a_siltstrider_forwardAnimation then
                    forwardAnimation = config.a_siltstrider_forwardAnimation
                end

                tes3.playAnimation({ reference = mount, group = tes3.animationGroup[forwardAnimation] })
            end
            if mountData.loopSound then
                local sound = mountData.sound[math.random(1, #mountData.sound)]
                tes3.playSound({
                    sound = sound,
                    reference = mount,
                    loop = true
                })
            end

            -- always start slotted
            free_movement = false

            -- register guide
            local guide2 = tes3.createReference {
                object = guide.baseObject.id,
                position = startPos + mountOffset,
                orientation = mount.orientation
            }
            guide2.mobile.hello = 0
            log:debug("> registering guide")
            common.registerGuide(mountData, tes3.makeSafeObjectHandle(guide2))

            -- register player
            log:debug("> registering player")
            tes3.player.position = startPos + mountOffset
            common.registerRefInRandomSlot(mountData, tes3.makeSafeObjectHandle(
                tes3.player))
            tes3.player.facing = new_facing

            -- register followers
            local followers = common.getFollowers()
            log:debug("> registering %s followers", #followers)
            for index, follower in ipairs(followers) do
                local handle = tes3.makeSafeObjectHandle(follower)
                local result = common.registerRefInRandomSlot(mountData, handle)
                if not result then
                    registerRefInHiddenSlot(mountData, handle)
                end
            end

            -- register passengers
            local maxPassengers = math.max(0, #mountData.slots - 2)
            if maxPassengers > 0 then
                local n = math.random(maxPassengers);
                log:debug("> registering %s / %s passengers", n, maxPassengers)
                for _i, value in ipairs(common.getRandomNpcsInCell(n)) do
                    local passenger = tes3.createReference {
                        object = value,
                        position = startPos + mountOffset,
                        orientation = mount.orientation
                    }
                    -- disable scripts
                    if passenger.baseObject.script then
                        passenger.attachments.variables.script = nil
                        passenger.data.rfuzzo_noscript = true;

                        log:debug("Disabled script %s on %s", passenger.baseObject.script.id, passenger.baseObject.id)
                    end

                    local refHandle = tes3.makeSafeObjectHandle(passenger)
                    common.registerRefInRandomSlot(mountData, refHandle)
                end
            end

            -- register statics
            if mountData.clutter then
                log:debug("> registering statics")
                for index, clutter in ipairs(mountData.clutter) do
                    if clutter.id then
                        -- instantiate
                        if clutter.orientation then
                            local inst =
                                tes3.createReference {
                                    object = clutter.id,
                                    position = startPos + mountOffset,
                                    orientation = common.toWorldOrientation(
                                        radvec(clutter.orientation),
                                        mount.orientation)
                                }
                            common.registerStatic(mountData,
                                tes3.makeSafeObjectHandle(inst),
                                index)
                        else
                            local inst =
                                tes3.createReference {
                                    object = clutter.id,
                                    position = startPos + mountOffset,
                                    orientation = mount.orientation
                                }
                            common.registerStatic(mountData,
                                tes3.makeSafeObjectHandle(inst),
                                index)
                        end
                    end
                end
            end

            -- start timer
            last_position = mount.position
            last_forwardDirection = mount.forwardDirection
            last_facing = mount.facing
            last_sway = 0
            splineIndex = 2

            -- register events
            event.register(tes3.event.mouseWheel, mouseWheelCallback)
            event.register(tes3.event.damage, damageInvincibilityGate)
            event.register(tes3.event.activate, activateCallback)
            event.register(tes3.event.combatStart, forcedPacifism)
            event.register(tes3.event.uiObjectTooltip, uiObjectTooltipCallback)
            event.register(tes3.event.keyDown, keyDownCallback)
            event.register(tes3.event.save, saveCallback)
            event.register(tes3.event.preventRest, preventRestCallback)
            event.register(tes3.event.cellChanged, cellChangedCallback)

            log:debug("starting timer")
            myTimer = timer.start({
                duration = TIMER_TICK,
                type = timer.simulate,
                iterations = -1,
                callback = onTimerTick
            })
        end)
    })
end

-- player is within the surface of the mount
---@return boolean
function CPlayerTravelManager.isOnMount()
    if not mount then return false end

    if not mountData then return false end

    local inside = true

    local volumeHeight = 200

    local bbox = mount.object.boundingBox

    local pos = tes3.player.position
    local surfaceOffset = mountData.slots[1].position.z
    local mountSurface = mount.position + tes3vector3.new(0, 0, surfaceOffset)

    if pos.z < (mountSurface.z - volumeHeight) then inside = false end
    if pos.z > (mountSurface.z + volumeHeight) then inside = false end

    local max_xy_d = tes3vector3.new(bbox.max.x, bbox.max.y, 0):length()
    local min_xy_d = tes3vector3.new(bbox.min.x, bbox.min.y, 0):length()
    local dist = mountSurface:distance(pos)
    local r = math.max(min_xy_d, max_xy_d) + 50
    if dist > r then inside = false end

    return inside
end

-- convenience method to check if player is currently travelling
function CPlayerTravelManager.isTraveling()
    if not currentSpline then return false end

    if not isOnMount() then return false end

    return true
end

--#endregion

--#region events

-- OnDestinationReached
function CPlayerTravelManager.OnDestinationReached()
    -- body

    tes3.fadeOut()
    if myTimer ~= nil then myTimer:cancel() end

    timer.start({
        type = timer.simulate,
        duration = 1,
        callback = (function()
            tes3.fadeIn()
            destinationReached(false)
        end)
    })
end

--#endregion

return CPlayerTravelManager

-- unregister events
-- event.unregister(tes3.event.mouseWheel, mouseWheelCallback)
-- event.unregister(tes3.event.damage, damageInvincibilityGate)
-- event.unregister(tes3.event.activate, activateCallback)
-- event.unregister(tes3.event.combatStart, forcedPacifism)
-- event.unregister(tes3.event.uiObjectTooltip, uiObjectTooltipCallback)
-- event.unregister(tes3.event.keyDown, keyDownCallback)
-- event.unregister(tes3.event.save, saveCallback)
-- event.unregister(tes3.event.preventRest, preventRestCallback)
-- event.unregister(tes3.event.cellChanged, cellChangedCallback)


-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// VARIABLES

local travelMenuId = tes3ui.registerID("it:travel_menu")
local travelMenuCancelId = tes3ui.registerID("it:travel_menu_cancel")

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// EVENTS

--- @param e cellChangedEventData
local function cellChangedCallback(e)
    if not isTraveling() then return end
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
local function forcedPacifism(e) if (isTraveling()) then return false end end


--- Disable all activate while in travel
--- @param e activateEventData
local function activateCallback(e)
    if (e.activator ~= tes3.player) then return end
    if not isTraveling() then return end
    if mount == nil then return; end
    if mountData == nil then return; end
    if myTimer == nil then return; end
    if mountData.guideSlot.handle == nil then return; end
    if not mountData.guideSlot.handle:valid() then return; end

    if e.target.id == mountData.guideSlot.handle:getObject().id and
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
                        tes3.player.facing = mount.facing
                        common.registerRefInRandomSlot(mountData,
                            tes3.makeSafeObjectHandle(
                                tes3.player))
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
    if not isTraveling() then return end
    if mount == nil then return; end
    if myTimer == nil then return; end
    if mountData == nil then return; end
    if mountData.guideSlot.handle == nil then return; end
    if not mountData.guideSlot.handle:valid() then return; end

    e.tooltip.visible = false
    return false
end

-- key down callbacks while in travel
--- @param e keyDownEventData
local function keyDownCallback(e)
    -- move
    if not free_movement and isTraveling() then
        if e.keyCode == tes3.scanCode["w"] or e.keyCode == tes3.scanCode["a"] or
            e.keyCode == tes3.scanCode["d"] then
            incrementSlot(mountData)
        end

        if e.keyCode == tes3.scanCode["s"] then
            if mountData == nil then return; end
            if mountData.hasFreeMovement then
                -- remove from slot
                for index, slot in ipairs(mountData.slots) do
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
    if isTraveling() then
        tes3.messageBox("You cannot save the game while travelling")
        return false
    end
end

-- always allow resting on a mount even with enemies near
--- @param e preventRestEventData
local function preventRestCallback(e) if isTraveling() then return false end end


-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// UI

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
            startTravel(tes3.player.cell.id, name, service, guide)
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
            mount = nil
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

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// EVENTS

-- resting while travelling skips to end
--- @param e uiShowRestMenuEventData
local function uiShowRestMenuCallback(e)
    if isTraveling() and currentSpline then
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
                                tes3.positionCell({
                                    reference = tes3.mobilePlayer,
                                    position = vec(currentSpline[#currentSpline])
                                })
                                -- then to destination
                                destinationReached(true)
                            end)
                        })
                    end
                }
            },
            cancels = true
        }

        return false
    end
end
event.register(tes3.event.uiShowRestMenu, uiShowRestMenuCallback)

--- Cleanup on save load
--- @param e loadEventData
local function loadCallback(e) cleanup() end
event.register(tes3.event.load, loadCallback)

-- upon entering the dialog menu, create the travel menu
---@param e uiActivatedEventData
local function onMenuDialog(e)
    local menuDialog = e.element
    local mobileActor = menuDialog:getPropertyObject("PartHyperText_actor") ---@cast mobileActor tes3mobileActor
    if mobileActor.actorType == tes3.actorType.npc then
        local ref = mobileActor.reference
        local obj = ref.baseObject
        local npc = obj ---@cast obj tes3npc

        if not offersTraveling(npc) then return end

        local services = common.loadServices()
        if not services then return end

        -- get npc class
        local class = npc.class.id
        local service = table.get(services, class)
        for key, value in pairs(services) do
            if value.override_npc ~= nil then
                if common.is_in(value.override_npc, npc.id) then
                    service = value
                    break
                end
            end
        end

        if service == nil then
            log:debug("no service found for %s", npc.id)
            return
        end

        -- Return if no destinations
        common.loadRoutes(service)
        local destinations = service.routes[ref.cell.id]
        if destinations == nil then return end
        if #destinations == 0 then return end

        log:debug("createTravelButton for %s", npc.id)
        createTravelButton(menuDialog, ref, service)
        menuDialog:updateLayout()
    end
end
event.register("uiActivated", onMenuDialog, { filter = "MenuDialog" })
