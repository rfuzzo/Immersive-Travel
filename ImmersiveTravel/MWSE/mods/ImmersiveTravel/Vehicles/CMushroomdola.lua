local CBoat = require("ImmersiveTravel.Vehicles.CBoat")

-- Define the CMushroomdola class inheriting from CBoat
---@class CMushroomdola : CBoat
local CMushroomdola = {}
setmetatable(CMushroomdola, { __index = CBoat })

---Constructor for CMushroomdola
---@return CMushroomdola
function CMushroomdola:new()
    local newObj = CBoat:new()
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj CMushroomdola

    -- set default values
    newObj.id = "a_mushroomdola_iv"
    newObj.sound = {
        "Boat Creak"
    }
    newObj.loopSound = true
    newObj.mesh = "dim\\dim_mushroomdola1.nif"
    newObj.offset = 40
    newObj.sway = 1
    newObj.speed = 2
    newObj.minSpeed = -2
    newObj.maxSpeed = 7
    newObj.turnspeed = 30
    newObj.scale = 1
    newObj.guideSlot = {
        animationGroup = { "idle6" },
        animationFile = "VA_sitting.nif",
        position = tes3vector3.new(-30, 0, -13)
    }
    newObj.userData = {
        name = "Mushroomdola",
        price = 300,
        materials = {
            { material = "wood",     count = 8 },
            { material = "rope",     count = 6 },
            { material = "fabric",   count = 4 },
            { material = "mushroom", count = 8 },
        }
    }

    return newObj
end

return CMushroomdola
