local config = require("ImmersiveTravel.config")
if not config then
    return
end

local this = {}

--#region global

local logger = require("logging.logger")
this.log = logger.new {
    name = config.mod,
    logLevel = config.logLevel,
    logToConsole = false,
    includeTimestamp = false
}

this.ANIM_CHANGE_FREQ = 10   -- change passenger animations every 10 seconds
this.SWAY_MAX_AMPL = 3       -- how much the ship can sway in a turn
this.SWAY_AMPL_CHANGE = 0.01 -- how much the ship can sway in a turn
this.SWAY_FREQ = 0.12        -- how fast the mount sways
this.SWAY_AMPL = 0.014       -- how much the mount sways
this.PASSENGER_HELLO = 10

local logLevels = {
    ["TRACE"] = 1,
    ["DEBUG"] = 2,
    ["INFO"] = 3,
    ["WARN"] = 4,
    ["ERROR"] = 5,
    ["NONE"] = 6,
}

function this.IsLogLevelAtLeast(level)
    return logLevels[config.logLevel] <= logLevels[level]
end

--#endregion


--#endregion

---@class ReferenceRecord
---@field cell tes3cell The cell
---@field position tes3vector3 The reference position

--region math

---@param pos tes3vector3
--- @return tes3vector3
function this.radvec(pos)
    return tes3vector3.new(math.rad(pos.x), math.rad(pos.y), math.rad(pos.z))
end

--- @param orientation tes3vector3
--- @param transform tes3transform
---@return tes3vector3
function this.toLocalOrientation(orientation, transform)
    local m = tes3matrix33.new()
    m:fromEulerXYZ(orientation.x, orientation.y, orientation.z)
    local t = transform.rotation:invert() * m
    local localOrientation = t:toEulerXYZ()
    return localOrientation
end

---@param orientation tes3vector3
---@return tes3vector3
function this.deg(orientation)
    return tes3vector3.new(
        math.deg(orientation.x),
        math.deg(orientation.y),
        math.deg(orientation.z)
    )
end

--- @param orientation tes3vector3
--- @param transform tes3transform
---@return tes3vector3
function this.toLocalOrientationDeg(orientation, transform)
    return this.deg(this.toLocalOrientation(orientation, transform))
end

-- Translate local orientation around a base-centered coordinate system to world orientation
---@param localOrientation tes3vector3
---@param baseOrientation tes3vector3
--- @return tes3vector3
function this.toWorldOrientation(localOrientation, baseOrientation)
    -- Convert the local orientation to a rotation matrix
    local baseRotationMatrix = tes3matrix33.new()
    baseRotationMatrix:fromEulerXYZ(baseOrientation.x, baseOrientation.y,
        baseOrientation.z)

    local localRotationMatrix = tes3matrix33.new()
    localRotationMatrix:fromEulerXYZ(localOrientation.x, localOrientation.y,
        localOrientation.z)

    -- Combine the rotation matrices to get the world rotation matrix
    local worldRotationMatrix = baseRotationMatrix * localRotationMatrix
    local worldOrientation, _isUnique = worldRotationMatrix:toEulerXYZ()
    return worldOrientation
end

-- Transform a local offset to world coordinates given a fixed orientation
---@param localVector tes3vector3
---@param orientation tes3vector3
--- @return tes3vector3
function this.toWorld(localVector, orientation)
    -- Convert the local orientation to a rotation matrix
    local baseRotationMatrix = tes3matrix33.new()
    baseRotationMatrix:fromEulerXYZ(orientation.x, orientation.y, orientation.z)

    -- Combine the rotation matrices to get the world rotation matrix
    return baseRotationMatrix * localVector
end

---comment
---@param point tes3vector3
---@param objectPosition tes3vector3
---@param objectForwardVector tes3vector3
---@return boolean
function this.isPointBehindObject(point, objectPosition, objectForwardVector)
    local vectorToPoint = point - objectPosition
    local dotProduct = vectorToPoint:dot(objectForwardVector)
    return dotProduct < 0
end

--- list contains
---@param tab string[]
---@param str string
function this.is_in(tab, str)
    for index, value in ipairs(tab) do
        if value == str then
            return true
        end
    end
    return false
end

--- @param forward tes3vector3
--- @return tes3matrix33
function this.rotationFromDirection(forward)
    forward:normalize()
    local up = tes3vector3.new(0, 0, -1)
    local right = up:cross(forward)
    right:normalize()
    up = right:cross(forward)

    local rotation_matrix = tes3matrix33.new(right.x, forward.x, up.x, right.y,
        forward.y, up.y, right.z,
        forward.z, up.z)

    return rotation_matrix
