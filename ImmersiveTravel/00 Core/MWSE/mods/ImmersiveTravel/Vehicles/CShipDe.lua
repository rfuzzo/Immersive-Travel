local CBoat = require("ImmersiveTravel.Vehicles.CBoat")

-- Define the CShipDe class inheriting from CBoat
---@class CShipDe : CBoat
local CShipDe = {
    id = "a_DE_ship",
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
setmetatable(CShipDe, { __index = CBoat })

---Constructor for CShipDe
---@return CShipDe
function CShipDe:new()
    local newObj = CBoat:new()
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj CShipDe

    return newObj
end

---Create a new instance of CShipDe
---@param id string
---@param position tes3vector3
---@param orientation tes3vector3
---@param facing number
---@return CShipDe
function CShipDe:create(id, position, orientation, facing)
    local newObj = CBoat:create(id, position, orientation, facing)
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj CShipDe

    newObj:OnCreate()

    return newObj
end

return CShipDe
