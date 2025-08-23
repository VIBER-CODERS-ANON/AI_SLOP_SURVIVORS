extends BaseBoon
class_name StackableUniqueBoonTemplate

## Template for unique boons that can be selected multiple times
## These are special boons with unique mechanics that stack in interesting ways
## Examples: Twin Slash (multiple sword strikes), Echo Strike (repeated attacks)
## Copy this file and rename for your specific stackable unique boon

# Track how this boon stacks
var stack_count: int = 0

func _init():
    # TODO: Set unique boon ID
    id = "stackable_unique_template"
    
    # TODO: Set display name
    display_name = "Stackable Power"
    
    # Always "unique" type
    base_type = "unique"
    
    # Unique boons use orange, but stackable ones might use purple
    icon_color = Color(0.8, 0.2, 0.8)  # Purple for stackable uniques
    
    # IMPORTANT: Must be true for stackable unique boons
    is_repeatable = true

func get_formatted_description() -> String:
    # Description should make it clear this stacks
    # Optionally show current stack count
    
    var base_desc = ""
    
    # TODO: Write description that explains stacking
    # Examples:
    # base_desc = "All sword-tagged weapons swing an additional time"
    # base_desc = "Your attacks echo, dealing 50% damage after 0.5s"
    # base_desc = "Spawn an additional projectile that orbits you"
    # base_desc = "Gain an extra dash charge"
    # base_desc = "Critical strikes chain to 1 additional enemy"
    
    # Optional: Show stack information
    if current_stacks > 0:
        base_desc += " (Stack %d)" % (current_stacks + 1)
    
    return base_desc

func _on_apply(entity: BaseEntity) -> void:
    # Ensure we're applying to a player
    if not entity is Player:
        push_warning("Stackable unique boon applied to non-player entity")
        return
    
    var player = entity as Player
    
    # TODO: Implement the stackable effect
    # Each stack should add to the effect in an interesting way
    
    # Example implementations:
    
    # Twin Slash (Extra weapon strikes):
    # var weapon = player.get_primary_weapon()
    # if weapon and "Sword" in weapon.get_weapon_tags():
    #     if weapon.has_method("add_extra_strike"):
    #         weapon.add_extra_strike()
    #         # Visual offset for 3+ strikes
    #         if current_stacks >= 2:
    #             weapon.set_strike_offset_pattern(true)
    
    # Echo Strike (Repeated attacks):
    # if not player.has_meta("echo_strike_count"):
    #     player.set_meta("echo_strike_count", 0)
    # var echo_count = player.get_meta("echo_strike_count")
    # player.set_meta("echo_strike_count", echo_count + 1)
    # player.set_meta("echo_damage_percent", 0.5)  # 50% damage
    # player.set_meta("echo_delay", 0.5)  # 0.5s delay
    
    # Orbital Projectiles (Defensive projectiles):
    # var orbital_count = player.get_meta("orbital_count", 0)
    # orbital_count += 1
    # player.set_meta("orbital_count", orbital_count)
    # _spawn_orbital_projectile(player, orbital_count)
    
    # Extra Dash Charges:
    # var dash_ability = player.get_ability("dash")
    # if dash_ability and dash_ability.has_method("add_charge"):
    #     dash_ability.add_charge()
    # else:
    #     player.set_meta("bonus_dash_charges", 
    #         player.get_meta("bonus_dash_charges", 0) + 1)
    
    # Chain Critical (Crits chain to enemies):
    # var chain_count = player.get_meta("crit_chain_count", 0)
    # chain_count += 1
    # player.set_meta("crit_chain_count", chain_count)
    # player.set_meta("crit_chain_range", 200.0)
    # player.set_meta("crit_chain_damage_percent", 0.7)  # 70% damage
    
    # Print confirmation with stack count
    print("🔷 %s gained %s! (Stack %d)" % [
        player.name,
        display_name,
        current_stacks + 1
    ])

# Helper method for creating visual patterns
func _get_stack_pattern(stack_number: int) -> Dictionary:
    # TODO: Define visual patterns for different stack counts
    # Useful for abilities that need positioning
    
    return {
        "offset_angle": floor((stack_number - 1) / 2.0) * 20.0,
        "alternate_side": stack_number % 2 == 0,
        "radius_multiplier": 1.0 + (stack_number * 0.1),
        "delay_offset": stack_number * 0.1
    }

# Some stackable boons might have stack limits
func can_stack() -> bool:
    # TODO: Implement stack limit if needed
    # return current_stacks < 10  # Max 10 stacks
    return true  # Unlimited stacking

# Removal is complex for stackable boons
func _on_remove(entity: BaseEntity) -> void:
    # Usually not implemented for stackable boons
    # Would need to track individual stack effects
    pass

## Design Guidelines for Stackable Unique Boons:
##
## 1. Visual Progression
##    - Each stack should be visually distinct
##    - Create patterns (alternating, spreading, etc.)
##
## 2. Meaningful Stacking
##    - Each stack should feel impactful
##    - Not just +1 to a number
##
## 3. Performance Considerations
##    - Test with many stacks (10+)
##    - Implement stack limits if needed
##
## 4. Interesting Patterns
##    - Stacks 1-2: Basic effect
##    - Stacks 3-4: Visual changes
##    - Stacks 5+: Dramatic patterns
##
## 5. Balance Scaling
##    - Linear stacking is predictable
##    - Consider diminishing returns
##    - Or escalating costs
##
## Common Stackable Patterns:
##
## Alternating:
##   Stack 1: Left side
##   Stack 2: Right side
##   Stack 3: Left side (wider)
##   Stack 4: Right side (wider)
##
## Circular:
##   Stack 1: Front
##   Stack 2: Front + Back
##   Stack 3: Triangle formation
##   Stack 4: Square formation
##
## Cascading:
##   Stack 1: Instant
##   Stack 2: +0.1s delay
##   Stack 3: +0.2s delay
##   Creates wave effects
##
## Spreading:
##   Stack 1: 0° offset
##   Stack 2: ±15° offset
##   Stack 3: ±30° offset
##   Creates fan patterns
