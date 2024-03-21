local CBoat = require("ImmersiveTravel.CBoat")

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
---@param position tes3vector3
---@param orientation tes3vector3
function CLongboat:new(position, orientation)
    -- create reference
    local reference = tes3.createReference {
        object = self.id,
        position = position,
        orientation = orientation
    }

    local newObj = CBoat:new(reference)
    self.__index = self
    setmetatable(newObj, self)
    return newObj
end

--#region CBoat methods

-- Define the CLongboat class inheriting from CBoat
function CLongboat:Delete()
    -- Call the superclass delete method
    CBoat.Delete(self)
end

--#endregion

--#regions methods



--#endregion

return CLongboat
