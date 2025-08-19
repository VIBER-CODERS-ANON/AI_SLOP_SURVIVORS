extends BaseBoon
class_name PickupBoon

## Increases pickup radius

func _init():
	id = "pickup_boost"
	display_name = "Magnetism"
	base_type = "pickup_radius"
	icon_color = Color(0.8, 0.2, 1)

func get_formatted_description() -> String:
	var value = get_effective_power(10.0)
	return "+%.0f%% Pickup Radius" % value

func _on_apply(entity: BaseEntity) -> void:
	if entity is Player:
		var player = entity as Player
		var radius_percent = get_effective_power(10.0)
		var radius_bonus = player.base_pickup_range * (radius_percent / 100.0)
		player.bonus_pickup_range += radius_bonus
		player._update_derived_stats()
		print("🧲 %s gained +%.0f%% Pickup Radius!" % [player.name, radius_percent])
