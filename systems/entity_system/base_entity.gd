extends CharacterBody2D
class_name BaseEntity

## Base class for all game entities (Player, Enemies, etc.)
## Provides common functionality like health, movement, tags, and damage handling

signal health_changed(new_health: float, max_health: float)
signal died(killer_name: String, death_cause: String)
signal damaged(amount: float, source: Node)
signal status_effect_applied(effect_name: String)
signal status_effect_removed(effect_name: String)

# Core stats
@export_group("Base Stats")
@export var max_health: float = 100.0
@export var move_speed: float = 300.0
@export var knockback_resistance: float = 0.0  # 0-1, where 1 is immune to knockback
@export var invincibility_time: float = 0.5  # I-frames duration after being hit

# Current state
var current_health: float
var is_alive: bool = true
var is_invincible: bool = false
var invincibility_timer: float = 0.0

# Damage accumulator for fractional damage
var accumulated_damage: float = 0.0
var active_buffs: Array = []
var status_effects: Dictionary = {}  # effect_name: timer

# Components
var taggable: Taggable
var sprite: Node2D  # Can be Sprite2D or AnimatedSprite2D
var ability_holder = null  # AbilityHolderComponent
var ability_manager = null  # AbilityManager

# Movement state
var movement_velocity: Vector2 = Vector2.ZERO
var knockback_velocity: Vector2 = Vector2.ZERO
var movement_modifier: float = 1.0  # For slows/speed boosts

func _ready():
	# Ensure entity pauses properly
	process_mode = Node.PROCESS_MODE_PAUSABLE
	
	# Initialize health
	current_health = max_health
	
	# Set up taggable component
	taggable = Taggable.new()
	taggable.name = "Taggable"
	add_child(taggable)
	
	# Set up ability system components
	ability_holder = AbilityHolderComponent.new()
	ability_holder.name = "AbilityHolder"
	add_child(ability_holder)
	
	ability_manager = AbilityManager.new()
	ability_manager.name = "AbilityManager"
	add_child(ability_manager)
	
	# Ensure ability manager has reference to ability holder
	await get_tree().process_frame  # Wait for children to be ready
	if ability_manager and ability_holder:
		ability_manager.ability_holder = ability_holder
	
	# Add to entities group
	add_to_group("entities")
	
	# Register with flocking system if AI controlled
	call_deferred("_register_with_flocking")
	
	# Set up sprite if exists
	sprite = get_node_or_null("Sprite")
	if not sprite:
		sprite = get_node_or_null("SpriteContainer/Sprite")
	if not sprite:
		sprite = get_node_or_null("AnimatedSprite2D")
	
	# Call virtual ready function for subclasses
	_entity_ready()

## Virtual function for subclasses to override
func _entity_ready():
	pass

func _register_with_flocking():
	# Only register AI-controlled entities
	if is_in_group("ai_controlled") and FlockingSystem.instance:
		FlockingSystem.instance.register_entity(self)

## Get the IAbilityHolder interface for this entity
func get_ability_holder():
	if ability_holder:
		return ability_holder.create_ability_holder()
	return null

## Ergonomic adapter for getting neighbors (OOP without perf loss)
func get_neighbors(cap: int = 8) -> Array:
	if FlockingSystem.instance:
		return FlockingSystem.instance.get_neighbors(self, cap)
	return []

func _physics_process(_delta):
	if not is_alive:
		return
	
	# Update invincibility timer
	if is_invincible and invincibility_timer > 0:
		invincibility_timer -= _delta
		if invincibility_timer <= 0:
			is_invincible = false
			_on_invincibility_ended()
	
	# Update status effects
	_update_status_effects(_delta)
	
	# Apply knockback
	if knockback_velocity.length() > 0:
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 500 * _delta)
	
	# Check if mob movement is disabled
	if is_in_group("enemies") and DebugSettings.instance and not DebugSettings.instance.mob_movement_enabled:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	# Get flocking force if this is an AI-controlled entity
	var flocking_force = Vector2.ZERO
	if is_in_group("ai_controlled") and FlockingSystem.instance:
		flocking_force = FlockingSystem.instance.get_flocking_force(self)
	
	# Calculate final velocity with flocking
	var final_velocity = (movement_velocity * movement_modifier) + knockback_velocity + flocking_force
	velocity = final_velocity
	
	# Handle collision based on debug settings
	_update_collision_settings()
	
	# Move the entity
	move_and_slide()
	
	# Call virtual physics process for subclasses
	_entity_physics_process(_delta)

## Virtual function for subclasses to override
func _entity_physics_process(_delta):
	pass

