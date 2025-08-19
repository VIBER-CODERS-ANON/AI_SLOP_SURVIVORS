extends BaseBoon
class_name UniqueBoonTemplate

## Template for unique boons with special mechanics
## These boons often have custom effects that don't follow standard scaling
## They may have drawbacks, special conditions, or game-changing mechanics
## Copy this file and rename for your specific unique boon

func _init():
    # TODO: Set unique boon ID
    id = "unique_template"
    
    # TODO: Set display name (make it memorable!)
    display_name = "Unique Mechanic"
    
    # Always set base_type to "unique" for special boons
    base_type = "unique"
    
    # Unique boons use orange color by convention
    icon_color = Color(1.0, 0.6, 0.2)  # Orange
    
    # TODO: Decide if this can be selected multiple times
    is_repeatable = false  # Most unique boons are one-time only

func get_formatted_description() -> String:
    # Unique boons often have custom descriptions that don't scale
    # Be very clear about both benefits AND drawbacks
    
    # TODO: Write a compelling description
    # Examples:
    # return "Double your damage, but halve your maximum health. High risk, high reward!"
    # return "Heal 10% max HP on kill, but lose 1 HP per second. Feed or perish!"
    # return "Gain 50% attack speed when below 30% health. Desperation fuels fury!"
    # return "Your attacks chain to 3 nearby enemies, but you take 20% more damage"
    # return "Become immune to slows, but movement never stops. Eternal momentum!"
    
    return "Gain a powerful effect with an interesting drawback"

func _on_apply(entity: BaseEntity) -> void:
    # Ensure we're applying to a player
    if not entity is Player:
        push_warning("Unique boon applied to non-player entity")
        return
    
    var player = entity as Player
    
    # TODO: Implement the unique mechanic
    # Unique boons often:
    # 1. Modify multiple stats at once
    # 2. Add new mechanics via meta properties
    # 3. Have both positive and negative effects
    # 4. Change fundamental gameplay
    
    # Example implementations:
    
    # Glass Cannon (High damage, low health):
    # var weapon = player.get_primary_weapon()
    # if weapon:
    #     weapon.base_damage *= 2.0
    # player.max_health *= 0.5
    # if player.current_health > player.max_health:
    #     player.current_health = player.max_health
    
    # Vampiric (Heal on kill, health drain):
    # player.set_meta("is_vampiric", true)
    # player.set_meta("vampiric_heal_percent", 0.1)  # 10% max HP
    # player.set_meta("vampiric_drain_per_second", 1.0)
    # # The game's damage/health system checks these metas
    
    # Berserker (Attack speed at low health):
    # player.set_meta("has_berserker", true)
    # player.set_meta("berserker_threshold", 0.3)  # 30% HP
    # player.set_meta("berserker_attack_speed_bonus", 0.5)  # 50% faster
    
    # Chain Lightning (Attacks chain, increased damage taken):
    # var weapon = player.get_primary_weapon()
    # if weapon and weapon.has_method("enable_chaining"):
    #     weapon.enable_chaining(3)  # Chain to 3 enemies
    # player.damage_taken_multiplier *= 1.2  # 20% more damage taken
    
    # Unstoppable (Can't be slowed, can't stop moving):
    # player.set_meta("is_unstoppable", true)
    # player.immunity_tags.append("Slow")
    # player.immunity_tags.append("Root")
    # player.minimum_move_speed = 100.0  # Always moving
    
    # Phase Walker (Phase through enemies, take more magic damage):
    # player.set_meta("can_phase", true)
    # player.collision_mask &= ~2  # Remove enemy collision
    # player.magic_damage_multiplier = 1.5
    
    # Always print dramatic confirmation
    print("🌟 %s acquired %s! %s" % [
        player.name,
        display_name,
        _get_flavor_text()
    ])

# Helper method for flavor text
func _get_flavor_text() -> String:
    # TODO: Add dramatic flavor text for the printout
    # Examples:
    # return "Power at a terrible price!"
    # return "The hunt begins!"
    # return "Rage consumes all!"
    # return "Lightning courses through your veins!"
    # return "You cannot be stopped!"
    
    return "A choice has been made!"

# Some unique boons might be removable
func _on_remove(entity: BaseEntity) -> void:
    # TODO: Only implement if the boon can be removed
    # Remember to reverse ALL effects
    
    # Example removal:
    # if entity is Player:
    #     var player = entity as Player
    #     
    #     # Remove meta properties
    #     player.remove_meta("is_vampiric")
    #     player.remove_meta("vampiric_heal_percent")
    #     player.remove_meta("vampiric_drain_per_second")
    #     
    #     # Reverse stat changes (if tracked)
    #     # This is why many unique boons are non-removable!
    
    pass

## Design Guidelines for Unique Boons:
##
## 1. Risk vs Reward
##    - Every powerful benefit should have a drawback
##    - Make players think before selecting
##
## 2. Game-Changing Mechanics
##    - Add new gameplay patterns
##    - Not just number increases
##
## 3. Clear Communication
##    - Players must understand the full effect
##    - No hidden surprises (unless that's the theme!)
##
## 4. Memorable Names
##    - "Glass Cannon" not "Damage Health Tradeoff"
##    - "Blood for Blood" not "Lifesteal With Drain"
##
## 5. Visual/Audio Feedback
##    - Unique boons should feel special
##    - Consider adding visual effects to the player
##
## 6. Balance Considerations
##    - Test with other boons for broken combos
##    - Some unique boons might exclude others
##
## Common Unique Boon Archetypes:
## - Glass Cannon (offense for defense)
## - Berserker (conditional power)
## - Vampiric (sustain with drain)
## - Gambler (RNG-based effects)
## - Martyr (power from taking damage)
## - Speedster (mobility focused)
## - Tank (defense focused with drawbacks)
