extends BaseEntity
class_name Player

## Player character class
## Handles player-specific functionality and integrates with game systems

signal experience_gained(amount: int)
signal level_up(new_level: int)

@export_group("Player Stats")
@export var base_move_speed: float = 210.0
@export var base_pickup_range: float = 100.0
@export var base_health: float = 20.0
@export var sprite_scale: float = 0.9  # 3x bigger than original 0.3

# Leveling
var level: int = 1
var experience: int = 0
var experience_to_next_level: int = 10

# Current values
var pickup_range: float

# Bonus stats - ALL additive/multiplicative modifiers go here
var bonus_move_speed: float = 0.0  # Flat bonus to movement
var bonus_health: float = 0.0  # Flat bonus to max health
var bonus_pickup_range: float = 0.0  # Flat bonus to pickup range
var bonus_crit_chance: float = 0.0  # Added to weapons with "Crit" tag
var bonus_crit_multiplier: float = 0.0  # Added to crit damage
var bonus_attack_speed: float = 0.0  # Multiplier for "AttackSpeed" tag
var area_of_effect: float = 1.0  # Multiplier for "AoE" tag (1.0 = 100%)
var bonus_damage: float = 0.0  # Flat damage bonus for "Damage" tag
var bonus_damage_multiplier: float = 1.0  # Multiplier for "Damage" tag

# Cheat mode
var invulnerable: bool = false  # God mode flag

# Vampiric system
var vampiric_drain_timer: float = 0.0
var vampiric_heal_on_kill_percent: float = 0.1  # 10% max HP heal on kill

# Hit sound cooldowns
var last_dot_hit_sound_time: float = 0.0
const DOT_HIT_SOUND_COOLDOWN: float = 2.0  # 2 seconds between DoT hit sounds

# Active abilities (to be implemented)
var abilities: Array = []

# Dash ability
# var dash_ability: Node  # Removed - using new ability system

# Combat state tracking
var in_combat: bool = false
var combat_timer: float = 0.0
const COMBAT_TIMEOUT: float = 3.0  # Exit combat after 3 seconds of no damage

# Movement state
var is_sprinting_flag: bool = false

func _entity_ready():
	# Make sure player pauses properly
	process_mode = Node.PROCESS_MODE_PAUSABLE
	
	# Add to player group FIRST (before child nodes look for us)
	add_to_group("player")
	
	# Set player-specific tags
	taggable.permanent_tags = ["Player", "Ground"]
	taggable.add_tag("Player")
	taggable.add_tag("Ground")
	
	# Initialize stats
	_update_derived_stats()
	# Set initial health to match our actual max (not the base_entity default)
	current_health = max_health
	
	# DEV TOOL - Set up modular audio tester (can be removed)
	if use_dev_audio_tester:
		_setup_modular_audio_tester()
	
	# Set up player movement controller
	var movement_controller = PlayerMovementController.new()
	movement_controller.name = "PlayerMovementController"  # Match the name expected by abilities
	add_child(movement_controller)
	
	# Set up abilities using the new ability system
	var new_dash_ability = DashAbility.new()
	add_ability(new_dash_ability)
	
	# Set keybind for dash
	if ability_manager:
		ability_manager.set_ability_keybind(0, "dash")  # Slot 0 = dash action
		# Connect to ability events for UI
		var dash_ability_ref = ability_manager.get_ability_by_id("dash")
		if dash_ability_ref:
			dash_ability_ref.cooldown_started.connect(_on_dash_cooldown_started)
			dash_ability_ref.cooldown_ended.connect(_on_dash_cooldown_ended)
	
	# Player stats are set in _update_derived_stats()
	
	# Get animated sprite and setup animation
	var anim_sprite = get_node_or_null("SpriteContainer/Sprite")
	if anim_sprite and anim_sprite is AnimatedSprite2D:
		anim_sprite.scale = Vector2(sprite_scale, sprite_scale)  # Apply configured scale
		anim_sprite.play("idle")
	
	# Set up primary weapon (ArcingSwordWeapon)
	var primary_weapon = get_node_or_null("ArcingSwordWeapon")
	if primary_weapon:
		# Apply attack speed if we have modifiers
		if has_method("get_attack_speed_multiplier"):
			primary_weapon.set_attack_speed_multiplier(get_attack_speed_multiplier())
	
	# Create dash cooldown UI under the player
	_setup_dash_cooldown_ui()
	
	# Create health bar above the player
	_setup_health_bar_ui()
	
	# Set camera zoom (smaller values = more zoomed out)
	var camera = $Camera2D
	if camera:
		camera.zoom = Vector2(0.85, 0.85)  # Zoom out a bit

