# AI Slop Survivors - Game Architecture

This document describes the core architecture of the game, focusing on the hybrid enemy system and key design patterns.

## Overview

AI Slop Survivors is a Vampire Survivors-style game with deep Twitch chat integration, built in Godot 4.x with a focus on scalability and modularity.

## Hybrid Enemy Architecture

The game uses a dual approach to handle different types of entities efficiently:

### Minions (Data-Oriented System)
**Used for**: High-volume enemies (rats, succubus, woodland_joe)

**Key Components**:
- **EnemyManager**: Manages enemies as parallel arrays (positions, health, damage, etc.)
- **MultiMesh Rendering**: GPU-instanced rendering for 1000+ entities
- **Spatial Grid**: O(1) neighbor queries and collision detection
- **Flow-Field Pathfinding**: Single BFS from player, all enemies follow gradient

**Data Storage**:
```gdscript
# Arrays in EnemyManager
positions: PackedVector2Array
healths: PackedFloat32Array  
move_speeds: PackedFloat32Array
attack_damages: PackedFloat32Array
# ... dozens more parallel arrays
```

**Performance Benefits**:
- 1000+ enemies at 60 FPS
- Minimal memory allocation
- Cache-friendly data layout
- Efficient batch processing

### Bosses (Node-Based System)
**Used for**: Complex individual entities (thor, mika, forsen, zzran)

**Key Components**:
- **BossFactory**: Creates individual CharacterBody2D nodes
- **Dedicated Scripts**: Each boss has custom behavior script
- **Traditional Godot Systems**: Full scene/node capabilities
- **Custom Abilities**: Complex multi-phase behaviors

**Boss Examples**:
- `thor_enemy.gd` - Melee boss with voice lines
- `mika_boss.gd` - Fast boss with dash attacks
- `forsen_boss.gd` - Multi-phase transformation boss

## Core System Architecture

### GameController (Orchestrator)
**Role**: Main system coordinator and initialization

**Responsibilities**:
- Initialize all core managers in correct order
- Handle Twitch chat message routing
- Coordinate pause states and game flow
- Provide boss spawning methods
- Bridge between UI and game systems

### Command Processing Flow
```
Twitch Chat → TwitchBot → GameController → CommandProcessor → Target System
```

**Key Systems**:
1. **CommandProcessor**: Parses and validates all chat commands
2. **TicketSpawnManager**: Handles `!join` and entity spawning
3. **MXPManager**: Manages currency and upgrade purchases
4. **EvolutionSystem**: Processes `!evolve` requests
5. **BossVoteManager**: Manages periodic boss voting

### Data-Oriented Enemy System Details

**Movement & AI**:
- **Flow-Field Navigation**: Single BFS creates direction field from player
- **Obstacle Avoidance**: Arena boundaries, pits, and pillars
- **Attack Logic**: Unified collision detection via PlayerCollisionDetector

**Ability System Integration**:
- **Simple Abilities**: Direct effect instantiation (explosions, poison clouds)
- **Complex Abilities**: V2AbilityProxy bridges array data to node-based abilities
- **Per-Entity Cooldowns**: Individual timing tracked in arrays

**Live Physics Subset**:
- Small pool of CharacterBody2D nodes for nearest enemies
- Recycled and positioned dynamically
- Enables traditional weapon/collision interactions
- Bodies disabled when not in use

## Twitch Integration Architecture

### Real-Time Chat Processing
```
Twitch IRC → TwitchBot → GameController → CommandProcessor → Game Systems
```

### User State Management
- **MXPManager**: Persistent currency per user
- **ChatterEntityManager**: User upgrade tracking
- **TicketSpawnManager**: Spawn pool membership
- **Color System**: Consistent user colors via hash

### Command Categories
1. **Free Commands**: !explode, !fart, !boost (cooldown-limited)
2. **MXP Commands**: !hp, !speed, !evolve (currency cost)
3. **System Commands**: !join, !vote1/2/3 (system interaction)

## Performance Optimization Patterns

### Batch Processing
- Enemy updates processed in configurable slices
- Position integration every frame for smoothness
- Heavy logic (AI, abilities) spread across multiple frames

### Memory Management
- Object pooling for UI elements and physics bodies
- MultiMesh eliminates per-entity node overhead
- Packed arrays for cache-friendly data access

### Rendering Optimization
- GPU instancing via MultiMesh
- Automatic frustum culling
- Per-type rendering for visual variety

## Signal-Based Communication

### Core Signals
```gdscript
# GameController
signal chat_message_received(username, message, color)

# BossFactory
signal boss_spawned(boss_node, boss_type)

# EvolutionSystem
signal evolution_completed(username, old_entity, new_entity)
```

### Benefits
- Loose coupling between systems
- Event-driven architecture
- Easy to add new listeners
- Clear data flow

## Singleton Pattern Usage

### Global Managers
```gdscript
EnemyManager.instance
MXPManager.instance
GameController.instance
TicketSpawnManager.instance
```

### Access Pattern
```gdscript
# Safe singleton access
if EnemyManager.instance:
    EnemyManager.instance.spawn_enemy(type, pos, username)
```

## System Initialization Order

1. **Core Singletons**: DebugSettings, ResourceManager
2. **Core Managers**: WorldSetup, Session, Input, UI
3. **Game Systems**: Enemy, Boss, MXP, Evolution
4. **Twitch Integration**: Chat processing, command routing
5. **World Setup**: Player creation, UI connection

## Adding New Features

### New Chat Command
1. Add command parsing in `CommandProcessor`
2. Implement validation and cost checking
3. Route to appropriate system
4. Add feedback via action feed

### New Enemy Type (Minion)
1. Define stats in `EnemyConfigManager`
2. Add type ID to `EnemyManager`
3. Create MultiMesh variant if needed
4. Define abilities in bridge system

### New Boss
1. Create dedicated script extending `BaseBoss`
2. Define in `BossFactory.BOSS_CONFIGS`
3. Create scene file with visuals
4. Add spawn method to `GameController`

## File Structure
```
AI_SLOP_SURVIVORS/
├── game_controller.gd           # Main orchestrator
├── systems/
│   ├── core/                   # Core systems
│   │   ├── enemy_manager.gd    # Data-oriented enemy system  
│   │   ├── boss_factory.gd     # Node-based boss creation
│   │   ├── command_processor.gd # Chat command handling
│   │   └── ...
│   ├── managers/               # Specialized managers
│   │   ├── mxp_manager.gd     # Currency system
│   │   ├── boss_vote_manager.gd # Boss voting
│   │   └── ...
│   └── ability_system/         # Ability framework
├── entities/
│   ├── enemies/regular/        # Minion scenes/scripts
│   └── enemies/bosses/         # Boss scripts
└── ui/                        # User interface
```

## Key Design Principles

1. **Hybrid Approach**: Use the right tool for each job (arrays vs nodes)
2. **Scalability First**: Support 1000+ entities without performance loss
3. **Modular Systems**: Each system has clear responsibilities
4. **Signal Communication**: Event-driven architecture for loose coupling
5. **Twitch-Native**: Chat integration as a first-class citizen
6. **Performance Conscious**: Batch processing, object pooling, efficient data structures

## Testing & Debugging

### Development Tools
- Comprehensive cheat system (F1-F3, Alt+1-0)
- Mock chat for offline testing
- Real-time performance monitoring
- Visual debug overlays

### Performance Testing
- 1000+ enemy stress tests
- Memory usage monitoring  
- Frame rate stability testing
- System integration validation

This architecture supports the game's core goal: providing an engaging Twitch-integrated experience that scales to thousands of concurrent entities while maintaining clean, maintainable code.