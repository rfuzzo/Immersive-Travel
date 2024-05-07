local CBoat = require("ImmersiveTravel.Vehicles.CBoat")

-- Define the CMushroomdola class inheriting from CBoat
---@class CMushroomdola : CBoat
local CMushroomdola = {
    id = "a_mushroomdola_iv",
    sound = {
        "Boat Creak"
    },
    loopSound = true,
    mesh = "dim\\dim_mushroomdola1.nif",
    offset = 40,
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
        position = tes3vector3.new(-30, 0, -13)
    },
    userData = {
        name = "Mushroomdola",
        price = 300,
        materials = {
            { material = "wood",     count = 8 },
            { material = "rope",     count = 6 },
            { material = "fabric",   count = 4 },
            { material = "mushroom", count = 8 },
        }
    },
}
setmetatable(CMushroomdola, { __index = CBoat })

---Constructor for CMushroomdola
---@return CMushroomdola
function CMushroomdola:new()
    local newObj = CBoat:new()
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj CMushroomdola

    return newObj
end

return CMushroomdola