func _setup_dash_cooldown_ui():
	# Create a small cooldown indicator that appears under the player
	var dash_ui = Control.new()
	dash_ui.name = "DashCooldownUI"
	dash_ui.custom_minimum_size = Vector2(50, 4)  # Very small and thin
	dash_ui.position = Vector2(-25, 50)  # Positioned under the player sprite (moved down 20px)
	dash_ui.visible = false  # Hidden by default
	add_child(dash_ui)
	
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.5)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dash_ui.add_child(bg)
	
	# Cooldown progress bar
	var cooldown_bar = ProgressBar.new()
	cooldown_bar.name = "CooldownBar"
	cooldown_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cooldown_bar.min_value = 0
	cooldown_bar.max_value = 1
	cooldown_bar.value = 0
	cooldown_bar.show_percentage = false
	
	# Style the bar
	var style_bg = StyleBoxFlat.new()
	style_bg.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	cooldown_bar.add_theme_stylebox_override("background", style_bg)
	
	var style_fill = StyleBoxFlat.new()
	style_fill.bg_color = Color(0.2, 0.8, 1.0)  # Blue
	cooldown_bar.add_theme_stylebox_override("fill", style_fill)
	
	dash_ui.add_child(cooldown_bar)
	
	# Store UI references for ability cooldown display
	set_meta("dash_ui", dash_ui)
	set_meta("dash_cooldown_bar", cooldown_bar)

func _setup_health_bar_ui():
	# Create a health bar that hovers above the player
	var health_container = Node2D.new()
	health_container.name = "HealthContainer"
	health_container.position = Vector2(0, -55)  # Position above the player sprite (moved up 15px)
	health_container.z_index = 69  # Elevate above other game objects
	add_child(health_container)
	
	# Create the health bar
	var health_bar = ProgressBar.new()
	health_bar.name = "HealthBar"
	health_bar.custom_minimum_size = Vector2(60, 6)  # Narrow bar
	health_bar.position = Vector2(-30, 0)  # Center the bar
	health_bar.show_percentage = false
	health_bar.value = 100
	health_bar.max_value = 100
	
	# Style the health bar background
	var style_bg = StyleBoxFlat.new()
	style_bg.bg_color = Color(0.2, 0.1, 0.1, 0.8)
	style_bg.border_color = Color(0.3, 0.1, 0.1)
	style_bg.set_border_width_all(1)
	health_bar.add_theme_stylebox_override("background", style_bg)
	
	# Style the health bar fill
	var style_fill = StyleBoxFlat.new()
	style_fill.bg_color = Color(0.9, 0.1, 0.1)
	health_bar.add_theme_stylebox_override("fill", style_fill)
	
	health_container.add_child(health_bar)
	
	# Store reference for updating
	set_meta("health_bar", health_bar)
	
	# Update health bar with current values
	_update_health_bar_display()

func _update_health_bar_display():
	# Check if health bar exists before trying to update it
	if has_meta("health_bar"):
		var health_bar = get_meta("health_bar")
		if health_bar and is_instance_valid(health_bar):
			health_bar.max_value = max_health
			health_bar.value = current_health

## Update all derived stats from base + bonus
func _update_derived_stats():
	# Movement
	move_speed = base_move_speed + bonus_move_speed
	
	# Health
	var old_max_health = max_health
	max_health = base_health + bonus_health
	
	# If max health increased, heal the difference but cap at max
	if max_health > old_max_health:
		current_health = min(current_health + (max_health - old_max_health), max_health)
	
	# Pickup
	pickup_range = base_pickup_range + bonus_pickup_range
	
	# Update displays
	_update_health_bar_display()

func _entity_physics_process(_delta):
	# Face the mouse cursor
	_face_mouse()
	
	# Update combat timer
	if in_combat:
		combat_timer -= _delta
		if combat_timer <= 0:
			exit_combat()
	
	# Handle vampiric drain
	_handle_vampiric_drain(_delta)
	
	# Handle animation based on movement
	var animated_sprite = get_node_or_null("SpriteContainer/Sprite")
	if animated_sprite and animated_sprite is AnimatedSprite2D:
		if movement_velocity.length() > 10:  # Moving
			if animated_sprite.animation != "walk":
				animated_sprite.play("walk")
		else:  # Stopped
			if animated_sprite.animation != "idle":
				animated_sprite.play("idle")
	
	# Check for nearby pickups
	_check_pickups()
	
	# Update abilities
	_update_abilities(_delta)

## Check for and collect nearby pickups
func _check_pickups():
	var pickups = get_tree().get_nodes_in_group("pickups")
	for pickup in pickups:
		if pickup.has_method("can_be_picked_up") and pickup.can_be_picked_up():
			var distance = global_position.distance_to(pickup.global_position)
			if distance <= pickup_range:
				if pickup.has_method("collect"):
					pickup.collect(self)

## Update all active abilities
func _update_abilities(_delta):
	for ability in abilities:
		if ability.has_method("update"):
			ability.update(_delta)

