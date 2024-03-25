local CAiState = require("ImmersiveTravel.Statemachine.ai.CAiState")

-- on spline state class
---@class OnSplineState : CAiState
local OnSplineState = {
    transitions = {
        [CAiState.NONE] = function(ctx)
            -- transition to none state if spline is nil
            local vehicle = ctx.scriptedObject ---@cast vehicle CVehicle
            if vehicle then
                return vehicle.currentSpline == nil
            end

            return true
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

-- constructor for OnSplineState
---@return OnSplineState
function OnSplineState:new()
    local newObj = CAiState:new()
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj OnSplineState
    return newObj
end

function OnSplineState:enter(scriptedObject)
end

function OnSplineState:update(dt, scriptedObject)
    -- Implement on spline state update logic here
    local vehicle = scriptedObject ---@cast vehicle CVehicle
    if vehicle.splineIndex > #vehicle.currentSpline then
        -- reached end of spline
        vehicle.currentSpline = nil
    end
end

function OnSplineState:exit(scriptedObject)
    local vehicle = scriptedObject ---@cast vehicle CVehicle
    vehicle:Delete()
end

return OnSplineState
