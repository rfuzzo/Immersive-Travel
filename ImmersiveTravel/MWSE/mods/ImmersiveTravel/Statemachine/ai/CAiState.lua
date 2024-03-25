local AbstractState = require("ImmersiveTravel.Statemachine.CAbstractState")
local lib = require("ImmersiveTravel.lib")

-- Abstract AI state machine class
---@class CAiState : CAbstractState
local CAiState = {
    transitions = {}
}

-- enum for AI states
CAiState.NONE = "NONE"
CAiState.ONSPLINE = "ONSPLINE"
CAiState.PLAYERSTEER = "PLAYERSTEER"
CAiState.PLAYERTRAVEL = "PLAYERTRAVEL"

---Constructor for AI State
---@return CAiState
function CAiState:new()
    local newObj = AbstractState:new()
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj CAiState
    return newObj
end

return CAiState