## Gain experience
func gain_experience(amount: int):
	experience += amount
	experience_gained.emit(amount)
	
	# Check for level up
	while experience >= experience_to_next_level:
		_perform_level_up()

## Add XP (alias for gain_experience for consistency)
func add_xp(amount: int):
	gain_experience(amount)

## Level up the player
func _perform_level_up():
	level += 1
	experience -= experience_to_next_level
	
	# Linear progression: level 1->2 = 10 XP, 2->3 = 20 XP, etc.
	experience_to_next_level = level * 10
	
	# Heal on level up
	heal(max_health * 0.5)
	
	# Play epic level up sound through AudioManager
	if AudioManager.instance:
		AudioManager.instance.play_sfx(
			preload("res://audio/sfx_Epic__20250811_111128.mp3"),
			global_position,
			-5.0,  # Same volume as before
			1.0
		)
	
	# Create visual effects
	_create_level_up_effects()
	
	level_up.emit(level)

## Add an ability scene to the player (legacy method - renamed to avoid conflict)
func add_ability_scene(ability_scene: PackedScene):
	var ability_instance = ability_scene.instantiate()
	ability_instance.owner_entity = self
	abilities.append(ability_instance)
	add_child(ability_instance)

## Remove an ability
func remove_ability(ability_instance):
	if ability_instance in abilities:
		abilities.erase(ability_instance)
		ability_instance.queue_free()

## Handle vampiric drain effect
func _handle_vampiric_drain(delta):
	if not has_meta("is_vampiric") or not get_meta("is_vampiric"):
		return
	
	# Drain 1 HP per second
	vampiric_drain_timer += delta
	if vampiric_drain_timer >= 1.0:
		vampiric_drain_timer -= 1.0
		take_damage(1.0, null)  # Take 1 damage per second
		
		# Visual feedback
		modulate = Color(1.2, 0.8, 0.8)  # Reddish tint
		var tween = create_tween()
		tween.tween_property(self, "modulate", Color.WHITE, 0.2)

## Called when this player kills an enemy
func on_enemy_killed(_enemy: BaseEntity):
	# Check for vampiric healing
	if has_meta("is_vampiric") and get_meta("is_vampiric"):
		var heal_amount = max_health * vampiric_heal_on_kill_percent
		heal(heal_amount)
		
		# Visual effect - blood absorption
		var blood_effect = ColorRect.new()
		blood_effect.color = Color(0.8, 0, 0, 0.6)
		blood_effect.size = Vector2(50, 50)
		blood_effect.position = Vector2(-25, -25)
		add_child(blood_effect)
		
		var tween = create_tween()
		tween.set_parallel(true)
		
		# Kill tween when effect is freed
		blood_effect.tree_exiting.connect(func(): 
			if tween and tween.is_valid():
				tween.kill()
		)
		
		tween.tween_property(blood_effect, "scale", Vector2(2, 2), 0.3)
		tween.tween_property(blood_effect, "modulate:a", 0.0, 0.3)
		tween.chain().tween_callback(blood_effect.queue_free)
		
	

## Override damage modifiers for player
func _get_damage_modifiers() -> Dictionary:
	return {
		"Fire:Player": 0.9,  # Take 10% less fire damage
		"Dark:Player": 1.2   # Take 20% more dark damage
	}

