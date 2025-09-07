local lib         = require("ImmersiveTravel.lib")

local log         = mwse.Logger.new()

---@class ServiceData
---@field class string The npc class name
---@field mount string The mountid
---@field override_npc string[]? register specific npcs with the service
---@field override_mount table<string,string[]>? register specific mounts with the service
---@field ground_offset number DEPRECATED: editor marker offset
---@field guide string[]? guide npcs
-- RUNTIME DATA
---@field segments table<string, SSegment>? segment name -> SSegment
---@field ports table<string, SPort>? cell name -> SPort
---@field routes table<string, SRoute>? routeId -> SRoute
---@field sharedSegments table<string, SharedWaterway>? shared segments by name
---@field intersections table<string, RouteIntersection>? route intersections by name
local ServiceData = {}

---@return ServiceData
function ServiceData:new(o)
    o = o or {} -- create object if user does not provide one
    setmetatable(o, self)
    self.__index = self
    return o
end

---@param start string
---@return string[]
function ServiceData:GetDestinations(start)
    local destinations = {}
    for _, route in ipairs(self.routes) do
        if route.id.start == start then
            table.insert(destinations, route.id.destination)
        end
    end
    return destinations
end

---@return string[]
function ServiceData:GetStarts()
    return table.keys(self.routes)
end

---@return string[]
function ServiceData:GetPorts()
    return table.keys(self.ports)
end

---@return string[]
function ServiceData:GetSegments()
    return table.keys(self.segments)
end

---@param name string
---@param mountId string
---@return PortData?
function ServiceData:GetPort(name, mountId)
    local port = self.ports[name]
    if port then
        return port.data[mountId]
    end

    return nil
end

---@param segment string
---@return SSegment?
function ServiceData:GetSegment(segment)
    return self.segments[segment]
end

---@param id RouteId
---@return SRoute?
function ServiceData:GetRoute(id)
    return self.routes[id:ToString()]
end

---@param id RouteId
---@return string
function ServiceData:ResolveMountId(id)
    -- create mount
    local mountId = self.mount
    -- override mounts
    if self.override_mount then
        for _, o in ipairs(self.override_mount) do
            if lib.is_in(o.points, id.start) and lib.is_in(o.points, id.destination) then
                mountId = o.id
                break
            end
        end
    end
    return mountId
end

---@param segmentId string
---@return SharedWaterway?
function ServiceData:GetSharedWaterwayBySegment(segmentId)
    for _, waterway in pairs(self.sharedSegments) do
        if waterway.segmentId == segmentId then
            return waterway
        end
    end
    return nil
end

