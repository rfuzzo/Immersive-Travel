local lib = require("ImmersiveTravel.lib")
local interop = require("ImmersiveTravel.interop")

-- TODO modified false on save

-- Define a class to manage the tracking list and timer
---@class CTrackingManager
---@field trackingList CTickingEntity[]
---@field timer mwseTimer?
---@field TIMER_TICK number
local TrackingManager = {
    trackingList = {},
    timer = nil
}

TrackingManager.TIMER_TICK = 0.01
-- TODO add budget for tracking list

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
    table.insert(self.trackingList, entity)

    -- TODO is this a good idea?
    entity.referenceHandle:getObject().tempData.scriptedEntity = entity

    lib.log:debug("Added %s to tracking list", entity.id)
    lib.log:debug("Tracking list size: %s", #self.trackingList)
end

--- Remove an entity from the tracking list
---@param entity CTickingEntity
function TrackingManager:RemoveEntity(entity)
    table.removevalue(self.trackingList, entity)

    entity.referenceHandle:getObject().tempData.scriptedEntity = nil

    lib.log:debug("Removed %s from tracking list", entity.id)
    lib.log:debug("Tracking list size: %s", #self.trackingList)
end

-- Start the timer to call OnTick on each entity in the tracking list
function TrackingManager:StartTimer()
    self.timer = timer.start {
        duration = self.TIMER_TICK,
        type = timer.simulate,
        iterations = -1, -- Repeat indefinitely
        callback = function()
            for _, entity in ipairs(self.trackingList) do
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

    lib.log:debug("TrackingManager cleaned up")
end

--#region events

--- activate the entity
---@param reference tes3reference
function TrackingManager:OnActivate(reference)
    if interop.isScriptedEntity(reference.id) then
        -- check if entity is already in tracking list
        if reference.tempData.scriptedEntity then
            -- get it from table and delegate to entity
            reference.tempData.scriptedEntity:OnActivate()
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
function TrackingManager.OnDestroy(reference)
    if interop.isScriptedEntity(reference.id) then
        if reference.tempData.scriptedEntity then
            reference.tempData.scriptedEntity:Delete()
        else
            reference:delete()
        end
    end
end

--#endregion

return TrackingManager