## Override take damage to check for god mode and pause state - NO I-FRAMES!
func take_damage(amount: float, source: Node = null, damage_tags: Array = []):
	# Check if we're already dead
	if not is_alive:
		return
		
	# Check if game is paused - no damage during pause
	if GameController.instance and GameController.instance.state_manager and GameController.instance.state_manager.is_paused():
		# Visual feedback that damage was ignored during pause
		var label = Label.new()
		label.text = "PAUSED"
		label.add_theme_font_size_override("font_size", 20)
		label.modulate = Color(0.5, 0.5, 1, 1)
		label.position = Vector2(0, -50)
		label.z_index = 100
		add_child(label)
		
		# Animate the text
		var tween = create_tween()
		tween.set_parallel(true)
		
		# Kill tween when label is freed
		label.tree_exiting.connect(func(): 
			if tween and tween.is_valid():
				tween.kill()
		)
		
		tween.tween_property(label, "position:y", -80, 0.4)
		tween.tween_property(label, "modulate:a", 0.0, 0.4)
		tween.set_parallel(false)
		tween.tween_callback(label.queue_free)
		
		return  # No damage taken during pause
	
	# Check god mode
	if invulnerable:
		# Visual feedback that damage was ignored
		var label = Label.new()
		label.text = "IMMUNE"
		label.add_theme_font_size_override("font_size", 24)
		label.modulate = Color(1, 1, 0, 1)
		label.position = Vector2(0, -60)
		label.z_index = 100
		add_child(label)
		
		# Animate the text
		var tween = create_tween()
		tween.set_parallel(true)
		
		# Kill tween when label is freed
		label.tree_exiting.connect(func(): 
			if tween and tween.is_valid():
				tween.kill()
		)
		
		tween.tween_property(label, "position:y", -100, 0.5)
		tween.tween_property(label, "modulate:a", 0.0, 0.5)
		tween.set_parallel(false)
		tween.tween_callback(label.queue_free)
		
		return  # No damage taken
	
	# Check if this is DoT damage and if we should play the hit sound
	var is_dot_damage = "DoT" in damage_tags
	var should_play_hit_sound = true
	
	if is_dot_damage:
		var current_time = Time.get_ticks_msec() / 1000.0
		if current_time - last_dot_hit_sound_time < DOT_HIT_SOUND_COOLDOWN:
			should_play_hit_sound = false
		else:
			last_dot_hit_sound_time = current_time
	
	# Play hit sound only if allowed
	if should_play_hit_sound:
		__play_hit_sfx()
	
	# RAWDOG DAMAGE - NO I-FRAMES!
	# Calculate damage modifiers based on tags
	var damage_modifier = 1.0
	if source and source.has_method("get_tags"):
		var source_tags = source.get_tags()
		damage_modifier = TagSystem.calculate_tag_modifier(
			damage_tags if damage_tags.size() > 0 else source_tags,
			get_tags(),
			_get_damage_modifiers()
		)
	
	# Apply final damage
	var final_damage = amount * damage_modifier
	current_health -= final_damage
	current_health = max(0, current_health)
	
	# Track damage source for death reporting
	if source:
		set_meta("last_damage_source", source)
	
	# Emit signals
	damaged.emit(final_damage, source)
	health_changed.emit(current_health, max_health)
	
	# Check death
	if current_health <= 0:
		die()
	
	# Visual feedback - enhanced red flash and blood
	_on_damaged(final_damage, source)
	
	# Spawn RED damage number
	_spawn_damage_number(final_damage, false, true)  # Third param = is_player_damage
	
	# Update health bar display
	_update_health_bar_display()

func heal(amount: float):
	# Call parent heal
	super.heal(amount)
	
	# Update health bar display
	_update_health_bar_display()

## DEV TOOL - Audio tester reference (can be removed)
var audio_tester: AudioSFXTester = null
var use_dev_audio_tester: bool = false  # Set to true to enable testing

