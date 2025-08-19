extends Node2D
class_name BasePrimaryWeapon

## Base class for all primary player weapons
## Follows OOP principles for modularity and extensibility

signal attack_performed()
signal enemy_hit(enemy: Node, damage: float)

# Core weapon stats
@export_group("Weapon Stats")
@export var base_damage: float = 10.0
@export var base_attack_speed: float = 1.0  # Attacks per second
@export var knockback_force: float = 100.0
@export var weapon_tags: Array[String] = ["Melee", "Primary"]

@export_group("Critical Hit Stats")
@export var base_crit_chance: float = 0.05  # 5% default crit chance
@export var base_crit_multiplier: float = 2.0  # 2x damage on crit

# Owner reference
var owner_entity: Node  # The player or entity wielding this weapon
var attack_speed_multiplier: float = 1.0  # Modified by buffs/items

# Cached player bonus references (updated each attack)
var cached_player_bonuses: Dictionary = {}

# Attack timing
var attack_cooldown_timer: float = 0.0
var is_attacking: bool = false

# Statistical tracking
var total_damage_dealt: float = 0.0
var enemies_hit_count: int = 0
var total_crits: int = 0  # Track critical hits

func _ready():
	print("🔧 BasePrimaryWeapon._ready() called!")
	set_process(true)
	add_to_group("player_weapons")
	add_to_group("primary_weapons")
	
	# Defer owner finding to first frame
	# This ensures the player has time to initialize and add itself to groups
	call_deferred("_find_owner")

## Virtual method for subclasses to override
func _on_weapon_ready():
	pass

func _find_owner():
	# First check if direct parent is the player
	var parent = get_parent()
	
	# Check for player-specific methods or class
	if parent and (parent.has_method("get_primary_weapon") or parent.has_method("gain_experience") or parent.name == "Player"):
		# This is the player
		owner_entity = parent
		print("✅ BasePrimaryWeapon: Found player as direct parent: ", owner_entity.name)
		_on_weapon_ready()
		return
	
	# If not direct parent, wait a frame for groups to be set up
	await get_tree().process_frame
	
	# Now try searching by group
	owner_entity = parent
	var max_depth = 5  # Prevent infinite loop
	var depth = 0
	while owner_entity and not owner_entity.is_in_group("player") and depth < max_depth:
		owner_entity = owner_entity.get_parent()
		depth += 1
	
	if not owner_entity or not owner_entity.is_in_group("player"):
		print("⚠️ BasePrimaryWeapon: No player owner found in hierarchy, searching scene...")
		# Try to find player in the scene tree as fallback
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			owner_entity = players[0]
			print("✅ BasePrimaryWeapon: Found player via group search: ", owner_entity.name)
		else:
			push_error("BasePrimaryWeapon: No player found anywhere!")
	else:
		print("✅ BasePrimaryWeapon: Owner found: ", owner_entity.name)
	
	# Now call the weapon ready
	_on_weapon_ready()

var _process_started = false
var _error_shown = false

func _process(_delta):
	if not _process_started:
		_process_started = true
		print("🔄 BasePrimaryWeapon _process started! Owner: ", owner_entity)
		if owner_entity:
			print("   Owner name: ", owner_entity.name)
			print("   Owner groups: ", owner_entity.get_groups())
			print("   Is instance valid: ", is_instance_valid(owner_entity))
		
	# Update attack cooldown
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= _delta
		
	# Check if we can attack
	if can_attack() and should_attack():
		perform_attack()
	else:
		# Debug why we can't attack
		if attack_cooldown_timer > 0:
			pass  # On cooldown, this is normal
		elif not is_alive() and not _error_shown:
			print("⚠️ Can't attack - owner not alive")
			print("   Owner entity: ", owner_entity)
			print("   Is valid: ", is_instance_valid(owner_entity) if owner_entity else false)
			_error_shown = true
		elif is_attacking and not _error_shown:
			print("⚠️ Can't attack - already attacking")
			_error_shown = true
		elif not should_attack() and not _error_shown:
			print("⚠️ Can't attack - should_attack() returned false")
			_error_shown = true
	
	# Virtual update for subclasses
	_weapon_process(_delta)

## Virtual method for subclasses to override
func _weapon_process(_delta: float):
	pass

## Check if weapon can currently attack
func can_attack() -> bool:
	return attack_cooldown_timer <= 0 and is_alive() and not is_attacking

## Check if weapon should attack (can be overridden)
func should_attack() -> bool:
	# By default, always attack when possible
	# Subclasses can override for different behavior
	return true

## Check if owner is alive
func is_alive() -> bool:
	# Simplified check - if we have an owner, assume they're alive
	# The owner will be freed when they die anyway
	return owner_entity != null and is_instance_valid(owner_entity)

## Perform the weapon attack
func perform_attack():
	is_attacking = true
	
	# Set cooldown based on attack speed
	var effective_attack_speed = base_attack_speed * attack_speed_multiplier
	attack_cooldown_timer = 1.0 / effective_attack_speed
	
	# Performing attack
	
	# Call virtual attack method
	_execute_attack()
	
	# Emit signal
	attack_performed.emit()

