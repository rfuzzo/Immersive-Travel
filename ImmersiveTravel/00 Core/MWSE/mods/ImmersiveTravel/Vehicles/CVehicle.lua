local CTickingEntity        = require("ImmersiveTravel.CTickingEntity")
local GPlayerVehicleManager = require("ImmersiveTravel.GPlayerVehicleManager")
local CAiState              = require("ImmersiveTravel.Statemachine.ai.CAiState")
local lib                   = require("ImmersiveTravel.lib")
local log                   = lib.log

---@class Slot
---@field position tes3vector3 slot
---@field animationGroup string[]?
---@field animationFile string?
---@field handle mwseSafeObjectHandle?
---@field node niNode?

---@class HiddenSlot
---@field position tes3vector3 slot
---@field handles mwseSafeObjectHandle[]?

---@class Clutter
---@field position tes3vector3 slot
---@field orientation tes3vector3? slot
---@field id string? reference id
---@field mesh string? reference id
---@field handle mwseSafeObjectHandle?

---@class UserData
---@diagnostic disable-next-line: undefined-doc-name
---@field materials CraftingFramework.MaterialRequirement[]? -- recipe materials for crafting the mount
---@field name string? -- name of the mount
---@field price number? -- price of the mount

---@class AnimationData
---@field idle tes3.animationGroup? -- walk animation
---@field forward tes3.animationGroup? -- walk animation
---@field accelerate tes3.animationGroup? -- animation to play while accelerating. slowing
---@field decelerate tes3.animationGroup? -- animation to play while accelerating. slowing

-- Define the CVehicle class inheriting from CTickingEntity
---@class CVehicle : CTickingEntity
---@field id string
---@field sound string[] The mount sound id
---@field loopSound boolean The mount sound id
---@field mesh string The mount mesh path
---@field offset number The mount offset to ground
---@field sway number The sway intensity
---@field turnspeed number turning speed
---@field hasFreeMovement boolean turning speed
---@field speed number travel speed
---@field maxSpeed number
---@field freedomtype string flying, boat, ground
-- optionals
---@field changeSpeed number? -- default 1
---@field minSpeed number?
---@field slots Slot[]
---@field guideSlot Slot
---@field hiddenSlot HiddenSlot?
---@field clutter Clutter[]?
---@field scale number?
---@field nodeName string? -- niNode, slots are relative tho this
---@field nodeOffset tes3vector3? -- position of the nodeName relative to sceneNode
---@field userData UserData?
---@field animation AnimationData?
-- runtime data
---@field last_position tes3vector3
---@field last_forwardDirection tes3vector3
---@field last_facing number
---@field last_sway number
---@field swayTime number
---@field routeId string? -- the id of the route
---@field splineIndex number
---@field virtualDestination tes3vector3?
---@field current_speed number
---@field current_sound string?
---@field speedChange number
---@field playerRegistered boolean
local CVehicle              = {}
setmetatable(CVehicle, { __index = CTickingEntity })

---Constructor for CVehicle
---@return CVehicle
function CVehicle:new()
    local newObj = CTickingEntity:new()
    setmetatable(newObj, self)
    self.__index = self
    ---@cast newObj CVehicle

    -- init default values
    newObj.sound = {}
    newObj.loopSound = false
    newObj.mesh = ""
    newObj.offset = 0
    newObj.sway = 0
    newObj.speed = 0
    newObj.turnspeed = 0
    newObj.hasFreeMovement = false
    newObj.slots = {}
    newObj.changeSpeed = 1
    newObj.swayTime = 0
    newObj.splineIndex = 1
    newObj.current_speed = 0
    newObj.speedChange = 0
    newObj.playerRegistered = false

    return newObj
end

--#region events

--- OnCreate is called when the vehicle is created
function CVehicle:OnCreate()
    log:trace("OnCreate %s", self.id)

    local mount = self.referenceHandle:getObject()

    self.last_position = mount.position
    self.last_forwardDirection = mount.forwardDirection
    self.last_facing = mount.facing
    self.last_sway = 0

    -- register statics
    if self.clutter then
        log:trace("\tregistering statics")
        for index, clutter in ipairs(self.clutter) do
            if clutter.id then
                -- instantiate
                if clutter.orientation then
                    local inst =
                        tes3.createReference {
                            object = clutter.id,
                            position = mount.position,
                            orientation = lib.toWorldOrientation(
                                lib.radvec(clutter.orientation),
                                mount.orientation)
                        }
                    clutter.handle = tes3.makeSafeObjectHandle(inst)
                else
                    local inst =
                        tes3.createReference {
                            object = clutter.id,
                            position = mount.position,
                            orientation = mount.orientation
                        }
                    clutter.handle = tes3.makeSafeObjectHandle(inst)
                end
                log:debug("\t\tregistered %s in static slot %s", clutter.id, index)
            end
        end
    end