## HIT SOUND TESTING SYSTEM (DEPRECATED - Use AudioSFXTester instead)
var hit_sound_test_mode: bool = false  # DEPRECATED
var current_hit_sound_index: int = 0
var sound_test_label: Label = null
var sound_desc_label: Label = null
var hit_sounds: Array[String] = [
	# Original 20
	"res://audio/hit_sounds/sfx_very__20250815_051747.mp3",  # 1
	"res://audio/hit_sounds/sfx_low-k_20250815_051757.mp3",  # 2
	"res://audio/hit_sounds/sfx_quiet_20250815_051801.mp3",  # 3
	"res://audio/hit_sounds/sfx_subtl_20250815_051806.mp3",  # 4
	"res://audio/hit_sounds/sfx_minim_20250815_051810.mp3",  # 5
	"res://audio/hit_sounds/sfx_soft__20250815_051820.mp3",  # 6
	"res://audio/hit_sounds/sfx_under_20250815_051823.mp3",  # 7
	"res://audio/hit_sounds/sfx_low_v_20250815_051828.mp3",  # 8
	"res://audio/hit_sounds/sfx_mello_20250815_051832.mp3",  # 9
	"res://audio/hit_sounds/sfx_subdu_20250815_051836.mp3",  # 10
	"res://audio/hit_sounds/sfx_gentl_20250815_051846.mp3",  # 11
	"res://audio/hit_sounds/sfx_hushe_20250815_051849.mp3",  # 12
	"res://audio/hit_sounds/sfx_restr_20250815_051853.mp3",  # 13
	"res://audio/hit_sounds/sfx_quiet_20250815_051857.mp3",  # 14
	"res://audio/hit_sounds/sfx_low-f_20250815_051900.mp3",  # 15
	"res://audio/hit_sounds/sfx_delic_20250815_051911.mp3",  # 16
	"res://audio/hit_sounds/sfx_minim_20250815_051915.mp3",  # 17
	"res://audio/hit_sounds/sfx_faint_20250815_051918.mp3",  # 18
	"res://audio/hit_sounds/sfx_subtl_20250815_051922.mp3",  # 19
	"res://audio/hit_sounds/sfx_whisp_20250815_051926.mp3",  # 20
	# New 40
	"res://audio/hit_sounds/sfx_ultra_20250815_052827.mp3",  # 21
	"res://audio/hit_sounds/sfx_quick_20250815_052831.mp3",  # 22
	"res://audio/hit_sounds/sfx_brief_20250815_052835.mp3",  # 23
	"res://audio/hit_sounds/sfx_tiny__20250815_052838.mp3",  # 24
	"res://audio/hit_sounds/sfx_fast__20250815_052841.mp3",  # 25
	"res://audio/hit_sounds/sfx_short_20250815_052852.mp3",  # 26
	"res://audio/hit_sounds/sfx_minim_20250815_052855.mp3",  # 27
	"res://audio/hit_sounds/sfx_quick_20250815_052859.mp3",  # 28
	"res://audio/hit_sounds/sfx_tiny__20250815_052902.mp3",  # 29
	"res://audio/hit_sounds/sfx_micro_20250815_052905.mp3",  # 30
	"res://audio/hit_sounds/sfx_crisp_20250815_052917.mp3",  # 31
	"res://audio/hit_sounds/sfx_snapp_20250815_052920.mp3",  # 32
	"res://audio/hit_sounds/sfx_quick_20250815_052923.mp3",  # 33
	"res://audio/hit_sounds/sfx_brigh_20250815_052927.mp3",  # 34
	"res://audio/hit_sounds/sfx_tight_20250815_052931.mp3",  # 35
	"res://audio/hit_sounds/sfx_dry_d_20250815_052943.mp3",  # 36
	"res://audio/hit_sounds/sfx_hollo_20250815_053139.mp3",  # 37
	"res://audio/hit_sounds/sfx_soft__20250815_053143.mp3",  # 38
	"res://audio/hit_sounds/sfx_clipp_20250815_053150.mp3",  # 39
	"res://audio/hit_sounds/sfx_warm__20250815_053155.mp3",  # 40
	"res://audio/hit_sounds/sfx_metal_20250815_053202.mp3",  # 41
	"res://audio/hit_sounds/sfx_plast_20250815_053214.mp3",  # 42
	"res://audio/hit_sounds/sfx_round_20250815_053220.mp3",  # 43
	"res://audio/hit_sounds/sfx_glitc_20250815_053228.mp3",  # 44
	"res://audio/hit_sounds/sfx_thin__20250815_053234.mp3",  # 45
	"res://audio/hit_sounds/sfx_muffl_20250815_053239.mp3",  # 46
	"res://audio/hit_sounds/sfx_raw_d_20250815_053256.mp3",  # 47
	"res://audio/hit_sounds/sfx_zappy_20250815_053302.mp3",  # 48
	"res://audio/hit_sounds/sfx_bounc_20250815_053306.mp3",  # 49
	"res://audio/hit_sounds/sfx_gritt_20250815_053311.mp3",  # 50
	"res://audio/hit_sounds/sfx_silky_20250815_053317.mp3",  # 51
	"res://audio/hit_sounds/sfx_woody_20250815_053335.mp3",  # 52
	"res://audio/hit_sounds/sfx_bubbl_20250815_053342.mp3",  # 53
	"res://audio/hit_sounds/sfx_crunc_20250815_053349.mp3",  # 54
	"res://audio/hit_sounds/sfx_foggy_20250815_053353.mp3",  # 55
	"res://audio/hit_sounds/sfx_spark_20250815_053359.mp3",  # 56
	# Chiptune sounds
	"res://audio/hit_sounds/sfx_pure__20250815_053414.mp3",  # 57
	"res://audio/hit_sounds/sfx_chipt_20250815_053419.mp3",  # 58
	"res://audio/hit_sounds/sfx_chipt_20250815_053424.mp3",  # 59
	"res://audio/hit_sounds/sfx_chipt_20250815_053432.mp3",  # 60
	"res://audio/hit_sounds/sfx_chipt_20250815_053438.mp3",  # 61
	"res://audio/hit_sounds/sfx_chipt_20250815_053453.mp3",  # 62
	"res://audio/hit_sounds/sfx_chipt_20250815_053457.mp3",  # 63
	"res://audio/hit_sounds/sfx_chipt_20250815_053505.mp3",  # 64
	"res://audio/hit_sounds/sfx_chipt_20250815_053513.mp3",  # 65
	"res://audio/hit_sounds/sfx_chipt_20250815_053517.mp3",  # 66
]
var hit_sound_descriptions: Array[String] = [
	# Original 20
	"8-bit soft beep",  # 1
	"16-bit muffled thud",  # 2
	"NES tiny chirp",  # 3
	"Game Boy square boop",  # 4
	"Atari 2600 blip",  # 5
	"SNES digital thump",  # 6
	"Genesis metallic ping",  # 7
	"Arcade retro tap",  # 8
	"Chiptune sawtooth buzz",  # 9
	"Pixel art quiet pop",  # 10
	"Platformer faint click",  # 11
	"8-bit RPG sine dip",  # 12
	"Vintage triangle bump",  # 13
	"Old school thwack",  # 14
	"Lo-fi pulse wave",  # 15
	"NES bit crush",  # 16
	"Game Gear chip beep",  # 17
	"Shoot-em-up zap",  # 18
	"C64 digital knock",  # 19
	"Pixel game pluck",  # 20
	# New 40
	"Ultra short tick",  # 21
	"Quick synth blip",  # 22
	"Brief digital click",  # 23
	"Tiny arcade beep",  # 24
	"Fast electronic chirp",  # 25
	"Short square wave",  # 26
	"Minimal sine dip",  # 27
	"Quick pulse tick",  # 28
	"Tiny sawtooth blip",  # 29
	"Micro triangle bump",  # 30
	"Crisp 8-bit pop",  # 31
	"Snappy chip beep",  # 32
	"Quick synth stab",  # 33
	"Bright retro beep",  # 34
	"Tight electronic pluck",  # 35
	"Dry digital tap",  # 36
	"Hollow digital knock",  # 37
	"Soft bit-crushed beep",  # 38
	"Clipped synth tick",  # 39
	"Warm retro boop",  # 40
	"Metallic chip ping",  # 41
	"Plastic digital tap",  # 42
	"Rounded square beep",  # 43
	"Glitchy micro blip",  # 44
	"Thin electronic ping",  # 45
	"Muffled chip thud",  # 46
	"Raw digital click",  # 47
	"Zappy retro hit",  # 48
	"Bouncy chip boop",  # 49
	"Gritty 8-bit thwack",  # 50
	"Silky electronic pip",  # 51
	"Woody digital knock",  # 52
	"Bubbly retro pop",  # 53
	"Crunchy 8-bit snap",  # 54
	"Foggy chip beep",  # 55
	"Sparky digital zap",  # 56
	# Chiptune specific
	"Pure chiptune beep",  # 57
	"Chiptune pulse hit",  # 58
	"Chiptune triangle thud",  # 59
	"Chiptune sawtooth snap",  # 60
	"Chiptune noise burst",  # 61
	"Chiptune arp hit",  # 62
	"Chiptune FM boop",  # 63
	"Chiptune duty cycle",  # 64
	"Chiptune vibrato ping",  # 65
	"Chiptune pitch bend",  # 66
]

