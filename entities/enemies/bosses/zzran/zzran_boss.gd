extends BaseBoss
class_name ZZranBoss

## ZZran - The mysterious boss
## Currently just a base boss - waiting for oxygen thief aura implementation

# Sprite animation states
var current_sprite_state: String = "idle"
var attack_sprites: Array[Texture2D] = []

# Dialog system
var dialog_queue: Array = []
var spawn_dialog_played: bool = false

func _ready():
	print("🎭 ZZran boss _ready() called!")
	
	# Set ZZran specific properties
	boss_name = "ZZran"
	boss_title = "The Enigmatic"
	boss_health = 100.0
	boss_damage = 5.0
	boss_move_speed = 80.0
	boss_attack_range = 70.0
	boss_scale = 1.2
	custom_modulate = Color(0.9, 0.9, 1.0)  # Slightly blue tint
	
	# Load ZZran sprites (commented out - loaded in spawn function)
	# _load_zzran_sprites()
	
	# Call parent ready
	super._ready()
	
	# Set up ZZran specific features
	_setup_zzran_abilities()
	
	# Play spawn dialog after a short delay
	if not spawn_dialog_played:
		spawn_dialog_played = true
		print("🎭 Scheduling spawn dialog in 2.0 seconds...")
		# Increased delay to ensure spawn effect is playing
		var timer = get_tree().create_timer(2.0)
		timer.timeout.connect(_play_spawn_dialog)

func _load_zzran_sprites():
	# Load available Ziz sprites
	var idle_sprite = load("res://BespokeAssetSources/zizidle.png")
	if idle_sprite:
		sprite_texture = idle_sprite
	
	# Load attack sprites for future use
	var atk2 = load("res://BespokeAssetSources/zizatk2.png")
	var atk3 = load("res://BespokeAssetSources/zizatk3.png")
	if atk2:
		attack_sprites.append(atk2)
	if atk3:
		attack_sprites.append(atk3)

func _setup_zzran_abilities():
	# TODO: Implement oxygen thief aura here
	pass

func on_spawn_complete():
	print("🎭 ZZran spawn effect complete - showing fullscreen attack!")
	_show_fullscreen_attack()
	await get_tree().create_timer(0.3).timeout

