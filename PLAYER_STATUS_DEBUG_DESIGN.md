# Player Status Debug System Design

## Overview

This document outlines the design for a comprehensive player status display system that integrates with the main debug system. The goal is to provide complete visibility into player stats, active boons, modifiers, and real-time calculations during debug mode.

## Current State Analysis

### What Exists Now

- **PlayerStatsDisplay**: Basic health/mana bars only
- **XP Bar**: Experience progression display
- **MXP Display**: Monster XP currency from Twitch
- **BoonSelection**: Level-up boon choice UI (temporary)
- **Player class**: Tracks all bonus stats but doesn't display them

### What's Missing

- **Active boons display** with effects and durations
- **Stat breakdown** showing base vs modified values
- **Real-time stat calculations** and tooltips
- **Boon stack visualization** (if applicable)
- **Debug stat manipulation** controls

## Proposed Player Status Debug Panel

### Panel Location

The player status panel will be integrated into the main debug UI as a collapsible section:

```
┌─────────────────────────────────────────────┐
│ Debug Mode (F12)                            │
├─────────────────────────────────────────────┤
│ [Enemy Spawner] [Enemy Inspector]           │
│ ... (existing enemy debug UI) ...          │
├─────────────────────────────────────────────┤
│ ▼ Player Status                             │
│ ┌─────────────────────────────────────────┐ │
│ │ [Core Stats] [Active Boons] [Modifiers] │ │
│ └─────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

### Core Stats Tab

```
┌─────────────────────────────────────────────┐
│ Core Stats                                  │
├─────────────────────────────────────────────┤
│ Health: 45/65 (20 + 45 bonus)             │
│ [Set: ___] [Damage: 10] [Heal Full]        │
│                                             │
│ Move Speed: 310 (210 + 100 bonus)         │
│ [Set: ___] [Reset to Base]                 │
│                                             │
│ Pickup Range: 150 (100 + 50 bonus)        │
│ [Set: ___] [Reset to Base]                 │
│                                             │
│ Level: 12 | XP: 85/120                    │
│ [Set Level: ___] [Grant XP: ___]           │
│                                             │
│ Combat Stats:                              │
│ • Crit Chance: 25% (0% + 25% bonus)       │
│ • Crit Multiplier: 2.5x (base + 0.5 bonus)│ │
│ • Damage Bonus: +15 flat                  │
│ • Damage Multiplier: 1.3x                 │
│ • AoE Multiplier: 1.8x                    │
│ • Attack Speed: 1.2x                      │
└─────────────────────────────────────────────┘
```

### Active Boons Tab

```
┌─────────────────────────────────────────────┐
│ Active Boons (5/∞)                         │
├─────────────────────────────────────────────┤
│ 🔥 [RARE] Berserker                        │
│    +20% damage, +10% crit, -5% move speed  │
│    Stacks: 2 | Duration: Permanent         │
│    [Remove] [Add Stack]                    │
│                                             │
│ ⚡ [MAGIC] Lightning Affinity              │
│    +15% AoE, weapons deal lightning damage │
│    Duration: Permanent                      │
│    [Remove]                                │
│                                             │
│ 💚 [COMMON] Health Boost                   │
│    +25 max health                          │
│    Duration: Permanent                      │
│    [Remove]                                │
│                                             │
│ [Add Boon ▼]                               │
│ ├─ Common Boons                            │
│ ├─ Magic Boons                             │
│ ├─ Rare Boons                              │
│ └─ Unique Boons                            │
└─────────────────────────────────────────────┘
```

### Modifiers Tab

```
┌─────────────────────────────────────────────┐
│ Stat Modifiers Breakdown                    │
├─────────────────────────────────────────────┤
│ Move Speed (310 total):                    │
│ • Base: 210                                │
│ • Boon bonuses: +85                       │
│ • Equipment: +15                           │
│ • Temporary effects: +0                    │
│                                             │
│ Damage Calculation:                         │
│ • Base weapon: 25                          │
│ • Flat bonuses: +15                        │
│ • Multipliers: 1.3x                       │
│ • Final: (25 + 15) × 1.3 = 52 damage     │
│                                             │
│ Critical Hits:                             │
│ • Chance: 25% (0% base + 25% boons)       │
│ • Multiplier: 2.5x (2.0x base + 0.5x boons)│
│ • Expected DPS: 62 (52 × 1.25 crit bonus) │
│                                             │
│ Area of Effect:                            │
│ • Base: 1.0x (100%)                       │
│ • Boon multipliers: 1.8x (180%)          │
│ • Equipment: 1.0x                         │
│ • Final: 1.8x area                        │
└─────────────────────────────────────────────┘
```

## Technical Implementation

### PlayerStatusDebugPanel Class

```gdscript
extends Control
class_name PlayerStatusDebugPanel

