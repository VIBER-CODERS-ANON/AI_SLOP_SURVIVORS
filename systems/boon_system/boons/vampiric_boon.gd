extends BaseBoon
class_name VampiricBoon

## Unique Boon: Heal on kill but take damage over time

func _init():
	id = "vampiric"
	display_name = "Vampiric Curse"
	base_type = "unique"
	icon_color = Color(1.0, 0.6, 0.2)  # Orange

func get_formatted_description() -> String:
	return "Heal 10% max HP on kill, but lose 1 HP per second. Feed or perish!"

func _on_apply(entity: BaseEntity) -> void:
	if entity is Player:
		var player = entity as Player
		# This will need to be implemented with a proper vampiric system
		# For now, just mark the player as vampiric
		player.set_meta("is_vampiric", true)
		print("🧛 %s became Vampiric! Kill to survive!" % player.name)