## Override death behavior
func __play_hit_sfx():
	if not AudioManager.instance:
		return
	
	# Skip if modular tester is handling sounds
	if audio_tester and audio_tester.enabled:
		return
	
	# DEPRECATED TESTING MODE - cycle through sounds
	if hit_sound_test_mode:
		var stream: AudioStream = load(hit_sounds[current_hit_sound_index]) as AudioStream
		if stream:
			AudioManager.instance.play_sfx_on_node(stream, self, -5.0, randf_range(0.95, 1.05))
			_update_sound_test_label()
	else:
		# PRODUCTION MODE - use selected sound #33
		var stream: AudioStream = load("res://audio/hit_sounds/sfx_quick_20250815_052923.mp3") as AudioStream
		if stream:
			AudioManager.instance.play_sfx_on_node(stream, self, -5.0, randf_range(0.95, 1.05))

func __subtle_damage_feedback():
	# This is now handled in _on_damaged
	pass

## Override damage visual feedback with better effects
func _on_damaged(_amount: float, _source: Node):
	# Enter combat
	enter_combat()
	
	# Trigger player light damage flash
	var player_light = get_node_or_null("PlayerLight")
	if player_light and player_light.has_method("trigger_damage_flash"):
		player_light.trigger_damage_flash()
	
	# Non-queuing red hue shift
	if sprite:
		# Store and kill any existing flash tween
		if has_meta("flash_tween"):
			var old_tween = get_meta("flash_tween")
			if old_tween and old_tween.is_valid():
				old_tween.kill()
		
		# MORE PROMINENT red flash - slower taper
		sprite.modulate = Color(2.0, 0.3, 0.3)  # Even more red!
		var flash_tween = create_tween()
		flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)  # Slower taper off
		
		# Store the tween reference
		set_meta("flash_tween", flash_tween)
	
	# Spawn blood particles
	_spawn_blood_effect()
	
	# Micro camera shake
	var cam = get_viewport().get_camera_2d()
	if cam:
		_apply_camera_shake(cam, 0.1, 4.0)

## Spawn blood particle effect
func _spawn_blood_effect():
	var blood = CPUParticles2D.new()
	blood.amount = 8
	blood.lifetime = 0.4
	blood.emitting = true
	blood.one_shot = true
	blood.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	blood.emission_sphere_radius = 10.0
	blood.spread = 45.0
	blood.initial_velocity_min = 50.0
	blood.initial_velocity_max = 150.0
	blood.angular_velocity_min = -180.0
	blood.angular_velocity_max = 180.0
	blood.gravity = Vector2(0, 500)  # Fall down
	blood.scale_amount_min = 1.5
	blood.scale_amount_max = 3.0
	blood.color = Color(0.6, 0, 0, 0.8)  # Dark red
	add_child(blood)
	
	# Auto cleanup
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(blood):
		blood.queue_free()