end

--#endregion

--#region tes3

--- @param e mouseWheelEventData
function this.mouseWheelCallback(e)
    local isControlDown = tes3.worldController.inputController:isControlDown()
    if isControlDown then
        -- update fov
        if e.delta > 0 then
            tes3.set3rdPersonCameraOffset({ offset = tes3.get3rdPersonCameraOffset() + tes3vector3.new(0, 10, 0) })
        else
            tes3.set3rdPersonCameraOffset({ offset = tes3.get3rdPersonCameraOffset() - tes3vector3.new(0, 10, 0) })
        end
    end
end

--- @param from tes3vector3
--- @return number|nil
function this.getGroundZ(from)
    local rayhit = tes3.rayTest {
        position = from,
        direction = tes3vector3.new(0, 0, -1),
        returnNormal = true,
        root = tes3.game.worldLandscapeRoot
    }

    if (rayhit) then
        local to = rayhit.intersection
        return to.z
    end

    return nil
end

--- @param from tes3vector3
--- @return number|nil
function this.testCollisionZ(from)
    local rayhit = tes3.rayTest {
        position = from,
        direction = tes3vector3.new(0, 0, -1),
        returnNormal = true,
        root = tes3.game.worldObjectRoot
    }

    if (rayhit) then
        local to = rayhit.intersection
        return to.z
    end

    return nil
end

