local lib = require("ImmersiveTravel.lib")
local interop = require("ImmersiveTravel.interop")
local log = lib.log

-- define the player steer manager class
---@class CPlayerSteerManager
---@field trackedVehicle CVehicle?
---@field cameraOffset tes3vector3?
---@field speedChange number
CPlayerSteerManager = {
    trackedVehicle = nil,
    cameraOffset = nil,
    speedChange = 0
}

local DEBUG = false

-- constructor
function CPlayerSteerManager:new()
    local newObj = {}
    self.__index = self
    setmetatable(newObj, self)

    return newObj
end

-- singleton instance
--- @type CPlayerSteerManager?
local steerManager = nil
--- @return CPlayerSteerManager
function CPlayerSteerManager.getInstance()
    if steerManager == nil then
        steerManager = CPlayerSteerManager:new()
    end
    return steerManager
end

--#region events

--- @param e keyDownEventData
local function mountKeyDownCallback(e)
    local this = CPlayerSteerManager.getInstance()
    local vehicle = this.trackedVehicle
    if not vehicle then
        return
    end
    local mountHandle = vehicle.referenceHandle

    if mountHandle and mountHandle:valid() then
        if e.keyCode == tes3.scanCode["w"] then
            -- increment speed
            if vehicle.current_speed < vehicle.maxSpeed then
                this.speedChange = 1
                -- play anim
                if vehicle.accelerateAnimation then
                    tes3.loadAnimation({ reference = mountHandle:getObject() })
                    tes3.playAnimation({
                        reference = mountHandle:getObject(),
                        group = tes3.animationGroup
                            [vehicle.accelerateAnimation]
                    })
                end
            end
        end

        if e.keyCode == tes3.scanCode["s"] then
            -- decrement speed
            if vehicle.current_speed > vehicle.minSpeed then
                this.speedChange = -1
                -- play anim
                if vehicle.accelerateAnimation then
                    tes3.loadAnimation({ reference = mountHandle:getObject() })
                    tes3.playAnimation({
                        reference = mountHandle:getObject(),
                        group = tes3.animationGroup
                            [vehicle.accelerateAnimation]
                    })
                end
            end
        end
    end
end

--- @param e keyUpEventData
local function keyUpCallback(e)
    local this = CPlayerSteerManager.getInstance()
    local vehicle = this.trackedVehicle
    if not vehicle then
        return
    end
    local mountData = vehicle.userData
    if not mountData then
        return
    end
    local mountHandle = vehicle.referenceHandle

    if mountHandle and mountHandle:valid() then
        if e.keyCode == tes3.scanCode["w"] or e.keyCode == tes3.scanCode["s"] then
            -- stop increment speed
            this.speedChange = 0
            -- play anim
            if vehicle.forwardAnimation then
                tes3.loadAnimation({ reference = mountHandle:getObject() })
                tes3.playAnimation({
                    reference = mountHandle:getObject(),
                    group = tes3.animationGroup[vehicle.forwardAnimation]
                })
            end

            if DEBUG then
                tes3.messageBox("Current Speed: " .. tostring(vehicle.current_speed))
            end
        end
    end
end

