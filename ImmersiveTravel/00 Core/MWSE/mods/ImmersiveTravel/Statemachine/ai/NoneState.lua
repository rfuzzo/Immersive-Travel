local CAiState       = require("ImmersiveTravel.Statemachine.ai.CAiState")
local lib            = require("ImmersiveTravel.lib")
local GRoutesManager = require("ImmersiveTravel.GRoutesManager")

local log            = lib.log

---@param ctx any
---@return boolean?
function ToOnSpline(ctx)
    local vehicle = ctx.scriptedObject ---@cast vehicle CVehicle
    if vehicle:isPlayerInGuideSlot() then
        return false
    end

    return vehicle.currentPort == nil and vehicle.routeId ~= nil
end

-- None State class
---@class NoneState : CAiState
local NoneState = {
    name = CAiState.NONE,
    transitions = {
        [CAiState.PLAYERSTEER] = CAiState.ToPlayerSteer,
        [CAiState.ONSPLINE] = ToOnSpline,
        -- TODO the port states
    }
}
setmetatable(NoneState, { __index = CAiState })

-- constructor for NoneState
---@return NoneState
function NoneState:new()
    local newObj = CAiState:new()
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj NoneState
    return newObj
end

---@param scriptedObject CTickingEntity
function NoneState:OnActivate(scriptedObject)
    local vehicle = scriptedObject ---@cast vehicle CVehicle

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
            local mount = vehicle.referenceHandle:getObject()
            if vehicle.freedomtype ~= "boat" then
                local top = tes3vector3.new(0, 0, mount.object.boundingBox.max.z)
                local z = lib.getGroundZ(mount.position + top)
                if not z then
                    z = tes3.player.position.z
                end
                mount.position = tes3vector3.new(mount.position.x, mount.position.y,
                    z + (vehicle.offset * vehicle.scale))
            end
            mount.orientation = tes3.player.orientation

            -- transition to player steer state
            vehicle:StartPlayerSteer()
        end)
    })
end

return NoneState
