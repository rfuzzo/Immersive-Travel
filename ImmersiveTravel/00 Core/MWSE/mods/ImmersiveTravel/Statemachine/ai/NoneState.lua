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

---@param guide tes3npc
---@param start string
---@return string?
local function GetRandomRouteFrom(guide, start)
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
        lib.log:debug("no service found for %s in cell %s", guide.id, start)
        return nil
    end

    lib.log:debug("service found for %s in cell %s: service %s", guide.id, start, service.class)

    -- Return if no destinations
    local destinations = service.routes[start]
    if destinations == nil then return nil end
    if #destinations == 0 then return nil end

    lib.log:debug("found %s destinations for %s", #destinations, start)

    -- get a random destination
    local destination = destinations[math.random(#destinations)]
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
            duration = 5,
            callback = (function()
                if not vehicle.lastRouteId then
                    scriptedObject.markForDelete = true
                    return
                end

                -- sometimes the current cell is not valid, so we check the last route
                local split = string.split(vehicle.lastRouteId, "_")
                -- local start = split[1]
                local destination = split[2]
                local route = GetRandomRouteFrom(guide, destination)
                if not route then
                    tes3.messageBox("No route found")
                    log:debug("[%s] No route found for %s", vehicle:Id(), guide.id)

                    scriptedObject.markForDelete = true

                    return
                end
                tes3.messageBox("New route: %s", route)
                log:debug("[%s] New route: %s", vehicle:Id(), route)

                -- rotate the vehicle into the direction of the next point
                local spline = GRoutesManager.getInstance().routes[route]
                if spline == nil then
                    scriptedObject.markForDelete = true
                    return
                end


                if not vehicle.referenceHandle:valid() then
                    scriptedObject.markForDelete = true
                    return
                end
                local mount = vehicle.referenceHandle:getObject()
                if not mount then
                    scriptedObject.markForDelete = true
                    return
                end

                local startPoint = mount.position --lib.vec(spline[1])
                local nextPoint = lib.vec(spline[2])
                local orientation = nextPoint - startPoint
                orientation:normalize()
                local facing = math.atan2(orientation.x, orientation.y)

                mount.facing = facing

                vehicle.splineIndex = 1
                vehicle.last_position = mount.position
                vehicle.last_forwardDirection = mount.forwardDirection
                vehicle.last_facing = mount.facing
                vehicle.last_sway = 0

                -- after 5 seconds, set the new route
                timer.start({
                    type = timer.simulate,
                    iterations = 1,
                    duration = 5,
                    callback = (function()
                        -- set a new route
                        vehicle.routeId = route
                        vehicle.current_speed = vehicle.speed --TODO move this to spline start
                    end)
                })
            end)
        })
    end
end

return NoneState