## Take damage from a source
func take_damage(amount: float, source: Node = null, damage_tags: Array = []):
	if not is_alive or is_invincible:
		return
	
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
	else:
		# Activate invincibility frames only if duration > 0
		if invincibility_time > 0:
			is_invincible = true
			invincibility_timer = invincibility_time
			_on_invincibility_started()
	
	# Visual feedback
	_on_damaged(final_damage, source)
	
	# Check if this was a critical hit (exact "crit" tag, not "Crit" capability)
	var is_crit = false
	for tag in damage_tags:
		if str(tag) == "crit":
			is_crit = true
			break
	
	# Spawn damage number
	_spawn_damage_number(final_damage, is_crit)

## Heal the entity
func heal(amount: float):
	if not is_alive:
		return
	
	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)

## Kill the entity
func die():
	if not is_alive:
		return
	
	is_alive = false
	
	# Unregister from flocking system
	if is_in_group("ai_controlled") and FlockingSystem.instance:
		FlockingSystem.instance.unregister_entity(self)
	
	# Get killer information before emitting signal
	var killer_info = _get_killer_info()
	died.emit(killer_info.killer_name, killer_info.death_cause)
	
	# Call virtual death function
	_on_death()
	
	# Default behavior - queue free after a delay
	await get_tree().create_timer(0.5).timeout
	queue_free()

## Get killer information from last damage source
func _get_killer_info() -> Dictionary:
	var killer_name = "Unknown"
	var death_cause = ""
	
	if has_meta("last_damage_source"):
		var source = get_meta("last_damage_source")
		if source and is_instance_valid(source):
			# Try to get killer name from various sources
			if source.has_method("get_killer_display_name"):
				killer_name = source.get_killer_display_name()
			elif source.has_method("get_chatter_username"):
				killer_name = source.get_chatter_username()
			elif source.has_method("get_display_name"):
				killer_name = source.get_display_name()
			elif source.has_meta("source_name"):
				killer_name = source.get_meta("source_name")
			else:
				killer_name = source.name
			
			# Try to get attack/death cause
			# Check metadata first for temporary ability overrides
			if source.has_meta("active_ability_name"):
				death_cause = source.get_meta("active_ability_name")
			elif source.has_method("get_attack_name"):
				death_cause = source.get_attack_name()
			elif source.has_meta("attack_name"):
				death_cause = source.get_meta("attack_name")
			elif source.name == "PoisonCloud":
				death_cause = "toxic fart cloud"
			elif source.name == "ExplosionEffect":
				death_cause = "explosion"
			elif source.name == "HeartProjectile":
				death_cause = "heart projectile"
			else:
				# Try to determine from source name or ability
				if source is Node:
					death_cause = _guess_death_cause_from_name(source.name)
				elif source is Resource and source.has("ability_name"):
					death_cause = source.ability_name.to_lower()
	
	return {
		"killer_name": killer_name,
		"death_cause": death_cause
	}

## Guess death cause from source name
func _guess_death_cause_from_name(source_name: String) -> String:
	var lower_name = source_name.to_lower()
	if "projectile" in lower_name:
		return "projectile"
	elif "explosion" in lower_name:
		return "explosion"
	elif "poison" in lower_name or "gas" in lower_name:
		return "poison"
	elif "fire" in lower_name:
		return "fire"
	elif "ice" in lower_name or "frost" in lower_name:
		return "frost"
	elif "lightning" in lower_name or "electric" in lower_name:
		return "lightning"
	elif "suction" in lower_name or "drain" in lower_name or "succ" in lower_name:
		return "life drain"
	return ""

## Apply knockback
func apply_knockback(direction: Vector2, force: float):
	var actual_force = force * (1.0 - knockback_resistance)
	knockback_velocity = direction.normalized() * actual_force

## Apply a status effect
func apply_status_effect(effect_name: String, duration: float):
	status_effects[effect_name] = duration
	status_effect_applied.emit(effect_name)
	
	# Apply effect modifiers
	match effect_name:
		"Slowed":
			movement_modifier = 0.5
		"Stunned":
			movement_modifier = 0.0
		"Hasted":
			movement_modifier = 1.5

## Remove a status effect
func remove_status_effect(effect_name: String):
	if effect_name in status_effects:
		status_effects.erase(effect_name)
		status_effect_removed.emit(effect_name)
		
		# Remove effect modifiers
		if effect_name in ["Slowed", "Stunned", "Hasted"]:
			movement_modifier = 1.0

## Update status effects
func _update_status_effects(_delta):
	var effects_to_remove = []
	
	for effect_name in status_effects:
		status_effects[effect_name] -= _delta
		if status_effects[effect_name] <= 0:
			effects_to_remove.append(effect_name)
	
	for effect in effects_to_remove:
		remove_status_effect(effect)

