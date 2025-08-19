extends BaseBoon
class_name PercentageBoonTemplate

## Template for percentage-based boons using MORE (multiplicative) scaling
## These boons provide percentage increases that compound when stacked
## Copy this file and rename for your specific percentage boon

# Configuration
const BASE_PERCENTAGE = 0.05  # 5% base (as decimal)

func _init():
    # TODO: Set unique boon ID
    id = "percentage_template"
    
    # TODO: Set display name (shown in UI)
    display_name = "Percentage Boost"
    
    # TODO: Set base type for categorization
    base_type = "percentage_modifier"  # e.g., "damage_mult", "speed_mult", "aoe"
    
    # TODO: Set icon color
    icon_color = Color.YELLOW  # Choose appropriate color
    
    # Percentage boons are usually repeatable for stacking
    is_repeatable = true

func get_formatted_description() -> String:
    # Calculate the actual percentage based on rarity
    var percentage = get_effective_power(BASE_PERCENTAGE)
    
    # TODO: Choose between MORE and Increased wording
    # MORE = multiplicative (compounds)
    # Increased = additive (doesn't compound)
    
    # For MORE scaling:
    return "%.0f%% MORE [Something]" % (percentage * 100)
    
    # For Increased scaling:
    # return "+%.0f%% Increased [Something]" % (percentage * 100)

func _on_apply(entity: BaseEntity) -> void:
    # Ensure we're applying to a player
    if not entity is Player:
        push_warning("Percentage boon applied to non-player entity")
        return
    
    var player = entity as Player
    var multiplier = get_effective_power(BASE_PERCENTAGE)
    
    # TODO: Apply the percentage modifier
    # Choose between MORE (multiplicative) and Increased (additive)
    
    # MORE SCALING (Multiplicative - Compounds with each stack):
    # player.some_stat *= (1.0 + multiplier)
    # Example: 100 * 1.05 * 1.05 * 1.05 = 115.76 (3 stacks of 5%)
    
    # INCREASED SCALING (Additive - Linear growth):
    # player.some_stat_bonus += multiplier
    # Then in getter: return base_stat * (1.0 + some_stat_bonus)
    # Example: 100 * (1.0 + 0.05 + 0.05 + 0.05) = 115 (3 stacks of 5%)
    
    # Common examples:
    
    # Attack Speed (MORE):
    # var weapon = player.get_primary_weapon()
    # if weapon:
    #     weapon.attack_speed_multiplier *= (1.0 + multiplier)
    
    # Area of Effect (MORE):
    # player.area_of_effect *= (1.0 + multiplier)
    
    # Damage Multiplier (MORE):
    # player.damage_multiplier *= (1.0 + multiplier)
    
    # Movement Speed (Increased):
    # player.movement_speed_bonus += multiplier
    
    # Critical Damage (MORE):
    # player.crit_damage *= (1.0 + multiplier)
    
    # Experience Gain (MORE):
    # player.experience_multiplier *= (1.0 + multiplier)
    
    # Always print confirmation with clear language
    var percentage_display = multiplier * 100
    print("📊 %s gained %s: %.0f%% MORE!" % [
        player.name,
        display_name,
        percentage_display
    ])

# Percentage boons rarely need removal
func _on_remove(entity: BaseEntity) -> void:
    # Only needed if the boon can be removed
    # Would need to track the multiplier somehow
    pass

## Balance Guidelines for Percentage Boons:
##
## MORE Scaling (Multiplicative):
## - Attack Speed: 10-20% base (can break animations if too high)
## - Area of Effect: 5-10% base (visual impact)
## - Damage: 5-15% base (primary scaling)
## - Critical Damage: 20-50% base (conditional)
##
## INCREASED Scaling (Additive):
## - Movement Speed: 5-10% base (map control)
## - Resistances: 10-20% base (damage reduction)
## - Resource Generation: 10-25% base (mana/stamina)
##
## MORE scaling becomes VERY powerful when stacked!
## Example: 10% MORE with 5 stacks = 1.1^5 = 1.61 (61% total increase)
##
## Remember: These percentages are for COMMON rarity
## Magic = 2x, Rare = 3x, Epic = 4x automatically