--- visualize on tick
--- @param e simulatedEventData
local function mountSimulatedCallback(e)
    local this = CPlayerSteerManager.getInstance()
    local vehicle = this.trackedVehicle
    if not vehicle then
        return
    end
    local mountHandle = vehicle.referenceHandle

    -- update next pos
    if mountHandle and mountHandle:valid() then
        local mount = mountHandle:getObject()
        local dist = 2048
        if vehicle.freedomtype == "ground" then
            dist = 100
        end
        local target = tes3.getPlayerEyePosition() + tes3.getPlayerEyeVector() * dist

        local isControlDown = tes3.worldController.inputController:isControlDown()
        if isControlDown then
            target = mount.sceneNode.worldTransform * tes3vector3.new(0, 2048, 0)
        end
        if vehicle.freedomtype == "boat" then
            -- pin to waterlevel
            target.z = 0
        elseif vehicle.freedomtype == "ground" then
            -- pin to groundlevel
            local z = lib.getGroundZ(target + tes3vector3.new(0, 0, 100))
            if not z then
                target.z = 0
            else
                target.z = z + 50
            end
        end

        vehicle.virtualDestination = target

        -- todo debug
        -- if DEBUG and travelMarker then
        --     travelMarker.translation = target
        --     local m = tes3matrix33.new()
        --     if isControlDown then
        --         m:fromEulerXYZ(mount.orientation.x, mount.orientation.y, mount.orientation.z)
        --     else
        --         m:fromEulerXYZ(tes3.player.orientation.x, tes3.player.orientation.y, tes3.player.orientation.z)
        --     end
        --     travelMarker.rotation = m
        --     travelMarker:update()
        -- end
    end

    -- collision
    if mountHandle and mountHandle:valid() then
        -- raytest at sealevel to detect shore transition
        local box = mountHandle:getObject().object.boundingBox
        local max = box.max * vehicle.scale
        local min = box.min * vehicle.scale
        local t = mountHandle:getObject().sceneNode.worldTransform

        if vehicle.current_speed > 0 then
            -- detect shore
            if vehicle.freedomtype == "boat" then
                local bowPos = t * tes3vector3.new(0, max.y, min.z + (vehicle.offset * vehicle.scale))
                local hitResult1 = tes3.rayTest({
                    position = bowPos,
                    direction = tes3vector3.new(0, 0, -1),
                    root = tes3.game.worldLandscapeRoot,
                    --maxDistance = 4096
                })
                if (hitResult1 == nil) then
                    vehicle.current_speed = 0
                    if DEBUG then
                        tes3.messageBox("HIT Shore Fwd")
                        log:debug("HIT Shore Fwd")
                    end
                end
            end

            -- raytest from above to detect objects in water
            local bowPosTop = t * tes3vector3.new(0, max.y, max.z)
            local hitResult2 = tes3.rayTest({
                position = bowPosTop,
                direction = tes3vector3.new(0, 0, -1),
                root = tes3.game.worldObjectRoot,
                ignore = { mountHandle:getObject() },
                maxDistance = max.z * vehicle.scale
            })
            if (hitResult2 ~= nil) then
                vehicle.current_speed = 0
                if DEBUG then
                    tes3.messageBox("HIT Object Fwd")
                    log:debug("HIT Object Fwd")
                end
            end
        elseif vehicle.current_speed < 0 then
            -- detect shore
            if vehicle.freedomtype == "boat" then
                local sternPos = t * tes3vector3.new(0, min.y, min.z + (vehicle.offset * vehicle.scale))
                local hitResult1 = tes3.rayTest({
                    position = sternPos,
                    direction = tes3vector3.new(0, 0, -1),
                    root = tes3.game.worldLandscapeRoot,
                    --maxDistance = 4096
                })
                if (hitResult1 == nil) then
                    vehicle.current_speed = 0
                    if DEBUG then
                        tes3.messageBox("HIT Shore Back")
                        log:debug("HIT Shore Back")
                    end
                end
            end

            -- raytest from above to detect objects in water
            local sternPosTop = t * tes3vector3.new(0, min.y, max.z)
            local hitResult2 = tes3.rayTest({
                position = sternPosTop,
                direction = tes3vector3.new(0, 0, -1),
                root = tes3.game.worldObjectRoot,
                ignore = { mountHandle:getObject() },
                maxDistance = max.z
            })
            if (hitResult2 ~= nil) then
                vehicle.current_speed = 0
                if DEBUG then
                    tes3.messageBox("HIT Object Back")
                    log:debug("HIT Object Back")
                end
            end
        end
    end
end

--#endregion

--#region travel

--- activate the vehicle, start or stop steer
---@param reference tes3reference
function CPlayerSteerManager:OnActivate(reference)
    if lib.validMount(reference.id) then
        if self:isOnMount(reference) then
            -- stop
            self:OnPlayerStopSteer()
        else
            -- start
            self:StartSteer(reference)
        end
    end
end

--- destroy the vehicle
---@param reference tes3reference
function CPlayerSteerManager:OnDestroy(reference)
    -- stop
    self:OnPlayerStopSteer()
    self:destroy(reference)
end

function CPlayerSteerManager:OnPlayerStopSteer()
    log:debug("CPlayerSteerManager:OnPlayerStopSteer")

    -- reset camera
    if self.cameraOffset then
        tes3.set3rdPersonCameraOffset({ offset = self.cameraOffset })
    end

    self.trackedVehicle:EndPlayerSteer()

    -- don't delete ref since we may want to use the mount later
    self.trackedVehicle:cleanup()
    self.trackedVehicle:Detach()
    self:Detach()

    -- todo debug
    -- local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
    -- ---@diagnostic disable-next-line: param-type-mismatch
    -- if travelMarker then vfxRoot:detachChild(travelMarker) end
    -- if mountMarker then vfxRoot:detachChild(mountMarker) end
    -- travelMarker = nil
    -- mountMarker = nil

    -- unregister events
    event.unregister(tes3.event.mouseWheel, lib.mouseWheelCallback)
    event.unregister(tes3.event.keyDown, mountKeyDownCallback)
    event.unregister(tes3.event.keyUp, keyUpCallback)
    event.unregister(tes3.event.simulated, mountSimulatedCallback)
end

