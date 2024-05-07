local CAbstractState   = require("ImmersiveTravel.Statemachine.CAbstractState")
local lib              = require("ImmersiveTravel.lib")
local CTrackingManager = require("ImmersiveTravel.CTrackingManager")
local GRoutesManager   = require("ImmersiveTravel.GRoutesManager")
local CAiState         = require("ImmersiveTravel.Statemachine.ai.CAiState")

-- Abstract locomotion state machine class
---@class CLocomotionState : CAbstractState
local CLocomotionState = {
    transitions = {}
}
setmetatable(CLocomotionState, { __index = CAbstractState })

--#region methods

-- enum for locomotion states
CLocomotionState.IDLE       = "IDLE"
CLocomotionState.MOVING     = "MOVING"
CLocomotionState.ACCELERATE = "ACCELERATE"
CLocomotionState.DECELERATE = "DECELERATE"

---Constructor for LocomotionState
---@return CLocomotionState
function CLocomotionState:new()
    local newObj = CAbstractState:new()
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj CLocomotionState
    return newObj
end

--- transition to moving state
---@param ctx table
---@return boolean
local function toMovingState(ctx)
    local vehicle = ctx.scriptedObject ---@cast vehicle CVehicle
    return (vehicle.routeId or vehicle.virtualDestination) and vehicle.speedChange == 0 and
        (vehicle.current_speed > 0.5 or vehicle.current_speed < -0.5)
end

--- transition to idle state
---@param ctx table
---@return boolean
local function toIdleState(ctx)
    local vehicle = ctx.scriptedObject ---@cast vehicle CVehicle

    -- if no spline and no virtual destination, then idle
    if vehicle.routeId == nil and vehicle.virtualDestination == nil then
        return true
    end

    if vehicle.speedChange ~= 0 then
        return false
    end

    return vehicle.current_speed < 0.5 and vehicle.current_speed > -0.5
end

--- transition to accelerate state
---@param ctx table
---@return boolean
local function toAccelerateState(ctx)
    local vehicle = ctx.scriptedObject ---@cast vehicle CVehicle
    return (vehicle.routeId or vehicle.virtualDestination) and vehicle.speedChange > 0
end

--- transition to decelerate state
---@param ctx table
---@return boolean
local function toDecelerateState(ctx)
    local vehicle = ctx.scriptedObject ---@cast vehicle CVehicle
    return (vehicle.routeId or vehicle.virtualDestination) and vehicle.speedChange < 0
end

--#endregion

--#region IdleState

-- Idle state class
---@class IdleState : CLocomotionState
CLocomotionState.IdleState = {
    name = CLocomotionState.IDLE,
    transitions = {
        [CLocomotionState.MOVING] = toMovingState,
        [CLocomotionState.ACCELERATE] = toAccelerateState,
        [CLocomotionState.DECELERATE] = toDecelerateState
    }
}
setmetatable(CLocomotionState.IdleState, { __index = CLocomotionState })

-- constructor for IdleState
---@return IdleState
function CLocomotionState.IdleState:new()
    local newObj = CLocomotionState:new()
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj IdleState
    return newObj
end

function CLocomotionState.IdleState:enter(scriptedObject)
    local vehicle = scriptedObject ---@cast vehicle CVehicle

    if vehicle.current_sound then
        local mount = vehicle.referenceHandle:getObject()
        tes3.removeSound({ reference = mount, sound = vehicle.current_sound })
        vehicle.current_sound = nil
    end

    -- play anim
    if vehicle.animation and vehicle.animation.idle then
        tes3.loadAnimation({ reference = vehicle.referenceHandle:getObject() })
        tes3.playAnimation({
            reference = vehicle.referenceHandle:getObject(),
            group = vehicle.animation.idle
        })
    end
end

--#endregion

--#region MovingState

-- Moving state class
---@class MovingState : CLocomotionState
CLocomotionState.MovingState = {
    name = CLocomotionState.MOVING,
    transitions = {
        [CLocomotionState.IDLE] = toIdleState,
        [CLocomotionState.ACCELERATE] = toAccelerateState,
        [CLocomotionState.DECELERATE] = toDecelerateState
    }
}
setmetatable(CLocomotionState.MovingState, { __index = CLocomotionState })

-- constructor for MovingState
---@return MovingState
function CLocomotionState.MovingState:new()
    local newObj = CLocomotionState:new()
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj MovingState
    return newObj
end

--#region methods

