extends Control
class_name PlayerStatsDisplay

## Displays player health and mana bars with text indicators

@onready var health_bar: ProgressBar = $VBoxContainer/HealthContainer/HealthBar
@onready var health_label: Label = $VBoxContainer/HealthContainer/HealthLabel
@onready var mana_bar: ProgressBar = $VBoxContainer/ManaContainer/ManaBar
@onready var mana_label: Label = $VBoxContainer/ManaContainer/ManaLabel

func _ready():
	# Style the bars
	_style_health_bar()
	_style_mana_bar()

func _style_health_bar():
	# Create red style for health bar
	var style_fg = StyleBoxFlat.new()
	style_fg.bg_color = Color(0.8, 0.2, 0.2)
	style_fg.corner_radius_top_left = 2
	style_fg.corner_radius_top_right = 2
	style_fg.corner_radius_bottom_left = 2
	style_fg.corner_radius_bottom_right = 2
	
	var style_bg = StyleBoxFlat.new()
	style_bg.bg_color = Color(0.2, 0.2, 0.2)
	style_bg.border_color = Color(0.1, 0.1, 0.1)
	style_bg.border_width_left = 1
	style_bg.border_width_right = 1
	style_bg.border_width_top = 1
	style_bg.border_width_bottom = 1
	
	health_bar.add_theme_stylebox_override("fill", style_fg)
	health_bar.add_theme_stylebox_override("background", style_bg)

func _style_mana_bar():
	# Create blue style for mana bar
	var style_fg = StyleBoxFlat.new()
	style_fg.bg_color = Color(0.2, 0.4, 1.0)
	style_fg.corner_radius_top_left = 2
	style_fg.corner_radius_top_right = 2
	style_fg.corner_radius_bottom_left = 2
	style_fg.corner_radius_bottom_right = 2
	
	var style_bg = StyleBoxFlat.new()
	style_bg.bg_color = Color(0.2, 0.2, 0.2)
	style_bg.border_color = Color(0.1, 0.1, 0.1)
	style_bg.border_width_left = 1
	style_bg.border_width_right = 1
	style_bg.border_width_top = 1
	style_bg.border_width_bottom = 1
	
	mana_bar.add_theme_stylebox_override("fill", style_fg)
	mana_bar.add_theme_stylebox_override("background", style_bg)

func update_health(current: float, max_value: float):
	health_bar.max_value = max_value
	health_bar.value = current
	health_label.text = "%d/%d" % [int(current), int(max_value)]
	
	# Change label color based on health percentage
	var health_percent = current / max_value
	if health_percent > 0.6:
		health_label.modulate = Color.WHITE
	elif health_percent > 0.3:
		health_label.modulate = Color.YELLOW
	else:
		health_label.modulate = Color.RED

func update_mana(current: float, max_value: float):
	mana_bar.max_value = max_value
	mana_bar.value = current
	mana_label.text = "%d/%d" % [int(current), int(max_value)]