--- set up everything
---@param mount tes3reference
function CPlayerSteerManager:StartSteer(mount)
    local class = interop.getVehicleStaticData(mount.id)
    if not class then
        log:error("No data found for %s", mount.id)
        return
    end

    -- fade out
    tes3.fadeOut({ duration = 1 })

    -- fade back in
    timer.start({
        type = timer.simulate,
        iterations = 1,
        duration = 1,
        callback = (function()
            tes3.fadeIn({ duration = 1 })

            -- position mount at ground level
            if class.freedomtype ~= "boat" then
                local top = tes3vector3.new(0, 0, mount.object.boundingBox.max.z)
                local z = lib.getGroundZ(mount.position + top)
                if not z then
                    z = tes3.player.position.z
                end
                mount.position = tes3vector3.new(mount.position.x, mount.position.y,
                    z + (class.offset * class.scale))
            end
            mount.orientation = tes3.player.orientation

            -- register vehicle with ticker
            local vehicle = interop.newVehicle(mount.id)
            if not vehicle then
                return
            end

            self:Attach(vehicle)
            vehicle:StartPlayerSteer()

            -- register events
            event.register(tes3.event.mouseWheel, lib.mouseWheelCallback)
            event.register(tes3.event.keyDown, mountKeyDownCallback)
            event.register(tes3.event.keyUp, keyUpCallback)
            event.register(tes3.event.simulated, mountSimulatedCallback)

            -- visualize debug marker
            -- TODO debug
            -- if DEBUG and travelMarkerMesh then
            --     local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
            --     local child = travelMarkerMesh:clone()
            --     local from = tes3.getPlayerEyePosition() + tes3.getPlayerEyeVector() * 256
            --     child.translation = from
            --     child.appCulled = false
            --     ---@diagnostic disable-next-line: param-type-mismatch
            --     vfxRoot:attachChild(child)
            --     vfxRoot:update()
            --     travelMarker = child
            -- end
        end)
    })
end

--#endregion

--#region methods

---@param reference tes3reference
local function isTracked(reference)
    return reference.tempData.CPlayerSteerManager == true
end

---@param reference tes3reference
function CPlayerSteerManager:destroy(reference)
    if isTracked(reference) then
        self.trackedVehicle:Delete()
    end
end

---@param vehicle CVehicle
function CPlayerSteerManager:Attach(vehicle)
    self.trackedVehicle = vehicle
    self.trackedVehicle.referenceHandle:getObject().tempData.CPlayerSteerManager = true
end

function CPlayerSteerManager:Detach()
    self.trackedVehicle.referenceHandle:getObject().tempData.CPlayerSteerManager = false
    self.trackedVehicle = nil
end

---
---@param reference tes3reference
function CPlayerSteerManager:isOnMount(reference)
    -- TODO debug
    if reference == self.trackedVehicle.referenceHandle:getObject() then
        log:debug("isOnMount equal reference")
    end

    if isTracked(reference) then
        return self.trackedVehicle:isOnMount()
    end

    return false
end

--#endregion

--#region ui

---@param testpos tes3vector3
---@return boolean
local function checkIsCollision(testpos)
    -- raycast fore and aft to check boundaries
    local hitResult = tes3.rayTest({
        position = testpos,
        direction = tes3vector3.new(0, 0, -1),
        root = tes3.game.worldObjectRoot,
        maxDistance = 2048
    })

    if not hitResult then
        hitResult = tes3.rayTest({
            position = testpos,
            direction = tes3vector3.new(0, 0, -1),
            root = tes3.game.worldPickRoot,
            maxDistance = 2048
        })
    end

    -- no result means no collision
    return hitResult ~= nil
end

