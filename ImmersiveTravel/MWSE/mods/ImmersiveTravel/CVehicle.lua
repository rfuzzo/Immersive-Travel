local CTickingEntity = require("ImmersiveTravel.CTickingEntity")
local CPlayerTravelManager = require("ImmersiveTravel.CPlayerTravelManager")
local lib = require("ImmersiveTravel.lib")
local log = lib.log

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
---@field node niNode?

-- Define the CVehicle class inheriting from CTickingEntity
---@class CVehicle : CTickingEntity
-- serialized properties
---@field id string
---@field sound string[] The mount sound id
---@field loopSound boolean The mount sound id
---@field mesh string The mount mesh path
---@field offset number The mount offset to ground
---@field sway number The sway intensity
---@field speed number forward speed
---@field turnspeed number turning speed
---@field hasFreeMovement boolean turning speed
---@field slots Slot[]
---@field guideSlot Slot?
---@field hiddenSlot HiddenSlot?
---@field clutter Clutter[]?
---@field idList string[]?
---@field scale number?
---@field nodeName string? -- niNode, slots are relative tho this
---@field nodeOffset tes3vector3? -- position of the nodeName relative to sceneNode
---@field forwardAnimation string? -- walk animation
-- runtime variables
---@field last_position tes3vector3
---@field last_forwardDirection tes3vector3
---@field last_facing number
---@field last_sway number
---@field swayTime number
---@field currentSpline PositionRecord[]?
---@field splineIndex number
local CVehicle = {
    -- Add properties here
    sound = {},
    loopSound = false,
    mesh = "",
    offset = 0,
    sway = 0,
    speed = 0,
    turnspeed = 0,
    hasFreeMovement = false,
    slots = {},
    guideSlot = nil,
    hiddenSlot = nil,
    clutter = {},
    idList = {},
    scale = 0,
    nodeName = "",
    nodeOffset = nil,
    forwardAnimation = "",
    -- runtime
    swayTime = 0,
}
setmetatable(CVehicle, { __index = CTickingEntity })

--#region variables
local ANIM_CHANGE_FREQ = 10   -- change passenger animations every 10 seconds
local SWAY_MAX_AMPL = 3       -- how much the ship can sway in a turn
local SWAY_AMPL_CHANGE = 0.01 -- how much the ship can sway in a turn
local SWAY_FREQ = 0.12        -- how fast the mount sways
local SWAY_AMPL = 0.014       -- how much the mount sways
--#endregion

---Constructor for CVehicle
---@param reference tes3reference
function CVehicle:new(reference)
    local newObj = CTickingEntity:new(reference)
    self.__index = self
    setmetatable(newObj, self)

    self:OnCreate()

    return newObj
end

--#region events

