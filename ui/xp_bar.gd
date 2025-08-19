extends Control
class_name XPBar

## XP bar display for the player

@onready var progress_bar: ProgressBar = $XPProgressBar
@onready var level_label: Label = $LevelLabel
@onready var xp_label: Label = $XPLabel

func _ready():
	# Set up the XP bar appearance
	custom_minimum_size = Vector2(400, 30)
	
	# Set colors
	if progress_bar:
		progress_bar.modulate = Color(1, 0.8, 0)  # Gold color

func update_xp(current_xp: int, xp_to_next_level: int, level: int):
	if progress_bar:
		progress_bar.value = float(current_xp) / float(xp_to_next_level) * 100.0
		
	if level_label:
		level_label.text = "Level %d" % level
		
	if xp_label:
		xp_label.text = "%d / %d XP" % [current_xp, xp_to_next_level]

func on_level_up(new_level: int):
	# Visual feedback for level up
	if level_label:
		level_label.text = "Level %d" % new_level
		
		# Flash effect
		var tween = create_tween()
		tween.tween_property(self, "modulate", Color(2, 2, 2), 0.1)
		tween.tween_property(self, "modulate", Color.WHITE, 0.3)