---comment
---@param origin tes3vector3
---@param forwardVector tes3vector3
---@param target tes3vector3
---@param coneRadius number
---@param coneAngle number
---@return boolean
local function isPointInCone(origin, forwardVector, target, coneRadius,
                             coneAngle)
    -- Calculate the vector from the origin to the target point
    local toTarget = target - origin

    -- Calculate the cosine of the angle between the forward vector and the vector to the target
    local dotProduct = forwardVector:dot(toTarget)

    -- Calculate the magnitudes of both vectors
    local forwardMagnitude = forwardVector:length()
    local toTargetMagnitude = toTarget:length()

    -- Calculate the cosine of the angle between the vectors
    local cosAngle = dotProduct / (forwardMagnitude * toTargetMagnitude)

    -- Calculate the angle in radians
    local angleInRadians = math.acos(cosAngle)

    -- Check if the angle is less than or equal to half of the cone angle and the distance is within the cone radius
    if angleInRadians <= coneAngle / 2 and toTargetMagnitude <= coneRadius then
        return true
    else
        return false
    end
end

---@param referenceVector tes3vector3
---@param targetVector tes3vector3
---@return boolean
local function isVectorRight(referenceVector, targetVector)
    local crossProduct =
        referenceVector.x * targetVector.y - referenceVector.y * targetVector.x

    if crossProduct > 0 then
        return true  -- "right"
    elseif crossProduct < 0 then
        return false -- "left"
    else
        return false --- "collinear"  -- The vectors are collinear
    end
end

---@param vehicle CVehicle
---@param nextPos tes3vector3
---@return tes3vector3, number, number
local function CalculatePositions(vehicle, nextPos)
    local mount = vehicle.referenceHandle:getObject()

    local mountOffset = tes3vector3.new(0, 0, vehicle.offset)
    local currentPos = vehicle.last_position - mountOffset

    -- change position when about to collide
    local virtualpos = nextPos

    -- only in onspline AI states
    -- TODO
    -- if vehicle.aiStateMachine.currentState.name == CAiState.ONSPLINE then
    --     local evade_right = false
    --     local collision = false
    --     -- get tracked objects
    --     for index, value in pairs(CTrackingManager.getInstance().trackingList) do
    --         ---@cast value CVehicle
    --         if value ~= vehicle and currentPos:distance(value.last_position) < 8192 then
    --             -- TODO what values to use here?
    --             local check = isPointInCone(currentPos, vehicle.last_forwardDirection, value.last_position, 6144, 0.785)
    --             if check then
    --                 collision = true
    --                 evade_right = isVectorRight(vehicle.last_forwardDirection, value.last_position - currentPos)
    --                 break
    --             end
    --         end
    --     end
    --     -- evade
    --     if collision then
    --         local rootBone = vehicle:GetRootBone()
    --         if rootBone then
    --             -- override the next position temporarily
    --             if evade_right then
    --                 -- evade to the right
    --                 virtualpos = rootBone.worldTransform * tes3vector3.new(1204, 1024, nextPos.z)
    --             else
    --                 -- evade to the left
    --                 virtualpos = rootBone.worldTransform * tes3vector3.new(-1204, 1024, nextPos.z)
    --             end
    --         else
    --             lib.log:debug("CalculatePositions %s: rootBone is nil", vehicle:Id())
    --         end
    --     end
    -- end

    -- calculate diffs
    local forwardDirection = vehicle.last_forwardDirection
    forwardDirection:normalize()
    local d = (virtualpos - currentPos):normalized()
    local lerp = forwardDirection:lerp(d, vehicle.turnspeed / 10):normalized()
    local forward = tes3vector3.new(mount.forwardDirection.x, mount.forwardDirection.y, lerp.z):normalized()
    local delta = forward * vehicle.current_speed
    local position = currentPos + delta + mountOffset

    -- calculate facing
    local new_facing = math.atan2(d.x, d.y)
    local turn = 0
    local current_facing = vehicle.last_facing
    local facing = new_facing
    local diff = new_facing - current_facing
    if diff < -math.pi then diff = diff + 2 * math.pi end
    if diff > math.pi then diff = diff - 2 * math.pi end
    local angle = vehicle.turnspeed / 10000
    if diff > 0 and diff > angle then
        facing = current_facing + angle
        turn = 1
    elseif diff < 0 and diff < -angle then
        facing = current_facing - angle
        turn = -1
    else
        facing = new_facing
    end

    return position, facing, turn
end