## Get entity tags (delegates to taggable component)
func get_tags() -> Array:
	if taggable:
		return taggable.get_tags()
	return []

## Add a tag
func add_tag(tag: String):
	if taggable:
		taggable.add_tag(tag)

## Remove a tag
func remove_tag(tag: String):
	if taggable:
		taggable.remove_tag(tag)

## Check if has tag
func has_tag(tag: String) -> bool:
	if taggable:
		return taggable.has_tag(tag)
	return false

## Virtual function - get damage modifiers for this entity type
func _get_damage_modifiers() -> Dictionary:
	return {}  # Override in subclasses

## Virtual function - called when damaged
func _on_damaged(_amount: float, _source: Node):
	# Flash red briefly
	if sprite:
		sprite.modulate = Color.RED
		await get_tree().create_timer(0.1).timeout
		if is_alive and sprite:
			sprite.modulate = Color.WHITE

## Virtual function - called on death
func _on_death():
	pass  # Override in subclasses

## Virtual function - called when invincibility starts
func _on_invincibility_started():
	# Make sprite flash
	if sprite:
		var tween = create_tween()
		tween.set_loops(int(invincibility_time / 0.1))
		tween.tween_property(sprite, "modulate:a", 0.3, 0.05)
		tween.tween_property(sprite, "modulate:a", 1.0, 0.05)

## Virtual function - called when invincibility ends
func _on_invincibility_ended():
	# Ensure sprite is fully visible
	if sprite:
		sprite.modulate.a = 1.0

## Get normalized health (0-1)
func get_health_percentage() -> float:
	return current_health / max_health if max_health > 0 else 0.0

## Update collision settings based on debug flags
func _update_collision_settings():
	if not DebugSettings.instance:
		return
	
	# Player collision
	if is_in_group("player"):
		if not DebugSettings.instance.player_collision_enabled:
			set_collision_layer_value(1, false)  # Disable player layer
			set_collision_mask_value(2, false)  # Don't collide with enemies
		else:
			set_collision_layer_value(1, true)
			set_collision_mask_value(2, true)
	
	# Enemy collision
	elif is_in_group("enemies"):
		if not DebugSettings.instance.mob_to_mob_collision_enabled:
			set_collision_mask_value(2, false)  # Don't collide with other enemies
		else:
			set_collision_mask_value(2, true)
		
		# Player collision for enemies
		if not DebugSettings.instance.player_collision_enabled:
			set_collision_mask_value(1, false)  # Don't collide with player
		else:
			set_collision_mask_value(1, true)

## Spawn a floating damage number
func _spawn_damage_number(damage: float, is_crit: bool = false):
	# Check if damage numbers are disabled
	if DebugSettings.instance and not DebugSettings.instance.damage_numbers_enabled:
		return
	
	var damage_num = preload("res://ui/damage_number.gd").new()
	damage_num.setup(damage, is_crit)
	
	# Add to parent (usually the game world)
	if get_parent():
		get_parent().add_child(damage_num)
		damage_num.global_position = global_position + Vector2(0, -20)

## Ability system integration methods
func add_ability(ability, slot: int = -1) -> bool:
	if ability_manager:
		return ability_manager.add_ability(ability, slot)
	return false

func remove_ability(ability_id: String) -> bool:
	if ability_manager:
		return ability_manager.remove_ability_by_id(ability_id)
	return false

func execute_ability(ability_id: String, target_data = null) -> bool:
	# Check if abilities are disabled
	if DebugSettings.instance and not DebugSettings.instance.ability_system_enabled:
		return false
	
	if ability_manager:
		var result = ability_manager.execute_ability_by_id(ability_id, target_data)
		return result
	return false

func has_ability(ability_id: String) -> bool:
	if ability_manager:
		return ability_manager.has_ability(ability_id)
	return false

func get_ability(ability_id: String):
	if ability_manager:
		return ability_manager.get_ability_by_id(ability_id)
	return null

## Status checks for ability system
func is_stunned() -> bool:
	return "Stunned" in status_effects

func is_silenced() -> bool:
	return "Silenced" in status_effects

func can_move() -> bool:
	return is_alive and not is_stunned() and not ("Rooted" in status_effects)

func can_act() -> bool:
	return is_alive and not is_stunned()

func set_invulnerable(invulnerable: bool) -> void:
	is_invincible = invulnerable
	if invulnerable:
		modulate.a = 0.5  # Visual feedback
	else:
		modulate.a = 1.0

func is_invulnerable() -> bool:
	return is_invincible
