extends BaseCreature
class_name UgandanWarrior

## Ugandan Warrior - Fast minion that explodes on contact
## Summoned by Forsen's abilities and chat interactions

# Warrior specific properties
@export var warrior_speed: float = 350.0  # Super fast speed
@export var explosion_damage: float = 100.0  # 100% of HP as damage
@export var explosion_radius: float = 120.0
@export var pushiness_force: float = 300.0  # Additional push force
@export var spawn_sound: AudioStream

# State
var has_yelled: bool = false
var is_exploding: bool = false

func _entity_ready():
	super._entity_ready()
	_setup_warrior()

func _setup_warrior():
	# REQUIRED: Core properties
	creature_type = "UgandanWarrior"
	base_scale = 0.56  # Reduced by 30% (was 0.8, now 0.8 * 0.7)
	abilities = ["suicide_bomb"]
	
	# REQUIRED: Stats
	max_health = 1.0  # Dies in one hit
	current_health = max_health
	move_speed = warrior_speed  # Fast movement
	damage = 1.0  # Base damage only 1 (was explosion_damage)
	attack_range = 120.0  # Trigger earlier when approaching player
	attack_cooldown = 0.1  # Almost instant
	attack_type = AttackType.MELEE
	
	# REQUIRED: Tags
	if taggable:
		taggable.add_tag("Enemy")
		taggable.add_tag("TwitchMob")
		taggable.add_tag("Minion")
		taggable.add_tag("UgandanWarrior")
		taggable.add_tag("Melee")
		taggable.add_tag("Explosive")
		taggable.add_tag("Lesser")
	
	# REQUIRED: Groups
	add_to_group("enemies")
	add_to_group("ai_controlled")
	add_to_group("twitch_mob")
	add_to_group("ugandan_warriors")
	
	# Set up sprite
	_setup_sprite()
	
	# Yell on spawn
	if not has_yelled:
		_yell_gwa_gwa()
		_play_spawn_gwa()
		has_yelled = true
	
	# Setup abilities deferred
	call_deferred("_setup_abilities")

func _setup_sprite():
	# Use 5-frame spritesheet: res://BespokeAssetSources/forsen/ugandanwarriorsprite.png
	# Node setup expects AnimatedSprite2D in scene
	sprite = get_node_or_null("AnimatedSprite2D")
	if not sprite:
		return

	# Crisp sampling and prevent bleeding
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED

	var frames = SpriteFrames.new()
	var texture = load("res://BespokeAssetSources/forsen/ugandanwarriorsprite.png")
	if not texture:
		return

	frames.add_animation("run")
	frames.set_animation_speed("run", 18.0)  # Fast, readable loop for 5 frames
	frames.set_animation_loop("run", true)

	var frames_count := 5
	var frame_width: int = int(floor(texture.get_width() / float(frames_count)))
	var frame_height: int = texture.get_height()
	for i in range(frames_count):
		var at := AtlasTexture.new()
		at.atlas = texture
		at.region = Rect2i(i * frame_width, 0, frame_width, frame_height)
		at.filter_clip = true
		frames.add_frame("run", at)

	sprite.sprite_frames = frames
	sprite.play("run")
	sprite.scale = Vector2(base_scale, base_scale)

func _setup_abilities():
	await get_tree().create_timer(0.1).timeout
	
	if ability_manager and ability_holder:
		ability_manager.ability_holder = ability_holder
	
	# Use suicide bomb ability with proximity activation
	var suicide_ability = SuicideBombAbility.new()
	suicide_ability.explosion_damage_percent = explosion_damage / max_health  # Convert to percentage
	suicide_ability.explosion_radius = explosion_radius
	suicide_ability.telegraph_time = 0.4  # Quick but visible detonation
	suicide_ability.activation_range = attack_range  # Use attack range for activation
	suicide_ability.activation_chance_per_frame = 0.15  # 15% max chance when very close
	suicide_ability.auto_activate_on_proximity = true  # Enable auto-activation
	
	add_ability(suicide_ability)

