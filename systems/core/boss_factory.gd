extends Node
class_name BossFactory

## Factory class for spawning all boss types

static var instance: BossFactory

signal boss_spawned(boss_node: Node, boss_type: String)

# Boss spawn configurations (based on original game controller methods)
const BOSS_CONFIGS = {
	"zzran": {
		"script": "res://entities/enemies/bosses/zzran/zzran_boss.gd",
		"texture": "res://BespokeAssetSources/zizidle.png",
		"scale": Vector2(0.75, 0.75),  # Original scale from working version
		"radius": 30.0,
		"portal_color": Color(0.8, 0.2, 0.8),  # Purple for ZZran
		"particle_color": Color(1.0, 0.0, 1.0),  # Magenta energy
		"use_lightning": false,  # ZZran uses portal energy instead
		"special_effect": "ziz_fullscreen",
		"camera_shake": {"intensity": 10.0, "duration": 0.5}  # Heavy shake for the enigmatic boss
	},
	"thor": {
		"script": "res://entities/enemies/bosses/thor/thor_enemy.gd",
		"texture": "res://entities/enemies/bosses/thor/pirate_skull.png",
		"scale": Vector2(0.1, 0.1),  # Original starts tiny and scales up
		"radius": 30.0,
		"portal_color": Color(0.2, 0.8, 1.0),  # Blue for THOR
		"particle_color": Color(1.0, 1.0, 0.2),  # Yellow lightning
		"use_lightning": true,
		"spawn_animation": "scale_in",
		"camera_shake": {"intensity": 6.0, "duration": 0.3}  # Medium thunder shake
	},
	"mika": {
		"script": "res://entities/enemies/bosses/mika/mika_boss.gd",
		"texture": "res://BespokeAssetSources/mika.png",
		"scale": Vector2(0.75, 0.75),  # Original scale
		"radius": 30.0,
		"portal_color": Color(1.0, 0.3, 0.1),  # Red/orange for Mika
		"particle_color": Color(1.0, 0.6, 0.0),  # Orange flames
		"use_lightning": false,
		"use_portal": false,  # Mika uses shockwave and lightning
		"spawn_animation": "dash_in",
		"camera_shake": {"intensity": 7.0, "duration": 0.25}  # Quick, sharp shake for swift strike
	},
	"forsen": {
		"script": "res://entities/enemies/bosses/forsen/forsen_boss.gd",
		"texture": "res://BespokeAssetSources/forsen/forsen.png",
		"scale": Vector2(1.2, 1.2),  # Original scale
		"radius": 30.0,
		"portal_color": Color(0.5, 0.0, 0.5),  # Purple for Forsen
		"particle_color": Color(0.8, 0.0, 0.8),  # Purple energy
		"use_lightning": true,  # Add some chaos
		"use_portal": true,
		"use_animated_sprite": true,  # Forsen uses AnimatedSprite2D
		"spawn_animation": "slide_in",
		"camera_shake": {"intensity": 9.0, "duration": 0.6}  # Chaotic meme lord shake
	}
}

# Reference to game scene for adding bosses
var game_scene: Node2D

func _ready():
	instance = self

func spawn_boss(boss_type: String, spawn_position: Vector2) -> Node:
	if not BOSS_CONFIGS.has(boss_type):
		push_error("Unknown boss type: " + boss_type)
		return null
	
	var config = BOSS_CONFIGS[boss_type]
	
	# Create boss node
	var boss = _create_boss_node(boss_type, config, spawn_position)
	
	# Add to scene
	if game_scene:
		game_scene.add_child(boss)
	else:
		push_error("No game scene set for BossFactory")
		boss.queue_free()
		return null
	
	# Create spawn effect (temporarily disabled for debugging)
	# _create_spawn_effect(config, spawn_position, boss)
	
	# Immediately call spawn complete for debugging
	_on_spawn_effect_complete(boss)
	
	# Assign rarity
	_assign_boss_rarity(boss)
	
	boss_spawned.emit(boss, boss_type)
	print("👹 %s boss spawned at %s" % [boss_type.capitalize(), spawn_position])
	
	return boss