func _show_fullscreen_attack():
	var game_scene = get_tree().current_scene
	if not game_scene:
		return
	
	# Create fullscreen container
	var fullscreen = Control.new()
	fullscreen.set_anchors_preset(Control.PRESET_FULL_RECT)
	fullscreen.z_index = 200  # Above everything
	fullscreen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fullscreen.process_mode = Node.PROCESS_MODE_ALWAYS  # Show even during pause
	
	# Add the epic Ziz attack image
	var attack_image = TextureRect.new()
	var texture_path = "res://BespokeAssetSources/ZizFullscreenAttack.jpg"
	if not ResourceLoader.exists(texture_path):
		push_error("ZizFullscreenAttack.jpg not found at: " + texture_path)
		return
	attack_image.texture = load(texture_path)
	attack_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	attack_image.set_anchors_preset(Control.PRESET_FULL_RECT)
	fullscreen.add_child(attack_image)
	
	# Add flash overlay for extra impact
	var flash = ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	fullscreen.add_child(flash)
	
	# Add to UI layer
	var ui_layer = game_scene.get_node_or_null("UILayer")
	if ui_layer:
		ui_layer.add_child(fullscreen)
	else:
		push_warning("UILayer not found, adding fullscreen effect to viewport")
		var viewport = game_scene.get_viewport()
		if viewport:
			viewport.add_child(fullscreen)
		else:
			push_error("Cannot add fullscreen effect - no viewport found!")
			fullscreen.queue_free()
			return
	
	# Epic animation sequence (all happens in < 1 second)
	fullscreen.scale = Vector2(1.5, 1.5)
	fullscreen.pivot_offset = game_scene.get_viewport().size / 2.0
	fullscreen.modulate = Color(2, 2, 2, 0)  # Start bright and invisible
	
	var tween = fullscreen.create_tween()
	tween.set_parallel(true)
	
	# Zoom in + fade in (0.2s)
	tween.tween_property(fullscreen, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	tween.tween_property(fullscreen, "modulate:a", 1.0, 0.15)
	
	# Sequential effects
	tween.set_parallel(false)
	
	# White flash at peak (0.1s)
	tween.tween_property(flash, "color:a", 0.8, 0.05)
	tween.tween_property(flash, "color:a", 0.0, 0.05)
	
	# Hold for dramatic effect (0.3s)
	tween.tween_interval(0.3)
	
	# Zoom out + fade (0.2s)
	tween.set_parallel(true)
	tween.tween_property(fullscreen, "scale", Vector2(0.8, 0.8), 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_property(fullscreen, "modulate:a", 0.0, 0.2)
	
	# Cleanup
	tween.set_parallel(false)
	tween.tween_callback(fullscreen.queue_free)
	

func _entity_physics_process(delta: float):
	super._entity_physics_process(delta)
	
	# TODO: Implement oxygen thief aura logic here
	# Should periodically turn on an aura that deals 30% max HP as DoT per second

func _perform_attack():
	# Change sprite to attack animation
	if attack_sprites.size() > 0 and sprite:
		sprite.texture = attack_sprites[randi() % attack_sprites.size()]
		# Return to idle after attack
		get_tree().create_timer(0.5).timeout.connect(func(): 
			if sprite and sprite_texture:
				sprite.texture = sprite_texture
		)
	
	super._perform_attack()



func _on_phase_changed(phase: int):
	match phase:
		1:
			speak_dialogue("You're stronger than expected...")
			boss_move_speed *= 1.2
		2:
			speak_dialogue("Enough games!")
			boss_attack_cooldown *= 0.8
		3:
			speak_dialogue("YOU WILL FALL!")
			boss_damage *= 1.5
			# TODO: Enable oxygen thief aura here

func _on_boss_damaged(_amount: float, _source: Node):
	# Chance to counter-attack or react to damage
	if randf() < 0.2:  # 20% chance
		var damage_lines = [
			"Is that all?",
			"You'll pay for that!",
			"Meaningless!",
			"Hah!"
		]
		speak_dialogue(damage_lines[randi() % damage_lines.size()])

func _play_spawn_dialog():
	print("🎭 _play_spawn_dialog() called!")
	# Play ZZran spawn dialog - try .ogg for better compatibility
	var audio_path = "res://audio/voices/ziz_spawn_dialog.ogg"
	_play_voice_line(audio_path, "The void calls... and I answer!")
	
func _play_voice_line(audio_path: String, dialog_text: String):
	print("🎵 _play_voice_line called with: ", audio_path)
	
	# Check if audio file exists
	if not ResourceLoader.exists(audio_path):
		print("⚠️ ZZran spawn dialog not found at: ", audio_path)
		speak_dialogue(dialog_text)  # Fallback to text-only
		return
	
	print("🎵 Audio file exists!")
	
	# Queue the dialog if already speaking
	if is_speaking:
		dialog_queue.append({"path": audio_path, "text": dialog_text})
		return
		
	is_speaking = true
	
	# Load and play audio
	var audio_stream = load(audio_path)
	if not audio_stream:
		print("⚠️ Failed to load audio stream from: ", audio_path)
		speak_dialogue(dialog_text)
		return
	
	# Create a direct audio player for critical boss dialog
	# Using non-2D player for global audio that doesn't fade with distance
	var audio_player = AudioStreamPlayer.new()
	audio_player.stream = audio_stream
	audio_player.volume_db = 0.0  # Normal volume for boss dialog
	audio_player.pitch_scale = 1.0
	
	# Check if Dialog bus exists, otherwise use default
	var audio_server = AudioServer
	var has_dialog_bus = false
	for i in range(audio_server.bus_count):
		if audio_server.get_bus_name(i) == "Dialog":
			has_dialog_bus = true
			break
	
	if has_dialog_bus:
		audio_player.bus = "Dialog"
		print("🎵 Using Dialog bus")
	else:
		audio_player.bus = "Master"
		print("⚠️ Dialog bus not found, using Master bus")
	
	audio_player.process_mode = Node.PROCESS_MODE_ALWAYS  # Play even during pause
	add_child(audio_player)
	
	print("🎵 Playing Ziz spawn dialog directly!")
	print("   - Stream: ", audio_stream)
	print("   - Bus: ", audio_player.bus)
	print("   - Volume: ", audio_player.volume_db, "db")
	audio_player.play()
	
	# Clean up when finished
	audio_player.finished.connect(func():
		print("🎵 Ziz dialog finished playing")
		audio_player.queue_free()
		_on_dialog_finished()
	)
	
	# Also show the text
	speak_dialogue(dialog_text)

func _on_dialog_finished():
	is_speaking = false
	
	# Play next queued dialog if any
	if dialog_queue.size() > 0:
		var next_dialog = dialog_queue.pop_front()
		_play_voice_line(next_dialog.path, next_dialog.text)

# Override speak_dialogue to use our dialog system
func speak_dialogue(text: String):
	# Only queue text dialogs if we're already speaking
	if is_speaking:
		dialog_queue.append({"path": "", "text": text})
		return
	
	# Call parent implementation for text display
	super.speak_dialogue(text)
