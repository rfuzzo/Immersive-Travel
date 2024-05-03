local lib                  = require("ImmersiveTravel.lib")
local CAiState             = require("ImmersiveTravel.Statemachine.ai.CAiState")
local interop              = require("ImmersiveTravel.interop")
local log                  = lib.log

-- Define a class to manage the tracking list and timer
---@class CTrackingManager
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
--- @type CTrackingManager?
local trackingManager = nil
--- @return CTrackingManager
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
    self.trackingList[entity.refid] = nil

    entity.referenceHandle:getObject().tempData.scriptedEntityId = nil

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
    self.timer = timer.start {
        duration = self.TIMER_TICK,
        type = timer.simulate,
        iterations = -1, -- Repeat indefinitely
        callback = function()
            self:doCull()

            for key, entity in pairs(self.trackingList) do
                -- log:debug("OnTick %s", entity.id)
                entity:OnTick(self.TIMER_TICK)
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
        -- only cull vehicles that are in onspline ai state
        if vehicle.aiStateMachine and vehicle.aiStateMachine.currentState.name == CAiState.ONSPLINE then
            if not vehicle:GetRootBone() then
                table.insert(toremove, s)
                goto continue
            end

            local d = tes3.player.position:distance(vehicle.last_position)
            if d > self.cullRadius * 8192 then
                table.insert(toremove, s)
            end

            -- if d > mge.distantLandRenderConfig.drawDistance * 8192 then
            --     table.insert(toremove, s)
            -- end
        end
        ::continue::
    end

    for _, s in ipairs(toremove) do
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
