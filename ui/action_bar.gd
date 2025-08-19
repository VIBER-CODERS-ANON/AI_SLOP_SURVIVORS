extends HBoxContainer
class_name ActionBar

## Action bar UI that displays 8 ability slots at the bottom of the screen

signal slot_clicked(slot_index: int)

const SLOT_COUNT = 8
var slots: Array = []

func _ready():
	# Set up container properties
	add_theme_constant_override("separation", 8)
	custom_minimum_size = Vector2(SLOT_COUNT * 64 + (SLOT_COUNT - 1) * 8, 64)
	
	# Create 8 slots
	for i in range(SLOT_COUNT):
		var slot = _create_slot(i)
		slots.append(slot)
		add_child(slot)
	
	# Add sword icon to first slot
	var sword_icon = load("res://ui/icons/sword_icon.png")
	if sword_icon:
		_set_slot_icon(0, sword_icon)

func _create_slot(index: int) -> Panel:
	var slot = Panel.new()
	slot.custom_minimum_size = Vector2(64, 64)
	
	# Style the slot
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	style.border_color = Color(0.5, 0.5, 0.5, 1.0)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	slot.add_theme_stylebox_override("panel", style)
	
	# Add icon container
	var icon = TextureRect.new()
	icon.name = "Icon"
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot.add_child(icon)
	
	# Add slot number label
	var label = Label.new()
	label.name = "SlotNumber"
	label.text = str(index + 1)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.8))
	label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	label.position = Vector2(4, 2)
	slot.add_child(label)
	
	# Add cooldown overlay
	var cooldown = ColorRect.new()
	cooldown.name = "Cooldown"
	cooldown.color = Color(0, 0, 0, 0.7)
	cooldown.visible = false
	cooldown.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot.add_child(cooldown)
	
	# Make clickable
	slot.gui_input.connect(_on_slot_input.bind(index))
	
	return slot

func _on_slot_input(event: InputEvent, slot_index: int):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		slot_clicked.emit(slot_index)
		_highlight_slot(slot_index)

func _set_slot_icon(slot_index: int, texture: Texture2D):
	if slot_index >= 0 and slot_index < slots.size():
		var icon = slots[slot_index].get_node("Icon")
		icon.texture = texture

func _highlight_slot(slot_index: int):
	# Brief highlight effect
	if slot_index >= 0 and slot_index < slots.size():
		var slot = slots[slot_index]
		var original_modulate = slot.modulate
		slot.modulate = Color(1.5, 1.5, 1.5, 1.0)
		
		await get_tree().create_timer(0.1).timeout
		slot.modulate = original_modulate

func set_slot_cooldown(slot_index: int, duration: float):
	if slot_index >= 0 and slot_index < slots.size():
		var cooldown = slots[slot_index].get_node("Cooldown")
		cooldown.visible = true
		
		# Animate cooldown
		var tween = create_tween()
		
		# Kill tween when cooldown is freed
		cooldown.tree_exiting.connect(func(): 
			if tween and tween.is_valid():
				tween.kill()
		)
		
		tween.tween_property(cooldown, "modulate:a", 0.0, duration)
		tween.finished.connect(func(): cooldown.visible = false; cooldown.modulate.a = 0.7)


