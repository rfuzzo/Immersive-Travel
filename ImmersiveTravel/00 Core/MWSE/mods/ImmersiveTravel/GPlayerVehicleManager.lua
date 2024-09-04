-- Define a class to manage the tracking list and timer
---@class GPlayerVehicleManager
---@field trackedVehicle CVehicle?
---@field free_movement boolean
---@field travelMarkerId  string
---@field travelMarkerMesh any?
---@field travelMarker     niNode?
local PlayerVehicleManager = {
    -- debug
    travelMarkerId = "marker_arrow.nif"
}

function PlayerVehicleManager:new()
    local newObj = {}
    self.__index = self
    setmetatable(newObj, self)
    return newObj
end

-- singleton instance
--- @type GPlayerVehicleManager?
local instance = nil
--- @return GPlayerVehicleManager
function PlayerVehicleManager.getInstance()
    if instance == nil then
        instance = PlayerVehicleManager:new()

        -- init
        instance.trackedVehicle = nil
        instance.free_movement = false
        instance.travelMarkerMesh = tes3.loadMesh(instance.travelMarkerId)
        instance.travelMarker = nil
    end
    return instance
end

function PlayerVehicleManager:IsPlayerTraveling()
    return self.trackedVehicle ~= nil
end

return PlayerVehicleManager
