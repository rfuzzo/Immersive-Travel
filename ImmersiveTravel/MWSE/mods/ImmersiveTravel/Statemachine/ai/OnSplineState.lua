local CAiState = require("ImmersiveTravel.Statemachine.ai.CAiState")

-- on spline state class
---@class OnSplineState : CAiState
local OnSplineState = {
    transitions = {
        [CAiState.NONE] = CAiState.ToNone,
        [CAiState.PLAYERSTEER] = CAiState.ToPlayerSteer,
        [CAiState.PLAYERTRAVEL] = CAiState.ToPlayerTravel,
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
    if vehicle.splineIndex > #vehicle.spline then
        -- reached end of spline
        vehicle.spline = nil
    end
end

function OnSplineState:exit(scriptedObject)
    local vehicle = scriptedObject ---@cast vehicle CVehicle
    vehicle:Delete()
end

return OnSplineState