--- @param ref tes3reference
--- @param id string
---@return boolean
local function trySpawnBoat(ref, id)
    local data = interop.getVehicleStaticData(id)
    if not data then
        log:error("No data found for %s", id)
        return false
    end

    local refpos = ref.position
    local playerEyePositionZ = tes3.getPlayerEyePosition().z
    log:debug("Try spawning %s at position %s", id, refpos)

    -- local rotation = ref.sceneNode.worldTransform.rotation
    -- local rotation = tes3.player.sceneNode.worldTransform.rotation
    local orientation = tes3.player.orientation
    local rotation = tes3matrix33.new()
    rotation:fromEulerXYZ(orientation.x, orientation.y, orientation.z)
    -- rotate matrix 90 degrees
    rotation = rotation * tes3matrix33.new(
        0, 1, 0,
        -1, 0, 0,
        0, 0, 1
    )

    -- get bounding box
    local mesh = tes3.loadMesh(data.mesh)
    local box = mesh:createBoundingBox()
    local max = box.max
    local min = box.min

    -- go in concentric circles around ref
    for i = 1, 20, 1 do
        local radius = i * 50
        -- check in a circle around ref in 45 degree steps
        for angle = 0, 360, 45 do
            local angle_rad = math.rad(angle)

            -- test position in water
            local x = refpos.x + radius * math.cos(angle_rad)
            local y = refpos.y + radius * math.sin(angle_rad)
            local testpos = tes3vector3.new(x, y, data.offset)

            -- check angles in 45 degree steps


            -- for z = 0, 360, 45 do
            --     -- rotate matrix 45 degrees
            --     if z > 0 then
            --         rotation = rotation * tes3matrix33.new(
            --             math.cos(math.rad(z)), -math.sin(math.rad(z)), 0,
            --             math.sin(math.rad(z)), math.cos(math.rad(z)), 0,
            --             0, 0, 1
            --         )
            --     end



            local t = tes3transform:new(rotation, testpos, data.scale)

            -- test four corners of bounding box from top and X
            --- @type tes3vector3[]
            local tests = {}
            tests[1] = t * tes3vector3.new(0, 0, 0)
            tests[2] = t * tes3vector3.new(max.x, max.y, 0)
            tests[3] = t * tes3vector3.new(max.x, min.y, 0)
            tests[4] = t * tes3vector3.new(min.x, max.y, 0)
            tests[5] = t * tes3vector3.new(min.x, min.y, 0)
            tests[6] = t * tes3vector3.new(max.x, 0, 0)
            tests[7] = t * tes3vector3.new(min.x, 0, 0)
            tests[8] = t * tes3vector3.new(0, max.y, 0)
            tests[9] = t * tes3vector3.new(0, min.y, 0)
            tests[10] = t * tes3vector3.new(max.x / 2, 0, 0)
            tests[11] = t * tes3vector3.new(min.x / 2, 0, 0)


            local collision = false
            for _, test in ipairs(tests) do
                test.z = playerEyePositionZ
                -- check if a collision found
                if checkIsCollision(test) then
                    collision = true
                    break
                end
            end

            if not collision then
                -- debug
                -- local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
                -- vfxRoot:detachAllChildren()

                -- for _, test in ipairs(tests) do
                --     if travelMarkerMesh then
                --         local child = travelMarkerMesh:clone()
                --         child.translation = test
                --         child.rotation = rotation
                --         child.appCulled = false
                --         ---@diagnostic disable-next-line: param-type-mismatch
                --         vfxRoot:attachChild(child)
                --     end
                -- end
                -- vfxRoot:update()

                tes3.createReference {
                    object = id,
                    position = testpos,
                    orientation = rotation:toEulerXYZ(),
                    scale = data.scale
                }
                log:debug("\tSpawning %s at %s", id, testpos)
                return true
            end
            -- end
        end
    end

    log:debug("No suitable position found")
    tes3.messageBox("No suitable position found")
    return false
end

--- no idea why this is needed
---@param menu tes3uiElement
local function updatePurchaseButton(menu)
    timer.frame.delayOneFrame(function()
        if not menu then return end
        local button = menu:findChild("rf_id_purchase_topic")
        if not button then return end
        button.visible = true
        button.disabled = false
    end)
end

---@param menu tes3uiElement
---@param ref tes3reference
function CPlayerSteerManager.createPurchaseTopic(menu, ref)
    local divider = menu:findChild("MenuDialog_divider")
    local topicsList = divider.parent
    local button = topicsList:createTextSelect({
        id = "rf_id_purchase_topic",
        text = "Purchase"
    })
    button.widthProportional = 1.0
    button.visible = true
    button.disabled = false

    topicsList:reorderChildren(divider, button, 1)

    button:register("mouseClick", function()
        local buttons = {}

        for _, id in ipairs(interop.vehicles) do
            local class = interop.getVehicleStaticData(id)
            if not class then
                goto continue
            end
            local data = class.userData
            if not data then
                goto continue
            end

            -- check if data is a boat
            -- TODO add other mounts
            if class.freedomtype == "boat" then
                local buttonText = string.format("Buy %s for %s gold", data.name, data.price)
                table.insert(buttons, {
                    text = buttonText,
                    callback = function(e)
                        -- check gold
                        local goldCount = tes3.getPlayerGold()
                        if data.price and goldCount < data.price then
                            tes3.messageBox("You don't have enough gold")
                            return
                        end

                        local success = tes3.payMerchant({ merchant = ref.mobile, cost = data.price })
                        if success then
                            if trySpawnBoat(ref, id) then
                                tes3.messageBox("You bought a new boat!")
                            end
                        else
                            tes3.messageBox("You don't have enough gold")
                        end

                        tes3ui.leaveMenuMode()
                    end,
                })
            end
            ::continue::
        end

        tes3ui.showMessageMenu({ message = "Purchase a mount", buttons = buttons, cancels = true })
    end)
    menu:registerAfter("update", function() updatePurchaseButton(menu) end)
end

--#endregion

return CPlayerSteerManager
