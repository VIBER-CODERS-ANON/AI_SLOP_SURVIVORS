extends BaseBoon
class_name DamageBoon

## Increases base damage

func _init():
	id = "damage_boost"
	display_name = "Strength"
	base_type = "base_damage"
	icon_color = Color(1, 0.5, 0)

func get_formatted_description() -> String:
	var value = get_effective_power(1.0)
	return "+%.0f Base Damage" % value

func _on_apply(entity: BaseEntity) -> void:
	if entity is Player:
		var player = entity as Player
		var damage_increase = get_effective_power(1.0)
		player.bonus_damage += damage_increase
		print("⚔️ %s gained +%.0f Damage!" % [player.name, damage_increase])
