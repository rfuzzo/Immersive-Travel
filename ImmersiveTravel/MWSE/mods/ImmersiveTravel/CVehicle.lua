local CTickingEntity = require("ImmersiveTravel.CTickingEntity")
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
---@field last_position tes3vector3?
---@field last_forwardDirection tes3vector3?
---@field last_facing number?
---@field last_sway number?
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
    forwardAnimation = ""
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
    return newObj
end

--#region CTickingEntity methods

-- Define the CVehicle class inheriting from CTickingEntity
function CVehicle:Delete()
    -- cleanup
    self:cleanup()
    -- Call the superclass delete method
    CTickingEntity.Delete(self)
end

-- Define the CVehicle class inheriting from CTickingEntity
function CVehicle:OnTick()
    -- Call the superclass onTick method
    CTickingEntity.OnTick(self)

    -- move the vehicle
    -- if currentSpline == nil then
    --     cleanup()
    --     return
    -- end

    -- if last_position == nil then
    --     cleanup()
    --     return
    -- end
    -- if last_facing == nil then
    --     cleanup()
    --     return
    -- end
    -- if last_forwardDirection == nil then
    --     cleanup()
    --     return
    -- end

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

    if splineIndex <= #currentSpline then
        local mountOffset = tes3vector3.new(0, 0, self.offset)
        local nextPos = currentSpline[splineIndex]
        local currentPos = last_position - mountOffset

        -- calculate diffs
        local forwardDirection = last_forwardDirection
        forwardDirection:normalize()
        local d = (nextPos - currentPos):normalized()
        local lerp = forwardDirection:lerp(d, self.turnspeed / 10):normalized()

        -- calculate position
        local forward = tes3vector3.new(mount.forwardDirection.x, mount.forwardDirection.y, lerp.z):normalized()
        local delta = forward * self.speed
        local playerShipLocal = rootBone.worldTransform:invert() * tes3.player.position

        -- calculate facing
        local turn = 0
        local current_facing = last_facing
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
        swayTime = swayTime + TIMER_TICK
        if swayTime > (2000 * SWAY_FREQ) then swayTime = TIMER_TICK end

        -- periodically change anims and play sounds
        local i, f = math.modf(swayTime)
        if i > 0 and f < TIMER_TICK and math.fmod(i, ANIM_CHANGE_FREQ) == 0 then
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
            math.sin(2 * math.pi * SWAY_FREQ * swayTime)
        -- offset roll during turns
        if turn > 0 then
            local max = (SWAY_MAX_AMPL * amplitude)
            sway = math.clamp(last_sway - sway_change, -max, max) -- - sway
        elseif turn < 0 then
            local max = (SWAY_MAX_AMPL * amplitude)
            sway = math.clamp(last_sway + sway_change, -max, max) -- + sway
        else
            -- normalize back
            if last_sway < (sway - sway_change) then
                sway = last_sway + sway_change -- + sway
            elseif last_sway > (sway + sway_change) then
                sway = last_sway - sway_change -- - sway
            end
        end
        self.last_sway = sway
        local newOrientation = lib.toWorldOrientation(
            tes3vector3.new(0.0, sway, 0.0),
            mount.orientation)
        mount.orientation = newOrientation

        -- player
        if free_movement == true and isOnMount() then
            -- this is needed to enable collisions :todd:
            tes3.dataHandler:updateCollisionGroupsForActiveCells {}
            mount.sceneNode:update()
            tes3.player.position = rootBone.worldTransform * playerShipLocal
        end

        -- hidden slot
        if self.hiddenSlot.handles then
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

        -- move to next marker
        local isBehind = lib.isPointBehindObject(nextPos, mount.position,
            forward)
        if isBehind then splineIndex = splineIndex + 1 end
    end
end

--#endregion

--#region CVehicle methods

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

--#endregion

-- cleanup all variables
function CVehicle:cleanup()
    log:debug("cleanup")

    -- redundant
    self.last_position = nil
    self.last_forwardDirection = nil
    self.last_facing = nil
    self.last_sway = 0

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

return CVehicle
