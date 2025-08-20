extends Control
class_name BoonSelection

## UI for selecting boons on level up with rarity-based visual effects

signal boon_selected(boon: BaseBoon)

var boon_cards: Array[Control] = []
var selected_boons: Array[Dictionary] = []
var boon_manager: BoonManager

func _ready():
	# Set up fullscreen overlay
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Ensure proper rendering above nameplates
	top_level = true
	z_as_relative = false
	z_index = 900  # High but below pause menu
	
	# Make sure this UI can process during pause
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	# Get boon manager
	boon_manager = BoonManager.new()
	boon_manager.name = "BoonManager"
	add_child(boon_manager)
	boon_manager.add_to_group("boon_manager")
	
	# Create dark background
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.85)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# Create main container
	var main_container = VBoxContainer.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	main_container.position = Vector2(-500, -200)
	main_container.custom_minimum_size = Vector2(1000, 400)
	main_container.alignment = BoxContainer.ALIGNMENT_CENTER
	main_container.add_theme_constant_override("separation", 30)
	add_child(main_container)
	
	# Title
	var title = Label.new()
	title.text = "LEVEL UP! Choose Your Boon:"
	title.add_theme_font_size_override("font_size", 42)
	title.modulate = Color(1, 0.9, 0.2)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(title)
	
	# Add title glow effect
	var _title_glow = _create_glow_effect(title, Color(1, 0.9, 0.2, 0.3))
	
	# Boon selection container
	var boon_container = HBoxContainer.new()
	boon_container.alignment = BoxContainer.ALIGNMENT_CENTER
	boon_container.add_theme_constant_override("separation", 40)
	main_container.add_child(boon_container)
	
	# Create boon cards
	for i in range(3):
		var boon_card = _create_boon_card()
		boon_container.add_child(boon_card)
		boon_cards.append(boon_card)
	
	# Start hidden
	visible = false

func _create_boon_card() -> Control:
	var card_container = Control.new()
	card_container.custom_minimum_size = Vector2(280, 200)
	
	# Background panel
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(280, 200)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	card_container.add_child(panel)
	
	# Content container
	var content = VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)
	content.position.y += 10
	
	# Rarity label
	var rarity_label = Label.new()
	rarity_label.add_theme_font_size_override("font_size", 14)
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(rarity_label)
	
	# Name label
	var name_label = Label.new()
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(name_label)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	content.add_child(spacer)
	
	# Description label
	var desc_label = Label.new()
	desc_label.add_theme_font_size_override("font_size", 16)
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(desc_label)
	
	# Button (invisible, covers entire card)
	var button = Button.new()
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	card_container.add_child(button)
	
	# Store references
	card_container.set_meta("panel", panel)
	card_container.set_meta("rarity_label", rarity_label)
	card_container.set_meta("name_label", name_label)
	card_container.set_meta("desc_label", desc_label)
	card_container.set_meta("button", button)
	
	return card_container

func show_selection():
	# Get 3 random boons from manager
	selected_boons = boon_manager.get_random_boons(3)
	
	# Update cards
	for i in range(3):
		var boon_data = selected_boons[i]
		var card = boon_cards[i]
		_update_card(card, boon_data, i)
	
	# Show (pause is handled by game controller)
	visible = true
	# z_index = 4096 already ensures we're on top

