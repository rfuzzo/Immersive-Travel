local CAiState = require("ImmersiveTravel.Statemachine.ai.CAiState")

-- None State class
---@class NoneState : CAiState
local NoneState = {
    transitions = {
        [CAiState.ONSPLINE] = function(ctx)
            -- transition to on spline state if spline is not nil
            return false
        end,
        [CAiState.PLAYERSTEER] = function(ctx)
            -- transition to player steer state if player is in guide slot
            local vehicle = ctx.scriptedObject ---@cast vehicle CVehicle
            if vehicle and vehicle:isPlayerInGuideSlot() then
                return true
            end
            return false
        end
    }
}

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
    vehicle:StartPlayerSteer()
    -- transition to player steer state
end

return NoneState
