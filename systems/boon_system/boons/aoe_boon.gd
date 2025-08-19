extends BaseBoon
class_name AoeBoon

## Multiplies area of effect size (MORE scaling - multiplicative)

func _init():
	id = "aoe_boost"
	display_name = "Devastation"
	base_type = "area_of_effect"
	icon_color = Color(0.8, 0.4, 1)

func get_formatted_description() -> String:
	var value = get_effective_power(5.0)  # 5% MORE
	return "%.0f%% MORE Area of Effect" % value

func _on_apply(entity: BaseEntity) -> void:
	if entity is Player:
		var player = entity as Player
		var aoe_percent = get_effective_power(5.0)  # 5% MORE
		player.area_of_effect *= (1.0 + aoe_percent / 100.0)
		print("💥 %s gained %.0f%% MORE Area of Effect! (%.2fx total)" % [player.name, aoe_percent, player.area_of_effect])