end

function CVehicle:OnActivate()
    self.aiStateMachine:OnActivate(self)
end

--#endregion

--#region CVehicle methods

--- StartPlayerSteer is called when the player starts steering
function CVehicle:StartPlayerSteer()
    log:trace("StartPlayerSteer %s", self.id)
    self:OnCreate()

    -- register player as guide
    log:debug("\tregistering player")
    self:registerGuide(tes3.makeSafeObjectHandle(tes3.player))
    -- tes3.player.facing = self.referenceHandle:getObject().facing

    -- register followers
    self:RegisterFollowers()
end

--- EndPlayerSteer is called when the player leaves the vehicle
function CVehicle:EndPlayerSteer()
    log:trace("EndPlayerSteer")

    self.virtualDestination = nil
    self:release()
end

--- Starts the vehicle on a route
---@param routeId string
---@param service ServiceData
function CVehicle:StartOnSpline(routeId, service)
    self:Attach()

    log:trace("StartOnSpline %s", self:Id())

    self.routeId = routeId -- this pushes the AI statemachine
    self.current_speed = self.speed

    -- register guide
    local mount = self.referenceHandle:getObject()
    local guides = service.guide
    if guides then
        local randomIndex = math.random(1, #guides)
        local guideId = guides[randomIndex]
        local guide = tes3.createReference {
            object = guideId,
            position = mount.position,
            orientation = mount.orientation
        }
        log:debug("\tregistering guide")
        self:registerGuide(tes3.makeSafeObjectHandle(guide))
    end

    -- TODO register passengers
    -- self:RegisterPassengers()
end

--- StartPlayerTravel is called when the player starts traveling
---@param guideId string
---@param routeId string
function CVehicle:StartPlayerTravel(guideId, routeId)
    log:debug("StartPlayerTravel %s", self.id)

    -- these push the AI statemachine
    self.playerRegistered = true
    self.routeId = routeId -- this pushes the locomotion statemachine
    self.current_speed = self.speed

    local mount = self.referenceHandle:getObject()

    -- register guide
    log:debug("\tregistering guide")
    local guide = tes3.createReference {
        object = guideId,
        position = mount.position,
        orientation = mount.orientation
    }
    self:registerGuide(tes3.makeSafeObjectHandle(guide))

    guide.mobile.hello = 0

    -- register player
    log:debug("\tregistering player")
    tes3.player.position = mount.position
    self:registerRefInRandomSlot(tes3.makeSafeObjectHandle(tes3.player))
    tes3.player.facing = mount.facing

    -- register followers
    self:RegisterFollowers()

    -- register passengers
    self:RegisterPassengers()
end

function CVehicle:EndPlayerTravel()
    log:debug("EndPlayerTravel")

    self.playerRegistered = false
    self:release()
end

function CVehicle:release()
    -- reset player
    tes3.mobilePlayer.movementCollision = true;
    tes3.loadAnimation({ reference = tes3.player })
    tes3.playAnimation({ reference = tes3.player, group = 0 })

    -- teleport followers
    for index, slot in ipairs(self.slots) do
        if slot.handle and slot.handle:valid() then
            local ref = slot.handle:getObject()
            if ref ~= tes3.player and ref.mobile and
                lib.isFollower(ref.mobile) then
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

    if self.hiddenSlot.handles then
        for index, handle in ipairs(self.hiddenSlot.handles) do
            if handle and handle:valid() then
                local ref = handle:getObject()
                if ref ~= tes3.player and ref.mobile and
                    lib.isFollower(ref.mobile) then
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
        self.hiddenSlot.handles = nil
    end

    -- cleanup
    self:cleanup()
end

--- registers a ref in a random free slot
---@param handle mwseSafeObjectHandle|nil
---@return boolean
function CVehicle:registerRefInRandomSlot(handle)
    if handle and handle:valid() then
        local i = self:getRandomFreeSlotIdx()
        if not i then
            log:debug("Could not register %s in normal slot", handle:getObject().id)
            return false
        end

        self:registerInSlot(handle, i)
        return true
    end

    return false
end

-- move player to next slot and rotate registered refs in slots
function CVehicle:incrementSlot()
    local playerIdx = nil
    local idx = nil

    -- find index of next slot
    for index, slot in ipairs(self.slots) do
        if slot.handle and slot.handle:getObject() == tes3.player then
            idx = index + 1
            if idx > #self.slots then idx = 1 end
            playerIdx = index
            break
        end
    end

    -- register anew for anims
    if playerIdx and idx then
        local temp_handle = self.slots[idx].handle
        self:registerInSlot(temp_handle, playerIdx)
        self:registerInSlot(tes3.makeSafeObjectHandle(tes3.player), idx)
    end
end

--- checks if player is slotted in guide slot
---@return boolean
function CVehicle:isPlayerInGuideSlot()
    if self.guideSlot.handle and self.guideSlot.handle:valid() then
        return self.guideSlot.handle:getObject() == tes3.player
    end

    return false
end

-- player is within the surface of the mount
---@return boolean
function CVehicle:isPlayerInMountBounds()
    local mount = self.referenceHandle:getObject()


    local inside = true

    local volumeHeight = 200

    local bbox = mount.object.boundingBox

    local pos = tes3.player.position
    local surfaceOffset = self.slots[1].position.z
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

--#endregion

--#region CTickingEntity methods

-- Define the CVehicle class inheriting from CTickingEntity
function CVehicle:Delete()
    log:trace("CVehicle Delete %s", self:Id())

    -- cleanup
    self:cleanup()

    -- Call the superclass delete method
    CTickingEntity.Delete(self)
end

-- Define the CVehicle class inheriting from CTickingEntity
---@param dt number
function CVehicle:OnTick(dt)
    -- Call the superclass onTick method
    CTickingEntity.OnTick(self, dt)

    self:UpdatePlayerCollision()
end

---@param dt number
function CVehicle:UpdateSlots(dt)
    local rootBone = self:GetRootBone()
    if rootBone == nil then
        log:warn("UpdateSlots %s: rootBone is nil", self:Id())
        return
    end

    local changeAnims = false
    local i, f = math.modf(self.swayTime)
    if i > 0 and f < dt and math.fmod(i, lib.ANIM_CHANGE_FREQ) == 0 then
        changeAnims = true
    end

    -- do not animate if animstate is ONSPLINE
    if self.aiStateMachine.currentState.name == CAiState.ONSPLINE then
        changeAnims = false
    end

    local mount = self.referenceHandle:getObject()
    local boneOffset = tes3vector3.new(0, 0, 0)
    if self.nodeName then
        boneOffset = self.nodeOffset
    end

    -- hidden slot
    if self.hiddenSlot and self.hiddenSlot.handles then
        for index, handle in ipairs(self.hiddenSlot.handles) do
            if handle and handle:valid() then
                tes3.positionCell({
                    reference = handle:getObject(),
                    position = rootBone.worldTransform *
                        self:getSlotTransform(self.hiddenSlot.position, boneOffset)
                })
            end
        end
    end

    -- guide
    if self.guideSlot.handle and self.guideSlot.handle:valid() then
        local guide = self.guideSlot.handle:getObject()
        guide.position = rootBone.worldTransform * self:getSlotTransform(self.guideSlot.position, boneOffset)
        if guide ~= tes3.player then
            guide.facing = mount.facing
            -- only change anims if behind player
            if changeAnims and
                lib.isPointBehindObject(guide.position, tes3.player.position,
                    tes3.player.forwardDirection) then
                local group = lib.getRandomAnimGroup(self.guideSlot)
                local animController = guide.mobile.animationController
                if animController then
                    local currentAnimationGroup =
                        animController.animationData.currentAnimGroups[tes3.animationBodySection.upper]
                    log:trace("%s switching to animgroup %s", guide.id, group)
                    if group ~= currentAnimationGroup then
                        tes3.loadAnimation({ reference = guide })
                        if self.guideSlot.animationFile then
                            tes3.loadAnimation({
                                reference = guide,
                                file = self.guideSlot.animationFile
                            })
                        end
                        tes3.playAnimation({ reference = guide, group = group })
                    end
                end
            end
        end
    end

    -- passengers
    for index, slot in ipairs(self.slots) do
        if slot.handle and slot.handle:valid() then
            local obj = slot.handle:getObject()

            slot.handle:getObject().position = rootBone.worldTransform *
                self:getSlotTransform(slot.position, boneOffset)

            if obj ~= tes3.player then
                -- disable scripts
                if obj.baseObject.script and not lib.isFollower(obj.mobile) and obj.data.rfuzzo_noscript then
                    obj.attachments.variables.script = nil
                end

                -- only change anims if behind player
                if changeAnims and
                    lib.isPointBehindObject(obj.position,
                        tes3.player.position,
                        tes3.player.forwardDirection) then
                    local group = lib.getRandomAnimGroup(slot)
                    log:trace("%s switching to animgroup %s", obj.id, group)
                    local animController = obj.mobile.animationController
                    if animController then
                        local currentAnimationGroup = animController.animationData.currentAnimGroups
                            [tes3.animationBodySection.upper]

                        if group ~= currentAnimationGroup then
                            tes3.loadAnimation({ reference = obj })
                            if slot.animationFile then
                                tes3.loadAnimation({
                                    reference = obj,
                                    file = slot.animationFile
                                })
                            end
                            tes3.playAnimation({ reference = obj, group = group
                            })
                        end
                    end
                end
            end
        end
    end

    -- statics
    if self.clutter then
        for index, clutter in ipairs(self.clutter) do
            if clutter.handle == nil then
                log:warn("UpdateSlots %s: clutter handle is nil", self:Id())
            end

            if clutter.handle and clutter.handle:valid() then
                if not clutter.handle:valid() then
                    log:warn("UpdateSlots %s: clutter handle is invalid", self:Id())
                end

                clutter.handle:getObject().position = rootBone.worldTransform *
                    self:getSlotTransform(clutter.position, boneOffset)
                if clutter.orientation then
                    clutter.handle:getObject().orientation =
                        lib.toWorldOrientation(lib.radvec(clutter.orientation), mount.orientation)
                end
            end
        end
    end
end

---@return niNode?
function CVehicle:GetRootBone()
    if not self.referenceHandle then
        log:trace("GetRootBone %s: referenceHandle is nil", self:Id())
        return nil
    end
    if not self.referenceHandle:valid() then
        log:trace("GetRootBone %s: referenceHandle is invalid", self:Id())
        return nil
    end

    local mount = self.referenceHandle:getObject()
    if not mount then
        log:trace("GetRootBone %s: mount is nil", self:Id())
        return nil
    end

    local rootBone = mount.sceneNode
    if not rootBone then
        log:trace("GetRootBone %s: sceneNode is nil", self:Id())
        return nil
    end

    if self.nodeName then
        rootBone = mount.sceneNode:getObjectByName(self.nodeName) --[[@as niNode]]
    end
    if rootBone == nil then
        rootBone = mount.sceneNode
    end

    return rootBone
end

-- you can register a guide with the vehicle
---@param handle mwseSafeObjectHandle|nil
function CVehicle:registerGuide(handle)
    if handle and handle:valid() then
        self.guideSlot.handle = handle
        -- tcl
        local reference = handle:getObject()
        reference.mobile.movementCollision = false;
        reference.data.rfuzzo_invincible = true;

        -- play animation
        local group = lib.getRandomAnimGroup(self.guideSlot)
        tes3.loadAnimation({ reference = reference })
        if self.guideSlot.animationFile then
            tes3.loadAnimation({
                reference = reference,
                file = self.guideSlot.animationFile
            })
        end
        tes3.playAnimation({ reference = reference, group = group })

        log:debug("\t\tregistered %s in guide slot with animgroup %s", reference.id, group)
    end
end

--#endregion

--#region private CVehicle methods

function CVehicle:UpdatePlayerCollision()
    -- check if player is in freemovement mode
    if self.hasFreeMovement and GPlayerVehicleManager.getInstance().free_movement and self:isPlayerInMountBounds() then
        log:trace("UpdatePlayerCollision %s", self:Id())

        -- move player when on vehicle
        local rootBone = self:GetRootBone()
        if rootBone == nil then
            log:trace("UpdatePlayerCollision %s: rootBone is nil", self:Id())
            return
        end

        local playerShipLocal = rootBone.worldTransform:invert() * tes3.player.position
        -- this is needed to enable collisions :todd:
        tes3.dataHandler:updateCollisionGroupsForActiveCells {}
        self.referenceHandle:getObject().sceneNode:update()
        tes3.player.position = rootBone.worldTransform * playerShipLocal
    end
end

-- cleanup all variables
function CVehicle:cleanup()
    log:trace("CVehicle cleanup %s", self:Id())

    local mount = self.referenceHandle:getObject()
    tes3.removeSound({ reference = mount })

    -- delete guide
    log:debug("\tDeleting guide:")
    if self.guideSlot.handle and self.guideSlot.handle:valid() then
        if self.guideSlot.handle:getObject() ~= tes3.player then
            log:debug("\t\tdeleted %s", self.guideSlot.handle:getObject().id)

            self.guideSlot.handle:getObject():delete()
            self.guideSlot.handle = nil
        end
    end

    -- delete passengers
    log:debug("\tDeleting passengers:")
    for index, slot in ipairs(self.slots) do
        if slot.handle and slot.handle:valid() then
            local ref = slot.handle:getObject()
            if ref ~= tes3.player and not lib.isFollower(ref.mobile) then
                log:debug("\t\tdeleted %s", ref.id)

                ref:delete()
                slot.handle = nil
            end
        end
    end

    -- delete statics
    if self.clutter then
        log:debug("\tDeleting clutter:")
        for index, clutter in ipairs(self.clutter) do
            if clutter.handle and clutter.handle:valid() then
                log:debug("\t\tdeleted %s", clutter.handle:getObject().id)

                clutter.handle:getObject():delete()
            end
            clutter.handle = nil
        end
    end
end

function CVehicle:RegisterFollowers()
    local followers = lib.getFollowers()
    log:debug("\tregistering %s followers", #followers)
    for index, follower in ipairs(followers) do
        local handle = tes3.makeSafeObjectHandle(follower)
        local result = self:registerRefInRandomSlot(handle)
        if not result then
            self:registerRefInHiddenSlot(handle)
        end
    end
end

--- Registers the passengers for the vehicle.
function CVehicle:RegisterPassengers()
    local mount = self.referenceHandle:getObject()

    -- register passengers
    local maxPassengers = math.max(0, #self.slots - 2)
    if maxPassengers > 0 then
        local n = math.random(maxPassengers);
        log:debug("\tregistering %s / %s passengers", n, maxPassengers)
        for _i, value in ipairs(lib.getRandomNpcsInCell(n)) do
            local passenger = tes3.createReference {
                object = value,
                position = mount.position,
                orientation = mount.orientation
            }
            -- disable scripts
            if passenger.baseObject.script then
                passenger.attachments.variables.script = nil
                passenger.data.rfuzzo_noscript = true;

                log:debug("Disabled script %s on %s", passenger.baseObject.script.id, passenger.baseObject.id)
            end

            local refHandle = tes3.makeSafeObjectHandle(passenger)
            self:registerRefInRandomSlot(refHandle)
        end
    end
end

--- registers a ref in a slot
---@param handle mwseSafeObjectHandle|nil
---@param idx integer
function CVehicle:registerInSlot(handle, idx)
    self.slots[idx].handle = handle

    -- play animation
    if handle and handle:valid() then
        local slot = self.slots[idx]
        local reference = handle:getObject()
        -- disable physics
        reference.mobile.movementCollision = false;

        if reference ~= tes3.player then
            -- disable greetings
            reference.data.rfuzzo_invincible = true;
            reference.mobile.hello = lib.PASSENGER_HELLO;
        end

        local group = lib.getRandomAnimGroup(slot)
        tes3.loadAnimation({ reference = reference })
        if slot.animationFile then
            tes3.loadAnimation({
                reference = reference,
                file = slot.animationFile
            })
        end
        tes3.playAnimation({ reference = reference, group = group })

        log:debug("\t\tregistered %s in slot %s with animgroup %s", reference.id, idx, group)
    end
end

--- get a random free slot index
---@return integer|nil index
function CVehicle:getRandomFreeSlotIdx()
    local nilIndices = {}

    -- Collect indices of nil entries
    for index, value in ipairs(self.slots) do
        if value.handle == nil then table.insert(nilIndices, index) end
    end

    -- Check if there are nil entries
    if #nilIndices > 0 then
        local randomIndex = math.random(1, #nilIndices)
        return nilIndices[randomIndex]
    else
        return nil -- No nil entries found
    end
end

---@param slotPosition tes3vector3
---@param boneOffset tes3vector3
function CVehicle:getSlotTransform(slotPosition, boneOffset)
    local transform = slotPosition
    if self.nodeName then
        local o = slotPosition - boneOffset
        transform = tes3vector3.new(o.x, -o.z, o.y)
    end
    return transform
end

-- register a ref in the hidden slot container
---@param handle mwseSafeObjectHandle|nil
function CVehicle:registerRefInHiddenSlot(handle)
    if self.hiddenSlot.handles == nil then self.hiddenSlot.handles = {} end

    if handle and handle:valid() then
        local idx = #self.hiddenSlot.handles + 1
        self.hiddenSlot.handles[idx] = handle
        -- tcl
        local reference = handle:getObject()
        reference.mobile.movementCollision = false;
        reference.data.rfuzzo_invincible = true;

        log:debug("\t\tregistered %s in hidden slot #%s", reference.id, idx)
    end
end

--#endregion

return CVehicle
