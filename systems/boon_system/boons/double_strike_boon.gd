extends BaseBoon
class_name DoubleStrikeBoon

## Makes sword weapons perform an additional attack per swing (stackable)

func _init():
	id = "double_strike"
	display_name = "Twin Slash"
	base_type = "unique"
	icon_color = Color(0.8, 0.2, 0.9)  # Purple for unique
	is_repeatable = true  # NOW STACKABLE!

func get_formatted_description() -> String:
	return "+1 Sword Strike (Swords swing an additional time)"

func _on_apply(entity: BaseEntity) -> void:
	if entity is Player:
		var player = entity as Player
		var weapon = player.get_primary_weapon()
		if weapon and weapon.has_method("get_weapon_tags"):
			var tags = weapon.get_weapon_tags()
			if "Sword" in tags and weapon.has_method("add_extra_strike"):
				weapon.add_extra_strike()
				var total_strikes = weapon.extra_strikes + 1
				print("⚔️⚔️ %s gained Twin Slash! Swords now attack %d times!" % [player.name, total_strikes])
			else:
				push_warning("Twin Slash applied but weapon is not a sword")
		else:
			push_warning("Twin Slash boon applied but weapon doesn't support it")
