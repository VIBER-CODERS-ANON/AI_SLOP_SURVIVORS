class_name BaseUIComponent
extends Control

## Base class for all UI components
## Provides common functionality for UI elements

signal visibility_changed(is_visible: bool)
signal animation_completed()

@export_group("Animation Settings")
@export var fade_duration: float = 0.3
@export var slide_duration: float = 0.3
@export var scale_duration: float = 0.2
@export var use_animations: bool = true

@export_group("Auto-hide Settings")
@export var auto_hide: bool = false
@export var auto_hide_delay: float = 3.0

var is_animating: bool = false
var auto_hide_timer: Timer

func _ready() -> void:
	_setup_component()
	
	if auto_hide:
		_setup_auto_hide()

func _setup_component() -> void:
	# Override in child classes for specific setup
	pass

func _setup_auto_hide() -> void:
	auto_hide_timer = Timer.new()
	auto_hide_timer.wait_time = auto_hide_delay
	auto_hide_timer.one_shot = true
	auto_hide_timer.timeout.connect(hide_animated)
	add_child(auto_hide_timer)

## Show the component with optional animation
func show_animated(animation_type: String = "fade") -> void:
	if is_animating:
		return
	
	visible = true
	visibility_changed.emit(true)
	
	if not use_animations:
		modulate.a = 1.0
		scale = Vector2.ONE
		return
	
	is_animating = true
	
	match animation_type:
		"fade":
			await _animate_fade_in()
		"slide":
			await _animate_slide_in()
		"scale":
			await _animate_scale_in()
		_:
			await _animate_fade_in()
	
	is_animating = false
	animation_completed.emit()
	
	if auto_hide and auto_hide_timer:
		auto_hide_timer.start()

## Hide the component with optional animation
func hide_animated(animation_type: String = "fade") -> void:
	if is_animating:
		return
	
	if not use_animations:
		visible = false
		visibility_changed.emit(false)
		return
	
	is_animating = true
	
	match animation_type:
		"fade":
			await _animate_fade_out()
		"slide":
			await _animate_slide_out()
		"scale":
			await _animate_scale_out()
		_:
			await _animate_fade_out()
	
	visible = false
	is_animating = false
	visibility_changed.emit(false)
	animation_completed.emit()

## Pulse animation for emphasis
func pulse(intensity: float = 1.2, duration: float = 0.2) -> void:
	if is_animating:
		return
	
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE * intensity, duration * 0.5)
	tween.tween_property(self, "scale", Vector2.ONE, duration * 0.5)

## Shake animation for error or impact
func shake(intensity: float = 10.0, duration: float = 0.3) -> void:
	if is_animating:
		return
	
	var original_position = position
	var tween = create_tween()
	
	for i in range(6):
		var offset = Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		tween.tween_property(self, "position", original_position + offset, duration / 6)
	
	tween.tween_property(self, "position", original_position, duration / 6)

## Flash animation for damage or collection
func flash(color: Color = Color.WHITE, duration: float = 0.1) -> void:
	var original_modulate = modulate
	var tween = create_tween()
	tween.tween_property(self, "modulate", color, duration * 0.5)
	tween.tween_property(self, "modulate", original_modulate, duration * 0.5)

# Animation implementations
func _animate_fade_in() -> void:
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, fade_duration)
	await tween.finished

func _animate_fade_out() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_duration)
	await tween.finished

func _animate_slide_in() -> void:
	var start_pos = position
	position.y -= 50
	modulate.a = 0.0
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", start_pos, slide_duration).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, slide_duration)
	await tween.finished

func _animate_slide_out() -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y + 50, slide_duration).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, slide_duration)
	await tween.finished

func _animate_scale_in() -> void:
	scale = Vector2.ZERO
	modulate.a = 0.0
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE, scale_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "modulate:a", 1.0, scale_duration)
	await tween.finished

func _animate_scale_out() -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ZERO, scale_duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "modulate:a", 0.0, scale_duration)
	await tween.finished

## Reset auto-hide timer (useful when updating content)
func reset_auto_hide_timer() -> void:
	if auto_hide and auto_hide_timer:
		auto_hide_timer.stop()
		auto_hide_timer.start()

## Update content - override in child classes
func update_content(data: Dictionary) -> void:
	# Override in child classes to update specific content
	pass

## Get formatted text with color
static func format_colored_text(text: String, color: Color) -> String:
	return "[color=#%s]%s[/color]" % [color.to_html(false), text]

## Get formatted text with size
static func format_sized_text(text: String, size: int) -> String:
	return "[font_size=%d]%s[/font_size]" % [size, text]