--- OnCreate is called when the vehicle is created
function CVehicle:OnCreate()
    -- TODO checks?
    local mount = self.referenceHandle:getObject()

    self.last_position = mount.position
    self.last_forwardDirection = mount.forwardDirection
    self.last_facing = mount.facing
    self.last_sway = 0

    -- animation
    if self.forwardAnimation then
        tes3.loadAnimation({ reference = mount })
        local forwardAnimation = self.forwardAnimation
        tes3.playAnimation({ reference = mount, group = tes3.animationGroup[forwardAnimation] })
    end

    -- sounds
    if self.loopSound then
        local sound = self.sound[math.random(1, #self.sound)]
        tes3.playSound({
            sound = sound,
            reference = mount,
            loop = true
        })
    end

    -- register statics
    if self.clutter then
        log:debug("> registering statics")
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
                    self:registerStatic(tes3.makeSafeObjectHandle(inst), index)
                else
                    local inst =
                        tes3.createReference {
                            object = clutter.id,
                            position = mount.position,
                            orientation = mount.orientation
                        }
                    self:registerStatic(tes3.makeSafeObjectHandle(inst), index)
                end
            end
        end
    end
end

--- OnStartPlayerTravel is called when the player starts traveling
---@param guideId string The ID of the guide object.
---@param spline PositionRecord[] The spline to travel on.
function CVehicle:OnStartPlayerTravel(spline, guideId)
    -- TODO checks?
    local mount = self.referenceHandle:getObject()

    self.currentSpline = spline

    -- register guide
    if self.guideSlot then
        local guide2 = tes3.createReference {
            object = guideId,
            position = mount.position,
            orientation = mount.orientation
        }
        guide2.mobile.hello = 0
        log:debug("> registering guide")
        self:registerGuide(tes3.makeSafeObjectHandle(guide2))
    end

    -- register player
    log:debug("> registering player")
    tes3.player.position = mount.position
    self:registerRefInRandomSlot(tes3.makeSafeObjectHandle(tes3.player))
    tes3.player.facing = mount.facing

    -- register followers
    local followers = lib.getFollowers()
    log:debug("> registering %s followers", #followers)
    for index, follower in ipairs(followers) do
        local handle = tes3.makeSafeObjectHandle(follower)
        local result = self:registerRefInRandomSlot(handle)
        if not result then
            self:registerRefInHiddenSlot(handle)
        end
    end

    -- register passengers
    self:RegisterPassengers()
end

function CVehicle:OnEndPlayerTravel()
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

function CVehicle:OnDestinationReached()
    -- TODO notify travel manager
    CPlayerTravelManager.getInstance():OnDestinationReached()
end

--#endregion

--#region CTickingEntity methods

-- Define the CVehicle class inheriting from CTickingEntity
function CVehicle:Delete()
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


    -- TODO checks?
    local mount = self.referenceHandle:getObject()

    if self.currentSpline == nil then
        return
    end
    if self.splineIndex > #self.currentSpline then
        self:OnDestinationReached()
        return
    end

    -- move the vehicle
    local boneOffset = tes3vector3.new(0, 0, 0)
    local rootBone = mount.sceneNode
    if self.nodeName then
        rootBone = mount.sceneNode:getObjectByName(self.nodeName) --[[@as niNode]]
        boneOffset = self.nodeOffset
    end
    if rootBone == nil then
        rootBone = mount.sceneNode
    end
    if rootBone == nil then
        return
    end
    local playerShipLocal = rootBone.worldTransform:invert() * tes3.player.position
    -- player TODO check id player is in freemovement mode
    if self.hasFreeMovement and self:isOnMount() then
        -- this is needed to enable collisions :todd:
        tes3.dataHandler:updateCollisionGroupsForActiveCells {}
        mount.sceneNode:update()
        tes3.player.position = rootBone.worldTransform * playerShipLocal
    end

    local mountOffset = tes3vector3.new(0, 0, self.offset)
    local nextPos = self.currentSpline[self.splineIndex]
    local currentPos = self.last_position - mountOffset

    -- calculate diffs
    local forwardDirection = self.last_forwardDirection
    forwardDirection:normalize()
    local d = (nextPos - currentPos):normalized()
    local lerp = forwardDirection:lerp(d, self.turnspeed / 10):normalized()

    -- calculate position
    local forward = tes3vector3.new(mount.forwardDirection.x, mount.forwardDirection.y, lerp.z):normalized()
    local delta = forward * self.speed

    -- calculate facing
    local turn = 0
    local current_facing = self.last_facing
    local new_facing = math.atan2(d.x, d.y)
    local facing = new_facing
    local diff = new_facing - current_facing
    if diff < -math.pi then diff = diff + 2 * math.pi end
    if diff > math.pi then diff = diff - 2 * math.pi end
    local angle = self.turnspeed / 10000
    if diff > 0 and diff > angle then
        facing = current_facing + angle
        turn = 1
    elseif diff < 0 and diff < -angle then
        facing = current_facing - angle
        turn = -1
    else
        facing = new_facing
    end

    -- move
    mount.facing = facing
    mount.position = currentPos + delta + mountOffset

    -- save
    self.last_position = mount.position
    self.last_forwardDirection = mount.forwardDirection
    self.last_facing = mount.facing

    -- set sway
    local amplitude = SWAY_AMPL * self.sway
    local sway_change = amplitude * SWAY_AMPL_CHANGE
    local changeAnims = false
    self.swayTime = self.swayTime + dt
    if self.swayTime > (2000 * SWAY_FREQ) then self.swayTime = dt end

    -- periodically change anims and play sounds
    local i, f = math.modf(self.swayTime)
    if i > 0 and f < dt and math.fmod(i, ANIM_CHANGE_FREQ) == 0 then
        changeAnims = true

        if not self.loopSound and math.random() > 0.5 then
            local sound = self.sound[math.random(1, #self.sound)]
            tes3.playSound({
                sound = sound,
                reference = mount
            })
        end
    end

    local sway = amplitude *
        math.sin(2 * math.pi * SWAY_FREQ * self.swayTime)
    -- offset roll during turns
    if turn > 0 then
        local max = (SWAY_MAX_AMPL * amplitude)
        sway = math.clamp(self.last_sway - sway_change, -max, max) -- - sway
    elseif turn < 0 then
        local max = (SWAY_MAX_AMPL * amplitude)
        sway = math.clamp(self.last_sway + sway_change, -max, max) -- + sway
    else
        -- normalize back
        if self.last_sway < (sway - sway_change) then
            sway = self.last_sway + sway_change -- + sway
        elseif self.last_sway > (sway + sway_change) then
            sway = self.last_sway - sway_change -- - sway
        end
    end
    self.last_sway = sway
    local newOrientation = lib.toWorldOrientation(
        tes3vector3.new(0.0, sway, 0.0),
        mount.orientation)
    mount.orientation = newOrientation



    --#region slots

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
    if self.guideSlot then
        local guide = self.guideSlot.handle:getObject()
        tes3.positionCell({
            reference = guide,
            position = rootBone.worldTransform *
                self:getSlotTransform(self.guideSlot.position, boneOffset)
        })
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
            if clutter.handle and clutter.handle:valid() then
                clutter.handle:getObject().position = rootBone.worldTransform *
                    self:getSlotTransform(clutter.position, boneOffset)
                if clutter.orientation then
                    clutter.handle:getObject().orientation =
                        lib.toWorldOrientation(lib.radvec(clutter.orientation), mount.orientation)
                end
            end
        end
    end

    --#endregion

    -- move to next marker
    local isBehind = lib.isPointBehindObject(lib.vec(nextPos), mount.position, forward)
    if isBehind then
        self.splineIndex = self.splineIndex + 1
    end
end

--#endregion

--#region CVehicle methods

--- Registers the passengers for the vehicle.
function CVehicle:RegisterPassengers()
    -- TODO checks?
    local mount = self.referenceHandle:getObject()

    -- register passengers
    local maxPassengers = math.max(0, #self.slots - 2)
    if maxPassengers > 0 then
        local n = math.random(maxPassengers);
        log:debug("> registering %s / %s passengers", n, maxPassengers)
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

-- player is within the surface of the mount
---@return boolean
function CVehicle:isOnMount()
    -- TODO checks?
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

-- you can register a guide with the vehicle
---@param handle mwseSafeObjectHandle|nil
function CVehicle:registerGuide(handle)
    if self.guideSlot and handle and handle:valid() then
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

        log:debug("registered %s in guide slot with animgroup %s", reference.id, group)
    end
end

-- you can register clutter with the vehicle
---@param handle mwseSafeObjectHandle|nil
---@param i integer
function CVehicle:registerStatic(handle, i)
    self.clutter[i].handle = handle

    if handle and handle:valid() then
        log:debug("registered %s in static slot %s", handle:getObject().id, i)
    end
end

local PASSENGER_HELLO = 10

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
            reference.mobile.hello = PASSENGER_HELLO;
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

        log:debug("registered %s in slot %s with animgroup %s", reference.id, idx, group)
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

        log:debug("registered %s in hidden slot #%s", reference.id, idx)
    end
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

-- cleanup all variables
function CVehicle:cleanup()
    log:debug("cleanup")

    -- TODO checks?
    local mount = self.referenceHandle:getObject()
    tes3.removeSound({ reference = mount })

    -- delete guide
    if self.guideSlot.handle and self.guideSlot.handle:valid() then
        self.guideSlot.handle:getObject():delete()
        self.guideSlot.handle = nil
    end

    -- delete passengers
    for index, slot in ipairs(self.slots) do
        if slot.handle and slot.handle:valid() then
            local ref = slot.handle:getObject()
            if ref ~= tes3.player and not lib.isFollower(ref.mobile) then
                ref:delete()
                slot.handle = nil
            end
        end
    end

    -- delete statics
    if self.clutter then
        for index, clutter in ipairs(self.clutter) do
            if clutter.handle and clutter.handle:valid() then
                clutter.handle:getObject():delete()
                clutter.handle = nil
            end
        end
    end
end

--#endregion

return CVehicle
