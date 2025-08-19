extends BaseBoon
class_name BerserkerBoon

## Unique Boon: Attack speed increases as health decreases

func _init():
	id = "berserker"
	display_name = "Berserker's Fury"
	base_type = "unique"
	icon_color = Color(1.0, 0.6, 0.2)  # Orange

func get_formatted_description() -> String:
	return "Your attack speed increases as your health decreases. Up to +100% attack speed at 10% health!"

func _on_apply(entity: BaseEntity) -> void:
	if entity is Player:
		var player = entity as Player
		# Mark player as berserker
		player.set_meta("is_berserker", true)
		
		# Connect to health changes
		if not player.health_changed.is_connected(_on_player_health_changed):
			player.health_changed.connect(_on_player_health_changed.bind(player))
		
		print("⚔️🔥 %s became a Berserker! Lower health = faster attacks!" % player.name)

func _on_player_health_changed(new_health: float, max_health: float, player: Player):
	# Calculate health percentage
	var health_percent = new_health / max_health
	
	# Calculate attack speed bonus (inverse of health %)
	# At 100% health: 0% bonus
	# At 50% health: 50% bonus
	# At 10% health: 100% bonus
	var missing_health_percent = 1.0 - health_percent
	var attack_speed_bonus = missing_health_percent
	
	# Apply to sword if exists
	var weapon = player.get_primary_weapon()
	if weapon and weapon.has_method("set_attack_speed_multiplier"):
		weapon.set_attack_speed_multiplier(1.0 + attack_speed_bonus)
		
		# Visual feedback - redder as health decreases
		player.modulate = Color(1.0 + missing_health_percent * 0.5, 1.0 - missing_health_percent * 0.3, 1.0 - missing_health_percent * 0.3)
