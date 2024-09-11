---@class PositionRecord
---@field x number The x position
---@field y number The y position
---@field z number The z position
local PositionRecord = {}

--- @return tes3vector3
--- @param o PositionRecord
function PositionRecord.ToVec(o)
    return tes3vector3.new(o.x, o.y, o.z)
end

return PositionRecord