---@param slot Slot
---@return integer
function this.getRandomAnimGroup(slot)
    local group = tes3.animationGroup.idle5
    if slot.animationGroup then
        -- choose a random animation
        if #slot.animationGroup > 0 then
            local randomIndex = math.random(1, #slot.animationGroup)
            local animkey = slot.animationGroup[randomIndex]
            group = tes3.animationGroup[animkey]
        else
            -- if len is 0 then we pick one of the idles
            local index = {
                "idle2", "idle3", "idle4", "idle5", "idle6", "idle7", "idle8"
            }
            local randomIndex = math.random(1, #index)
            local randomkey = index[randomIndex]
            group = tes3.animationGroup[randomkey]
        end
    end

    if group == nil then group = tes3.animationGroup.idle5 end

    return group
end

--- With the above function we can build a function that
--- creates a table with all of the player's followers
---@return tes3reference[] followerList
function this.getFollowers()
    local followers = {}
    local i = 1

    for _, mobile in pairs(tes3.mobilePlayer.friendlyActors) do
        ---@cast mobile tes3mobileNPC|tes3mobileCreature
        if this.isFollower(mobile) then
            followers[i] = mobile.reference
            i = i + 1
        end
    end

    return followers
end

--- This function returns `true` if a given mobile has
--- follow ai package with player as its target
---@param mobile tes3mobileNPC|tes3mobileCreature
---@return boolean isFollower
function this.isFollower(mobile)
    if not mobile then
        return false
    end

    local planner = mobile.aiPlanner
    if not planner then return false end

    local package = planner:getActivePackage()
    if not package then return false end
    if package.type == tes3.aiPackage.follow then
        local target = package.targetActor

        if target.objectType == tes3.objectType.mobilePlayer then
            return true
        end
    end
    return false
end

-- This function loops over the references inside the
-- tes3referenceList and adds them to an array-style table
---@param list tes3referenceList
---@return tes3reference[]
function this.referenceListToTable(list)
    local references = {} ---@type tes3reference[]
    local i = 1
    if list.size == 0 then return {} end
    local ref = list.head

    while ref.nextNode do
        references[i] = ref
        i = i + 1
        ref = ref.nextNode
    end

    -- Add the last reference
    references[i] = ref
    return references
end

---@return ReferenceRecord|nil
function this.findClosestTravelMarker()
    ---@type table<ReferenceRecord>
    local results = {}
    local cells = tes3.getActiveCells()
    for _index, cell in ipairs(cells) do
        local references = this.referenceListToTable(cell.activators)
        for _, r in ipairs(references) do
            if r.baseObject.isLocationMarker and r.baseObject.id ==
                "TravelMarker" then
                table.insert(results, { cell = cell, position = r.position })
            end
        end
    end

    local last_distance = 8000
    local last_index = 1
    for index, marker in ipairs(results) do
        local dist = tes3.mobilePlayer.position:distance(marker.position)
        if dist < last_distance then
            last_index = index
            last_distance = dist
        end
    end

    local result = results[last_index]
    if not result then this.log:warn("No TravelMarker found to teleport to") end

    return results[last_index]
end

--- get a table of N actors in the current 9 cells
--- @param N integer
---@return string[]
function this.getRandomActorsInCell(N)
    -- get all actors
    local npcsTable = {} ---@type string[]
    local cells = tes3.getActiveCells()
    for _index, cell in ipairs(cells) do
        local references = this.referenceListToTable(cell.actors)
        for _, r in ipairs(references) do
            local id = r.baseObject.id
            if not this.is_in(npcsTable, id) then
                table.insert(npcsTable, id)
            end
        end
    end

    -- get random pick
    local result = {} ---@type string[]
    for i = 1, math.min(N, #npcsTable) do
        local randomIndex = math.random(1, #npcsTable)
        local id = npcsTable[randomIndex]
        if not this.is_in(result, id) then
            table.insert(result, id)
        end
    end

    return result
end

--- get a table of N actors in the current 9 cells
--- @param N integer
---@return string[]
function this.getRandomNpcsInCell(N)
    -- get all actors
    local npcsTable = {} ---@type string[]
    local cells = tes3.getActiveCells()
    for _index, cell in ipairs(cells) do
        local references = this.referenceListToTable(cell.actors)
        for _, r in ipairs(references) do
            if r.baseObject.objectType == tes3.objectType.npc then
                -- only add non-scripted npcs as passengers
                -- local script = r.baseObject.script
                --if script == nil or (script and script.id == "nolore") then
                local id = r.baseObject.id
                if not this.is_in(npcsTable, id) then
                    table.insert(npcsTable, id)
                end
                --end
            end
        end
    end

    -- get random pick
    local result = {} ---@type string[]
    for i = 1, math.min(N, #npcsTable) do
        local randomIndex = math.random(1, #npcsTable)
        local id = npcsTable[randomIndex]
        if not this.is_in(result, id) then
            table.insert(result, id)
        end
    end

    return result
end

--- This function returns `true` if given NPC
--- or creature offers traveling service.
---@param actor tes3npc|tes3npcInstance|tes3creature|tes3creatureInstance
---@return boolean
function this.offersTraveling(actor)
    local travelDestinations = actor.aiConfig.travelDestinations

    -- Actors that can't transport the player
    -- have travelDestinations equal to `nil`
    return travelDestinations ~= nil
end

-- teleport player to closest travel marker
function this.teleportToClosestMarker()
    local marker = this.findClosestTravelMarker()
    if marker ~= nil then
        tes3.positionCell({
            reference = tes3.mobilePlayer,
            position = marker.position,
            suppressFader = true
        })
    end
end

--- checks if a position is inside the active cells
---@param position tes3vector3
---@return boolean
local function isPointLoaded(position)
    -- check if cell is in cells
    for _, cell in ipairs(tes3.getActiveCells()) do
        if cell:isPointInCell(position.x, position.y) then
            return true
        end
    end

    return false
end

---@param vehicle CVehicle
---@return boolean
function this.IsColliding(vehicle)
    local mountHandle = vehicle.referenceHandle
    if not mountHandle then
        return false
    end

    if not mountHandle:valid() then
        return false
    end

    if not isPointLoaded(mountHandle:getObject().position) then
        return false
    end

    -- raytest at sealevel to detect shore transition
    local box = mountHandle:getObject().object.boundingBox
    local max = box.max * vehicle.scale
    local min = box.min * vehicle.scale
    local t = mountHandle:getObject().sceneNode.worldTransform

    if vehicle.current_speed > 0 then
        -- detect shore
        if vehicle.freedomtype == "boat" then
            local bowPos = t * tes3vector3.new(0, max.y, min.z + (vehicle.offset * vehicle.scale))
            if not isPointLoaded(bowPos) then
                return false
            end

            local hitResult1 = tes3.rayTest({
                position = bowPos,
                direction = tes3vector3.new(0, 0, -1),
                root = tes3.game.worldLandscapeRoot,
                --maxDistance = 4096
            })
            if (hitResult1 == nil) then
                this.log:debug("[%s] HIT Shore Fwd", vehicle:Id())
                return true
            end
        end

        -- raytest from above to detect objects in water
        local bowPosTop = t * tes3vector3.new(0, max.y, max.z)
        if not isPointLoaded(bowPosTop) then
            return false
        end

        local hitResult2 = tes3.rayTest({
            position = bowPosTop,
            direction = tes3vector3.new(0, 0, -1),
            root = tes3.game.worldObjectRoot,
            ignore = { mountHandle:getObject() },
            maxDistance = max.z * vehicle.scale
        })
        if (hitResult2 ~= nil) then
            return true
        end
    elseif vehicle.current_speed < 0 then
        -- detect shore
        if vehicle.freedomtype == "boat" then
            local sternPos = t * tes3vector3.new(0, min.y, min.z + (vehicle.offset * vehicle.scale))
            if not isPointLoaded(sternPos) then
                return false
            end

            local hitResult1 = tes3.rayTest({
                position = sternPos,
                direction = tes3vector3.new(0, 0, -1),
                root = tes3.game.worldLandscapeRoot,
                --maxDistance = 4096
            })
            if (hitResult1 == nil) then
                return true
            end
        end

        -- raytest from above to detect objects in water
        local sternPosTop = t * tes3vector3.new(0, min.y, max.z)
        if not isPointLoaded(sternPosTop) then
            return false
        end

        local hitResult2 = tes3.rayTest({
            position = sternPosTop,
            direction = tes3vector3.new(0, 0, -1),
            root = tes3.game.worldObjectRoot,
            ignore = { mountHandle:getObject() },
            maxDistance = max.z
        })
        if (hitResult2 ~= nil) then
            return true
        end
    end

    return false
end

--#endregion

--#region io

---@class PositionRecord
---@field x number The x position
---@field y number The y position
---@field z number The z position

---@param pos PositionRecord
--- @return tes3vector3
function this.vec(pos)
    return tes3vector3.new(pos.x, pos.y, pos.z)
end

this.localmodpath = "mods\\ImmersiveTravel\\"
this.fullmodpath = "Data Files\\MWSE\\" .. this.localmodpath

local localmodpath = this.localmodpath
local fullmodpath = this.fullmodpath

---@class ServiceData
---@field class string The npc class name
---@field mount string The mount
---@field override_npc string[]? register specific npcs with the service
---@field override_mount table<string,string[]>? register specific mounts with the service
---@field routes table<string, string[]>? routes
---@field ground_offset number DEPRECATED: editor marker offset
---@field guide string[]? guide npcs

--- load json spline from file
---@param start string
---@param destination string
---@param data ServiceData
---@return PositionRecord[]|nil
function this.loadSpline(start, destination, data)
    local fileName = start .. "_" .. destination
    local filePath = localmodpath .. data.class .. "\\" .. fileName
    if tes3.getFileExists("MWSE\\" .. filePath .. ".json") then
        local result = json.loadfile(filePath)
        if result ~= nil then
            -- log:debug("loaded spline: " .. fileName)
            return result
        else
            this.log:error("!!! failed to load spline: " .. fileName)
            return nil
        end
    else
        -- check if return route exists
        fileName = destination .. "_" .. start
        filePath = localmodpath .. data.class .. "\\" .. fileName
        if tes3.getFileExists("MWSE\\" .. filePath .. ".json") then
            local result = json.loadfile(filePath)
            if result ~= nil then
                -- log:debug("loaded spline: " .. fileName)

                -- reverse result
                local reversed = {}
                for i = #result, 1, -1 do
                    local val = result[i]
                    table.insert(reversed, val)
                end

                this.log:debug("reversed spline: " .. fileName)
                return reversed
            else
                this.log:error("!!! failed to load spline: " .. fileName)
                return nil
            end
        else
            this.log:error("!!! failed to find any file: " .. fileName)
        end
    end
end

--- Load all route splines for a given service
---@param service ServiceData
function this.loadRoutes(service)
    local map = {} ---@type table<string, table>
    for file in lfs.dir(fullmodpath .. service.class) do
        if (string.endswith(file, ".json")) then
            local split = string.split(file:sub(0, -6), "_")
            if #split == 2 then
                local start = ""
                local destination = ""
                for i, id in ipairs(split) do
                    if i == 1 then
                        start = id
                    else
                        destination = id
                    end
                end

                local result = table.get(map, start, nil)
                if not result then
                    local v = {}
                    v[destination] = 1
                    map[start] = v
                else
                    result[destination] = 1
                    map[start] = result
                end

                -- add return trip
                result = table.get(map, destination, nil)
                if not result then
                    local v = {}
                    v[start] = 1
                    map[destination] = v
                else
                    result[start] = 1
                    map[destination] = result
                end
            end
        end
    end

    local r = {}
    for key, value in pairs(map) do
        local v = {}
        for d, _ in pairs(value) do table.insert(v, d) end
        r[key] = v
    end
    service.routes = r
end

--#endregion

--- shuffle a table
function this.shuffle(tbl)
    for i = #tbl, 2, -1 do
        local j = math.random(i)
        tbl[i], tbl[j] = tbl[j], tbl[i]
    end
end

return this
