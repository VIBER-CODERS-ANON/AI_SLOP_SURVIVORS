extends BaseBoon
class_name HealthBoon

## Increases maximum health

func _init():
	id = "health_boost"
	display_name = "Vitality"
	base_type = "max_health"
	icon_color = Color(1, 0.2, 0.2)

func get_formatted_description() -> String:
	var value = get_effective_power(10.0)
	return "+%.0f Maximum Health" % value

func _on_apply(entity: BaseEntity) -> void:
	if entity is Player:
		var player = entity as Player
		var health_increase = get_effective_power(10.0)
		player.bonus_health += health_increase
		player._update_derived_stats()  # This handles healing the difference
		print("🛡️ %s gained +%.0f Max HP!" % [player.name, health_increase])
