local CVehicle = require("ImmersiveTravel.CVehicle")

-- Define the CBoat class inheriting from CVehicle
---@class CBoat : CVehicle
local CBoat = {
    sound = { "Boat Hull" },
}
setmetatable(CBoat, { __index = CVehicle })

---Constructor for CBoat
---@param reference tes3reference
function CBoat:new(reference)
    local newObj = CVehicle:new(reference)
    self.__index = self
    setmetatable(newObj, self)
    return newObj
end

--#region CVehicle methods

-- Define the CBoat class inheriting from CVehicle
function CBoat:Delete()
    -- Call the superclass delete method
    CVehicle.Delete(self)
end

--#endregion

return CBoat
