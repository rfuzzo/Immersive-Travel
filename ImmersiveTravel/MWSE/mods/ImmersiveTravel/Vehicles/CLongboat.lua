local lib = require("ImmersiveTravel.lib")
local CBoat = require("ImmersiveTravel.Vehicles.CBoat")

-- Define the CLongboat class inheriting from CBoat
---@class CLongboat : CBoat
local CLongboat = {
    id = "a_longboat",
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
setmetatable(CLongboat, { __index = CBoat })

---Constructor for CLongboat
---@param position tes3vector3
---@param orientation tes3vector3
---@param facing number
---@return CLongboat
function CLongboat:create(position, orientation, facing)
    -- create reference
    local mountOffset = tes3vector3.new(0, 0, self.offset)
    local reference = tes3.createReference {
        object = self.id,
        position = position + mountOffset,
        orientation = orientation
    }
    reference.facing = facing

    local newObj = CBoat:create(reference)
    self.__index = self
    setmetatable(newObj, self)

    newObj:OnCreate()

    return newObj
end

return CLongboat
