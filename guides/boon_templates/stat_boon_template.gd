extends BaseBoon
class_name StatBoonTemplate

## Template for stat-based boons (Health, Damage, Speed, etc.)
## These boons provide simple numerical increases to player stats
## Copy this file and rename for your specific stat boon

# Configuration
const BASE_VALUE = 10.0  # Adjust this for balance

func _init():
    # TODO: Set unique boon ID
    id = "stat_template"
    
    # TODO: Set display name (shown in UI)
    display_name = "Stat Boost"
    
    # TODO: Set base type for categorization
    base_type = "stat_category"  # e.g., "health", "damage", "defense"
    
    # TODO: Set icon color (when no custom icon)
    icon_color = Color.WHITE  # Choose appropriate color
    
    # This is a common boon, always repeatable
    is_repeatable = true

func get_formatted_description() -> String:
    # Calculate the actual value based on rarity
    var value = get_effective_power(BASE_VALUE)
    
    # TODO: Return formatted description with the calculated value
    # Examples:
    # return "+%.0f Maximum Health" % value
    # return "+%.0f Base Damage" % value
    # return "+%.0f Movement Speed" % value
    # return "+%.1f HP Regeneration per Second" % value
    
    return "+%.0f to Something" % value

func _on_apply(entity: BaseEntity) -> void:
    # Ensure we're applying to a player
    if not entity is Player:
        push_warning("Stat boon applied to non-player entity")
        return
    
    var player = entity as Player
    var bonus_value = get_effective_power(BASE_VALUE)
    
    # TODO: Apply the stat bonus to the appropriate player stat
    # Examples:
    
    # For health:
    # player.max_health += bonus_value
    # player.current_health += bonus_value  # Also heal to maintain ratio
    
    # For damage (weapon-based):
    # var weapon = player.get_primary_weapon()
    # if weapon:
    #     weapon.base_damage += bonus_value
    
    # For movement speed:
    # player.move_speed += bonus_value
    
    # For regeneration:
    # player.health_regen_per_second += bonus_value
    
    # For defense:
    # player.defense += bonus_value
    
    # For critical chance (percentage):
    # player.crit_chance += bonus_value * 0.01  # Convert to 0-1 range
    
    # For pickup radius:
    # player.pickup_range += bonus_value
    
    # Always print confirmation
    print("📈 %s gained %s: +%.0f!" % [
        player.name,
        display_name,
        bonus_value
    ])

# Most stat boons don't need removal logic
func _on_remove(entity: BaseEntity) -> void:
    # Only implement if this boon can be removed
    # Most permanent stat increases don't need this
    pass

## Balance Guidelines for Stat Boons:
##
## Health: 5-20 base (affects survivability)
## Damage: 1-5 base (scales with attack speed)
## Speed: 5-20 base (affects dodging and map control)
## Defense: 1-5 base (percentage reduction or flat)
## Crit Chance: 2-5% base (caps at 100%)
## Regeneration: 0.5-2.0 base (HP per second)
##
## Remember: These values are for COMMON rarity
## Magic = 2x, Rare = 3x, Epic = 4x automatically
