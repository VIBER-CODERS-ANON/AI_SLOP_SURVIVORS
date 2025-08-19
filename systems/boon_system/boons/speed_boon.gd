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
		player.move_speed *= (1.0 + speed_percent / 100.0)
		print("💨 %s gained +%.0f%% Move Speed!" % [player.name, speed_percent])