# References
var player_ref: Player
var boon_manager: BoonManager

# UI Tabs
var core_stats_tab: Control
var active_boons_tab: Control
var modifiers_tab: Control

# Core Stats Controls
var health_input: LineEdit
var speed_input: LineEdit
var level_input: LineEdit
var xp_input: LineEdit

# Boon Management
var active_boons_list: VBoxContainer
var add_boon_dropdown: OptionButton

func _ready():
    _setup_tabs()
    _connect_to_player()
    _populate_boon_dropdown()

func _setup_tabs():
    # Create tabbed interface
    var tab_container = TabContainer.new()
    add_child(tab_container)

    # Core Stats tab
    core_stats_tab = _create_core_stats_tab()
    tab_container.add_child(core_stats_tab)
    core_stats_tab.name = "Core Stats"

    # Active Boons tab
    active_boons_tab = _create_active_boons_tab()
    tab_container.add_child(active_boons_tab)
    active_boons_tab.name = "Active Boons"

    # Modifiers tab
    modifiers_tab = _create_modifiers_tab()
    tab_container.add_child(modifiers_tab)
    modifiers_tab.name = "Modifiers"

func _connect_to_player():
    player_ref = get_tree().get_first_node_in_group("player") as Player
    if player_ref:
        # Connect to player events for real-time updates
        player_ref.level_up.connect(_on_player_level_up)
        player_ref.experience_gained.connect(_on_player_xp_gained)

func update_display():
    if not player_ref:
        return

    _update_core_stats()
    _update_active_boons()
    _update_modifiers()
```

### Core Stats Tab Implementation

```gdscript
func _create_core_stats_tab() -> Control:
    var scroll = ScrollContainer.new()
    var container = VBoxContainer.new()
    scroll.add_child(container)

    # Health section
    var health_section = _create_stat_section(
        "Health",
        func(): return "%d/%d (%d + %d bonus)" % [
            player_ref.current_health,
            player_ref.max_health,
            player_ref.base_health,
            player_ref.bonus_health
        ]
    )
    container.add_child(health_section)

    # Add manipulation controls
    var health_controls = HBoxContainer.new()
    health_input = LineEdit.new()
    health_input.placeholder_text = "Set health..."
    var set_health_btn = Button.new()
    set_health_btn.text = "Set"
    set_health_btn.pressed.connect(_set_player_health)

    var damage_btn = Button.new()
    damage_btn.text = "Damage 10"
    damage_btn.pressed.connect(func(): player_ref.take_damage(10, "debug"))

    var heal_btn = Button.new()
    heal_btn.text = "Heal Full"
    heal_btn.pressed.connect(func(): player_ref.current_health = player_ref.max_health)

    health_controls.add_child(health_input)
    health_controls.add_child(set_health_btn)
    health_controls.add_child(damage_btn)
    health_controls.add_child(heal_btn)
    container.add_child(health_controls)

    # Similar sections for other stats...

    return scroll

func _set_player_health():
    var value = health_input.text.to_float()
    if value > 0:
        player_ref.current_health = min(value, player_ref.max_health)
        health_input.clear()
```

### Active Boons Tab Implementation

```gdscript
func _create_active_boons_tab() -> Control:
    var scroll = ScrollContainer.new()
    active_boons_list = VBoxContainer.new()
    scroll.add_child(active_boons_list)

    # Add controls at bottom
    var controls = HBoxContainer.new()
    add_boon_dropdown = OptionButton.new()
    add_boon_dropdown.text = "Add Boon"

    var add_btn = Button.new()
    add_btn.text = "Add Selected"
    add_btn.pressed.connect(_add_selected_boon)

    controls.add_child(add_boon_dropdown)
    controls.add_child(add_btn)
    active_boons_list.add_child(controls)

    return scroll