func _create_boss_node(boss_type: String, config: Dictionary, spawn_position: Vector2) -> CharacterBody2D:
	var boss_script = load(config.script)
	if not boss_script:
		push_error("Failed to load boss script: " + config.script)
		return null
		
	var boss = CharacterBody2D.new()
	boss.set_script(boss_script)
	boss.name = boss_type.capitalize() + "Boss"
	boss.position = spawn_position
	boss.collision_layer = 2  # Enemy layer
	boss.collision_mask = 1   # Collide with player layer
	boss.process_mode = Node.PROCESS_MODE_PAUSABLE
	boss.visible = true
	
	# Add sprite
	var boss_sprite = Sprite2D.new()
	boss_sprite.name = "Sprite"
	boss_sprite.texture = load(config.texture)
	boss_sprite.scale = config.scale
	boss.add_child(boss_sprite)
	
	# Add collision shape
	var collision = CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape = CircleShape2D.new()
	shape.radius = config.radius
	collision.shape = shape
	boss.add_child(collision)
	
	# Add boss health UI if needed
	_create_boss_health_ui(boss)
	
	return boss

func _create_spawn_effect(config: Dictionary, spawn_position: Vector2, boss: Node):
	var spawn_effect = preload("res://entities/effects/boss_spawn_effect.gd").new()
	spawn_effect.position = spawn_position
	spawn_effect.portal_color = config.portal_color
	spawn_effect.particle_color = config.particle_color
	spawn_effect.use_lightning = config.use_lightning
	spawn_effect.process_mode = Node.PROCESS_MODE_ALWAYS
	
	if game_scene:
		game_scene.add_child(spawn_effect)
	
	# Connect spawn complete signal
	spawn_effect.spawn_complete.connect(func():
		_on_spawn_effect_complete(boss)
	)

func _on_spawn_effect_complete(boss: Node):
	if not is_instance_valid(boss):
		print("⚠️ Spawn effect complete but boss is invalid!")
		return
	
	print("✨ Spawn effect complete for: %s" % boss.name)
	
	# Apply camera shake based on boss configuration
	var boss_type = _get_boss_type_from_name(boss.name)
	if boss_type and BOSS_CONFIGS.has(boss_type) and BOSS_CONFIGS[boss_type].has("camera_shake"):
		var shake_config = BOSS_CONFIGS[boss_type]["camera_shake"]
		CameraShake.shake_custom(shake_config.intensity, shake_config.duration)
		print("📷 Applied %s camera shake: intensity=%.1f, duration=%.2fs" % [boss_type, shake_config.intensity, shake_config.duration])
	else:
		# Fallback to default if no config found
		CameraShake.shake_preset("boss_spawn")
		print("📷 Applied default boss spawn camera shake")
	
	# Let boss handle its own special effects
	if boss.has_method("on_spawn_complete"):
		boss.on_spawn_complete()
	
	# Make boss visible with fade-in (already visible for debugging, but ensure full opacity)
	if is_instance_valid(boss):
		boss.visible = true
		boss.modulate.a = 1.0  # Full opacity immediately for debugging
		print("👁️ Boss %s is now fully visible" % boss.name)

# Removed _show_ziz_fullscreen_attack - moved to zzran_boss.gd

func _create_boss_health_ui(_boss: Node):
	# Legacy function - bosses now handle their own health bars
	# Kept for compatibility
	pass

func _assign_boss_rarity(boss: Node):
	var rarity_manager = NPCRarityManager.get_instance()
	if rarity_manager:
		rarity_manager.assign_rarity_type(boss, NPCRarity.Type.UNIQUE)

func spawn_random_boss(spawn_position: Vector2) -> Node:
	var boss_types = BOSS_CONFIGS.keys()
	var random_type = boss_types[randi() % boss_types.size()]
	return spawn_boss(random_type, spawn_position)

func _get_boss_type_from_name(boss_name: String) -> String:
	# Extract boss type from name (e.g., "ZzranBoss" -> "zzran")
	var type_name = boss_name.to_lower()
	if type_name.ends_with("boss"):
		type_name = type_name.substr(0, type_name.length() - 4)
	return type_name

