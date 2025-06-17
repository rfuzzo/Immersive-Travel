---@meta

---@class SPortDto
---@field data table<string, PortDataDto> The port data

---@class PortDataDto
---@field position PositionRecord The port position
---@field rotation PositionRecord The port orientation
---@field positionEnd PositionRecord? The docked orientation
---@field rotationEnd PositionRecord? The docked orientation
---@field positionStart PositionRecord? The start orientation
---@field rotationStart PositionRecord? The start orientation
---@field reverseStart boolean? reverse out of dock?

---@class SSegmentDto
---@field id string? unique id
---@field route1 PositionRecord[]?

---@class ReferenceRecord
---@field cell tes3cell The cell
---@field position tes3vector3 The reference position

---@class Node
---@field id string
---@field position tes3vector3? RUNTIME
---@field reverse boolean

---@class SharedWaterway
---@field id string unique identifier for the shared segment
---@field segmentId string the segment ID that is shared
---@field occupiedBy string? vehicle ID currently using this waterway
---@field queue string[] list of vehicle IDs waiting to use this waterway

---@class RouteIntersection
---@field id string unique identifier for the intersection
---@field segmentName string the segment containing the intersection point
---@field pointIndex number the index of the point in the segment where intersection occurs
---@field radius number collision detection radius around the intersection
---@field occupiedBy string? vehicle ID currently in the intersection
---@field queue string[] list of vehicle IDs waiting to enter intersection
