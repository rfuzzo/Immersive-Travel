local CBoat = require("ImmersiveTravel.Vehicles.CBoat")

-- Define the CTelvcatboat class inheriting from CBoat
---@class CTelvcatboat : CBoat
local CTelvcatboat = {}
setmetatable(CTelvcatboat, { __index = CBoat })

---Constructor for CTelvcatboat
---@return CTelvcatboat
function CTelvcatboat:new()
    local newObj = CBoat:new()
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj CTelvcatboat

    -- set default values
    -- set default values
    newObj.id = "a_telvcatboat_iv"
    newObj.sound = {
        "Boat Creak"
    }
    newObj.loopSound = true
    newObj.mesh = "dim\\dim_telvcatboatS.nif"
    newObj.offset = 20
    newObj.sway = 1
    newObj.speed = 2
    newObj.minSpeed = -2
    newObj.maxSpeed = 7
    newObj.changeSpeed = 1.5
    newObj.turnspeed = 30
    newObj.scale = 1
    newObj.guideSlot = {
        animationGroup = { "idle6" },
        animationFile = "VA_sitting.nif",
        position = tes3vector3.new(-109, -403, 111)
    }
    newObj.userData = {
        name = "Catboat",
        price = 1000,
        materials = {
            { material = "wood",     count = 50 },
            { material = "rope",     count = 20 },
            { material = "fabric",   count = 30 },
            { material = "mushroom", count = 20 },
        }
    }

    return newObj
end

return CTelvcatboat
