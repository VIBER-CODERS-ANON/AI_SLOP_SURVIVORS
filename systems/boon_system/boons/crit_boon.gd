extends BaseBoon
class_name CritBoon

## Increases critical hit chance

func _init():
	id = "crit_boost"
	display_name = "Precision"
	base_type = "crit_chance"
	icon_color = Color(1, 1, 0.2)

func get_formatted_description() -> String:
	var value = get_effective_power(2.5)
	return "+%.1f%% Critical Hit Chance" % value

func _on_apply(entity: BaseEntity) -> void:
	if entity is Player:
		var player = entity as Player
		var crit_increase = get_effective_power(0.025)  # 2.5% as decimal
		
		# Apply to all player weapons
		var weapons = player.get_tree().get_nodes_in_group("player_weapons")
		for weapon in weapons:
			if weapon.has_method("add_crit_chance"):
				weapon.add_crit_chance(crit_increase)
		
		# Also keep on player for UI display if needed
		if player.has("crit_chance"):
			player.crit_chance += crit_increase
		
		print("✨ %s gained +%.1f%% Crit Chance on all weapons!" % [player.name, crit_increase * 100])
