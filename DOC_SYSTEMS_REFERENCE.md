# AI Slop Survivors - Systems Reference

This document provides an overview of all major systems in the game architecture, their key methods, and how they interact.

## Core Systems Architecture

### GameController (`game_controller.gd`)
**Main orchestrator of all game systems**

**Key Methods:**
- `_initialize_core_managers()` - Sets up all core managers
- `_setup_game_world()` - Creates player, UI, and connects systems
- `_handle_chat_message(username, message, color)` - Processes Twitch chat
- `spawn_*_boss(spawn_pos)` - Boss spawning methods (thor, mika, forsen, zzran)
- `get_action_feed()` - Gets UI action feed for messages
- `_execute_command_on_all_entities(username, method_name)` - Execute commands on entities

**Managed Systems:**
- WorldSetupManager, InputManager, SessionManager, UICoordinator
- BossFactory, GameStateManager, CursorManager, SystemInitializer
- CommandProcessor, CheatManager

---

## Core Management Systems

### EnemyManager (`systems/core/enemy_manager.gd`)
**V2 multimesh-based enemy system for minions (rats, succubus, woodland_joe)**

**Key Methods:**
- `spawn_enemy(enemy_type, position, username)` - Spawn new enemy
- `clear_all_enemies()` - Remove all enemies
- `evolve_enemy(enemy_id, new_type_id)` - Evolve enemy to new type
- `update_enemy_stats(enemy_id, stat_name, new_value)` - Update individual stats
- `get_enemy_type_from_string(type_name)` - Convert string to type ID
- `apply_damage_to_enemy(enemy_id, damage, source)` - Damage system
- `_physics_process(delta)` - Main update loop for movement/AI

**Data Arrays:** Handles positions, healths, damages, scales, colors via parallel arrays

### BossFactory (`systems/core/boss_factory.gd`)
**Node-based boss spawning system using dedicated scripts**

**Key Methods:**
- `spawn_boss(boss_type, spawn_position)` - Create boss instance
- `spawn_random_boss(spawn_position)` - Random boss selection
- `get_random_spawn_position(player_pos, min_dist, max_dist)` - Positioning

**Boss Types:** thor, mika, forsen, zzran (each with dedicated `.gd` scripts)

### EnemyConfigManager (`systems/core/enemy_config_manager.gd`)
**Configuration system for minion enemies (NOT used by bosses)**

**Key Methods:**
- `get_enemy_config(enemy_type)` - Get configuration data
- `get_base_stats(enemy_type)` - Get base stats for enemy type
- `apply_config_to_enemy(enemy_id, enemy_type, enemy_manager)` - Apply stats
- `validate_config(enemy_type)` - Validate configuration integrity

**Note:** Boss configs are legacy/reference only - bosses use dedicated scripts

### CommandProcessor (`systems/core/command_processor.gd`)
**Handles all Twitch chat commands**

**Key Methods:**
- `process_chat_command(username, message)` - Main command handler
- `_execute_entity_command(username, command)` - Execute commands on user entities
- `get_user_color(username)` - Generate consistent user colors

**Commands:** !explode, !fart, !boost, !evolve, !vote1/2/3, etc.

---

## Specialized Managers

### SessionManager (`systems/core/session_manager.gd`)
**Game session lifecycle management**

**Key Methods:**
- `start_session()` - Initialize new game session
- `end_session()` - Clean up current session
- `_perform_cleanup()` - Remove orphaned nodes
- `get_monster_power_stats()` - Get current difficulty stats

### TicketSpawnManager (`systems/core/ticket_spawn_manager.gd`)
**Manages Twitch user entity spawning and tracking**

**Key Methods:**
- `spawn_entity_for_chatter(username, entity_type, spawn_pos)` - Spawn user entity
- `get_alive_entities_for_chatter(username)` - Get user's active entities
- `handle_entity_death(entity_id)` - Process entity deaths
- `cleanup_inactive_chatters()` - Remove inactive users

### MXPManager (`systems/managers/mxp_manager.gd`)
**Monster XP currency system for Twitch users**

**Key Methods:**
- `award_mxp(username, amount, source)` - Give MXP to user
- `spend_mxp(username, amount, purpose)` - Deduct MXP from user
- `get_available_mxp(username)` - Check user's current MXP
- `get_leaderboard()` - Get top MXP holders

### BossVoteManager (`systems/managers/boss_vote_manager.gd`)
**Twitch chat boss voting system**

**Key Methods:**
- `_start_vote()` - Begin boss vote session
- `handle_vote_command(username, vote_number)` - Process vote commands
- `_spawn_winning_boss(boss_id)` - Spawn the winning boss
- `get_time_until_next_vote()` - Vote timer info

**Vote Cycle:** 5-minute intervals, 20-second voting windows

---

## Ability & Combat Systems

### AbilityManager (`systems/ability_system/core/ability_manager.gd`)
**Manages all entity abilities (explode, fart, boost, etc.)**

**Key Methods:**
- `get_ability(ability_name)` - Get ability instance
- `execute_ability(entity, ability_name, target_data)` - Trigger ability
- `register_ability(name, ability_class)` - Register new ability type

