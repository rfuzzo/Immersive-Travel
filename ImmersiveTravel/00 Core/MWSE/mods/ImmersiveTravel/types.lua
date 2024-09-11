---@meta

---@class ServiceData
---@field class string The npc class name
---@field mount string The mount
---@field override_npc string[]? register specific npcs with the service
---@field override_mount table<string,string[]>? register specific mounts with the service
---@field routes table<string, string[]>? Destinations for this Cell name
---@field ground_offset number DEPRECATED: editor marker offset
---@field guide string[]? guide npcs
---@field ports table<string, PortData>? port list

---@class PortData
---@field position PositionRecord The port position
---@field rotation PositionRecord The port orientation
---@field positionEnd PositionRecord? The docked orientation
---@field rotationEnd PositionRecord? The docked orientation
---@field positionStart PositionRecord? The start orientation
---@field rotationStart PositionRecord? The start orientation
---@field reverseStart boolean? reverse out of dock?

---@class ReferenceRecord
---@field cell tes3cell The cell
---@field position tes3vector3 The reference position

---@class PositionRecord
---@field x number The x position
---@field y number The y position
---@field z number The z position

---@class SSegment
---@field id string -- TODO unique id
---@field routes PositionRecord[][]

---@class SSegmentMetaData
---@field routeIdx number The route index inside the Segment

---@class SRoute
---@field start string The start cell name
---@field destination string The destination cell name
---@field segments string[] The route segments
---@field segmentsMetaData table<string, SSegmentMetaData> The route segments meta data
