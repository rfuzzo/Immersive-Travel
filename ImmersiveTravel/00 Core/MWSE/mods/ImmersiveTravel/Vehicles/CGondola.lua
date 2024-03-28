local CBoat = require("ImmersiveTravel.Vehicles.CBoat")

-- Define the CGondola class inheriting from CBoat
---@class CGondola : CBoat
local CGondola = {
    id = "a_gondola_01",
    sound = {
        "Boat Creak"
    },
    loopSound = true,
    mesh = "x\\Ex_Gondola_01_rot.nif",
    scale = 1,
    offset = 40,
    sway = 1,
    speed = 2,
    minSpeed = -2,
    maxSpeed = 7,
    turnspeed = 40,
    hasFreeMovement = false,
    freedomtype = "boat",
    guideSlot = {
        animationGroup = { "idle6" },
        position = tes3vector3.new(0, -171, -18)
    },
    hiddenSlot = {
        position = tes3vector3.new(0, 0, -200)
    },
    slots = {
        {
            animationGroup = {
                "idle6"
            },
            animationFile = "VA_sitting.nif",
            position = tes3vector3.new(0, 82, -15)
        },
        {
            animationGroup = {
                "idle6"
            },
            animationFile = "VA_sitting.nif",
            position = tes3vector3.new(0, -82, -15)
        },
        {
            animationGroup = {},
            position = tes3vector3.new(0, 7, -15)
        },
    },
    clutter = {
        {
            id = "light_de_paper_lantern_01_nr",
            position = tes3vector3.new(0, -219, 56)
        },
        {
            id = "light_de_paper_lantern_04_nr",
            position = tes3vector3.new(0, 176, 17)
        }
    },
    userData = {
        name = "Gondola",
        price = 500,
        materials = {
            { material = "wood",   count = 20 },
            { material = "rope",   count = 10 },
            { material = "fabric", count = 4 },
        },
    },

}
setmetatable(CGondola, { __index = CBoat })

---Constructor for CGondola
---@return CGondola
function CGondola:new()
    local newObj = CBoat:new()
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj CGondola

    return newObj
end

---@param position tes3vector3
---@param orientation tes3vector3
---@param facing number
---@return CGondola
function CGondola:create(position, orientation, facing)
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
    ---@cast newObj CGondola

    newObj:OnCreate()

    return newObj
end

return CGondola
