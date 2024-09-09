local config = require("ImmersiveTravel.config")
local CVehicle = require("ImmersiveTravel.Vehicles.CVehicle")

-- Define the CSiltStrider class inheriting from CVehicle
---@class CSiltStrider : CVehicle
local CSiltStrider = {}
setmetatable(CSiltStrider, { __index = CVehicle })

---Constructor for CSiltStrider
---@return CSiltStrider
function CSiltStrider:new()
    local newObj = CVehicle:new()
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj CSiltStrider

    -- set default values
    newObj.id = "a_siltstrider"
    newObj.sound = {
        "Silt_1",
        "Silt_2",
        "Silt_3"
    }
    newObj.loopSound = false
    newObj.mesh = "r\\Siltstrider.nif"
    newObj.offset = -1220
    newObj.sway = 1
    newObj.speed = 3
    newObj.turnspeed = 30
    newObj.hasFreeMovement = false
    newObj.freedomtype = "ground"
    newObj.serviceId = "Caravaner"
    newObj.nodeName = "Body"
    newObj.nodeOffset = tes3vector3.new(0, 56, 1005)
    newObj.guideSlot = {
        animationGroup = { "idle5" },
        position = tes3vector3.new(0, 10, 1223)
    }
    newObj.hiddenSlot = {
        position = tes3vector3.new(0, 0, 1000)
    }
    newObj.slots = {
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
    newObj.animation = {
        forward = tes3.animationGroup.walkForward,
        idle = tes3.animationGroup.idle
    }

    return newObj
end

return CSiltStrider
