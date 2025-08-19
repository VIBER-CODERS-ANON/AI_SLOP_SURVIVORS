extends Label
class_name DamageNumber

## Floating damage number that rises and fades

@export var fade_time: float = 4.0  # SUPER slow - more than half speed
@export var horizontal_spread: float = 30.0

var is_crit: bool = false
var is_player_damage: bool = false

func _ready():
	# Set up label properties
	add_theme_font_size_override("font_size", 24)
	
	# Center the text
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Create a shadow effect by adding a duplicate label behind
	var shadow = Label.new()
	shadow.text = text
	shadow.add_theme_font_size_override("font_size", 24)
	shadow.modulate = Color(0, 0, 0, 0.8)  # Black shadow
	shadow.position = Vector2(2, 2)  # Offset for shadow
	shadow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shadow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(shadow)
	move_child(shadow, 0)  # Put shadow behind main text
	
	# Add random horizontal offset
	position.x += randf_range(-horizontal_spread, horizontal_spread)
	
	# Set z-index to be above everything
	z_index = 100
	
	# Start animation
	_animate()

func setup(damage: float, crit: bool = false, player_damage: bool = false):
	is_crit = crit
	is_player_damage = player_damage
	text = str(int(damage))
	
	if is_player_damage:
		# RED color for player taking damage
		modulate = Color(1, 0.2, 0.2)  # Bright red
		add_theme_font_size_override("font_size", 26)  # Slightly bigger
	elif is_crit:
		# Yellow color for crits
		modulate = Color(1, 1, 0)
		add_theme_font_size_override("font_size", 32)  # Bigger for crits
		
		# Add exclamation mark for emphasis
		text = text + "!"
	else:
		# White color for normal hits
		modulate = Color.WHITE
		add_theme_font_size_override("font_size", 24)
	
	# Update shadow if it exists
	if get_child_count() > 0:
		var shadow = get_child(0)
		if shadow is Label:
			shadow.text = text
			shadow.add_theme_font_size_override("font_size", 32 if is_crit else 24)

func _animate():
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Kill tween when damage number is freed
	tree_exiting.connect(func(): 
		if tween and tween.is_valid():
			tween.kill()
	)
	
	# SAME slow upward movement for both types
	var float_distance = -60
	tween.tween_property(self, "position:y", position.y + float_distance, fade_time)
	
	# DIFFERENT fade times!
	# Player taking damage: 2 seconds
	# Player dealing damage: 1 second ONLY!
	var opacity_fade_time = fade_time / 2.0 if is_player_damage else fade_time / 4.0
	
	# Fade out main label
	tween.tween_property(self, "modulate:a", 0.0, opacity_fade_time)
	
	# Fade out shadow
	if get_child_count() > 0:
		var shadow = get_child(0)
		if shadow is Label:
			tween.tween_property(shadow, "modulate:a", 0.0, opacity_fade_time)
	
	# Scale effect for crits
	if is_crit:
		tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.1)
		tween.chain().tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)
	
	# Clean up after movement completes
	_delayed_free()

func _delayed_free():
	await get_tree().create_timer(fade_time).timeout
	queue_free()
