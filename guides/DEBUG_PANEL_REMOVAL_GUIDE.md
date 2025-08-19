# Debug Panel Removal Guide

## Overview
The debug panel system was added for performance testing and can be completely removed without affecting gameplay. All debug code is wrapped with checks for `DebugSettings.instance`.

## Files to Delete

### Core Debug Files (DELETE THESE)
1. `systems/debug_settings.gd` - The singleton that stores all debug flags
2. `ui/debug_panel.gd` - The UI panel component
3. `ui/entity_counter.gd` - The entity counter display (optional - can keep if useful)

### Modified Files (REMOVE DEBUG CODE)

#### 1. `game_controller.gd`
**Remove:**
```gdscript
# Line ~575-577 - Entity counter creation
var entity_counter = preload("res://ui/entity_counter.gd").new()
entity_counter.name = "EntityCounter"
ui_layer.add_child(entity_counter)
```

#### 2. `ui/pause_menu.gd`
**Remove:**
- Lines 14-16: Debug panel variables
- Lines 89-92: Debug button creation
- Lines 365-428: `_on_debug_pressed()` function entirely
- Any references to `debug_panel_window` or `debug_panel`

#### 3. `systems/entity_system/base_entity.gd`
**Remove these debug checks:**
```gdscript
# Line ~124-127 - Movement disable check
if is_in_group("enemies") and DebugSettings.instance and not DebugSettings.instance.mob_movement_enabled:
    velocity = Vector2.ZERO
    move_and_slide()
    return

# Line ~383-408 - _update_collision_settings() function entirely

# Line ~133 - Remove this line:
_update_collision_settings()

# Line ~413-414 - Damage number check
if DebugSettings.instance and not DebugSettings.instance.damage_numbers_enabled:
    return

# Line ~437-438 - Ability check
if DebugSettings.instance and not DebugSettings.instance.ability_system_enabled:
    return false
```

#### 4. `entities/enemies/base_enemy.gd`
**Remove:**
```gdscript
# Line ~102-104 - AI disable check
if DebugSettings.instance and not DebugSettings.instance.mob_ai_enabled:
    return

# Line ~219-220 - XP drops check
if DebugSettings.instance and not DebugSettings.instance.xp_drops_enabled:
    return
```

#### 5. `entities/base_creature.gd`
**Remove:**
```gdscript
# Line ~44-49 - Physics process for nameplate
func _physics_process(_delta):
    super._physics_process(_delta)
    # Update nameplate visibility based on debug settings
    if username_label and DebugSettings.instance:
        username_label.visible = DebugSettings.instance.nameplates_enabled

# Line ~53-55 - In _setup_username_label()
if DebugSettings.instance and not DebugSettings.instance.nameplates_enabled:
    username_label.visible = false
```

#### 6. `systems/movement_system/ai_movement_controller.gd`
**Remove:**
```gdscript
# Line ~106-112 - All debug checks
if DebugSettings.instance:
    if not DebugSettings.instance.mob_ai_enabled:
        return
    if not DebugSettings.instance.mob_movement_enabled:
        return
    if not DebugSettings.instance.pathfinding_enabled:
        return
```

#### 7. `systems/movement_system/zombie_movement_controller.gd`
**Remove:**
```gdscript
# Line ~27-32 - Debug checks
if DebugSettings.instance:
    if not DebugSettings.instance.mob_movement_enabled:
        return Vector2.ZERO
    if not DebugSettings.instance.mob_ai_enabled:
        return Vector2.ZERO
```

#### 8. `systems/flocking_system.gd`
**Remove:**
```gdscript
# Line ~40-45 - Flocking disable check
if DebugSettings.instance and not DebugSettings.instance.flocking_enabled:
    # Clear all forces if disabled
    for entity in flock_entities:
        flock_cache[entity] = Vector2.ZERO
    return
```

#### 9. `systems/ticket_spawn_manager.gd`
**Remove:**
```gdscript
# Line ~58-60 - Spawning disable check
if DebugSettings.instance and not DebugSettings.instance.spawning_enabled:
    return
```

#### 10. `systems/weapon_system/weapon.gd`
**Remove:**
```gdscript
# Line ~48-50 - Weapon disable check
if DebugSettings.instance and not DebugSettings.instance.weapon_system_enabled:
    return

# Line ~15-16 - Debug variables (if not used elsewhere)
var show_attack_debug: bool = false
var attack_debug_timer: float = 0.0
```

## Removal Steps

### Step 1: Delete Core Files
```bash
rm systems/debug_settings.gd
rm ui/debug_panel.gd
rm ui/entity_counter.gd  # Optional
rm guides/DEBUG_PANEL_REMOVAL_GUIDE.md  # This file
```

### Step 2: Clean Modified Files
Use your editor's search to find all occurrences of:
- `DebugSettings.instance`
- `debug_panel`
- `debug_settings`
- `entity_counter`

Remove all the code blocks mentioned above.

### Step 3: Test
1. Run the game to ensure no errors
2. Check that all systems work normally
3. Verify pause menu still functions

## Alternative: Keep But Disable

If you want to keep the debug system but disable it:

1. In `game_controller.gd`, comment out the entity counter creation
2. In `pause_menu.gd`, comment out the debug button creation
3. Set all flags to `true` in `debug_settings.gd` by default

## Design Pattern Used

The debug system uses:
- **Singleton pattern** (DebugSettings.instance)
- **Null-safe checks** (always checks if instance exists)
- **Non-invasive integration** (only adds checks, doesn't modify core logic)

This makes it safe to remove - the game will function identically without it.

## Summary

Total files to modify: ~10
Total lines to remove: ~100-150
Risk level: LOW - All debug code is isolated with checks

The debug panel was designed for easy removal. All integration points check for `DebugSettings.instance` before executing, so removing the singleton immediately disables all debug functionality.