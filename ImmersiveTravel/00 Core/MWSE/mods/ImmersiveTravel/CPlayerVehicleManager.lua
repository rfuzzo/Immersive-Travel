-- Define a class to manage the tracking list and timer
---@class CPlayerVehicleManager
---@field trackedVehicle CVehicle?
---@field free_movement boolean
local PlayerVehicleManager = {
}

function PlayerVehicleManager:new()
    local newObj = {}
    self.__index = self
    setmetatable(newObj, self)
    return newObj
end

-- singleton instance
--- @type CPlayerVehicleManager?
local instance = nil
--- @return CPlayerVehicleManager
function PlayerVehicleManager.getInstance()
    if instance == nil then
        instance = PlayerVehicleManager:new()
    end
    return instance
end

return PlayerVehicleManager
