extends BaseBoon
class_name ArcExtensionBoon

## Extends the arc angle of sword weapons by degrees (additive scaling)

func _init():
	id = "arc_extension"
	display_name = "Sweeping Blade"
	base_type = "arc_angle"
	icon_color = Color(0.4, 0.7, 1.0)  # Light blue
	is_repeatable = true  # Can stack additively!

func get_formatted_description() -> String:
	var value = get_effective_power(25.0)  # +25 degrees base
	return "+%.0f° Arc Angle for Swords" % value

func _on_apply(entity: BaseEntity) -> void:
	if entity is Player:
		var player = entity as Player
		var weapon = player.get_primary_weapon()
		if weapon and weapon.has_method("get_weapon_tags"):
			var tags = weapon.get_weapon_tags()
			if "Sword" in tags and weapon.has_method("add_arc_degrees"):
				var degrees_to_add = get_effective_power(25.0)
				weapon.add_arc_degrees(degrees_to_add)
				print("🌀 %s gained +%.0f° Arc Angle!" % [player.name, degrees_to_add])
			else:
				push_warning("Arc Extension applied but weapon is not a sword")
		else:
			push_warning("Arc Extension boon applied but weapon doesn't support it")
