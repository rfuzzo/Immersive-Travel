local CAbstractState   = require("ImmersiveTravel.Statemachine.CAbstractState")
local lib              = require("ImmersiveTravel.lib")
local GTrackingManager = require("ImmersiveTravel.GTrackingManager")
local GRoutesManager   = require("ImmersiveTravel.GRoutesManager")
local CAiState         = require("ImmersiveTravel.Statemachine.ai.CAiState")
local worldConfig      = require("ImmersiveTravelAddonWorld.config")

local log              = lib.log

-- Abstract locomotion state machine class
---@class CLocomotionState : CAbstractState
local CLocomotionState = {
    transitions = {}
}
setmetatable(CLocomotionState, { __index = CAbstractState })

local EVADE_RADIUS          = 1024 * 3
local EVADE_FORWARD_OFFSET  = 0.1
local EVADE_TURN_MULT       = 2.0

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
    return (vehicle.routeId or vehicle.virtualDestination) and vehicle.changeSpeed == 0 and
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

    if vehicle.changeSpeed ~= 0 then
        return false
    end

    return vehicle.current_speed > -0.5 and vehicle.current_speed < 0.5
end

--- transition to accelerate state
---@param ctx table
---@return boolean
local function toAccelerateState(ctx)
    local vehicle = ctx.scriptedObject ---@cast vehicle CVehicle
    return (vehicle.routeId or vehicle.virtualDestination) and vehicle.changeSpeed > 0
end

--- transition to decelerate state
---@param ctx table
---@return boolean
local function toDecelerateState(ctx)
    local vehicle = ctx.scriptedObject ---@cast vehicle CVehicle
    return (vehicle.routeId or vehicle.virtualDestination) and vehicle.changeSpeed < 0
end

--#endregion

--#region IdleState

