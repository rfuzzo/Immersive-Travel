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

---@param id string
---@param position tes3vector3
---@param orientation tes3vector3
---@param facing number
---@return CBoat
function CBoat:create(id, position, orientation, facing)
    local newObj = CVehicle:create(id, position, orientation, facing)
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj CBoat

    return newObj
end

return CBoat