## Virtual method that subclasses must implement
func _execute_attack():
	push_error("BasePrimaryWeapon._execute_attack() must be overridden!")
	is_attacking = false

## Update cached player bonuses
func _update_player_bonuses():
	if not owner_entity:
		cached_player_bonuses = {}
		return
	
	# Direct property access - we know owner is Player
	cached_player_bonuses = {
		"crit_chance": owner_entity.bonus_crit_chance,
		"crit_multiplier": owner_entity.bonus_crit_multiplier,
		"attack_speed": owner_entity.bonus_attack_speed,
		"aoe": owner_entity.area_of_effect,
		"damage": owner_entity.bonus_damage,
		"damage_mult": owner_entity.bonus_damage_multiplier
	}

## Calculate final damage with crit chance
func calculate_final_damage(base_dmg: float, damage_multiplier: float = 1.0) -> Dictionary:
	_update_player_bonuses()
	
	# Apply damage bonuses if weapon has Damage tag
	var modified_damage = base_dmg
	if "Damage" in weapon_tags:
		modified_damage += cached_player_bonuses.get("damage", 0.0)
		modified_damage *= cached_player_bonuses.get("damage_mult", 1.0)
	modified_damage *= damage_multiplier
	
	# Calculate crit if weapon has Crit tag
	var is_crit = false
	if "Crit" in weapon_tags:
		var total_crit_chance = base_crit_chance + cached_player_bonuses.get("crit_chance", 0.0)
		total_crit_chance = clamp(total_crit_chance, 0.0, 1.0)
		is_crit = randf() < total_crit_chance
		
		if is_crit:
			var total_crit_mult = base_crit_multiplier + cached_player_bonuses.get("crit_multiplier", 0.0)
			modified_damage *= total_crit_mult
			total_crits += 1
	
	return {
		"damage": modified_damage,
		"is_crit": is_crit
	}

## Apply damage to an enemy
func deal_damage_to_enemy(enemy: Node, damage_multiplier: float = 1.0):
	if not enemy or not enemy.has_method("take_damage"):
		return
	
	# Calculate damage with crit system
	var damage_result = calculate_final_damage(base_damage, damage_multiplier)
	var final_damage = damage_result.damage
	var is_crit = damage_result.is_crit
	
	# Prepare tags for damage application
	var damage_tags = weapon_tags.duplicate()
	if is_crit:
		damage_tags.append("crit")
	
	# Deal damage with proper tags
	enemy.take_damage(final_damage, owner_entity, damage_tags)
	
	# Track statistics
	total_damage_dealt += final_damage
	enemies_hit_count += 1
	
	# Apply knockback immediately
	if enemy.has_method("apply_knockback") and knockback_force > 0:
		var knockback_direction = (enemy.global_position - global_position).normalized()
		enemy.apply_knockback(knockback_direction, knockback_force)
	
	# Play impact sound
	if ImpactSoundSystem.instance:
		ImpactSoundSystem.instance.play_impact(self, enemy, enemy.global_position, weapon_tags)
	
	# Emit signal
	enemy_hit.emit(enemy, final_damage)

## Set the attack speed multiplier (for buffs/items)
func set_attack_speed_multiplier(multiplier: float):
	attack_speed_multiplier = max(0.1, multiplier)  # Minimum 10% speed

## Get the current effective attack speed
func get_effective_attack_speed() -> float:
	_update_player_bonuses()
	var speed = base_attack_speed * attack_speed_multiplier
	if "AttackSpeed" in weapon_tags:
		speed *= (1.0 + cached_player_bonuses.get("attack_speed", 0.0))
	return speed

## Get effective AOE scale
func get_aoe_scale() -> float:
	if "AoE" in weapon_tags:
		_update_player_bonuses()
		return cached_player_bonuses.get("aoe", 1.0)
	return 1.0

## Get weapon type for various systems
func get_weapon_type() -> String:
	return "base_weapon"  # Override in subclasses

## Get current weapon tags
func get_weapon_tags() -> Array:
	return weapon_tags

## Get total crit chance for UI display
func get_total_crit_chance() -> float:
	if "Crit" in weapon_tags:
		_update_player_bonuses()
		return clamp(base_crit_chance + cached_player_bonuses.get("crit_chance", 0.0), 0.0, 1.0)
	return 0.0

## Get total crit multiplier for UI display
func get_total_crit_multiplier() -> float:
	if "Crit" in weapon_tags:
		_update_player_bonuses()
		return base_crit_multiplier + cached_player_bonuses.get("crit_multiplier", 0.0)
	return 0.0

## Add a tag to the weapon
func add_weapon_tag(tag: String):
	if not tag in weapon_tags:
		weapon_tags.append(tag)

## Remove a tag from the weapon
func remove_weapon_tag(tag: String):
	weapon_tags.erase(tag)