-- Idle state class
---@class IdleState : CLocomotionState
CLocomotionState.IdleState = {
    name = CLocomotionState.IDLE,
    states = {
        CLocomotionState.MOVING,
        CLocomotionState.ACCELERATE,
        CLocomotionState.DECELERATE,
    },
    transitions = {
        toMovingState,
        toAccelerateState,
        toDecelerateState
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
    states = {
        CLocomotionState.IDLE,
        CLocomotionState.ACCELERATE,
        CLocomotionState.DECELERATE,
    },
    transitions = {
        toIdleState,
        toAccelerateState,
        toDecelerateState
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

---@param vehicle CVehicle
---@param nextPos tes3vector3
---@return tes3vector3, number, number
local function CalculatePositions(vehicle, nextPos)
    local mount         = vehicle.referenceHandle:getObject()

    local mountOffset   = tes3vector3.new(0, 0, vehicle.offset)
    local currentPos    = vehicle.last_position - mountOffset

    -- change position when about to collide
    local virtualpos    = nextPos
    local current_speed = vehicle.current_speed
    local turnspeed     = vehicle.current_turnspeed

    -- only in onspline AI states
    -- evade
    local rootBone      = vehicle:GetRootBone()
    local enableEvade   = false --worldConfig and worldConfig.enableEvade
    if enableEvade and rootBone and vehicle.aiStateMachine.currentState.name == CAiState.ONSPLINE then
        local result = nil
        local is_evading = false;

        -- get tracked objects
        for _, other_vehicle in pairs(GTrackingManager.getInstance().trackingList) do
            ---@cast other_vehicle CVehicle
            if other_vehicle ~= vehicle and currentPos:distance(other_vehicle.last_position) < 8192 then
                -- if any vehicle is too close, evade
                if currentPos:distance(other_vehicle.last_position) < EVADE_RADIUS then
                    local local_distance = rootBone.worldTransform:invert() * (other_vehicle.last_position - currentPos)
                    local_distance.z = 0
                    local_distance:normalize()

                    -- check if other vehicle is in front of this vehicle
                    if local_distance.y > 0 then
                        if local_distance.x > EVADE_FORWARD_OFFSET then
                            -- result is the local distance vector rotated by 90 degrees to the left around the z axis
                            result = tes3vector3.new(-local_distance.y, local_distance.x, 0)
                        else
                            -- result is the local distance vector rotated by 90 degrees to the right around the z axis
                            result = tes3vector3.new(local_distance.y, -local_distance.x, 0)
                        end

                        result:normalize()
                        result = result * 1024

                        break
                    end

                    is_evading = true
                end
            end
        end

        -- evade
        if is_evading then
            -- increase the angle speed during maneuvres
            turnspeed = turnspeed * EVADE_TURN_MULT
        end

        if result then
            -- -- lower the speed
            -- current_speed = current_speed * EVADE_SPEED_MULT
            -- override the next position temporarily
            virtualpos = rootBone.worldTransform * result
            virtualpos.z = currentPos.z
        end
    end

    local isReversing = vehicle.current_speed < 0

    -- calculate diffs
    local forwardDirection = vehicle.last_forwardDirection
    if isReversing then
        forwardDirection = tes3vector3.new(-forwardDirection.x, -forwardDirection.y, forwardDirection.z)
    end

    forwardDirection:normalize()
    local d = (virtualpos - currentPos):normalized()
    local lerp = forwardDirection:lerp(d, turnspeed / 10):normalized()
    local f = mount.forwardDirection
    local forward = tes3vector3.new(f.x, f.y, lerp.z):normalized()
    -- TODO fix for vehicle steering
    if isReversing then
        forward = tes3vector3.new(-f.x, -f.y, lerp.z):normalized()
    end
    local delta = forward * math.abs(current_speed)
    local position = currentPos + delta + mountOffset

    -- calculate facing
    local turn = 0

    local current_facing = vehicle.last_facing
    local new_facing = math.atan2(d.x, d.y)
    local facing = new_facing
    local diff = new_facing - current_facing
    if diff < -math.pi then diff = diff + 2 * math.pi end
    if diff > math.pi then diff = diff - 2 * math.pi end
    local angle = turnspeed / 10000
    if diff > 0 and diff > angle then
        facing = current_facing + angle
        turn = 1
        if isReversing then
            facing = current_facing - angle
        end
    elseif diff < 0 and diff < -angle then
        facing = current_facing - angle
        turn = -1
        if isReversing then
            facing = current_facing + angle
        end
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
        -- check if close to virtual destination
        if vehicle.last_position:distance(vehicle.virtualDestination) < 100 then
            return nil
        end

        return vehicle.virtualDestination
    end

    -- move on spline
    if not vehicle.routeId then return nil end

    local service = GRoutesManager.getInstance():GetService(vehicle.serviceId)
    if not service then return nil end

    local route = service:GetRoute(vehicle.routeId)
    if not route then return nil end

    local spline = route:GetSegmentRoute(service, route.segments[vehicle.segmentIndex])
    if not spline then return nil end

    -- check if we are at the end of all segments
    if vehicle.segmentIndex > #route.segments then
        return nil
    end

    -- check if we need to move to the next segment
    if vehicle.splineIndex > #spline then
        -- TODO move to method
        vehicle.segmentIndex = vehicle.segmentIndex + 1

        local nextSegment = service:GetSegment(route.segments[vehicle.segmentIndex])
        -- check if we are at the end of all segments again
        if not nextSegment then
            log:trace("No more segments")
            return nil
        end
        log:trace("Moving to the next segment: '%s'", nextSegment.id)

        -- new route in the new segment
        spline = route:GetSegmentRoute(service, route.segments[vehicle.segmentIndex])
        assert(spline, "Route not found")

        vehicle.splineIndex = 2 -- NOTE it needs to be 2 because we are already at the first position
    end

    -- move to next marker
    local nextPos = spline[vehicle.splineIndex]
    local isBehind = lib.isPointBehindObject(nextPos, vehicle.last_position, vehicle.last_forwardDirection)
    if isBehind then
        vehicle.splineIndex = vehicle.splineIndex + 1
        log:warn("Move %s: nextPos is behind", vehicle:Id())
    end

    return nextPos
end

---@param dt number
---@param vehicle CVehicle
local function Move(vehicle, dt)
    if not vehicle.referenceHandle:valid() then
        log:warn("Move %s: referenceHandle is invalid", vehicle:Id())
        return
    end

    local nextPos = getNextPositionHeading(vehicle)
    if nextPos == nil then
        -- log:warn("Move %s: nextPos is nil", vehicle:Id())
        return
    end

    -- speed change
    if vehicle.changeSpeed > 0 and vehicle.current_speed >= vehicle.maxSpeed then
        vehicle.changeSpeed = 0
    end
    if vehicle.changeSpeed < 0 and vehicle.current_speed <= vehicle.minSpeed then
        vehicle.changeSpeed = 0
    end

    if vehicle.changeSpeed ~= 0 then
        local change = vehicle.current_speed + (vehicle.changeSpeed * dt)
        vehicle.current_speed = math.clamp(change, vehicle.minSpeed, vehicle.maxSpeed)
    end

    -- move
    local position, facing, turn = CalculatePositions(vehicle, nextPos)

    -- move the reference
    --- local skipMove = false
    -- TODO skip move when in unloaded cell
    -- if vehicle.aiStateMachine.currentState.name == CAiState.ONSPLINE then
    --     local behind = lib.isPointBehindObject(position, tes3.player.position, tes3.player.forwardDirection)
    --     if behind then
    --         skipMove = true
    --     end
    -- end

    local mount = vehicle.referenceHandle:getObject()

    --if not skipMove then
    mount.facing = facing
    mount.position = position
    --end

    -- save positions
    vehicle.last_position = mount.position
    vehicle.last_forwardDirection = mount.forwardDirection --  calculate this
    vehicle.last_facing = mount.facing

    ---if not skipMove then
    -- sway
    if vehicle.current_speed > 0 then
        mount.orientation = calculateOrientation(vehicle, dt, turn)
    end
    -- update slots
    vehicle:UpdateSlots(dt)
    --else
    --  unregister slots
    --end
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
    states = {
        CLocomotionState.IDLE,
        CLocomotionState.MOVING,
        CLocomotionState.DECELERATE,
    },
    transitions = {
        toIdleState,
        toMovingState,
        toDecelerateState
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
    states = {
        CLocomotionState.IDLE,
        CLocomotionState.MOVING,
        CLocomotionState.ACCELERATE,
    },
    transitions = {
        toIdleState,
        toMovingState,
        toAccelerateState
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
