local ServiceData = require("ImmersiveTravel.models.Service")

local this = {}

--#region services

---@param name string
---@return ServiceData
local function newService(name)
    local o = require("ImmersiveTravel.Services." .. name)
    local service = ServiceData:new(o)
    return service
end

---@type table<string, ServiceData>
this.services               = {}
this.services["Shipmaster"] = newService("Shipmaster")
--this.services["Caravaner"]  = require("ImmersiveTravel.Services.Caravaner")
--this.services["Gondolier"]  = require("ImmersiveTravel.Services.Gondolier")

-- insert to table
---@param id string
---@param serviceData ServiceData
function this.insertService(id, serviceData)
    this.services[id] = serviceData
end

--#endregion


--#region vehicles

---@type table<string, string>
this.vehicles                  = {}
this.vehicles["a_siltstrider"] = "CSiltStrider"
this.vehicles["a_gondola_01"]  = "CGondola"
this.vehicles["a_longboat"]    = "CLongboat"
this.vehicles["a_DE_ship"]     = "CShipDe"

-- insert to table
---@param id string
---@param className string
function this.insertVehicle(id, className)
    this.vehicles[id] = className
end

--- get vehicle
---@param id string
---@param position tes3vector3
---@param orientation tes3vector3
---@param facing number
---@return CVehicle?
function this.createVehicle(id, position, orientation, facing)
    -- get from vehicles table
    if this.vehicles[id] then
        local vehicle = require("ImmersiveTravel.Vehicles." .. this.vehicles[id])
        ---@cast vehicle CVehicle
        local o = vehicle:new()

        -- create reference
        local mountOffset = tes3vector3.new(0, 0, o.offset)
        local reference = tes3.createReference {
            object = id,
            position = position + mountOffset,
            orientation = orientation
        }
        reference.facing = facing

        o.referenceHandle = tes3.makeSafeObjectHandle(reference)

        o:OnCreate()

        return o
    end

    return nil
end

--- get vehicle
---@param mountId string
---@return CVehicle?
function this.newVehicle(mountId)
    -- get from vehicles table
    if this.vehicles[mountId] then
        local vehicle = require("ImmersiveTravel.Vehicles." .. this.vehicles[mountId])
        return vehicle:new()
    end

    return nil
end

--- get static vehicle data
---@param mountId string
---@return CVehicle?
function this.getVehicleStaticData(mountId)
    -- get from vehicles table
    if this.vehicles[mountId] then
        local vehicle = require("ImmersiveTravel.Vehicles." .. this.vehicles[mountId])
        return vehicle:new()
    end

    return nil
end

--- check if valid mount
---@param id string
---@return boolean
function this.isScriptedEntity(id)
    return this.vehicles[id] ~= nil
end

--#endregion

return this
