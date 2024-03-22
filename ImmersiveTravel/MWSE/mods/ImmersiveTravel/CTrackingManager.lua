local lib = require("ImmersiveTravel.lib")

-- TODO modiefied false on save

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

    lib.log:debug("Added %s to tracking list", entity.id)
end

--- Remove an entity from the tracking list
---@param entity CTickingEntity
function TrackingManager:RemoveEntity(entity)
    table.removevalue(self.trackingList, entity)

    lib.log:debug("Removed %s from tracking list", entity.id)
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

return TrackingManager
