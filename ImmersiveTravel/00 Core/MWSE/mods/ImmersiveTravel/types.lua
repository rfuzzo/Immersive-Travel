---@meta

---@class PortDataDto
---@field position PositionRecord The port position
---@field rotation PositionRecord The port orientation
---@field positionEnd PositionRecord? The docked orientation
---@field rotationEnd PositionRecord? The docked orientation
---@field positionStart PositionRecord? The start orientation
---@field rotationStart PositionRecord? The start orientation
---@field reverseStart boolean? reverse out of dock?

---@class SSegmentDto
---@field id string unique id
---@field routes PositionRecord[][]?
---@field segments SSegmentDto[]?

---@class ReferenceRecord
---@field cell tes3cell The cell
---@field position tes3vector3 The reference position

---@class SSegmentMetaData
---@field routeIdx number The route index inside the Segment