func _update_active_boons():
    # Clear existing boon displays
    for child in active_boons_list.get_children():
        if child.has_meta("is_boon_display"):
            child.queue_free()

    # Get player's active boons (this would require extending the Player class)
    var active_boons = player_ref.get_active_boons() # New method needed

    for boon_data in active_boons:
        var boon_display = _create_boon_display(boon_data)
        active_boons_list.add_child(boon_display)
        active_boons_list.move_child(boon_display, -2) # Before controls

func _create_boon_display(boon_data: Dictionary) -> Control:
    var container = PanelContainer.new()
    container.set_meta("is_boon_display", true)

    var content = VBoxContainer.new()
    container.add_child(content)

    # Boon name and rarity
    var header = HBoxContainer.new()
    var rarity_icon = Label.new()
    rarity_icon.text = _get_rarity_icon(boon_data.rarity)

    var name_label = Label.new()
    name_label.text = "[%s] %s" % [boon_data.rarity, boon_data.boon.display_name]
    name_label.modulate = _get_rarity_color(boon_data.rarity)

    header.add_child(rarity_icon)
    header.add_child(name_label)
    content.add_child(header)

    # Effect description
    var desc_label = Label.new()
    desc_label.text = boon_data.boon.get_debug_description()
    desc_label.add_theme_font_size_override("font_size", 14)
    content.add_child(desc_label)

    # Controls
    var controls = HBoxContainer.new()
    var remove_btn = Button.new()
    remove_btn.text = "Remove"
    remove_btn.pressed.connect(_remove_boon.bind(boon_data.boon.id))
    controls.add_child(remove_btn)

    if boon_data.boon.can_stack:
        var add_stack_btn = Button.new()
        add_stack_btn.text = "Add Stack"
        add_stack_btn.pressed.connect(_add_boon_stack.bind(boon_data.boon.id))
        controls.add_child(add_stack_btn)

    content.add_child(controls)
    return container
```

### Modifiers Tab Implementation

```gdscript
func _create_modifiers_tab() -> Control:
    var scroll = ScrollContainer.new()
    var container = VBoxContainer.new()
    scroll.add_child(container)

    # Real-time calculation displays
    var calculations_label = RichTextLabel.new()
    calculations_label.custom_minimum_size.y = 400
    calculations_label.fit_content = true
    container.add_child(calculations_label)

    # Store reference for updates
    set_meta("calculations_display", calculations_label)

    return scroll

func _update_modifiers():
    var display = get_meta("calculations_display") as RichTextLabel
    if not display or not player_ref:
        return

    var text = ""

    # Move Speed breakdown
    text += "[b]Move Speed (%d total):[/b]\n" % _get_total_move_speed()
    text += "• Base: %d\n" % player_ref.base_move_speed
    text += "• Boon bonuses: +%d\n" % player_ref.bonus_move_speed
    text += "• Equipment: +0\n"
    text += "• Temporary effects: +0\n\n"

    # Damage calculation
    var base_weapon_damage = _get_base_weapon_damage()
    var total_flat_bonus = player_ref.bonus_damage
    var total_multiplier = player_ref.bonus_damage_multiplier
    var final_damage = (base_weapon_damage + total_flat_bonus) * total_multiplier

    text += "[b]Damage Calculation:[/b]\n"
    text += "• Base weapon: %d\n" % base_weapon_damage
    text += "• Flat bonuses: +%d\n" % total_flat_bonus
    text += "• Multipliers: %.1fx\n" % total_multiplier
    text += "• Final: (%d + %d) × %.1f = %d damage\n\n" % [
        base_weapon_damage, total_flat_bonus, total_multiplier, final_damage
    ]

    # Critical hit calculations
    var crit_chance = player_ref.bonus_crit_chance
    var crit_multiplier = 2.0 + player_ref.bonus_crit_multiplier
    var expected_dps = final_damage * (1.0 + (crit_chance / 100.0) * (crit_multiplier - 1.0))

    text += "[b]Critical Hits:[/b]\n"
    text += "• Chance: %.1f%% (0%% base + %.1f%% boons)\n" % [crit_chance, crit_chance]
    text += "• Multiplier: %.1fx (2.0x base + %.1fx boons)\n" % [crit_multiplier, player_ref.bonus_crit_multiplier]
    text += "• Expected DPS: %.1f\n\n" % expected_dps

    # AoE calculations
    text += "[b]Area of Effect:[/b]\n"
    text += "• Base: 1.0x (100%%)\n"
    text += "• Boon multipliers: %.1fx (%.0f%%)\n" % [player_ref.area_of_effect, player_ref.area_of_effect * 100]
    text += "• Equipment: 1.0x\n"
    text += "• Final: %.1fx area\n" % player_ref.area_of_effect

    display.text = text
