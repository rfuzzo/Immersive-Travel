local CBoat = require("ImmersiveTravel.Vehicles.CBoat")

-- Define the CRowboat class inheriting from CBoat
---@class CRowboat : CBoat
local CRowboat = {}
setmetatable(CRowboat, { __index = CBoat })

---Constructor for CRowboat
---@return CRowboat
function CRowboat:new()
    local newObj = CBoat:new()
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj CRowboat

    -- set default values
    -- set default values
    newObj.id = "a_rowboat_iv"
    newObj.sound = {
        "Boat Creak"
    }
    newObj.loopSound = true
    newObj.mesh = "iv\\Ex_De_Rowboat.nif"
    newObj.offset = 4
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
        position = tes3vector3.new(0, -45, 10)
    }
    newObj.userData = {
        name = "Rowboat",
        price = 100,
        materials = {
            { material = "wood",   count = 14 },
            { material = "rope",   count = 2 },
            { material = "fabric", count = 1 }
        }
    }

    return newObj
end

return CRowboat
