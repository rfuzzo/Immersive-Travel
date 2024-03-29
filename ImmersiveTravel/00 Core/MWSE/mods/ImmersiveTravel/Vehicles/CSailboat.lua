local CBoat = require("ImmersiveTravel.Vehicles.CBoat")

-- Define the CSailboat class inheriting from CBoat
---@class CSailboat : CBoat
local CSailboat = {
    id = "a_sailboat_iv",
    sound = {
        "Boat Creak"
    },
    loopSound = true,
    mesh = "iv\\sky_ex_fisherboat_02.nif",
    offset = 20,
    sway = 1,
    speed = 2,
    minSpeed = -2,
    maxSpeed = 7,
    changeSpeed = 1.5,
    turnspeed = 30,
    scale = 0.7,
    guideSlot = {
        animationGroup = { "idle6" },
        animationFile = "VA_sitting.nif",
        position = tes3vector3.new(-30, -96, 25)
    },
    userData = {
        name = "Small boat",
        price = 700,
        materials = {
            { material = "wood",   count = 30 },
            { material = "rope",   count = 10 },
            { material = "fabric", count = 20 }
        }
    },
}
setmetatable(CSailboat, { __index = CBoat })

---Constructor for CSailboat
---@return CSailboat
function CSailboat:new()
    local newObj = CBoat:new()
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj CSailboat

    return newObj
end

---Create a new instance of CSailboat
---@param id string
---@param position tes3vector3
---@param orientation tes3vector3
---@param facing number
---@return CSailboat
function CSailboat:create(id, position, orientation, facing)
    local newObj = CBoat:create(id, position, orientation, facing)
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj CSailboat

    newObj:OnCreate()

    return newObj
end

return CSailboat
