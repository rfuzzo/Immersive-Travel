local CBoat = require("ImmersiveTravel.Vehicles.CBoat")

-- Define the CSailboat class inheriting from CBoat
---@class CSailboat : CBoat
local CSailboat = {}
setmetatable(CSailboat, { __index = CBoat })

---Constructor for CSailboat
---@return CSailboat
function CSailboat:new()
    local newObj = CBoat:new()
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj CSailboat

    -- set default values
    -- set default values
    newObj.id = "a_sailboat_iv"
    newObj.sound = {
        "Boat Creak"
    }
    newObj.loopSound = true
    newObj.mesh = "iv\\sky_ex_fisherboat_02.nif"
    newObj.offset = 20
    newObj.sway = 1
    newObj.speed = 2
    newObj.minSpeed = -2
    newObj.maxSpeed = 7
    newObj.changeSpeed = 1.5
    newObj.turnspeed = 30
    newObj.scale = 0.7
    newObj.guideSlot = {
        animationGroup = { "idle6" },
        animationFile = "VA_sitting.nif",
        position = tes3vector3.new(-30, -96, 25)
    }
    newObj.userData = {
        name = "Small boat",
        price = 700,
        materials = {
            { material = "wood",   count = 30 },
            { material = "rope",   count = 10 },
            { material = "fabric", count = 20 }
        }
    }

    return newObj
end

return CSailboat