### V2AbilityProxy (`systems/core/v2_ability_proxy.gd`)
**Bridge between V2 multimesh system and ability system**

**Key Methods:**
- `execute_ability_for_enemy(enemy_id, ability_name)` - Execute on V2 enemy
- `_create_ability_effect(position, ability_config)` - Visual effects

---

## UI & Input Systems

### UICoordinator (`systems/core/ui_coordinator.gd`)
**Manages all UI elements and HUD**

**Key Methods:**
- `setup_ui(game_controller)` - Initialize UI systems
- `show_death_screen(killer, cause, color)` - Display death screen
- `show_pause_menu()` - Show/hide pause menu
- `get_action_feed()` - Get message feed component

### InputManager (`systems/core/input_manager.gd`)
**Handles keyboard shortcuts and cheat keys**

**Key Methods:**
- `_input(event)` - Process input events
- `show_cheat_instructions()` - Display available cheats

**Cheat Keys:**
- Alt+1-6: Spawn test enemies
- Alt+7-0: Spawn bosses
- F1: Grant XP, F2: Grant MXP, F3: Health boost

### CheatManager (`systems/core/cheat_manager.gd`)
**Implements cheat/debug functionality**

**Key Methods:**
- `spawn_test_rats(count)` - Spawn test enemies
- `spawn_boss_cheat(boss_type)` - Spawn specific boss
- `grant_global_mxp(amount)` - Give MXP to all users
- `clear_all_enemies()` - Remove all enemies

---

## Supporting Systems

### ResourceManager (`systems/core/resource_manager.gd`)
**Centralized resource loading and caching**

**Key Methods:**
- `load_scene(path)` - Load and cache scenes
- `load_texture(path)` - Load and cache textures
- `setup_background_music(parent)` - Initialize audio

### GameStateManager (`systems/core/game_state_manager.gd`)
**Pause state and game flow management**

**Key Methods:**
- `set_pause(reason, paused)` - Set pause state with reason
- `toggle_manual_pause()` - Toggle user pause
- `is_paused()` - Check if game is paused

**Pause Reasons:** MANUAL_PAUSE, DEATH_SCREEN, BOSS_VOTE, UPGRADE_SELECTION

### PositionHelper (`systems/core/position_helper.gd`)
**Utility for world positioning and boundaries**

**Key Methods:**
- `get_random_spawn_position(center, min_dist, max_dist)` - Safe spawn positions
- `is_within_world_bounds(position)` - Check position validity
- `clamp_to_world_bounds(position)` - Keep position in world

---

## Evolution & Upgrade Systems

### EvolutionSystem (`systems/evolution_system/evolution_system.gd`)
**Handles entity evolutions (rat → succubus, etc.)**

**Key Methods:**
- `request_evolution(username, evolution_name)` - Process evolution request
- `get_evolution_list()` - Available evolutions and costs
- `register_evolution(name, config)` - Add new evolution type

### ChatterEntityManager (`systems/managers/chatter_entity_manager.gd`)
**Manages Twitch user entity upgrades and tracking**

**Key Methods:**
- `apply_upgrades_to_entity(entity, username)` - Apply user upgrades
- `track_entity_for_chatter(username, entity)` - Associate entity with user

---

## System Initialization

### SystemInitializer (`systems/core/system_initializer.gd`)
**Bootstraps all game systems in correct order**

**Key Methods:**
- `initialize_all_systems(game_controller)` - Setup all systems
- `_initialize_singletons()` - Create singleton managers
- `_setup_system_references()` - Connect system dependencies

**Initialization Order:**
1. Singleton managers (MXP, BossVote, etc.)
2. Core systems (EnemyManager, AbilityManager)
3. UI and supporting systems
4. Twitch integration

---

## Key Architectural Patterns

### Singleton Systems
Many managers use singleton pattern for global access:
- `EnemyManager.instance`
- `MXPManager.instance`
- `GameController.instance`
- `TicketSpawnManager.instance`

### Enemy Architecture Split
- **Minions** (rats, succubus): EnemyManager (multimesh) + EnemyConfigManager
- **Bosses** (thor, mika): BossFactory + dedicated scripts (`thor_enemy.gd`, etc.)

### Signal-Based Communication
Systems communicate via Godot signals for loose coupling:
- `chat_message_received` - Chat integration
- `boss_spawned` - Boss events
- `evolution_completed` - Evolution system

### Command Pattern
Chat commands processed through CommandProcessor with standardized interface for entity actions.

---

## File Locations

### Core Systems
- `systems/core/` - Main game systems
- `systems/managers/` - Specialized managers
- `game_controller.gd` - Main orchestrator

### Specialized Systems
- `systems/ability_system/` - Ability framework
- `systems/evolution_system/` - Evolution mechanics
- `systems/twitch_system/` - Twitch integration
- `systems/ui_system/` - UI components

### Entity Scripts
- `entities/player/` - Player-related scripts
- `entities/enemies/bosses/` - Dedicated boss scripts
- `entities/enemies/regular/` - Minion enemy scripts