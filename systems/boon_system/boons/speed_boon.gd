extends BaseBoon
class_name SpeedBoon

## Increases movement speed

func _init():
	id = "speed_boost"
	display_name = "Swiftness"
	base_type = "move_speed"
	icon_color = Color(0.2, 0.8, 1)

func get_formatted_description() -> String:
	var value = get_effective_power(2.0)
	return "+%.0f%% Movement Speed" % value

func _on_apply(entity: BaseEntity) -> void:
	if entity is Player:
		var player = entity as Player
		var speed_percent = get_effective_power(2.0)
		var speed_bonus = player.base_move_speed * (speed_percent / 100.0)
		player.bonus_move_speed += speed_bonus
		player._update_derived_stats()
		print("💨 %s gained +%.0f%% Move Speed!" % [player.name, speed_percent])