## Override spawn damage number to support red player damage
func _spawn_damage_number(damage: float, is_crit: bool = false, is_player_damage: bool = false):
	var damage_num = preload("res://ui/damage_number.gd").new()
	damage_num.setup(damage, is_crit, is_player_damage)
	
	# Add to parent (usually the game world)
	if get_parent():
		get_parent().add_child(damage_num)
		damage_num.global_position = global_position + Vector2(0, -20)

func _on_death():
	# Player-specific death logic
	print("Player died!")
	# The killer information is now handled in base_entity's die() method
	# which passes it through the died signal to game_controller
	
	# Don't queue_free immediately - might want to show death screen

## Get the primary weapon for modifications
func get_primary_weapon() -> Node:
	return get_node_or_null("ArcingSwordWeapon")

## Make the player face the mouse cursor
func _face_mouse():
	# Flip only the animated sprite, not the whole container (keeps sword transform stable)
	var animated_sprite: AnimatedSprite2D = get_node_or_null("SpriteContainer/Sprite")
	var sprite_container = get_node_or_null("SpriteContainer")
	if not sprite_container:
		return
	
	var mouse_pos = get_global_mouse_position()
	var mouse_is_left = mouse_pos.x < global_position.x
	
	if animated_sprite:
		animated_sprite.flip_h = mouse_is_left
	
	# Ensure container isn't flipped so child transforms (sword/hitbox) are consistent
	sprite_container.scale.x = 1
	sprite_container.rotation = 0

## Create WoW-style level up visual effects
func _create_level_up_effects():
	# Golden glow on player
	if sprite:
		var glow_tween = create_tween()
		glow_tween.tween_property(sprite, "modulate", Color(2, 1.8, 0.5), 0.2)
		glow_tween.tween_property(sprite, "modulate", Color.WHITE, 0.8)
	
	# Create rising particles
	var particles = CPUParticles2D.new()
	particles.amount = 50  # Reduced for performance
	particles.lifetime = 1.5  # Shorter lifetime
	particles.emitting = true
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 30.0
	particles.spread = 15.0
	particles.initial_velocity_min = 50.0
	particles.initial_velocity_max = 150.0
	particles.direction = Vector2(0, -1)  # Upward
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = Color(1, 0.9, 0.3, 0.8)  # Golden
	particles.one_shot = true  # Auto cleanup
	add_child(particles)
	
	# Create expanding ring effect
	var ring_label = Label.new()
	ring_label.text = "LEVEL UP!"
	ring_label.add_theme_font_size_override("font_size", 32)
	ring_label.modulate = Color(1, 0.9, 0.2)
	ring_label.position = Vector2(0, -50)
	ring_label.z_index = 100
	add_child(ring_label)
	
	# Animate the text
	var text_tween = create_tween()
	text_tween.set_parallel(true)
	
	# Kill tween when label is freed
	ring_label.tree_exiting.connect(func(): 
		if text_tween and text_tween.is_valid():
			text_tween.kill()
	)
	
	text_tween.tween_property(ring_label, "position:y", -100, 1.0)
	text_tween.tween_property(ring_label, "modulate:a", 0.0, 1.0)
	text_tween.tween_property(ring_label, "scale", Vector2(1.5, 1.5), 0.5)
	text_tween.set_parallel(false)
	text_tween.tween_callback(ring_label.queue_free)
	
	# Clean up particles after they finish
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(particles):
		particles.queue_free()

## Get current attack speed multiplier (for weapon system)
func get_attack_speed_multiplier() -> float:
	return 1.0  # Base attack speed, can be modified by buffs/items

## Ability system stat methods
func get_spell_power() -> float:
	return 1.0  # Base spell power

func get_physical_power() -> float:
	return 1.0  # Base physical power

func get_cooldown_reduction() -> float:
	return 0.0  # No CDR by default

func get_area_of_effect() -> float:
	return area_of_effect

func _unhandled_input(_event: InputEvent):
	# Dash is now handled by AbilityManager keybinds
	# Legacy dash code removed - ability system handles input
	
	# DEPRECATED SOUND TEST - Only use if modular tester isn't active
	if not audio_tester and hit_sound_test_mode and _event is InputEventKey and _event.pressed:
		if _event.keycode == KEY_F12:
			current_hit_sound_index = (current_hit_sound_index + 1) % hit_sounds.size()
			_update_sound_test_label()
			# Play the new sound immediately
			__play_hit_sfx()

func _on_dash_cooldown_started(duration: float):
	# Update UI when dash goes on cooldown
	var dash_ui = get_meta("dash_ui", null)
	var cooldown_bar = get_meta("dash_cooldown_bar", null)
	if dash_ui and cooldown_bar:
		dash_ui.visible = true
		# Create tween to animate cooldown
		var tween = create_tween()
		tween.tween_property(cooldown_bar, "value", 1.0, duration).from(0.0)

