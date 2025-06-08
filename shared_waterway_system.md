# Shared Waterway & Intersection Collision System

## Overview

This system replaces the complex real-time evasion mechanics with a simpler queuing system for handling vehicle collisions in two scenarios:
1. **Shared waterways** - Narrow passages that can only accommodate one vehicle at a time
2. **Route intersections** - Geographic locations where different routes cross each other

## How It Works

### Key Components

1. **Shared Waterways**: Defined in TOML files under `data/{service}/shared/` directories
2. **Route Intersections**: Defined in TOML files under `data/{service}/intersections/` directories  
3. **Queue Management**: Vehicles queue to enter busy waterways and intersections
4. **Rear Collision Detection**: Prevents vehicles from colliding from behind on the same route

### Configuration

**Shared waterways** are configured in TOML files:

```toml
# Example: firewatch_strait_narrows.toml
segmentId = "Firewatch Strait"
```

**Route intersections** are configured in TOML files:

```toml
# Example: vivec_foreign_quarter.toml
[position]
x = 96000.0
y = -103000.0
z = 0.0

radius = 300.0
```

The file name becomes the waterway/intersection ID. For shared waterways, `segmentId` specifies which route segment is shared. For intersections, `position` and `radius` define the geographic collision area.

### Vehicle Movement Logic

1. **Entering Segments**: When a vehicle moves to a new segment, it checks if that segment is a shared waterway:
   - If free: Vehicle enters immediately
   - If occupied: Vehicle is added to a queue and waits

2. **Intersection Checking**: Before moving each frame, vehicles check nearby intersections:
   - If intersection is free: Vehicle enters the intersection area
   - If occupied: Vehicle is added to intersection queue and waits

3. **Proceeding on Segments**: Before moving each frame, vehicles check:
   - Can proceed on current segment (not blocked by another vehicle)
   - Can proceed through nearby intersections (not blocked by cross-traffic)
   - No rear collision risk from vehicles behind

4. **Exiting Areas**: When leaving segments or intersections, vehicles:
   - Exit the shared waterway/intersection
   - Allow the next queued vehicle to enter

### Safety Features

- **Automatic Cleanup**: Vehicles exit shared waterways and intersections when deleted/cleaned up
- **Rear Collision Avoidance**: Vehicles slow down if another vehicle is too close behind
- **Cross-Route Collision Prevention**: Vehicles wait at intersections when cross-traffic is present
- **Validation**: Robust error checking for missing routes, services, or invalid references

## File Locations

- **Main Logic**: `Statemachine/locomotion/CLocomotionState.lua`
- **Manager**: `GRoutesManager.lua` (shared waterway and intersection methods)
- **Cleanup**: `Vehicles/CVehicle.lua` (exit on vehicle destruction)
- **Waterway Configuration**: `data/{service}/shared/*.toml`
- **Intersection Configuration**: `data/{service}/intersections/*.toml`

## Example Configurations

### Firewatch Strait Narrows
```toml
# data/Shipmaster/shared/firewatch_strait_narrows.toml
segmentId = "Firewatch Strait"
```

### Vivec Canal Entrance
```toml
# data/Shipmaster/shared/vivec_canal_entrance.toml
segmentId = "Inner Sea Vicec Connection 1" 
```

### Hla Oad Bridge
```toml
# data/Shipmaster/shared/hla_oad_bridge.toml
segmentId = "Hla Oad Connection"
```

## Benefits

1. **Simpler Logic**: No complex real-time evasion calculations
2. **Realistic Behavior**: Vehicles queue naturally at bottlenecks
3. **Configurable**: Easy to add new shared waterways via TOML files
4. **Robust**: Automatic cleanup and error handling
5. **Performance**: Segment-based checks are more efficient than continuous collision detection

## Usage

The system activates automatically when:
1. Shared waterway TOML files are present in `data/{service}/shared/`
2. Vehicles attempt to use segments defined in those files
3. Multiple vehicles are active on the same routes

No additional configuration or activation is required - the system works transparently with existing vehicle movement logic.