---@param vehicle CVehicle
---@param dt number
---@param turn number
local function calculateOrientation(vehicle, dt, turn)
    local mount = vehicle.referenceHandle:getObject()

    local amplitude = lib.SWAY_AMPL * vehicle.sway
    local sway_change = amplitude * lib.SWAY_AMPL_CHANGE

    vehicle.swayTime = vehicle.swayTime + dt
    if vehicle.swayTime > (2000 * lib.SWAY_FREQ) then vehicle.swayTime = dt end

    -- periodically change anims and play sounds
    local i, f = math.modf(vehicle.swayTime)
    if i > 0 and f < dt and math.fmod(i, lib.ANIM_CHANGE_FREQ) == 0 then
        if not vehicle.loopSound and math.random() > 0.5 then
            local sound = vehicle.sound[math.random(1, #vehicle.sound)]
            vehicle.current_sound = sound
            tes3.playSound({
                sound = sound,
                reference = mount
            })
        end
    end

    local sway = amplitude *
        math.sin(2 * math.pi * lib.SWAY_FREQ * vehicle.swayTime)
    -- offset roll during turns
    if turn > 0 then
        local max = (lib.SWAY_MAX_AMPL * amplitude)
        sway = math.clamp(vehicle.last_sway - sway_change, -max, max) -- - sway
    elseif turn < 0 then
        local max = (lib.SWAY_MAX_AMPL * amplitude)
        sway = math.clamp(vehicle.last_sway + sway_change, -max, max) -- + sway
    else
        -- normalize back
        if vehicle.last_sway < (sway - sway_change) then
            sway = vehicle.last_sway + sway_change -- + sway
        elseif vehicle.last_sway > (sway + sway_change) then
            sway = vehicle.last_sway - sway_change -- - sway
        end
    end
    vehicle.last_sway = sway
    local newOrientation = lib.toWorldOrientation(tes3vector3.new(0.0, sway, 0.0), mount.orientation)

    return newOrientation
end

---@param vehicle CVehicle
---@return tes3vector3?
local function getNextPositionHeading(vehicle)
    -- handle player steer and onspline states
    if vehicle.virtualDestination then
        return vehicle.virtualDestination
    end

    -- move on spline
    if vehicle.routeId == nil then
        return nil
    end

    local spline = GRoutesManager.getInstance().routes[vehicle.routeId]
    if spline == nil then
        return nil
    end
    if vehicle.splineIndex > #spline then
        return nil
    end

    -- move to next marker
    local nextPos = lib.vec(spline[vehicle.splineIndex])
    local isBehind = lib.isPointBehindObject(nextPos, vehicle.last_position, vehicle.last_forwardDirection)
    if isBehind then
        vehicle.splineIndex = vehicle.splineIndex + 1
    end
    if vehicle.splineIndex > #spline then
        return nil
    end

    nextPos = lib.vec(spline[vehicle.splineIndex])

    return nextPos
end

---@param dt number
---@param vehicle CVehicle
local function Move(vehicle, dt)
    if not vehicle.referenceHandle:valid() then
        lib.log:warn("Move %s: referenceHandle is invalid", vehicle:Id())
        return
    end

    local nextPos = getNextPositionHeading(vehicle)
    if nextPos == nil then
        lib.log:warn("Move %s: nextPos is nil", vehicle:Id())
        return
    end

    -- speed change
    if vehicle.speedChange > 0 then
        local change = vehicle.current_speed + (vehicle.changeSpeed * dt)
        vehicle.current_speed = math.clamp(change, vehicle.minSpeed, vehicle.maxSpeed)
    elseif vehicle.speedChange < 0 then
        local change = vehicle.current_speed - (vehicle.changeSpeed * dt)
        vehicle.current_speed = math.clamp(change, vehicle.minSpeed, vehicle.maxSpeed)
    end

    -- skip
    if vehicle.minSpeed then
        if vehicle.current_speed < vehicle.minSpeed then
            lib.log:warn("Move %s: current_speed < minSpeed", vehicle:Id())
            return
        end
    end

    local position, facing, turn = CalculatePositions(vehicle, nextPos)

    -- move the reference
    local skipMove = false
    -- if vehicle.aiStateMachine.currentState.name == CAiState.ONSPLINE then
    --     local behind = lib.isPointBehindObject(position, tes3.player.position, tes3.player.forwardDirection)
    --     if behind then
    --         skipMove = true
    --     end
    -- end

    local mount = vehicle.referenceHandle:getObject()

    if not skipMove then
        mount.facing = facing
        mount.position = position
    end

    -- save positions
    vehicle.last_position = mount.position
    vehicle.last_forwardDirection = mount.forwardDirection
    vehicle.last_facing = mount.facing

    if not skipMove then
        -- sway
        mount.orientation = calculateOrientation(vehicle, dt, turn)
        -- update slots
        vehicle:UpdateSlots(dt)
    else
        -- TODO unregister slots
    end
end

--#endregion

---@param scriptedObject CTickingEntity
function CLocomotionState.MovingState:enter(scriptedObject)
    local vehicle = scriptedObject ---@cast vehicle CVehicle

    -- sounds
    if vehicle.loopSound then
        local sound = vehicle.sound[math.random(1, #vehicle.sound)]
        vehicle.current_sound = sound
        tes3.playSound({
            sound = sound,
            reference = vehicle.referenceHandle:getObject(),
            loop = true
        })
    end

    -- play anim
    if vehicle.animation and vehicle.animation.forward then
        -- local forwardAnimation = self.forwardAnimation
        -- if config.a_siltstrider_forwardAnimation then
        --     forwardAnimation = config.a_siltstrider_forwardAnimation
        -- end

        tes3.loadAnimation({ reference = vehicle.referenceHandle:getObject() })
        tes3.playAnimation({
            reference = vehicle.referenceHandle:getObject(),
            group = vehicle.animation.forward
        })
    end
end

---@param dt number
---@param scriptedObject CTickingEntity
function CLocomotionState.MovingState:update(dt, scriptedObject)
    -- Implement moving state update logic here
    local vehicle = scriptedObject ---@cast vehicle CVehicle
    Move(vehicle, dt)
end

--#endregion

--#region AccelerateState

-- Accelerate state class
---@class AccelerateState : CLocomotionState
CLocomotionState.AccelerateState = {
    name = CLocomotionState.ACCELERATE,
    transitions = {
        [CLocomotionState.IDLE] = toIdleState,
        [CLocomotionState.MOVING] = toMovingState,
        [CLocomotionState.DECELERATE] = toDecelerateState
    }
}
setmetatable(CLocomotionState.AccelerateState, { __index = CLocomotionState })

-- constructor for MovingState
---@return AccelerateState
function CLocomotionState.AccelerateState:new()
    local newObj = CLocomotionState:new()
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj AccelerateState
    return newObj
end

function CLocomotionState.AccelerateState:enter(scriptedObject)
    local vehicle = scriptedObject ---@cast vehicle CVehicle
    -- play anim
    if vehicle.animation and vehicle.animation.accelerate then
        tes3.loadAnimation({ reference = vehicle.referenceHandle:getObject() })
        tes3.playAnimation({
            reference = vehicle.referenceHandle:getObject(),
            group = vehicle.animation.accelerate
        })
    end
end

---@param dt number
---@param scriptedObject CTickingEntity
function CLocomotionState.AccelerateState:update(dt, scriptedObject)
    -- Implement moving state update logic here
    local vehicle = scriptedObject ---@cast vehicle CVehicle
    Move(vehicle, dt)
end

--#endregion

--#region DecelerateState

-- Decelerate state class
---@class DecelerateState : CLocomotionState
CLocomotionState.DecelerateState = {
    name = CLocomotionState.DECELERATE,
    transitions = {
        [CLocomotionState.IDLE] = toIdleState,
        [CLocomotionState.MOVING] = toMovingState,
        [CLocomotionState.ACCELERATE] = toAccelerateState
    }
}
setmetatable(CLocomotionState.DecelerateState, { __index = CLocomotionState })

-- constructor for MovingState
---@return DecelerateState
function CLocomotionState.DecelerateState:new()
    local newObj = CLocomotionState:new()
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj DecelerateState
    return newObj
end

function CLocomotionState.DecelerateState:enter(scriptedObject)
    local vehicle = scriptedObject ---@cast vehicle CVehicle
    -- play anim
    if vehicle.animation and vehicle.animation.decelerate then
        tes3.loadAnimation({ reference = vehicle.referenceHandle:getObject() })
        tes3.playAnimation({
            reference = vehicle.referenceHandle:getObject(),
            group = vehicle.animation.decelerate
        })
    end
end

---@param dt number
---@param scriptedObject CTickingEntity
function CLocomotionState.DecelerateState:update(dt, scriptedObject)
    -- Implement moving state update logic here
    local vehicle = scriptedObject ---@cast vehicle CVehicle
    Move(vehicle, dt)
end

--#endregion

return CLocomotionState
