## Audio SFX Tester - Modular Dev Tool
## Attach this to any node to test multiple sound effects with F-key cycling
## Can be completely removed without breaking any code
extends Node

class_name AudioSFXTester

## Configuration for the tester
@export var enabled: bool = true
@export var test_key: Key = KEY_F12
@export var volume_db: float = -5.0
@export var pitch_variation: float = 0.05
@export var display_position: Vector2 = Vector2(-100, 100)
@export var display_font_size: int = 32

## Sound configuration
var sound_paths: Array[String] = []
var sound_descriptions: Array[String] = []
var current_sound_index: int = 0

## UI elements
var canvas_layer: CanvasLayer
var sound_label: Label
var desc_label: Label
var instructions_label: Label

## Optional callback when sound is played
var on_sound_played: Callable

func _ready():
	if not enabled:
		queue_free()
		return
	
	set_process_unhandled_input(true)
	_setup_ui()

func setup_sounds(paths: Array[String], descriptions: Array[String] = []):
	"""Configure the sounds to test"""
	sound_paths = paths
	
	# Auto-generate descriptions if not provided
	if descriptions.is_empty():
		for i in range(paths.size()):
			sound_descriptions.append("Sound %d" % (i + 1))
	else:
		sound_descriptions = descriptions
	
	# Update display
	_update_display()

func play_current_sound():
	"""Play the currently selected sound"""
	if current_sound_index >= sound_paths.size():
		return
	
	var stream: AudioStream = load(sound_paths[current_sound_index]) as AudioStream
	if stream and AudioManager.instance:
		var pitch = 1.0 + randf_range(-pitch_variation, pitch_variation)
		# Play at center of viewport for testing
		var viewport_center = get_viewport().get_visible_rect().size / 2.0
		AudioManager.instance.play_sfx(stream, viewport_center, volume_db, pitch)
		
		if on_sound_played.is_valid():
			on_sound_played.call(current_sound_index, sound_paths[current_sound_index])

func _unhandled_input(event: InputEvent):
	if not enabled or sound_paths.is_empty():
		return
	
	if event is InputEventKey and event.pressed:
		if event.keycode == test_key:
			# Cycle to next sound
			current_sound_index = (current_sound_index + 1) % sound_paths.size()
			_update_display()
			play_current_sound()
			get_viewport().set_input_as_handled()

func _setup_ui():
	"""Create the debug UI"""
	# Create canvas layer for UI
	canvas_layer = CanvasLayer.new()
	canvas_layer.name = "AudioTesterUI"
	add_child(canvas_layer)
	
	# Sound number label
	sound_label = Label.new()
	sound_label.name = "SoundLabel"
	sound_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	sound_label.position = display_position
	sound_label.add_theme_font_size_override("font_size", display_font_size)
	sound_label.add_theme_color_override("font_color", Color(1, 1, 0))
	sound_label.add_theme_color_override("font_outline_color", Color.BLACK)
	sound_label.add_theme_constant_override("outline_size", 3)
	canvas_layer.add_child(sound_label)
	
	# Description label
	desc_label = Label.new()
	desc_label.name = "DescLabel"
	desc_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	desc_label.position = display_position + Vector2(-50, 40)
	desc_label.add_theme_font_size_override("font_size", int(display_font_size * 0.75))
	desc_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.3))
	desc_label.add_theme_color_override("font_outline_color", Color.BLACK)
	desc_label.add_theme_constant_override("outline_size", 2)
	canvas_layer.add_child(desc_label)
	
	# Instructions
	instructions_label = Label.new()
	instructions_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	instructions_label.position = display_position + Vector2(-50, 80)
	instructions_label.add_theme_font_size_override("font_size", int(display_font_size * 0.5))
	instructions_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	instructions_label.add_theme_color_override("font_outline_color", Color.BLACK)
	instructions_label.add_theme_constant_override("outline_size", 2)
	instructions_label.text = "Press %s to cycle" % OS.get_keycode_string(test_key)
	canvas_layer.add_child(instructions_label)

func _update_display():
	"""Update the UI labels"""
	if not sound_label:
		return
	
	var total = sound_paths.size()
	if total == 0:
		sound_label.text = "No sounds loaded"
		desc_label.text = ""
		return
	
	sound_label.text = "Sound: %d/%d" % [current_sound_index + 1, total]
	
	if current_sound_index < sound_descriptions.size():
		desc_label.text = sound_descriptions[current_sound_index]
	else:
		desc_label.text = "Sound %d" % (current_sound_index + 1)

func set_enabled(value: bool):
	"""Enable/disable the tester"""
	enabled = value
	if canvas_layer:
		canvas_layer.visible = enabled
	set_process_unhandled_input(enabled)

func cleanup():
	"""Clean removal of the tester"""
	if canvas_layer:
		canvas_layer.queue_free()
	queue_free()
