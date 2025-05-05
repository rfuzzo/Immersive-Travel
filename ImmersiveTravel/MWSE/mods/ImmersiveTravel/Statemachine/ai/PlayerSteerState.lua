local CAiState              = require("ImmersiveTravel.Statemachine.ai.CAiState")
local GPlayerVehicleManager = require("ImmersiveTravel.GPlayerVehicleManager")
local lib                   = require("ImmersiveTravel.lib")
local config                = require("ImmersiveTravel.config")

if not config then
    return
end

-- player steer state class
---@class PlayerSteerState : CAiState
---@field cameraOffset tes3vector3?
local PlayerSteerState = {
    name         = CAiState.PLAYERSTEER,
    states       = {
        CAiState.NONE,
    },
    transitions  = {
        CAiState.ToNone,
    },
    cameraOffset = nil,
}
setmetatable(PlayerSteerState, { __index = CAiState })

-- constructor for PlayerSteerState
---@return PlayerSteerState
function PlayerSteerState:new()
    local newObj = CAiState:new()
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj PlayerSteerState
    return newObj
end

--#region events

--- hold w or s to change speed
--- @param e keyDownEventData
local function mountKeyDownCallback(e)
    local vehicle = GPlayerVehicleManager.getInstance().trackedVehicle
    if not vehicle then
        return
    end

    if e.keyCode == tes3.scanCode["w"] then
        -- increment speed
        if vehicle.current_speed < vehicle.maxSpeed then
            vehicle.changeSpeed = 1
        end
    elseif e.keyCode == tes3.scanCode["s"] then
        -- decrement speed
        if vehicle.current_speed > vehicle.minSpeed then
            vehicle.changeSpeed = -1
        end
    end
end

--- release w or s to stop changing speed
--- @param e keyUpEventData
local function keyUpCallback(e)
    local vehicle = GPlayerVehicleManager.getInstance().trackedVehicle
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
            vehicle.changeSpeed = 0
            -- if DEBUG then
            --     tes3.messageBox("Current Speed: " .. tostring(vehicle.current_speed))
            -- end
        end
    end
end

--- set virtual position
--- @param e simulatedEventData
local function mountSimulatedCallback(e)
    local vehicle = GPlayerVehicleManager.getInstance().trackedVehicle
    if not vehicle then
        return
    end

    -- update next pos
    if vehicle.referenceHandle and vehicle.referenceHandle:valid() then
        local mount = vehicle.referenceHandle:getObject()

        -- get virtual target in circle around player
        local dist = 2048
        if vehicle.freedomtype == "ground" then
            dist = 100
        end

        --local lookat = tes3.getPlayerEyeVector()
        -- local target = tes3.player.position +
        --     (tes3vector3.new(tes3.getPlayerEyeVector().x, tes3.getPlayerEyeVector().y, 0):normalized() * dist)

        local target = tes3.getPlayerEyePosition() + (tes3.getPlayerEyeVector() * dist)
        local isControlDown = tes3.worldController.inputController:isControlDown()
        if isControlDown then
            target = mount.sceneNode.worldTransform * (tes3vector3.new(0, 1, 0) * dist)
        end
        target.z = 0

        -- delegate to vehicle
        vehicle.virtualDestination = target

        -- debug
        local manager = GPlayerVehicleManager.getInstance()
        if config.logLevel == "DEBUG" and manager.travelMarker then
            manager.travelMarker.translation = target
            local m = tes3matrix33.new()
            if isControlDown then
                m:fromEulerXYZ(mount.orientation.x, mount.orientation.y, mount.orientation.z)
            else
                m:fromEulerXYZ(tes3.player.orientation.x, tes3.player.orientation.y, tes3.player.orientation.z)
            end
            manager.travelMarker.rotation = m
            manager.travelMarker:update()
        end
    end
end

--#endregion

---@param scriptedObject CTickingEntity
function PlayerSteerState:enter(scriptedObject)
    local vehicle = scriptedObject ---@cast vehicle CVehicle
    GPlayerVehicleManager.getInstance().trackedVehicle = vehicle

    -- register events
    event.register(tes3.event.mouseWheel, lib.mouseWheelCallback)
    event.register(tes3.event.keyDown, mountKeyDownCallback)
    event.register(tes3.event.keyUp, keyUpCallback)
    event.register(tes3.event.simulated, mountSimulatedCallback)

    self.cameraOffset = tes3.get3rdPersonCameraOffset()

    -- visualize debug marker
    local manager = GPlayerVehicleManager.getInstance()
    if config.logLevel == "DEBUG" and manager.travelMarkerMesh then
        local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
        local child = manager.travelMarkerMesh:clone()
        local from = tes3.getPlayerEyePosition() + tes3.getPlayerEyeVector() * 256
        child.translation = from
        child.appCulled = false
        vfxRoot:attachChild(child)
        vfxRoot:update()
        manager.travelMarker = child
    end
end

---@param dt number
---@param scriptedObject CTickingEntity
function PlayerSteerState:update(dt, scriptedObject)
    ---@cast scriptedObject CVehicle
    local vehicle = scriptedObject
    if lib.IsColliding(vehicle) then
        -- stop vehicle
        vehicle.current_speed = 0
    end
end

---@param scriptedObject CTickingEntity
function PlayerSteerState:exit(scriptedObject)
    -- reset camera
    if self.cameraOffset then
        tes3.set3rdPersonCameraOffset({ offset = self.cameraOffset })
    end

    local vehicle = scriptedObject ---@cast vehicle CVehicle

    vehicle:EndPlayerSteer()

    -- don't delete ref since we may want to use the mount later
    vehicle:Detach()
    GPlayerVehicleManager.getInstance().trackedVehicle = nil

    -- unregister events
    event.unregister(tes3.event.mouseWheel, lib.mouseWheelCallback)
    event.unregister(tes3.event.keyDown, mountKeyDownCallback)
    event.unregister(tes3.event.keyUp, keyUpCallback)
    event.unregister(tes3.event.simulated, mountSimulatedCallback)
end

---@param scriptedObject CTickingEntity
function PlayerSteerState:OnActivate(scriptedObject)
    -- exit state manually
    self:exit(scriptedObject)

    -- stop ticking
    local vehicle = scriptedObject ---@cast vehicle CVehicle
    vehicle:EndPlayerSteer()
end

return PlayerSteerState