func get_random_spawn_position(player_position: Vector2, min_distance: float = 300.0, max_distance: float = 500.0) -> Vector2:
	var angle = randf() * TAU
	var distance = randf_range(min_distance, max_distance)
	return player_position + Vector2(cos(angle), sin(angle)) * distance

# New resource-based spawn method
func spawn_from_resource(resource: EnemyResource, position: Vector2, username: String = "") -> Node:
	if not resource:
		print("⚠️ BossFactory: Invalid boss resource")
		return null
	
	if resource.enemy_category != "boss":
		print("⚠️ BossFactory: Resource is not a boss type")
		return null
	
	# Try to use existing config if available
	if BOSS_CONFIGS.has(resource.enemy_id):
		var boss = spawn_boss(resource.enemy_id, position)
		if boss and username != "":
			boss.set_meta("owner_username", username)
		return boss
	
	# Create boss from resource data
	var boss = _create_boss_from_resource(resource, position)
	if not boss:
		return null
	
	# Set owner if provided
	if username != "":
		boss.set_meta("owner_username", username)
	
	# Add to scene
	if game_scene:
		game_scene.add_child(boss)
	else:
		push_error("No game scene set for BossFactory")
		boss.queue_free()
		return null
	
	# Add to bosses group
	boss.add_to_group("bosses")
	
	boss_spawned.emit(boss, resource.enemy_id)
	print("👹 Boss '%s' spawned from resource at %s" % [resource.display_name, position])
	
	return boss

func _create_boss_from_resource(resource: EnemyResource, spawn_position: Vector2) -> CharacterBody2D:
	var boss = CharacterBody2D.new()
	boss.name = resource.display_name.replace(" ", "_")
	boss.position = spawn_position
	
	# Set up visuals
	var sprite: Sprite2D = null
	if resource.sprite_texture:
		sprite = Sprite2D.new()
		sprite.texture = resource.sprite_texture
		sprite.scale = Vector2.ONE * resource.base_scale
		boss.add_child(sprite)
	elif resource.sprite_frames:
		var animated_sprite = AnimatedSprite2D.new()
		animated_sprite.sprite_frames = resource.sprite_frames
		animated_sprite.scale = Vector2.ONE * resource.base_scale
		boss.add_child(animated_sprite)
		sprite = animated_sprite
	
	# Set up collision
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 30.0 * resource.base_scale
	collision.shape = shape
	boss.add_child(collision)
	
	# Add basic boss properties
	boss.set_script(preload("res://entities/enemies/base_boss.gd") if FileAccess.file_exists("res://entities/enemies/base_boss.gd") else null)
	
	# Set stats from resource
	boss.set_meta("max_health", resource.base_health)
	boss.set_meta("health", resource.base_health)
	boss.set_meta("speed", resource.base_speed)
	boss.set_meta("damage", resource.base_damage)
	boss.set_meta("attack_range", resource.attack_range)
	boss.set_meta("attack_cooldown", resource.attack_cooldown)
	boss.set_meta("xp_value", resource.xp_value)
	boss.set_meta("mxp_value", resource.mxp_value)
	
	# Store resource reference
	boss.set_meta("enemy_resource", resource)
	
	return boss

# Clear all bosses (for debug mode)
func clear_all_bosses():
	var bosses = get_tree().get_nodes_in_group("bosses")
	for boss in bosses:
		if is_instance_valid(boss):
			boss.queue_free()
	print("[BossFactory] Cleared all bosses")

# Get boss at position (for debug selection)
func get_boss_at_position(world_pos: Vector2) -> Node:
	var bosses = get_tree().get_nodes_in_group("bosses")
	var closest_boss = null
	var closest_distance = 50.0  # Maximum selection distance
	
	for boss in bosses:
		if not is_instance_valid(boss):
			continue
		
		var distance = boss.global_position.distance_to(world_pos)
		if distance < closest_distance:
			closest_distance = distance
			closest_boss = boss
	
	return closest_boss
