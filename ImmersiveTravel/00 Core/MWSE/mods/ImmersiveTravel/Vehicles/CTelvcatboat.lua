local CBoat = require("ImmersiveTravel.Vehicles.CBoat")

-- Define the CTelvcatboat class inheriting from CBoat
---@class CTelvcatboat : CBoat
local CTelvcatboat = {
    id = "a_telvcatboat_iv",
    sound = {
        "Boat Creak"
    },
    loopSound = true,
    mesh = "dim\\dim_telvcatboatS.nif",
    offset = 20,
    sway = 1,
    speed = 2,
    minSpeed = -2,
    maxSpeed = 7,
    changeSpeed = 1.5,
    turnspeed = 30,
    scale = 1,
    guideSlot = {
        animationGroup = { "idle6" },
        animationFile = "VA_sitting.nif",
        position = tes3vector3.new(-109, -403, 111)
    },
    userData = {
        name = "Catboat",
        price = 1000,
        materials = {
            { material = "wood",     count = 50 },
            { material = "rope",     count = 20 },
            { material = "fabric",   count = 30 },
            { material = "mushroom", count = 20 },
        }
    },
}
setmetatable(CTelvcatboat, { __index = CBoat })

---Constructor for CTelvcatboat
---@return CTelvcatboat
function CTelvcatboat:new()
    local newObj = CBoat:new()
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj CTelvcatboat

    return newObj
end

---Create a new instance of CTelvcatboat
---@param id string
---@param position tes3vector3
---@param orientation tes3vector3
---@param facing number
---@return CTelvcatboat
function CTelvcatboat:create(id, position, orientation, facing)
    local newObj = CBoat:create(id, position, orientation, facing)
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj CTelvcatboat

    newObj:OnCreate()

    return newObj
end

return CTelvcatboat
