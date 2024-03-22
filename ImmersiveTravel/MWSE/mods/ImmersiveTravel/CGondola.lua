local lib = require("ImmersiveTravel.lib")
local CBoat = require("ImmersiveTravel.CBoat")

-- Define the CGondola class inheriting from CBoat
---@class CGondola : CBoat
local CGondola = {
    id = "a_longboat",
    sound = {
        "Boat Creak"
    },
    loopSound = true,
    mesh = "x\\Ex_Gondola_01_rot.nif",
    offset = 40,
    sway = 1,
    speed = 2,
    turnspeed = 40,
    hasFreeMovement = false,
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
    }

}
setmetatable(CGondola, { __index = CBoat })

---Constructor for CGondola
---@param position tes3vector3
---@param orientation tes3vector3
---@param facing number
---@return CGondola
function CGondola:new(position, orientation, facing)
    -- create reference
    -- TODO this can be moved to the superclass
    local mountOffset = tes3vector3.new(0, 0, self.offset)
    local reference = tes3.createReference {
        object = self.id,
        position = position + mountOffset,
        orientation = orientation
    }
    reference.facing = facing

    local newObj = CBoat:new(reference)
    self.__index = self
    setmetatable(newObj, self)
    return newObj
end

-- onTick override
---@param dt number
function CGondola:OnTick(dt)
    lib.log:debug("CGondola OnTick called for %s", self.id)

    -- Call the superclass onTick method
    CBoat.OnTick(self, dt)
end

--#region CBoat methods

-- Define the CGondola class inheriting from CBoat
function CGondola:Delete()
    -- Call the superclass delete method
    CBoat.Delete(self)
end

--#endregion

--#regions methods



--#endregion

return CGondola
