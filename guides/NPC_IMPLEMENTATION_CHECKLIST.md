# NPC Implementation Checklist

## Pre-Implementation
- [ ] Determine NPC type (basic enemy, evolved form, boss)
- [ ] Choose base class: `BaseCreature` or `BaseEvolvedCreature`
- [ ] Plan abilities needed (if any)
- [ ] Decide attack type: MELEE or RANGED
- [ ] Gather/create sprite assets

## Core Script Setup
- [ ] Create script file in `entities/enemies/`
- [ ] Extend correct base class
- [ ] Add `class_name YourNPC`
- [ ] Override `_entity_ready()` and call `super._entity_ready()`
- [ ] Create `_setup_npc()` or `_setup_evolution()` method

## Required Properties
- [ ] Set `creature_type` (string identifier)
- [ ] Set `base_scale` (typically 0.8-1.5)
- [ ] Set `abilities` array (empty if none)
- [ ] Configure all stats:
  - [ ] `max_health` and `current_health`
  - [ ] `move_speed`
  - [ ] `damage`
  - [ ] `attack_range`
  - [ ] `attack_cooldown`
  - [ ] `attack_type` (MELEE/RANGED)
  - [ ] `has_mana = false` (unless needed)

## Tagging
- [ ] Add "Enemy" tag (required)
- [ ] Add "TwitchMob" tag (if Twitch-spawned)
- [ ] Add creature type tag
- [ ] Add attack style tag ("Melee" or "Ranged")
- [ ] Add any special tags ("Flying", "Boss", etc.)

## Groups
- [ ] Add to "enemies" group
- [ ] Add to "ai_controlled" group
- [ ] Add to any special groups (e.g., "twitch_rats", "bosses")

## Scene File (.tscn)
- [ ] Create scene file in `entities/enemies/`
- [ ] Root node: `CharacterBody2D`
- [ ] Set script to your NPC script
- [ ] Add `Sprite2D` or `AnimatedSprite2D` child
- [ ] Add `CollisionShape2D` child
- [ ] Configure collision:
  - [ ] `collision_layer = 2` (enemies)
  - [ ] `collision_mask = 3` (detect player + enemies)
  - [ ] `z_index = 4`

## Movement & AI
- [ ] AI controller auto-added by BaseEnemy (no action needed)
- [ ] Implement aggro system (if needed):
  - [ ] Add `aggro_radius` export
  - [ ] Add `is_aggroed` variable
  - [ ] Implement `_check_aggro_range()`
- [ ] Implement wandering (if needed):
  - [ ] Add wander variables
  - [ ] Implement `_handle_wandering()`
  - [ ] Implement `_randomize_wander_target()`
- [ ] Add `_face_movement_direction()` for sprite flipping

## Abilities (if any)
- [ ] Declare ability variables at class level
- [ ] Call `call_deferred("_setup_abilities")` in setup
- [ ] Create `_setup_abilities()` method:
  - [ ] Add `await get_tree().create_timer(0.1).timeout`
  - [ ] Check and link ability system components
  - [ ] Create and configure each ability
  - [ ] Call `add_ability()` for each

## Combat Behavior
- [ ] Override `_entity_physics_process()` if needed
- [ ] Implement attack patterns
- [ ] For ranged: Set `preferred_attack_distance`
- [ ] Handle ability execution based on range

## Death Attribution
- [ ] Verify `get_display_name()` works (inherited)
- [ ] Verify `get_killer_display_name()` works (inherited)
- [ ] Override `get_attack_name()` if custom attack names needed

## Testing
- [ ] Spawn NPC in game
- [ ] Verify sprite displays correctly
- [ ] Test collision detection
- [ ] Check wandering behavior
- [ ] Test aggro activation
- [ ] Verify combat AI:
  - [ ] Melee units close distance
  - [ ] Ranged units maintain distance
- [ ] Test all abilities trigger correctly
- [ ] Verify death and loot drops
- [ ] Check performance with multiple instances

## Common Issues & Fixes

### NPC doesn't move
- Check if AI controller exists: `get_node_or_null("AIMovementController")`
- Ensure `add_to_group("ai_controlled")` is called
- Verify collision layers are correct

### Abilities don't work
- Check ability system is linked: `ability_manager.ability_holder = ability_holder`
- Ensure `_setup_abilities()` uses `await` for timing
- Verify ability IDs match when calling `execute_ability()`

### Sprite doesn't flip
- Ensure `sprite` reference is set (inherited from BaseEntity)
- Call `_face_movement_direction()` in physics process

### NPC instantly dies
- Check `current_health = max_health` is set
- Verify collision mask isn't detecting wrong layers

### No aggro behavior
- Implement `_check_aggro_range()` method
- Call it in `_entity_physics_process()`
- Ensure `_find_player()` returns valid player (inherited method)

## Final Verification
- [ ] Code follows OOP principles
- [ ] All methods properly override parent methods
- [ ] No hardcoded values (use properties)
- [ ] Proper error handling for missing components
- [ ] Clean debug prints (remove or comment out)
- [ ] Documentation comments added
