local CAiState       = require("ImmersiveTravel.Statemachine.ai.CAiState")
local lib            = require("ImmersiveTravel.lib")
local GRoutesManager = require("ImmersiveTravel.GRoutesManager")

local log            = lib.log

-- None State class
---@class NoneState : CAiState
local NoneState      = {
    name = CAiState.NONE,
    transitions = {
        [CAiState.PLAYERSTEER] = CAiState.ToPlayerSteer,
        [CAiState.PLAYERTRAVEL] = CAiState.ToPlayerTravel,
        [CAiState.ONSPLINE] = CAiState.ToOnSpline,
    }
}
setmetatable(NoneState, { __index = CAiState })

-- constructor for NoneState
---@return NoneState
function NoneState:new()
    local newObj = CAiState:new()
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj NoneState
    return newObj
end

---@param scriptedObject CTickingEntity
function NoneState:OnActivate(scriptedObject)
    local vehicle = scriptedObject ---@cast vehicle CVehicle

    -- fade out
    tes3.fadeOut({ duration = 1 })

    -- fade back in
    timer.start({
        type = timer.simulate,
        iterations = 1,
        duration = 1,
        callback = (function()
            tes3.fadeIn({ duration = 1 })

            -- position mount at ground level
            local mount = vehicle.referenceHandle:getObject()
            if vehicle.freedomtype ~= "boat" then
                local top = tes3vector3.new(0, 0, mount.object.boundingBox.max.z)
                local z = lib.getGroundZ(mount.position + top)
                if not z then
                    z = tes3.player.position.z
                end
                mount.position = tes3vector3.new(mount.position.x, mount.position.y,
                    z + (vehicle.offset * vehicle.scale))
            end
            mount.orientation = tes3.player.orientation

            -- transition to player steer state
            vehicle:StartPlayerSteer()
        end)
    })
end

---@param cell tes3cell
---@param guide tes3npc
---@return string?
local function GetRouteIdForCell(cell, guide)
    local services = GRoutesManager.getInstance().services
    if not services then return nil end

    -- get npc class
    local class = guide.class.id
    local service = table.get(services, class)
    for key, value in pairs(services) do
        if value.override_npc ~= nil then
            if lib.is_in(value.override_npc, guide.id) then
                service = value
                break
            end
        end
    end

    if service == nil then
        lib.log:debug("no service found for %s in cell %s", guide.id, cell.id)
        return nil
    end

    lib.log:debug("service found for %s in cell %s: service %s", guide.id, cell.id, service.class)

    -- Return if no destinations
    local destinations = service.routes[cell.id]
    if destinations == nil then return nil end
    if #destinations == 0 then return nil end

    lib.log:debug("found %s destinations for %s", #destinations, cell.id)

    -- get a random destination
    local destination = destinations[math.random(#destinations)]
    local start = cell.id
    local routeId = start .. "_" .. destination

    return routeId
end

---@comment when we enter this state, the ship is docked in port
function NoneState:enter(scriptedObject)
    -- TODO unregister passengers
    local vehicle = scriptedObject ---@cast vehicle CVehicle
    local guide = vehicle:GetGuide()

    if vehicle.referenceHandle:valid() and guide then
        -- start timer for new route
        timer.start({
            type = timer.simulate,
            iterations = 1,
            duration = 10,
            callback = (function()
                -- get available routes

                local cell = vehicle.referenceHandle:getObject().cell


                local route = GetRouteIdForCell(cell, guide)
                if not route then
                    tes3.messageBox("No route found")
                    log:debug("No route found for %s", guide.id)

                    scriptedObject.markForDelete = true

                    return
                end
                tes3.messageBox("New route: %s", route)
                log:debug("New route: %s", route)

                -- set a new route
                vehicle.routeId = route
                vehicle.current_speed = vehicle.speed --TODO move this to spline start
            end)
        })
    end
end

return NoneState
