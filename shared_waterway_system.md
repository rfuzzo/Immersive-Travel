# Shared Waterway Collision System

## Overview

This system replaces the complex real-time evasion mechanics with a simpler segment-based queuing system for handling vehicle collisions on shared waterways (narrow passages that can only accommodate one vehicle at a time).

## How It Works

### Key Components

1. **Shared Waterways**: Defined in TOML files under `data/{service}/shared/` directories
2. **Queue Management**: Vehicles queue to enter busy waterways
3. **Rear Collision Detection**: Prevents vehicles from colliding from behind on the same route

### Configuration

Shared waterways are configured in TOML files:

```toml
# Example: firewatch_strait_narrows.toml
segmentId = "Firewatch Strait"
```

The file name becomes the waterway ID, and `segmentId` specifies which route segment is shared.

### Vehicle Movement Logic

1. **Entering Segments**: When a vehicle moves to a new segment, it checks if that segment is a shared waterway:
   - If free: Vehicle enters immediately
   - If occupied: Vehicle is added to a queue and waits

2. **Proceeding on Segments**: Before moving each frame, vehicles check:
   - Can proceed on current segment (not blocked by another vehicle)
   - No rear collision risk from vehicles behind

3. **Exiting Segments**: When leaving a segment, vehicles:
   - Exit the shared waterway
   - Allow the next queued vehicle to enter

### Safety Features

- **Automatic Cleanup**: Vehicles exit shared waterways when deleted/cleaned up
- **Rear Collision Avoidance**: Vehicles slow down if another vehicle is too close behind
- **Validation**: Robust error checking for missing routes, services, or invalid references

## File Locations

- **Main Logic**: `Statemachine/locomotion/CLocomotionState.lua`
- **Manager**: `GRoutesManager.lua` (shared waterway methods)
- **Cleanup**: `Vehicles/CVehicle.lua` (exit on vehicle destruction)
- **Configuration**: `data/{service}/shared/*.toml`

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