func _entity_physics_process(delta):
	super._entity_physics_process(delta)
	
	# Always aggro on player from anywhere on the map
	if not target_player:
		target_player = _find_player()
	
	# AI always targets player now - no configuration needed
	
	# Update sprite direction based on movement
	if sprite and movement_velocity.x != 0:
		sprite.flip_h = movement_velocity.x < 0  # Flip when moving left
	
	# Apply additional pushiness
	if movement_velocity.length() > 0:
		# Add extra force when moving
		movement_velocity = movement_velocity.normalized() * (move_speed + pushiness_force * 0.1)

func _yell_gwa_gwa():
	# Visual text
	var yell_text = "GWA GWA GWA GWA!"
	_show_yell_bubble(yell_text)
	
	# Audio
	if spawn_sound:
		if AudioManager.instance:
			AudioManager.instance.play_sfx_on_node(spawn_sound, self, 0.1, 1.0)
	# else: Play default sound

func _play_spawn_gwa():
	# Play gwa-gwa-gwa-zulul when a warrior spawns
	var sfx_path := "res://BespokeAssetSources/forsen/gwa-gwa-gwa-zulul.mp3"
	if ResourceLoader.exists(sfx_path):
		if AudioManager.instance:
			AudioManager.instance.play_sfx_on_node(load(sfx_path), self, 0.0, 1.0)
		else:
			var p := AudioStreamPlayer2D.new()
			add_child(p)
			p.stream = load(sfx_path)
			p.play()
	
	# Action feed
	var action_feed = get_action_feed()
	if action_feed:
		action_feed.add_message("🏃 %s yells: GWA GWA GWA GWA!" % chatter_username, Color(0.8, 0.8, 0))

func _show_yell_bubble(text: String):
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.modulate = Color(1, 1, 0)  # Yellow text
	label.z_index = 100
	
	# Position above warrior
	label.position = Vector2(-50, -40)
	add_child(label)
	
	# Animate and remove
	var tween = create_tween()
	tween.set_parallel()
	
	# Kill tween when label is freed
	label.tree_exiting.connect(func(): 
		if tween and tween.is_valid():
			tween.kill()
	)
	
	tween.tween_property(label, "position:y", label.position.y - 20, 2.0)
	tween.tween_property(label, "modulate:a", 0.0, 2.0)
	tween.chain().tween_callback(label.queue_free)

# Removed _trigger_explosion - now handled by suicide_bomb_ability

func take_damage(_amount: float, source: Node = null, damage_tags: Array = []):
	# Warriors die in one hit regardless of damage
	super.take_damage(max_health, source, damage_tags)

func die():
	# Award 1 XP
	_spawn_xp_orb(1)
	
	# If we haven't exploded yet, try to trigger suicide bomb ability
	if not is_exploding and ability_manager:
		# Try to execute suicide bomb if we have it
		for slot in ability_manager.abilities:
			var ability = ability_manager.abilities[slot]
			# Check if ability exists and has the suicide_bomb ID
			if ability and "ability_id" in ability and ability.ability_id == "suicide_bomb":
				ability.execute(ability_holder, {"position": global_position})
				break
	
	super.die()

func _spawn_xp_orb(value: int):
	var xp_orb_scene = preload("res://entities/pickups/xp_orb.tscn")
	if xp_orb_scene:
		var orb = xp_orb_scene.instantiate()
		orb.xp_value = value
		orb.global_position = global_position
		get_parent().call_deferred("add_child", orb)

func get_killer_display_name() -> String:
	return chatter_username

func get_attack_name() -> String:
	return "explosion"

func get_action_feed():
	var game = get_tree().get_first_node_in_group("game_controller")
	if game and game.has_method("get_action_feed"):
		return game.get_action_feed()
	return null

# For compatibility with abilities
func get_chatter_username() -> String:
	return chatter_username

func get_display_name() -> String:
	return chatter_username
