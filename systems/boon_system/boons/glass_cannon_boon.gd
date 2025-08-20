extends BaseBoon
class_name GlassCannonBoon

## Unique Boon: Doubles damage but halves health

func _init():
	id = "glass_cannon"
	display_name = "Glass Cannon"
	base_type = "unique"
	icon_color = Color(1.0, 0.6, 0.2)  # Orange

func get_formatted_description() -> String:
	return "Double your damage, but halve your maximum health. High risk, high reward!"

func _on_apply(entity: BaseEntity) -> void:
	if entity is Player:
		var player = entity as Player
		
		# Double damage multiplier
		player.bonus_damage_multiplier *= 2.0
		
		# Halve health (negative bonus)
		var health_reduction = player.base_health * 0.5
		player.bonus_health -= health_reduction
		player._update_derived_stats()
		
		print("💣 %s became a Glass Cannon! Double damage, half health!" % player.name)
