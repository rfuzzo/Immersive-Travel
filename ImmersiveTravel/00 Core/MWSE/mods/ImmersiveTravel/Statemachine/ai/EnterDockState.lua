local CAiState              = require("ImmersiveTravel.Statemachine.ai.CAiState")
local GPlayerVehicleManager = require("ImmersiveTravel.GPlayerVehicleManager")
local lib                   = require("ImmersiveTravel.lib")
local interop               = require("ImmersiveTravel.interop")
local GRoutesManager        = require("ImmersiveTravel.GRoutesManager")

local log                   = lib.log

---@param ctx any
---@return boolean?
local function ToDocked(ctx)
    local vehicle = ctx.scriptedObject ---@cast vehicle CVehicle
    if vehicle:isPlayerInGuideSlot() then
        return false
    end

    return vehicle.currentPort ~= nil and vehicle.routeId == nil
end

-- on spline state class
---@class EnterDockState : CAiState
local EnterDockState = {
    name = CAiState.ENTERDOCK,
    states = {
        CAiState.PLAYERSTEER,
        CAiState.DOCKED,
        CAiState.NONE,
    },
    transitions = {
        CAiState.ToPlayerSteer,
        ToDocked,
        CAiState.ToNone,
    }
}
setmetatable(EnterDockState, { __index = CAiState })

-- constructor for EnterDockState
---@return EnterDockState
function EnterDockState:new()
    local newObj = CAiState:new()
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj EnterDockState
    return newObj
end

function EnterDockState:update(dt, scriptedObject)
    -- call super update
    CAiState.update(self, dt, scriptedObject)

    local vehicle = scriptedObject ---@cast vehicle CVehicle
    local spline = GRoutesManager.getInstance():GetRoute(vehicle.routeId)
    if spline == nil then
        return
    end

    -- handle player leaving and entering the vehicle
    local manager = GPlayerVehicleManager.getInstance()
    if manager.free_movement then
        if vehicle.playerRegistered and not vehicle:isPlayerInMountBounds() and manager:IsPlayerTraveling() then
            -- tes3.messageBox("You have left the vehicle")
            log:debug("[%s] Player left the vehicle on route %s", vehicle:Id(), vehicle.routeId)
            vehicle.playerRegistered = false
            manager:StopTraveling()
        elseif not vehicle.playerRegistered and vehicle:isPlayerInMountBounds() and not manager:IsPlayerTraveling() then
            -- tes3.messageBox("This is a regular service on route '%s'", vehicle.routeId)
            log:debug("[%s] Player entered the vehicle on route %s", vehicle:Id(), vehicle.routeId)
            vehicle.playerRegistered = true
            manager:StartTraveling(vehicle)
        end
    end

    if not vehicle.playerRegistered then
        if lib.IsColliding(vehicle) then
            log:debug("[%s] Collision", vehicle:Id())
            vehicle.current_speed = 0 -- this pops idle locomotion state
            vehicle.markForDelete = true
        end
    end
end

function EnterDockState:enter(scriptedObject)
    local vehicle = scriptedObject ---@cast vehicle CVehicle
    vehicle.speedChange = 0.5
    vehicle.current_turnspeed = vehicle.turnspeed * 2
end

-- Method to exit the state
---@param scriptedObject CTickingEntity
function EnterDockState:exit(scriptedObject)
    local vehicle = scriptedObject ---@cast vehicle CVehicle

    vehicle.virtualDestination = nil
end

return EnterDockState
