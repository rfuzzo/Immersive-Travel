local CBoat = require("ImmersiveTravel.Vehicles.CBoat")

-- Define the CShipDe class inheriting from CBoat
---@class CShipDe : CBoat
local CShipDe = {
    id = "a_DE_ship",
    sound = {
        "Boat Hull"
    },
    loopSound = true,
    mesh = "x\\Ex_DE_ship_rot.nif",
    offset = -20,
    sway = 3,
    speed = 3,
    turnspeed = 10,
    hasFreeMovement = true,
    freedomtype = "boat",
    guideSlot = {
        animationGroup = {},
        position = tes3vector3.new(-25, -823, 360)
    },
    hiddenSlot = {
        position = tes3vector3.new(0, 0, 40)
    },
    slots = {
        {
            animationGroup = {},
            position = tes3vector3.new(0, 438, 257)
        },
        {
            animationGroup = {},
            position = tes3vector3.new(0, 29, 209)
        },
        {
            animationGroup = {},
            position = tes3vector3.new(-181, 139, 209)
        },
        {
            animationGroup = {},
            position = tes3vector3.new(181, -139, 209)
        },
        {
            animationGroup = {},
            position = tes3vector3.new(115, -466, 208)
        },
    },
    clutter = {
        {
            id = "Ex_DE_ship_cabindoor",
            position = tes3vector3.new(92, -617, 261),
            orientation = tes3vector3.new(0, 0, 180),
        },
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
