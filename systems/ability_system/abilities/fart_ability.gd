class_name FartAbility
extends BaseAbility

## Fart ability - creates a poison cloud at caster's location
## The cloud persists and damages enemies who enter it

# Poison cloud properties
@export var cloud_damage_per_second: float = 1.0
@export var cloud_radius: float = 120.0
@export var cloud_duration: float = 8.0
@export var cloud_fade_time: float = 2.0
@export var poison_cloud_scene_path: String = "res://entities/effects/poison_cloud.tscn"

# Audio
@export var fart_sound_path: String = "res://audio/sfx_Extre_20250811_095859.mp3"

# Visual feedback
@export var tint_duration: float = 0.4
@export var tint_color: Color = Color(0.5, 1, 0.5, 1)

# Cached resources
var poison_cloud_scene: PackedScene
var fart_sound: AudioStream

func _init() -> void:
	# Set base properties
	ability_id = "fart"
	ability_name = "Fart"
	ability_description = "Creates a toxic cloud that damages enemies over time"
	ability_tags = ["AoE", "Poison", "DoT", "Environmental"]
	ability_type = 0  # ACTIVE
	
	# Ability costs and cooldown
	base_cooldown = 100.0  # Long cooldown
	resource_costs = {}  # No resource cost
	
	# Targeting - self-targeted AoE
	targeting_type = 5  # AREA_AROUND_SELF
	base_range = 0.0  # Cast at self location

func on_added(holder) -> void:
	super.on_added(holder)
	
	# Preload resources
	if poison_cloud_scene_path != "":
		poison_cloud_scene = load(poison_cloud_scene_path)
	if fart_sound_path != "":
		fart_sound = load(fart_sound_path)
	
	var _entity_name = ""
	if holder.has_method("get_entity_node"):
		_entity_name = holder.get_entity_node().name
	elif holder.has_method("get_parent"):
		_entity_name = holder.get_parent().name
	else:
		_entity_name = str(holder.name) if holder.has("name") else "Unknown"


func can_execute(holder, target_data) -> bool:
	if not super.can_execute(holder, target_data):
		return false
	
	# Check if entity is alive
	var entity = holder
	if holder.has_method("get_entity_node"):
		entity = holder.get_entity_node()
	else:
		pass
	
	if entity and entity.has_method("is_alive") and not entity.is_alive:
		return false
	
	return true

func _execute_ability(holder, target_data) -> void:
	var entity = holder
	if holder.has_method("get_entity_node"):
		entity = holder.get_entity_node()
	if not entity:
		return
	
	# Report to action feed if this is a chatter
	if entity.has_method("get_chatter_username") and GameController.instance:
		var action_feed = GameController.instance.get_action_feed()
		if action_feed:
			action_feed.chatter_farted(entity.get_chatter_username())
	
	# Play fart sound
	if fart_sound and AudioManager.instance:
		AudioManager.instance.play_sfx_on_node(
			fart_sound,
			entity,
			0.0,
			1.0
		)
	
	# Spawn poison cloud
	if poison_cloud_scene:
		var poison_cloud = poison_cloud_scene.instantiate()
		
		# Apply AoE multiplier if entity has one
		if entity.has_method("get_aoe_multiplier"):
			poison_cloud.applied_aoe_scale = entity.get_aoe_multiplier()
		
		# Store source information for death messages
		if entity.has_method("get_chatter_username"):
			poison_cloud.set_meta("source_name", entity.get_chatter_username())
		elif entity.has_method("get_display_name"):
			poison_cloud.set_meta("source_name", entity.get_display_name())
		else:
			poison_cloud.set_meta("source_name", entity.name)
		
		poison_cloud.set_meta("spawner", entity)
		
		# Override cloud properties with ability values
		poison_cloud.damage_per_second = get_modified_value(cloud_damage_per_second, "spell_power", holder)
		poison_cloud.cloud_radius = cloud_radius
		poison_cloud.duration = cloud_duration
		poison_cloud.fade_time = cloud_fade_time
		
		# Add to scene
		entity.get_parent().add_child(poison_cloud)
		poison_cloud.global_position = entity.global_position
	
	# Visual feedback on the caster
	_apply_visual_feedback(entity)
	
	# Start cooldown
	_start_cooldown(holder)
	
	# Notify holder
	holder.on_ability_executed(self)
	executed.emit(target_data)

func _apply_visual_feedback(entity: Node) -> void:
	# Tint the sprite green briefly
	var sprite_container = entity.get_node_or_null("SpriteContainer")
	var sprite = null
	
	if sprite_container:
		sprite = sprite_container.get_node_or_null("Sprite")
	else:
		sprite = entity.get_node_or_null("sprite")
	
	if sprite:
		var tween = entity.create_tween()
		tween.tween_property(sprite, "modulate", tint_color, tint_duration * 0.25)
		tween.tween_property(sprite, "modulate", Color.WHITE, tint_duration * 0.75)

## Override to provide AoE preview radius
func get_range() -> float:
	return cloud_radius