func _update_card(card: Control, boon_data: Dictionary, index: int):
	var boon = boon_data["boon"] as BaseBoon
	var rarity = boon_data["rarity"] as BoonRarity
	
	var panel = card.get_meta("panel") as Panel
	var rarity_label = card.get_meta("rarity_label") as Label
	var name_label = card.get_meta("name_label") as Label
	var desc_label = card.get_meta("desc_label") as Label
	var button = card.get_meta("button") as Button
	
	# Set text
	rarity_label.text = "[" + rarity.display_name.to_upper() + "]"
	rarity_label.modulate = rarity.color
	name_label.text = boon.display_name
	name_label.modulate = rarity.color
	desc_label.text = boon.get_formatted_description()
	desc_label.modulate = Color(0.9, 0.9, 0.9)
	
	# Create style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.05, 0.95)
	style.border_width_left = rarity.border_width
	style.border_width_right = rarity.border_width
	style.border_width_top = rarity.border_width
	style.border_width_bottom = rarity.border_width
	style.border_color = rarity.color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	
	# Add glow for higher rarities
	if rarity.glow_intensity > 0:
		style.shadow_color = rarity.color
		style.shadow_color.a = rarity.glow_intensity
		style.shadow_size = 10
	
	panel.add_theme_stylebox_override("panel", style)
	
	# Add visual effects based on rarity
	_apply_rarity_effects(card, rarity)
	
	# Connect button
	if button.pressed.is_connected(_on_boon_selected):
		button.pressed.disconnect(_on_boon_selected)
	button.pressed.connect(_on_boon_selected.bind(index))
	
	# Add hover effects (check if already connected first)
	if not button.mouse_entered.is_connected(_on_card_hover):
		button.mouse_entered.connect(_on_card_hover.bind(card, rarity))
	if not button.mouse_exited.is_connected(_on_card_unhover):
		button.mouse_exited.connect(_on_card_unhover.bind(card, rarity))

func _apply_rarity_effects(card: Control, rarity: BoonRarity):
	# Remove old effects
	for child in card.get_children():
		if child.has_meta("is_effect"):
			child.queue_free()
	
	# Add shine effect for rare+
	if rarity.has_shine_effect:
		var shine = _create_shine_effect(card, rarity.color)
		card.add_child(shine)
	
	# Add particles for epic
	if rarity.has_particles:
		var particles = _create_particle_effect(card, rarity.color)
		card.add_child(particles)

func _create_shine_effect(parent: Control, color: Color) -> Control:
	var shine = ColorRect.new()
	shine.set_meta("is_effect", true)
	shine.color = Color(1, 1, 1, 0.0)
	shine.custom_minimum_size = Vector2(40, 200)
	shine.position = Vector2(-20, 0)
	shine.rotation = 0.3
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Gradient
	var gradient = GradientTexture2D.new()
	gradient.gradient = Gradient.new()
	gradient.gradient.add_point(0.0, Color(0, 0, 0, 0))
	gradient.gradient.add_point(0.5, color * 1.5)
	gradient.gradient.add_point(1.0, Color(0, 0, 0, 0))
	gradient.fill = GradientTexture2D.FILL_LINEAR
	gradient.fill_from = Vector2(0, 0)
	gradient.fill_to = Vector2(1, 0)
	
	# Animate shine
	var tween = parent.create_tween()
	tween.set_loops(-1)  # Infinite loops
	
	# Store tween reference for cleanup
	shine.set_meta("tween", tween)
	
	# Kill tween when shine is freed
	shine.tree_exiting.connect(func(): 
		if tween and tween.is_valid():
			tween.kill()
	)
	
	tween.tween_property(shine, "position:x", parent.size.x + 20, 3.0)
	tween.tween_property(shine, "position:x", -40, 0.0)
	tween.tween_interval(2.0)
	
	return shine

func _create_particle_effect(parent: Control, color: Color) -> CPUParticles2D:
	var particles = CPUParticles2D.new()
	particles.set_meta("is_effect", true)
	particles.position = parent.size / 2.0
	particles.amount = 20
	particles.lifetime = 2.0
	particles.preprocess = 2.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(parent.size.x / 2.0, parent.size.y / 2.0)
	particles.direction = Vector2(0, -1)
	particles.initial_velocity_min = 10.0
	particles.initial_velocity_max = 30.0
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.5
	particles.color = color
	
	# Sparkle effect
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(color.r, color.g, color.b, 0.0))
	gradient.add_point(0.2, Color(color.r, color.g, color.b, 1.0))
	gradient.add_point(0.8, Color(color.r, color.g, color.b, 1.0))
	gradient.add_point(1.0, Color(color.r, color.g, color.b, 0.0))
	particles.color_ramp = gradient
	
	return particles

