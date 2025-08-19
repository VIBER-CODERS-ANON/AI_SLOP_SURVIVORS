extends Control
class_name BossBuffDisplay

var buff_label: Label

func _ready():
	# Create UI structure
	custom_minimum_size = Vector2(300, 40)
	
	# Create background panel
	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	
	# Style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.2, 0.7)
	style.border_color = Color(0.3, 0.3, 0.5)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	panel.add_theme_stylebox_override("panel", style)
	
	# Create label
	buff_label = Label.new()
	buff_label.text = "Boss Buffs: None"
	buff_label.add_theme_font_size_override("font_size", 14)
	buff_label.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	buff_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.add_child(buff_label)
	
	# Connect to boss buff manager
	_connect_buff_manager()
	
	# Update initial display
	_update_display()

func _connect_buff_manager():
	if BossBuffManager.instance:
		BossBuffManager.instance.buff_applied.connect(_on_buff_applied)

func _on_buff_applied(_boss_name: String, _buff_description: String):
	_update_display()

func _update_display():
	if not BossBuffManager.instance:
		return
	
	var summary = BossBuffManager.instance.get_active_buff_summary()
	buff_label.text = summary
	
	# Hide if no buffs
	visible = summary != "No active boss buffs"
	
	# Add glow effect if buffs are active
	if visible:
		modulate = Color(1.1, 1.1, 1.1)
