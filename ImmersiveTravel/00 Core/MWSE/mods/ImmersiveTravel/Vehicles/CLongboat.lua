local CBoat = require("ImmersiveTravel.Vehicles.CBoat")

-- Define the CLongboat class inheriting from CBoat
---@class CLongboat : CBoat
local CLongboat = {
    id = "a_longboat",
    sound = {
        "Boat Hull"
    },
    loopSound = true,
    mesh = "x\\Ex_longboat_rot.nif",
    offset = 74,
    sway = 4,
    speed = 4,
    turnspeed = 24,
    hasFreeMovement = true,
    freedomtype = "boat",
    guideSlot = {
        animationGroup = {},
        position = tes3vector3.new(67, -457, -65)
    },
    hiddenSlot = {
        position = tes3vector3.new(0, 0, -200)
    },
    slots = {
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
    },
    clutter = {
        {
            id = "light_com_lantern_01",
            position = tes3vector3.new(0, 623, 28)
        },
        {
            id = "light_com_lantern_02",
            position = tes3vector3.new(0, -585, 18)
        }
    }

}
setmetatable(CLongboat, { __index = CBoat })

---Constructor for CLongboat
---@return CLongboat
function CLongboat:new()
    local newObj = CBoat:new()
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj CLongboat

    return newObj
end

---Create a new instance of CLongboat
---@param id string
---@param position tes3vector3
---@param orientation tes3vector3
---@param facing number
---@return CLongboat
function CLongboat:create(id, position, orientation, facing)
    local newObj = CBoat:create(id, position, orientation, facing)
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj CLongboat

    newObj:OnCreate()

    return newObj
end

return CLongboat
