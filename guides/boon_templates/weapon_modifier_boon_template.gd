extends BaseBoon
class_name WeaponModifierBoonTemplate

## Template for boons that modify weapon behavior
## These boons check for weapon tags and apply specific modifications
## Copy this file and rename for your specific weapon modifier boon

# Configuration
const BASE_VALUE = 25.0  # Base modification value
const REQUIRED_WEAPON_TAG = "Sword"  # Which weapons this affects

func _init():
    # TODO: Set unique boon ID
    id = "weapon_modifier_template"
    
    # TODO: Set display name
    display_name = "Weapon Enhancement"
    
    # TODO: Set base type
    base_type = "weapon_modifier"
    
    # TODO: Set icon color (weapon-themed colors work well)
    icon_color = Color(0.7, 0.7, 1.0)  # Light blue for weapon mods
    
    # Weapon modifiers are usually repeatable
    is_repeatable = true

func get_formatted_description() -> String:
    var value = get_effective_power(BASE_VALUE)
    
    # TODO: Customize description based on what the boon does
    # Be specific about which weapons are affected
    
    # Examples:
    # return "+%.0f° Arc Angle for Sword Weapons" % value
    # return "Projectiles from Bow Weapons pierce %.0f additional enemies" % value
    # return "Staff Weapons cast %.0f additional projectiles" % value
    # return "Hammer Weapons deal %.0f%% area damage on hit" % value
    
    return "+%.0f to %s Weapons" % [value, REQUIRED_WEAPON_TAG]

func _on_apply(entity: BaseEntity) -> void:
    # Ensure we're applying to a player
    if not entity is Player:
        push_warning("Weapon modifier boon applied to non-player entity")
        return
    
    var player = entity as Player
    
    # Get the player's primary weapon
    var weapon = player.get_primary_weapon()
    if not weapon:
        push_warning("No primary weapon found for " + display_name)
        return
    
    # Check if weapon has the required tag
    if not weapon.has_method("get_weapon_tags"):
        push_warning("Weapon doesn't support tags")
        return
    
    var weapon_tags = weapon.get_weapon_tags()
    if not REQUIRED_WEAPON_TAG in weapon_tags:
        # Weapon doesn't match - this is normal, not an error
        print("⚠️ %s has no effect - weapon is not tagged as %s" % [
            display_name,
            REQUIRED_WEAPON_TAG
        ])
        return
    
    # Apply the modification
    var modification_value = get_effective_power(BASE_VALUE)
    
    # TODO: Apply the specific weapon modification
    # Examples:
    
    # For arc angle (Sword):
    # if weapon.has_method("add_arc_degrees"):
    #     weapon.add_arc_degrees(modification_value)
    
    # For extra strikes (Sword):
    # if weapon.has_method("add_extra_strike"):
    #     weapon.add_extra_strike()
    
    # For projectile count (Staff/Wand):
    # if weapon.has_method("add_projectile_count"):
    #     weapon.add_projectile_count(int(modification_value))
    
    # For pierce count (Bow/Projectile):
    # if weapon.has_method("add_pierce"):
    #     weapon.add_pierce(int(modification_value))
    
    # For chain bounces (Lightning/Magic):
    # if weapon.has_method("add_chain_count"):
    #     weapon.add_chain_count(int(modification_value))
    
    # For damage zones (Hammer/Mace):
    # if weapon.has_method("enable_impact_zone"):
    #     weapon.enable_impact_zone(modification_value)
    
    # Always print confirmation
    print("🗡️ %s enhanced %s weapon: +%.0f!" % [
        player.name,
        REQUIRED_WEAPON_TAG,
        modification_value
    ])

# Optional: Also check secondary weapons
func _check_secondary_weapons(player: Player) -> void:
    # Some games might have multiple weapon slots
    if player.has_method("get_secondary_weapons"):
        var secondary_weapons = player.get_secondary_weapons()
        for weapon in secondary_weapons:
            if REQUIRED_WEAPON_TAG in weapon.get_weapon_tags():
                # Apply modification to secondary weapons too
                pass

# Weapon modifiers don't typically need removal
func _on_remove(entity: BaseEntity) -> void:
    # Only implement if weapon mods can be removed
    pass

## Common Weapon Tags and Modifications:
##
## Sword:
## - Arc angle increases (+25° base)
## - Extra strikes (+1 base)
## - Spin attacks (special)
##
## Bow/Projectile:
## - Pierce count (+1 base)
## - Multishot (+1 projectile base)
## - Homing strength (0.1-0.3 base)
##
## Staff/Magic:
## - Cast count (+1 spell base)
## - Chain lightning (+1 bounce base)
## - Area explosions (radius increase)
##
## Hammer/Mace:
## - Impact radius (+50 units base)
## - Stun chance (+10% base)
## - Ground slam effects
##
## Remember to check if the weapon supports the modification!
