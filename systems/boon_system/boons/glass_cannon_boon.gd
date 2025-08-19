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
		
		# Double damage
		var weapon = player.get_primary_weapon()
		if weapon:
			weapon.base_damage *= 2.0
		
		# Halve health
		player.max_health *= 0.5
		if player.current_health > player.max_health:
			player.current_health = player.max_health
		
		print("💣 %s became a Glass Cannon! Double damage, half health!" % player.name)