func _create_glow_effect(node: Control, color: Color) -> Control:
	var glow = Control.new()
	glow.set_meta("is_effect", true)
	glow.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	glow.custom_minimum_size = node.size * 1.5
	glow.position = -glow.custom_minimum_size / 2.0
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Create radial gradient
	var rect = ColorRect.new()
	rect.custom_minimum_size = glow.custom_minimum_size
	rect.color = color
	rect.material = CanvasItemMaterial.new()
	rect.material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.add_child(rect)
	
	# Pulse animation
	var tween = create_tween()
	tween.set_loops(-1)  # Infinite loops
	
	# Store tween reference for cleanup
	rect.set_meta("tween", tween)
	
	# Kill tween when rect is freed
	rect.tree_exiting.connect(func(): 
		if tween and tween.is_valid():
			tween.kill()
	)
	
	tween.tween_property(rect, "modulate:a", 0.3, 1.0)
	tween.tween_property(rect, "modulate:a", 0.1, 1.0)
	
	node.add_child(glow)
	node.move_child(glow, 0)  # Behind text
	
	return glow

func _on_boon_selected(index: int):
	var selected_boon_data = selected_boons[index]
	var boon = selected_boon_data["boon"] as BaseBoon
	
	# Flash selection
	var card = boon_cards[index]
	var panel = card.get_meta("panel") as Panel
	var tween = create_tween()
	tween.tween_property(panel, "modulate", Color.WHITE, 0.1)
	tween.tween_property(panel, "modulate", Color(1, 1, 1, 1), 0.1)
	tween.tween_callback(_complete_selection.bind(boon))

func _complete_selection(boon: BaseBoon):
	# Emit signal
	boon_selected.emit(boon)
	
	# Hide (unpause is handled by game controller)
	visible = false
	
	# Disconnect all signals
	for card in boon_cards:
		var button = card.get_meta("button") as Button
		if button.pressed.is_connected(_on_boon_selected):
			button.pressed.disconnect(_on_boon_selected)
		if button.mouse_entered.is_connected(_on_card_hover):
			button.mouse_entered.disconnect(_on_card_hover)
		if button.mouse_exited.is_connected(_on_card_unhover):
			button.mouse_exited.disconnect(_on_card_unhover)

func _on_card_hover(card: Control, rarity: BoonRarity):
	var panel = card.get_meta("panel") as Panel
	var style = panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		style = style.duplicate()
		style.border_color = rarity.color * 1.5
		style.border_width_left = rarity.border_width + 2
		style.border_width_right = rarity.border_width + 2
		style.border_width_top = rarity.border_width + 2
		style.border_width_bottom = rarity.border_width + 2
		if rarity.glow_intensity > 0:
			style.shadow_size = 20
		panel.add_theme_stylebox_override("panel", style)
	
	# Scale up slightly
	var tween = create_tween()
	tween.tween_property(card, "scale", Vector2(1.05, 1.05), 0.1)

func _on_card_unhover(card: Control, rarity: BoonRarity):
	var panel = card.get_meta("panel") as Panel
	var style = panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		style = style.duplicate()
		style.border_color = rarity.color
		style.border_width_left = rarity.border_width
		style.border_width_right = rarity.border_width
		style.border_width_top = rarity.border_width
		style.border_width_bottom = rarity.border_width
		if rarity.glow_intensity > 0:
			style.shadow_size = 10
		panel.add_theme_stylebox_override("panel", style)
	
	# Scale back
	var tween = create_tween()
	tween.tween_property(card, "scale", Vector2(1.0, 1.0), 0.1)