func _on_dash_cooldown_ended():
	# Hide UI when dash is ready
	var dash_ui = get_meta("dash_ui", null)
	if dash_ui:
		dash_ui.visible = false

# Legacy dash callbacks - replaced by ability system
# func _on_dash_started():
# func _on_dash_ended():

func set_invulnerable(value: bool):
	invulnerable = value

func _apply_camera_shake(camera: Camera2D, duration: float, strength: float):
	# Simple camera shake effect
	var original_offset = camera.offset
	
	# Create an object to hold the shake state
	var shake_data = { "elapsed": 0.0 }
	
	# Create a timer for the shake duration
	var timer = Timer.new()
	timer.wait_time = 0.016  # 60 FPS
	timer.one_shot = false  # Repeating timer
	
	timer.timeout.connect(func():
		shake_data.elapsed += timer.wait_time
		if shake_data.elapsed >= duration:
			camera.offset = original_offset
			timer.stop()
			timer.queue_free()
		else:
			# Random shake with decay
			var shake_percent = 1.0 - (shake_data.elapsed / duration)
			camera.offset = original_offset + Vector2(
				randf_range(-strength, strength) * shake_percent,
				randf_range(-strength, strength) * shake_percent
			)
	)
	
	add_child(timer)
	timer.start()

## SOUND TEST FUNCTIONS - REMOVE AFTER TESTING
func _setup_modular_audio_tester():
	"""Set up the modular audio tester - can be completely removed"""
	audio_tester = AudioSFXTester.new()
	audio_tester.name = "HitSoundTester"
	add_child(audio_tester)
	
	# Configure with our hit sounds
	audio_tester.setup_sounds(hit_sounds, hit_sound_descriptions)
	
	# Set up callback to play hit effect when testing
	audio_tester.on_sound_played = func(_index: int, _path: String):
		# Visual feedback when testing
		_on_damaged(0, null)  # Trigger visual effects without damage

func _setup_sound_test_ui():
	# Create canvas layer for UI
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "SoundTestUI"
	add_child(canvas_layer)
	
	# Create label for showing current sound
	sound_test_label = Label.new()
	sound_test_label.name = "SoundTestLabel"
	sound_test_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	sound_test_label.position = Vector2(-100, 100)  # Center top of screen
	sound_test_label.add_theme_font_size_override("font_size", 32)
	sound_test_label.add_theme_color_override("font_color", Color(1, 1, 0))  # Yellow
	sound_test_label.add_theme_color_override("font_outline_color", Color.BLACK)
	sound_test_label.add_theme_constant_override("outline_size", 3)
	sound_test_label.text = "Hit Sound: 1/66"
	canvas_layer.add_child(sound_test_label)
	
	# Description label
	sound_desc_label = Label.new()
	sound_desc_label.name = "SoundDescLabel"
	sound_desc_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	sound_desc_label.position = Vector2(-150, 140)
	sound_desc_label.add_theme_font_size_override("font_size", 24)
	sound_desc_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.3))
	sound_desc_label.add_theme_color_override("font_outline_color", Color.BLACK)
	sound_desc_label.add_theme_constant_override("outline_size", 2)
	sound_desc_label.text = hit_sound_descriptions[0]
	canvas_layer.add_child(sound_desc_label)
	
	# Instructions label
	var instructions = Label.new()
	instructions.set_anchors_preset(Control.PRESET_CENTER_TOP)
	instructions.position = Vector2(-150, 180)
	instructions.add_theme_font_size_override("font_size", 20)
	instructions.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	instructions.add_theme_color_override("font_outline_color", Color.BLACK)
	instructions.add_theme_constant_override("outline_size", 2)
	instructions.text = "Press F12 to cycle sounds"
	canvas_layer.add_child(instructions)

func _update_sound_test_label():
	if sound_test_label:
		sound_test_label.text = "Hit Sound: %d/66" % (current_hit_sound_index + 1)
	if sound_desc_label:
		sound_desc_label.text = hit_sound_descriptions[current_hit_sound_index]

# Methods for PlayerLight integration
func get_health_percentage() -> float:
	if max_health > 0:
		return current_health / max_health
	return 1.0

func is_in_combat() -> bool:
	return in_combat

func is_sprinting() -> bool:
	return is_sprinting_flag

func enter_combat():
	in_combat = true
	combat_timer = COMBAT_TIMEOUT
	
	# Notify player light if it exists
	var player_light = get_node_or_null("PlayerLight")
	if player_light and player_light.has_method("set_combat_mode"):
		player_light.set_combat_mode(true)

func exit_combat():
	in_combat = false
	
	# Notify player light if it exists
	var player_light = get_node_or_null("PlayerLight")
	if player_light and player_light.has_method("set_combat_mode"):
		player_light.set_combat_mode(false)
