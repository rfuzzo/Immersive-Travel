local CBoat = require("ImmersiveTravel.Vehicles.CBoat")

-- Define the CCanoe class inheriting from CBoat
---@class CCanoe : CBoat
local CCanoe = {
    id = "a_canoe_01",
    sound = {
        "Boat Creak"
    },
    loopSound = true,
    mesh = "x\\Ex_Gondola_01_rot.nif",
    scale = 0.7,
    offset = 40,
    sway = 0.7,
    speed = 2,
    minSpeed = -2,
    maxSpeed = 7,
    turnspeed = 40,
    hasFreeMovement = false,
    freedomtype = "boat",
    guideSlot = {
        animationGroup = { "idle6" },
        animationFile = "VA_sitting.nif",
        position = tes3vector3.new(0, -82, -15)
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
        name = "Canoe",
        price = 300,
        materials = {
            { material = "wood",   count = 12 },
            { material = "rope",   count = 6 },
            { material = "fabric", count = 4 },
        }
    },

}
setmetatable(CCanoe, { __index = CBoat })

---Constructor for CCanoe
---@return CCanoe
function CCanoe:new()
    local newObj = CBoat:new()
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj CCanoe

    return newObj
end

---@param id string
---@param position tes3vector3
---@param orientation tes3vector3
---@param facing number
---@return CCanoe
function CCanoe:create(id, position, orientation, facing)
    local newObj = CBoat:create(id, position, orientation, facing)
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj CCanoe

    newObj:OnCreate()

    return newObj
end

return CCanoe
