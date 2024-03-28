local CVehicle = require("ImmersiveTravel.Vehicles.CVehicle")

-- Define the CBoat class inheriting from CVehicle
---@class CBoat : CVehicle
local CBoat = {
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
    ---@cast newObj CBoat

    return newObj
end

---@param reference tes3reference
---@return CBoat
function CBoat:create(reference)
    local newObj = CVehicle:create(reference)
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj CBoat

    return newObj
end

return CBoat
