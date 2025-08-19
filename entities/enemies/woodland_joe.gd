extends BaseCreature
class_name WoodlandJoe

## Woodland Joe - A slow but powerful juggernaut
## Following the NPC Implementation Guide pattern

# No exports needed - all configuration in code

func _entity_ready():
	super._entity_ready()
	_setup_npc()

func _setup_npc():
	# REQUIRED: Core properties
	creature_type = "WoodlandJoe"
	base_scale = 1.0
	abilities = []  # No special abilities
	
	# REQUIRED: Stats
	max_health = 200
	current_health = max_health
	move_speed = 50  # Very slow - true juggernaut speed
	damage = 30
	attack_range = 60
	attack_cooldown = 1.0
	attack_type = AttackType.MELEE
	preferred_attack_distance = -1  # Uses attack_range * 0.8
	
	# No mana system
	has_mana = false
	
	# REQUIRED: Tags
	if taggable:
		taggable.add_tag("Enemy")
		taggable.add_tag("TwitchMob")
		taggable.add_tag("WoodlandJoe")
		taggable.add_tag("Melee")
		taggable.add_tag("Boss")  # Mini-boss tier
	
	# REQUIRED: Groups
	add_to_group("enemies")
	add_to_group("ai_controlled")
	
	# Set sprite
	if sprite:
		sprite.texture = preload("res://BespokeAssetSources/woodenJoe.png")
	
	# AI always targets player now - no configuration needed
	
	# Woodland Joe spawned

# Override sprite direction handling to use proper MXP-compatible method
func _face_movement_direction():
	if not sprite:
		return
	
	if velocity.x != 0:
		# IMPORTANT: Calculate actual scale including MXP buffs
		var actual_scale = base_scale * scale_multiplier
		# Sprite faces RIGHT by default
		if velocity.x > 0:
			sprite.scale.x = actual_scale
		else:
			sprite.scale.x = -actual_scale

# Custom death with extra rewards
func die():
	
	# Drop extra XP orbs as reward (deferred to avoid physics errors)
	for i in range(5):
		var xp_orb = preload("res://entities/pickups/xp_orb.tscn").instantiate()
		get_parent().call_deferred("add_child", xp_orb)
		xp_orb.set_deferred("global_position", global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30)))
	
	# Announce death in action feed
	if GameController.instance and GameController.instance.has_method("get_action_feed"):
		var feed = GameController.instance.get_action_feed()
		feed.add_message("🌲 WOODLAND JOE HAS BEEN DEFEATED!", Color(0.4, 0.8, 0.2))
	
	super.die()

# Death attribution
func get_killer_display_name() -> String:
	return chatter_username if chatter_username != "" else str(name)

func get_attack_name() -> String:
	return "Woodland Smash"
