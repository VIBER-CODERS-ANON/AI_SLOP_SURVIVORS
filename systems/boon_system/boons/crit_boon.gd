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
		player.crit_chance += crit_increase
		print("✨ %s gained +%.1f%% Crit Chance!" % [player.name, crit_increase * 100])
