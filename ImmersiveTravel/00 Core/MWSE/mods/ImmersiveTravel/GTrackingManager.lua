local lib                  = require("ImmersiveTravel.lib")
local CAiState             = require("ImmersiveTravel.Statemachine.ai.CAiState")
local interop              = require("ImmersiveTravel.interop")
local log                  = lib.log

-- Define a class to manage the tracking list and timer
---@class GTrackingManager
---@field trackingList table<number,CTickingEntity>
---@field timer mwseTimer?
---@field TIMER_TICK number
---@field budget number
---@field cullRadius number
local TrackingManager      = {
    trackingList = {},
    timer = nil
}

TrackingManager.TIMER_TICK = 0.01
TrackingManager.budget     = 20
TrackingManager.cullRadius = 4

function TrackingManager:new()
    local newObj = {}
    self.__index = self
    setmetatable(newObj, self)
    return newObj
end

-- singleton instance
--- @type GTrackingManager?
local trackingManager = nil
--- @return GTrackingManager
function TrackingManager.getInstance()
    if trackingManager == nil then
        trackingManager = TrackingManager:new()
    end
    return trackingManager
end

--- Add an entity to the tracking list
---@param entity CTickingEntity
function TrackingManager:AddEntity(entity)
    local refid = nil
    for i = 1, self.budget, 1 do
        if self.trackingList[i] == nil then
            refid = i
            break
        end
    end

    if refid == nil then
        log:debug("Budget exceeded")
        return
    end

    self.trackingList[refid] = entity
    entity.referenceHandle:getObject().tempData.scriptedEntityId = refid
    entity.refid = refid

    log:debug("Added %s to tracking list", entity:Id())
    log:debug("Tracking list size: %s", table.size(self.trackingList))
end

--- Remove an entity from the tracking list
---@param entity CTickingEntity
function TrackingManager:RemoveEntity(entity)
    entity.referenceHandle:getObject().tempData.scriptedEntityId = nil

    self.trackingList[entity.refid] = nil

    log:debug("Removed %s from tracking list", entity:Id())
    log:debug("Tracking list size: %s", table.size(self.trackingList))
end

--- Get an entity from the tracking list
---@param id number
---@return CTickingEntity?
function TrackingManager:GetEntity(id)
    return self.trackingList[id]
end

-- Start the timer to call OnTick on each entity in the tracking list
function TrackingManager:StartTimer()
    log:trace("TrackingManager Starting timer")

    self.timer = timer.start {
        duration = self.TIMER_TICK,
        type = timer.simulate,
        iterations = -1, -- Repeat indefinitely
        callback = function()
            self:doCull()

            for key, entity in pairs(self.trackingList) do
                -- skip marked
                if entity and entity.markForDelete == false then
                    entity:OnTick(self.TIMER_TICK)
                end
            end
        end
    }
end

-- Stop the timer
function TrackingManager:StopTimer()
    if self.timer then
        self.timer:cancel()
        self.timer = nil
    end
end

function TrackingManager:Cleanup()
    self:StopTimer()
    self.trackingList = {}

    log:debug("TrackingManager cleaned up")
end

--#region events

--- activate the entity
---@param reference tes3reference
function TrackingManager:OnActivate(reference)
    if interop.isScriptedEntity(reference.id) then
        -- check if entity is already in tracking list
        if reference.tempData.scriptedEntityId then
            -- get entity from tracking list
            local scriptedEntity = self:GetEntity(reference.tempData.scriptedEntityId)
            if scriptedEntity then
                scriptedEntity:OnActivate()
            end
        else
            -- make new scripted class and register it
            local scriptedEntity = interop.newVehicle(reference.id)
            if scriptedEntity then
                scriptedEntity.referenceHandle = tes3.makeSafeObjectHandle(reference)
                self:AddEntity(scriptedEntity)

                scriptedEntity:OnActivate()
            end
        end
    end
end

--- delete the entity
---@param reference tes3reference
function TrackingManager:OnDestroy(reference)
    if interop.isScriptedEntity(reference.id) then
        if reference.tempData.scriptedEntityId then
            local scriptedEntity = self:GetEntity(reference.tempData.scriptedEntityId)
            if scriptedEntity then
                scriptedEntity:Delete()
            end
        else
            reference:delete()
        end
    end
end

--- @param e saveEventData
local function saveCallback(e)
    -- go through all tracked objects and set .modified = false
    for key, s in pairs(TrackingManager.getInstance().trackingList) do
        -- only if ai state is onspline or playertravel or non
        if s.aiStateMachine and (s.aiStateMachine.currentState.name == CAiState.ONSPLINE
                or s.aiStateMachine.currentState.name == CAiState.PLAYERTRAVEL
                or s.aiStateMachine.currentState.name == CAiState.NONE) then
            if s.referenceHandle and s.referenceHandle:valid() then
                s.referenceHandle:getObject().modified = false

                -- go through all slots
                local vehicle = s ---@cast vehicle CVehicle
                -- hidden slot
                if vehicle.hiddenSlot and vehicle.hiddenSlot.handles then
                    for index, handle in ipairs(vehicle.hiddenSlot.handles) do
                        if handle and handle:valid() then
                            handle:getObject().modified = false
                        end
                    end
                end

                -- guide
                if vehicle.guideSlot.handle and vehicle.guideSlot.handle:valid() then
                    local guide = vehicle.guideSlot.handle:getObject()
                    if guide ~= tes3.player then
                        guide.modified = false
                    end
                end

                -- passengers
                for index, slot in ipairs(vehicle.slots) do
                    if slot.handle and slot.handle:valid() then
                        local obj = slot.handle:getObject()
                        if obj ~= tes3.player then
                            obj.modified = false
                        end
                    end
                end

                -- statics
                if vehicle.clutter then
                    for index, clutter in ipairs(vehicle.clutter) do
                        if clutter.handle and clutter.handle:valid() then
                            local obj = clutter.handle:getObject()
                            obj.modified = false
                        end
                    end
                end
            end
        end
    end
end
event.register(tes3.event.save, saveCallback)

--#endregion

--#region cull

--- cull nodes in distance
function TrackingManager:doCull()
    ---@type CTickingEntity[]
    local toremove = {}
    for key, s in pairs(self.trackingList) do
        local vehicle = s ---@cast vehicle CVehicle

        if s.markForDelete then
            log:debug("Marked as deleted %s", s:Id())
            table.insert(toremove, s)
            goto continue
        end

        -- only cull vehicles that are in onspline ai state
        if vehicle.aiStateMachine and vehicle.aiStateMachine.currentState.name == CAiState.ONSPLINE then
            if not vehicle:GetRootBone() then
                log:warn("No root bone %s", s:Id())
                table.insert(toremove, s)
                goto continue
            end

            local d = tes3.player.position:distance(vehicle.last_position)
            if d > self.cullRadius * 8192 then
                log:debug("Culled out of distance %s", s:Id())
                table.insert(toremove, s)
                goto continue
            end
            -- if d > mge.distantLandRenderConfig.drawDistance * 8192 then
            --     table.insert(toremove, s)
            -- end
        end

        ::continue::
    end

    for _, s in ipairs(toremove) do
        -- mark as deleted
        s.markForDelete = true

        s:Delete()

        log:debug("Culled %s", s:Id())
    end

    -- logging
    if #toremove > 0 then
        log:debug("Tracked: %s", table.size(self.trackingList))
        tes3.messageBox("Tracked: %s", table.size(self.trackingList))
    end
end

--#endregion

return TrackingManager
