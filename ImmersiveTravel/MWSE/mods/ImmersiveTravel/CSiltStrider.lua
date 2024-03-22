local lib = require("ImmersiveTravel.lib")
local CBoat = require("ImmersiveTravel.CBoat")

-- Define the CSiltStrider class inheriting from CBoat
---@class CSiltStrider : CBoat
local CSiltStrider = {
    id = "a_siltstrider",
    sound = {
        "Silt_1",
        "Silt_2",
        "Silt_3"
    },
    loopSound = false,
    mesh = "r\\Siltstrider.nif",
    offset = -1220,
    sway = 1,
    speed = 3,
    turnspeed = 30,
    hasFreeMovement = false,
    forwardAnimation = "runForward",
    nodeName = "Body",
    nodeOffset = tes3vector3.new(0, 56, 1005),
    guideSlot = {
        animationGroup = { "idle5" },
        position = tes3vector3.new(0, 10, 1223)
    },
    hiddenSlot = {
        position = tes3vector3.new(0, 0, 1000)
    },
    slots = {
        {
            animationGroup = {},
            position = tes3vector3.new(0, 80, 1223)
        },
        {
            animationGroup = {},
            position = tes3vector3.new(-81, 20, 1230)
        },
        {
            animationGroup = {},
            position = tes3vector3.new(81, 40, 1230)
        },
    }
}
setmetatable(CSiltStrider, { __index = CBoat })

---Constructor for CSiltStrider
---@param position tes3vector3
---@param orientation tes3vector3
---@param facing number
---@return CSiltStrider
function CSiltStrider:new(position, orientation, facing)
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
function CSiltStrider:OnTick(dt)
    -- Call the superclass onTick method
    CBoat.OnTick(self, dt)
end

--#region CBoat methods

-- Define the CSiltStrider class inheriting from CBoat
function CSiltStrider:Delete()
    -- Call the superclass delete method
    CBoat.Delete(self)
end

--#endregion

--#regions methods



--#endregion

return CSiltStrider
