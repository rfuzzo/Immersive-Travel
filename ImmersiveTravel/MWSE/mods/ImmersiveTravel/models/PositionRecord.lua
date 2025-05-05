---@class PositionRecord
---@field x number The x position
---@field y number The y position
---@field z number The z position
local PositionRecord = {}

--- @param o PositionRecord
--- @return tes3vector3
function PositionRecord.ToVec(o)
    return tes3vector3.new(o.x, o.y, o.z)
end

--- @param o tes3vector3
--- @return PositionRecord
function PositionRecord.FromVec(o)
    return {
        x = o.x,
        y = o.y,
        z = o.z
    }
end

--- @param o tes3vector3
--- @return PositionRecord
function PositionRecord.FromVecInt(o)
    return {
        x = math.round(o.x),
        y = math.round(o.y),
        z = math.round(o.z)
    }
end

---@param vec tes3vector3[]
---@return PositionRecord[]
function PositionRecord.ToList(vec)
    local list = {} ---@type PositionRecord[]
    for i = 1, #vec do
        list[i] = PositionRecord.FromVec(vec[i])
    end

    return list
end

---@param vec tes3vector3[]
---@return PositionRecord[]
function PositionRecord.ToListInt(vec)
    local list = {} ---@type PositionRecord[]
    for i = 1, #vec do
        list[i] = PositionRecord.FromVecInt(vec[i])
    end

    return list
end

return PositionRecord