---@param segmentId string
---@param vehicleId string
---@return boolean true if vehicle can enter the shared waterway
function ServiceData:TryEnterSharedWaterway(segmentId, vehicleId)
    local waterway = self:GetSharedWaterwayBySegment(segmentId)
    if not waterway then
        return true -- not a shared waterway, allow entry
    end

    if waterway.occupiedBy == nil then
        -- waterway is free, occupy it
        waterway.occupiedBy = vehicleId
        log:info("Vehicle %s entered shared waterway %s (segment %s)", vehicleId, waterway.id, segmentId)
        return true
    elseif waterway.occupiedBy == vehicleId then
        -- already occupied by this vehicle
        return true
    else
        -- waterway is occupied by another vehicle, add to queue
        local isAlreadyQueued = false
        for _, queuedVehicleId in ipairs(waterway.queue) do
            if queuedVehicleId == vehicleId then
                isAlreadyQueued = true
                break
            end
        end

        if not isAlreadyQueued then
            table.insert(waterway.queue, vehicleId)
            log:info("Vehicle %s queued for shared waterway %s (segment %s), queue position %d",
                vehicleId, waterway.id, segmentId, #waterway.queue)
        end

        return false
    end
end

---@param segmentId string
---@param vehicleId string
function ServiceData:ExitSharedWaterway(segmentId, vehicleId)
    local waterway = self:GetSharedWaterwayBySegment(segmentId)
    if not waterway then
        return -- not a shared waterway
    end

    if waterway.occupiedBy == vehicleId then
        waterway.occupiedBy = nil
        log:info("Vehicle %s exited shared waterway %s (segment %s)", vehicleId, waterway.id, segmentId)

        -- check if there's a vehicle waiting in queue
        if #waterway.queue > 0 then
            local nextVehicleId = table.remove(waterway.queue, 1)
            waterway.occupiedBy = nextVehicleId
            log:info("Vehicle %s from queue now occupies shared waterway %s (segment %s)",
                nextVehicleId, waterway.id, segmentId)
        end
    else
        -- remove from queue if present
        for i, queuedVehicleId in ipairs(waterway.queue) do
            if queuedVehicleId == vehicleId then
                table.remove(waterway.queue, i)
                log:info("Vehicle %s removed from queue for shared waterway %s (segment %s)",
                    vehicleId, waterway.id, segmentId)
                break
            end
        end
    end
end

---@param segmentId string
---@param vehicleId string
---@return boolean true if this vehicle can proceed on this segment
function ServiceData:CanProceedOnSegment(segmentId, vehicleId)
    local waterway = self:GetSharedWaterwayBySegment(segmentId)
    if not waterway then
        return true -- not a shared waterway, always allow
    end

    return waterway.occupiedBy == vehicleId or waterway.occupiedBy == nil
end

---@param segmentName string
---@param splineIndex number
---@param vehicleId string
---@return boolean true if vehicle can enter the intersection area
function ServiceData:TryEnterIntersection(segmentName, splineIndex, vehicleId)
    for _, intersection in pairs(self.intersections) do
        if intersection.segmentName == segmentName then
            -- Check if vehicle is near the intersection point
            local distance = math.abs(splineIndex - intersection.pointIndex)
            if distance <= intersection.radius then
                -- Vehicle is approaching this intersection
                if intersection.occupiedBy == nil then
                    -- Intersection is free, occupy it
                    intersection.occupiedBy = vehicleId
                    log:info("Vehicle %s entered intersection %s", vehicleId, intersection.id)
                    return true
                elseif intersection.occupiedBy == vehicleId then
                    -- Already occupied by this vehicle
                    return true
                else
                    -- Intersection is occupied by another vehicle, add to queue
                    local isAlreadyQueued = false
                    for _, queuedVehicleId in ipairs(intersection.queue) do
                        if queuedVehicleId == vehicleId then
                            isAlreadyQueued = true
                            break
                        end
                    end

                    if not isAlreadyQueued then
                        table.insert(intersection.queue, vehicleId)
                        log:info("Vehicle %s queued for intersection %s, queue position %d",
                            vehicleId, intersection.id, #intersection.queue)
                    end

                    return false
                end
            end
        end
    end

    return true -- No intersections nearby
end

---@param segmentName string
---@param splineIndex number
---@param vehicleId string
function ServiceData:ExitIntersection(segmentName, splineIndex, vehicleId)
    for _, intersection in pairs(self.intersections) do
        if intersection.occupiedBy == vehicleId and intersection.segmentName == segmentName then
            local distance = math.abs(splineIndex - intersection.pointIndex)
            -- Vehicle has moved outside the intersection radius
            if distance > intersection.radius + 5 then -- Add some buffer to avoid flickering
                intersection.occupiedBy = nil
                log:info("Vehicle %s exited intersection %s", vehicleId, intersection.id)

                -- Check if there's a vehicle waiting in queue
                if #intersection.queue > 0 then
                    local nextVehicleId = table.remove(intersection.queue, 1)
                    intersection.occupiedBy = nextVehicleId
                    log:info("Vehicle %s from queue now occupies intersection %s",
                        nextVehicleId, intersection.id)
                end
                break
            end
        end
    end
end

---@param vehicleId string
function ServiceData:ForceExitIntersection(vehicleId)
    for _, intersection in pairs(self.intersections) do
        if intersection.occupiedBy == vehicleId then
            intersection.occupiedBy = nil
            log:info("Vehicle %s force-exited intersection %s", vehicleId, intersection.id)

            -- Check if there's a vehicle waiting in queue
            if #intersection.queue > 0 then
                local nextVehicleId = table.remove(intersection.queue, 1)
                intersection.occupiedBy = nextVehicleId
                log:info("Vehicle %s from queue now occupies intersection %s",
                    nextVehicleId, intersection.id)
            end
        else
            -- Remove from queue if present
            for i, queuedVehicleId in ipairs(intersection.queue) do
                if queuedVehicleId == vehicleId then
                    table.remove(intersection.queue, i)
                    log:info("Vehicle %s removed from queue for intersection %s",
                        vehicleId, intersection.id)
                    break
                end
            end
        end
    end
end

return ServiceData