```

## Integration with Main Debug System

### DebugManager Integration

```gdscript
# Add to DebugManager class
var player_status_panel: PlayerStatusDebugPanel

func _create_debug_ui():
    # ... existing debug UI creation ...

    # Add player status section
    var player_section = _create_collapsible_section("Player Status")
    player_status_panel = PlayerStatusDebugPanel.new()
    player_section.add_child(player_status_panel)
    debug_ui.add_child(player_section)

func _update_debug_display():
    # ... existing updates ...

    # Update player status
    if player_status_panel:
        player_status_panel.update_display()
```

### Player Class Extensions Needed

```gdscript
# Add to Player class
var active_boons: Array[Dictionary] = []

func get_active_boons() -> Array[Dictionary]:
    return active_boons

func add_debug_boon(boon: BaseBoon, rarity: BoonRarity):
    # Add boon without going through normal level-up flow
    var boon_data = {
        "boon": boon,
        "rarity": rarity,
        "stacks": 1,
        "applied_time": Time.get_ticks_msec()
    }
    active_boons.append(boon_data)
    boon.apply_to_entity(self)

func remove_debug_boon(boon_id: String):
    for i in range(active_boons.size() - 1, -1, -1):
        if active_boons[i].boon.id == boon_id:
            active_boons[i].boon.remove_from_entity(self)
            active_boons.remove_at(i)
            break

func get_debug_stat_breakdown() -> Dictionary:
    return {
        "total_move_speed": base_move_speed + bonus_move_speed,
        "total_health": base_health + bonus_health,
        "total_pickup_range": base_pickup_range + bonus_pickup_range,
        # ... more stats
    }
```

## Benefits of This System

### For Development

- **Complete stat visibility** during testing
- **Real-time boon experimentation** without save/load
- **Stat calculation validation** to ensure formulas work correctly
- **Player progression testing** at any level/configuration

### For Debugging

- **Boon interaction testing** - see exactly how effects stack
- **Balance validation** - check if stat values are reasonable
- **Edge case identification** - test extreme stat combinations
- **Performance impact** - monitor complex calculations

### For Game Design

- **Boon effectiveness analysis** - see actual impact of each boon
- **Progression curve validation** - test player power at different levels
- **Build experimentation** - quickly test different character builds
- **Feedback loop optimization** - understand player power spikes

## Implementation Timeline

### Foundation

- Create `PlayerStatusDebugPanel` class
- Implement Core Stats tab
- Basic stat display and manipulation

### Boon System

- Implement Active Boons tab
- Add boon addition/removal functionality
- Integrate with existing boon system

### Calculations

- Implement Modifiers tab
- Add real-time calculation displays
- Optimize update performance

### Integration & Polish

- Integrate with main debug system
- Add keyboard shortcuts
- Performance optimization and testing

## Future Enhancements

- **Stat History Graphs** - Track stat changes over time
- **Build Presets** - Save/load specific boon/stat combinations
- **Comparison Tool** - Compare different build configurations
- **Export Functionality** - Export stat data for external analysis
- **Automated Testing** - Use debug system for automated balance testing

## Conclusion

This player status debug system provides comprehensive visibility into all player stats, boons, and calculations. It complements the enemy debug system perfectly, giving developers complete control over both sides of the game's core mechanics. The modular design allows for easy extension and integration with existing systems while maintaining performance during development and testing.
