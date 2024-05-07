local CVehicle = require("ImmersiveTravel.Vehicles.CVehicle")
local lib      = require("ImmersiveTravel.lib")
local log      = lib.log

-- Define the CBoat class inheriting from CVehicle
---@class CBoat : CVehicle
local CBoat    = {
    sound = { "Boat Hull" },
    freedomtype = "boat",
}
setmetatable(CBoat, { __index = CVehicle })

---Constructor for CBoat
---@return CBoat
function CBoat:new()
    local newObj = CVehicle:new()
    self.__index = self
    setmetatable(newObj, self)

    -- set default values
    newObj.sound = { "Boat Hull" }
    newObj.freedomtype = "boat"

    ---@cast newObj CBoat
    return newObj
end

return CBoat
