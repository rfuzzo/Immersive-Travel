local CBoat     = require("ImmersiveTravel.Vehicles.CBoat")
local lib       = require("ImmersiveTravel.lib")
local log       = lib.log

-- Define the CLongboat class inheriting from CBoat
---@class CLongboat : CBoat
local CLongboat = {}
setmetatable(CLongboat, { __index = CBoat })

---Constructor for CLongboat
---@return CLongboat
function CLongboat:new()
    local newObj = CBoat:new()
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj CLongboat

    -- set default values
    newObj.id = "a_longboat"
    newObj.sound = {
        "Boat Hull"
    }
    newObj.loopSound = true
    newObj.mesh = "x\\Ex_longboat_rot.nif"
    newObj.offset = 74
    newObj.sway = 4
    newObj.speed = 4
    newObj.minSpeed = -2
    newObj.maxSpeed = 4
    newObj.changeSpeed = 1.5
    newObj.turnspeed = 24
    newObj.hasFreeMovement = true
    newObj.freedomtype = "boat"
    newObj.serviceId = "Shipmaster"
    newObj.guideSlot = {
        animationGroup = {},
        position = tes3vector3.new(67, -457, -65)
    }
    newObj.hiddenSlot = {
        position = tes3vector3.new(0, 0, -200)
    }
    newObj.slots = {
        {
            animationGroup = {},
            position = tes3vector3.new(0, 411, -63)
        },
        {
            animationGroup = {},
            position = tes3vector3.new(-132, 67, -63)
        },
        {
            animationGroup = {},
            position = tes3vector3.new(160, -145, -63)
        },
        {
            animationGroup = {},
            position = tes3vector3.new(-79, -390, -67)
        },
        {
            animationGroup = {
                "idle6"
            },
            animationFile = "VA_sitting.nif",
            position = tes3vector3.new(0, 133, -26)
        },
        {
            animationGroup = {
                "idle6"
            },
            animationFile = "VA_sitting.nif",
            position = tes3vector3.new(-122, -181, -27)
        },
        {
            animationGroup = {
                "idle6"
            },
            animationFile = "VA_sitting.nif",
            position = tes3vector3.new(87, -259, -27)
        }
    }
    newObj.clutter = {
        {
            id = "light_com_lantern_01",
            position = tes3vector3.new(0, 623, 28)
        },
        {
            id = "light_com_lantern_02",
            position = tes3vector3.new(0, -585, 18)
        }
    }

    return newObj
end

return CLongboat
