extends BaseEnemy
class_name BaseCreature

## Base class for all chatter-controlled creatures
## Provides common functionality for different creature types

@export_group("Creature Config")
@export var creature_type: String = "unknown"
@export var base_scale: float = 1.0
@export var abilities: Array[String] = []

# Chatter info - can be set via constructor or set_chatter_data
var chatter_username: String = ""
var chatter_color: Color = Color.WHITE
var username_label: Label = null

# Visual customization
var scale_multiplier: float = 1.0
var aoe_multiplier: float = 1.0
var original_sprite_scale: Vector2

func _entity_ready():
	super._entity_ready()
	
	# Store original sprite scale
	if sprite:
		original_sprite_scale = sprite.scale
	else:
		original_sprite_scale = Vector2.ONE
	
	# Store original collision scale
	var collision = get_node_or_null("CollisionShape2D")
	if collision:
		collision.set_meta("original_scale", collision.scale)
	
	# Don't set up username label here - wait for set_chatter_data
	
	# Add to chatter entities group
	add_to_group("chatter_entities")
	
	# Apply initial scale
	_update_visual_scale()

func _physics_process(_delta):
	super._physics_process(_delta)
	
	# Update nameplate visibility based on debug settings
	if username_label and DebugSettings.instance:
		username_label.visible = DebugSettings.instance.nameplates_enabled

func _setup_username_label():
	username_label = Label.new()
	username_label.name = "UsernameLabel"
	username_label.text = chatter_username
	username_label.add_theme_font_size_override("font_size", 12)
	username_label.add_theme_color_override("font_color", chatter_color)
	username_label.add_theme_color_override("font_outline_color", Color.BLACK)
	username_label.add_theme_constant_override("outline_size", 2)
	
	# Check if nameplates are disabled
	if DebugSettings.instance and not DebugSettings.instance.nameplates_enabled:
		username_label.visible = false
	
	# Center the label horizontally
	username_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	username_label.anchor_left = 0.5
	username_label.anchor_right = 0.5
	username_label.position = Vector2(0, -40)
	
	# Ensure it stays on top
	username_label.z_index = 100
	username_label.show_behind_parent = false
	
	add_child(username_label)
	
	# Force update position after adding
	username_label.position.x = -username_label.size.x / 2.0

## Set chatter data
func set_chatter_data(username: String, color: Color):
	chatter_username = username
	chatter_color = color
	
	# Create label if it doesn't exist yet
	if not username_label:
		_setup_username_label()
	
	# Update label properties
	if username_label:
		username_label.text = username
		username_label.add_theme_color_override("font_color", color)

## Set scale multiplier (for upgrades)
func set_scale_multiplier(multiplier: float):
	scale_multiplier = multiplier
	_update_visual_scale()

## Update visual scale
func update_visual_scale(new_multiplier: float):
	scale_multiplier = new_multiplier
	_update_visual_scale()

func _update_visual_scale():
	if sprite and original_sprite_scale:
		sprite.scale = original_sprite_scale * base_scale * scale_multiplier
	
	# Update collision shape if exists
	var collision = get_node_or_null("CollisionShape2D")
	if collision:
		# Preserve the original aspect ratio if it was set (like for oval rats)
		var original_scale = collision.get_meta("original_scale", Vector2.ONE)
		collision.scale = original_scale * base_scale * scale_multiplier
	
	# Update health/mana bars if they exist
	var health_bar = get_node_or_null("HealthBar")
	if health_bar:
		health_bar.scale.x = 1.0 / scale_multiplier  # Keep bar same visual size


## Get display name for death messages
func get_display_name() -> String:
	return chatter_username + "'s " + creature_type

## Get the chatter's username
func get_chatter_username() -> String:
	return chatter_username

## Get the chatter's color
func get_chatter_color() -> Color:
	return chatter_color

## Get killer display name (for death messages)
func get_killer_display_name() -> String:
	return chatter_username

## Check if this is a specific creature type
func is_creature_type(type: String) -> bool:
	return creature_type == type

## Set AoE multiplier (for upgrades)
func set_aoe_multiplier(multiplier: float):
	aoe_multiplier = multiplier

## Get AoE multiplier for scaling abilities
func get_aoe_multiplier() -> float:
	return aoe_multiplier


## Static factory method to create a chatter entity with proper initialization
static func create_chatter_entity(scene_path: String, username: String, color: Color) -> BaseCreature:
	var scene = load(scene_path)
	if not scene:
		push_error("Failed to load chatter entity scene: " + scene_path)
		return null
	
	var entity = scene.instantiate()
	if not entity is BaseCreature:
		push_error("Scene is not a BaseCreature: " + scene_path)
		entity.queue_free()
		return null
	
	# Set chatter data using the proper method to trigger label creation
	entity.set_chatter_data(username, color)
	
	return entity
