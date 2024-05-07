local CBoat    = require("ImmersiveTravel.Vehicles.CBoat")
local lib      = require("ImmersiveTravel.lib")
local log      = lib.log

-- Define the CGondola class inheriting from CBoat
---@class CGondola : CBoat
local CGondola = {
    -- id = "a_gondola_01",
    -- sound = {
    --     "Boat Creak"
    -- },
    -- loopSound = true,
    -- mesh = "x\\Ex_Gondola_01_rot.nif",
    -- scale = 1,
    -- offset = 40,
    -- sway = 1,
    -- speed = 2,
    -- minSpeed = -2,
    -- maxSpeed = 7,
    -- turnspeed = 40,
    -- hasFreeMovement = false,
    -- freedomtype = "boat",
    -- guideSlot = {
    --     animationGroup = { "idle6" },
    --     position = tes3vector3.new(0, -171, -18)
    -- },
    -- hiddenSlot = {
    --     position = tes3vector3.new(0, 0, -200)
    -- },
    -- slots = {
    --     {
    --         animationGroup = {
    --             "idle6"
    --         },
    --         animationFile = "VA_sitting.nif",
    --         position = tes3vector3.new(0, 82, -15)
    --     },
    --     {
    --         animationGroup = {
    --             "idle6"
    --         },
    --         animationFile = "VA_sitting.nif",
    --         position = tes3vector3.new(0, -82, -15)
    --     },
    --     {
    --         animationGroup = {},
    --         position = tes3vector3.new(0, 7, -15)
    --     },
    -- },
    -- clutter = {
    --     {
    --         id = "light_de_paper_lantern_01_nr",
    --         position = tes3vector3.new(0, -219, 56)
    --     },
    --     {
    --         id = "light_de_paper_lantern_04_nr",
    --         position = tes3vector3.new(0, 176, 17)
    --     }
    -- },
    -- userData = {
    --     name = "Gondola",
    --     price = 500,
    --     materials = {
    --         { material = "wood",   count = 20 },
    --         { material = "rope",   count = 10 },
    --         { material = "fabric", count = 4 },
    --     },
    -- },
}
setmetatable(CGondola, { __index = CBoat })

---Constructor for CGondola
---@return CGondola
function CGondola:new()
    local newObj = CBoat:new()
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj CGondola

    -- set default values
    newObj.id = "a_gondola_01"
    newObj.sound = {
        "Boat Creak"
    }
    newObj.loopSound = true
    newObj.mesh = "x\\Ex_Gondola_01_rot.nif"
    newObj.scale = 1
    newObj.offset = 40
    newObj.sway = 1
    newObj.speed = 2
    newObj.minSpeed = -2
    newObj.maxSpeed = 7
    newObj.turnspeed = 40
    newObj.hasFreeMovement = false
    newObj.freedomtype = "boat"
    newObj.guideSlot = {
        animationGroup = { "idle6" },
        position = tes3vector3.new(0, -171, -18)
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
        name = "Gondola",
        price = 500,
        materials = {
            { material = "wood",   count = 20 },
            { material = "rope",   count = 10 },
            { material = "fabric", count = 4 },
        },
    }

    return newObj
end

return CGondola
