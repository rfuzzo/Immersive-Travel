local CBoat = require("ImmersiveTravel.Vehicles.CBoat")

-- Define the CCanoe class inheriting from CBoat
---@class CCanoe : CBoat
local CCanoe = {}
setmetatable(CCanoe, { __index = CBoat })

---Constructor for CCanoe
---@return CCanoe
function CCanoe:new()
    local newObj = CBoat:new()
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj CCanoe

    -- set default values
    newObj.id = "a_canoe_01"
    newObj.sound = {
        "Boat Creak"
    }
    newObj.loopSound = true
    newObj.mesh = "x\\Ex_Gondola_01_rot.nif"
    newObj.scale = 0.7
    newObj.offset = 40
    newObj.sway = 0.7
    newObj.speed = 2
    newObj.minSpeed = -2
    newObj.maxSpeed = 7
    newObj.turnspeed = 40
    newObj.hasFreeMovement = false
    newObj.freedomtype = "boat"
    newObj.guideSlot = {
        animationGroup = { "idle6" },
        animationFile = "VA_sitting.nif",
        position = tes3vector3.new(0, -82, -15)
    }
    newObj.hiddenSlot = {
        position = tes3vector3.new(0, 0, -200)
    }
    newObj.slots = {
        {
            animationGroup = {
                "idle6"
            },
            animationFile = "VA_sitting.nif",
            position = tes3vector3.new(0, 82, -15)
        },
        {
            animationGroup = {},
            position = tes3vector3.new(0, 7, -15)
        },
    }
    newObj.clutter = {
        {
            id = "light_de_paper_lantern_01_nr",
            position = tes3vector3.new(0, -219, 56)
        },
        {
            id = "light_de_paper_lantern_04_nr",
            position = tes3vector3.new(0, 176, 17)
        }
    }
    newObj.userData = {
        name = "Canoe",
        price = 300,
        materials = {
            { material = "wood",   count = 12 },
            { material = "rope",   count = 6 },
            { material = "fabric", count = 4 },
        }
    }

    return newObj
end

return CCanoe
