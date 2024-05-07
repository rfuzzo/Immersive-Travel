local CBoat = require("ImmersiveTravel.Vehicles.CBoat")

-- Define the CRowboat class inheriting from CBoat
---@class CRowboat : CBoat
local CRowboat = {
    id = "a_rowboat_iv",
    sound = {
        "Boat Creak"
    },
    loopSound = true,
    mesh = "iv\\Ex_De_Rowboat.nif",
    offset = 4,
    sway = 1,
    speed = 2,
    minSpeed = -2,
    maxSpeed = 7,
    changeSpeed = 1.5,
    turnspeed = 30,
    scale = 1,
    guideSlot = {
        animationGroup = { "idle6" },
        animationFile = "VA_sitting.nif",
        position = tes3vector3.new(0, -45, 10)
    },
    userData = {
        name = "Rowboat",
        price = 100,
        materials = {
            { material = "wood",   count = 14 },
            { material = "rope",   count = 2 },
            { material = "fabric", count = 1 }
        }
    },
}
setmetatable(CRowboat, { __index = CBoat })

---Constructor for CRowboat
---@return CRowboat
function CRowboat:new()
    local newObj = CBoat:new()
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj CRowboat

    return newObj
end

return CRowboat
