extends Node2D
class_name BossHealthBar

## Reusable boss health bar component
## Attach this to any boss to automatically display health bar and label

# Visual settings
@export var bar_color: Color = Color(1, 0.2, 0.2, 0.9)
@export var bar_size: Vector2 = Vector2(60, 6)
@export var bar_offset: Vector2 = Vector2(0, -70)  # How high above boss
@export var show_percentage: bool = false
@export var show_label: bool = true
@export var label_font_size: int = 10

# References
var health_bar: ProgressBar
var health_label: Label
var boss_entity: Node

func _ready():
	_create_health_ui()
	
	# Find parent boss entity
	boss_entity = get_parent()
	if boss_entity and boss_entity.has_signal("health_changed"):
		boss_entity.health_changed.connect(_on_boss_health_changed)
		_update_display(boss_entity.current_health, boss_entity.max_health)

func _create_health_ui():
	# Create container
	position = bar_offset
	
	# Create health bar
	health_bar = ProgressBar.new()
	health_bar.name = "HealthBar"
	health_bar.modulate = bar_color
	health_bar.position = Vector2(-bar_size.x / 2.0, 0)
	health_bar.size = bar_size
	health_bar.show_percentage = show_percentage
	health_bar.value = 100
	health_bar.max_value = 100
	
	# Style the health bar
	var style_bg = StyleBoxFlat.new()
	style_bg.bg_color = Color(0.2, 0.1, 0.1, 0.8)
	style_bg.border_color = Color(0.3, 0.1, 0.1)
	style_bg.set_border_width_all(1)
	health_bar.add_theme_stylebox_override("background", style_bg)
	
	var style_fill = StyleBoxFlat.new()
	style_fill.bg_color = Color(0.9, 0.1, 0.1)
	health_bar.add_theme_stylebox_override("fill", style_fill)
	
	add_child(health_bar)
	
	# Create health label if enabled
	if show_label:
		health_label = Label.new()
		health_label.name = "HealthLabel"
		health_label.text = "100/100"
		health_label.add_theme_font_size_override("font_size", label_font_size)
		health_label.position = Vector2(-15, bar_size.y + 2)
		health_label.add_theme_color_override("font_color", Color.WHITE)
		health_label.add_theme_color_override("font_shadow_color", Color.BLACK)
		health_label.add_theme_constant_override("shadow_offset_x", 1)
		health_label.add_theme_constant_override("shadow_offset_y", 1)
		add_child(health_label)

func _on_boss_health_changed(new_health: float, max_health_value: float):
	_update_display(new_health, max_health_value)

func _update_display(current: float, maximum: float):
	if not health_bar:
		return
		
	# Update bar
	health_bar.max_value = maximum
	health_bar.value = current
	
	# Update label
	if health_label:
		health_label.text = "%d/%d" % [int(current), int(maximum)]

func update_health(current: float, maximum: float):
	"""Manual update method for bosses that don't emit health_changed signal"""
	_update_display(current, maximum)

func set_bar_color(color: Color):
	if health_bar:
		health_bar.modulate = color

func set_visibility(should_be_visible: bool):
	self.visible = should_be_visible
