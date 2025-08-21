extends Node
class_name ChatterEntityManager

## Manages chatter-specific entity data and upgrades
## Tracks upgrades that persist through death within a session

signal entity_upgraded(username: String, upgrade_type: String, new_value)

static var instance: ChatterEntityManager

# Chatter data structure: username -> { upgrades: {}, entity_type: String }
var chatter_data: Dictionary = {}

# Default entity type for new chatters
const DEFAULT_ENTITY_TYPE = "twitch_rat"

func _ready():
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("🎮 Chatter Entity Manager initialized!")
	# Listen for MXP modifier applications so active entities update instantly
	if MXPModifierManager.instance:
		MXPModifierManager.instance.modifier_applied.connect(_on_modifier_applied)
	# Also listen to our own legacy signal
	entity_upgraded.connect(_on_entity_upgraded)

## Register a chatter (called when they first interact)
func register_chatter(username: String, entity_type: String = DEFAULT_ENTITY_TYPE):
	if not chatter_data.has(username):
		chatter_data[username] = {
			"entity_type": entity_type,
			"upgrades": {
				# Don't initialize legacy multipliers - let modifiers set them if needed
				"damage_multiplier": 1.0,
				"health_multiplier": 1.0,
				"aoe_multiplier": 1.0,  # Area of Effect multiplier
				# Add more upgrade types as needed
			},
			"total_upgrades": 0
		}
		print("📝 Registered new chatter: %s with entity type: %s" % [username, entity_type])

## Get chatter data (creates if doesn't exist)
func get_chatter_data(username: String) -> Dictionary:
	if not chatter_data.has(username):
		register_chatter(username)
	return chatter_data[username]

# Size and AoE upgrades are now handled by MXPModifierManager
# Legacy functions removed - use MXPModifierManager.process_command() instead

## Generic upgrade function
func _apply_upgrades(username: String, upgrade_type: String, amount: int, multiplier: float, emoji: String) -> int:
	if amount <= 0:
		return 0
	
	# Check available MXP
	var available_mxp = 0
	if MXPManager.instance:
		available_mxp = MXPManager.instance.get_available_mxp(username)
	
	# Calculate how many upgrades we can actually afford
	var cost_per_upgrade = get_upgrade_cost(upgrade_type)
	var max_affordable = available_mxp / float(cost_per_upgrade)
	var actual_amount = min(amount, max_affordable)
	
	if actual_amount <= 0:
		return 0
	
	# Spend the MXP
	var total_cost = actual_amount * cost_per_upgrade
	if not MXPManager.instance.spend_mxp(username, total_cost, upgrade_type):
		return 0
	
	# Apply the upgrades
	var _data = get_chatter_data(username)
	var field_name = upgrade_type + "_multiplier"
	
	# Apply compound multiplier for multiple upgrades
	for i in range(actual_amount):
		_data.upgrades[field_name] *= multiplier
	
	_data.total_upgrades += actual_amount
	
	entity_upgraded.emit(username, upgrade_type, _data.upgrades[field_name])
	
	# Notify in action feed
	if GameController.instance:
		var action_feed = GameController.instance.get_action_feed()
		if action_feed:
			var final_percent = _data.upgrades[field_name] * 100
			action_feed.add_message(
				"%s %s gained %dx %s! Now at %.0f%%!" % [emoji, username, actual_amount, upgrade_type, final_percent],
				Color(0.8, 0.8, 1.0)
			)
	
	# Update active entity if exists
	_update_active_entity(username)
	
	return actual_amount

## Get entity type for chatter
func get_entity_type(username: String) -> String:
	return get_chatter_data(username).entity_type

## Set entity type (for future transformation system)
func set_entity_type(username: String, entity_type: String):
	var _data = get_chatter_data(username)
	_data.entity_type = entity_type
	print("🔄 %s transformed to: %s" % [username, entity_type])

## Apply upgrades to an entity
func apply_upgrades_to_entity(entity: Node, username: String):
	var _data = get_chatter_data(username)
	var upgrades = _data.upgrades
	
	# Get NPC rarity multiplier
	var rarity_multiplier = 1.0
	var rarity_manager = NPCRarityManager.get_instance()
	if rarity_manager:
		rarity_multiplier = rarity_manager.get_mxp_multiplier(entity)
		if rarity_multiplier > 1.0:
			pass  # Applying rarity multiplier to upgrades
	
	# Apply size (from HP modifier only)
	if entity.has_method("set_scale_multiplier"):
		# Only use hp_size_more_multiplier from HP modifier
		var size_mult = upgrades.get("hp_size_more_multiplier", 1.0)
		var final_size = 1.0 + ((size_mult - 1.0) * rarity_multiplier)
		entity.set_scale_multiplier(final_size)
	
	# Apply AoE with rarity multiplier
	if entity.has_method("set_aoe_multiplier"):
		# Use bonus_aoe from new flat MXP system
		var bonus_aoe = upgrades.get("bonus_aoe", 0.0)
		var final_aoe = (1.0 + bonus_aoe) * rarity_multiplier
		entity.set_aoe_multiplier(final_aoe)
	
	# Apply other stats if it's a BaseCreature/BaseEnemy
	if entity is BaseEnemy:
		# Cache base stats once to prevent compounding on re-apply
		if not entity.has_meta("base_max_health"):
			entity.set_meta("base_max_health", entity.max_health)
		if not entity.has_meta("base_damage"):
			entity.set_meta("base_damage", entity.damage)
		if not entity.has_meta("base_move_speed"):
			entity.set_meta("base_move_speed", entity.move_speed)
		if not entity.has_meta("base_attack_cooldown"):
			entity.set_meta("base_attack_cooldown", entity.attack_cooldown)

		var base_max_health: float = entity.get_meta("base_max_health")
		var base_damage: float = entity.get_meta("base_damage")
		var base_move_speed: float = entity.get_meta("base_move_speed")
		var base_attack_cooldown: float = entity.get_meta("base_attack_cooldown")

		# Apply HP modifiers
		var hp_flat = upgrades.get("bonus_health", 0) * rarity_multiplier
		var hp_increased = upgrades.get("hp_increased_percent", 0.0)
		var final_health_mult = 1.0 + (hp_increased * rarity_multiplier)
		
		# Legacy health multiplier support
		if upgrades.has("health_multiplier"):
			final_health_mult = max(final_health_mult, 1.0 + ((upgrades.health_multiplier - 1.0) * rarity_multiplier))
		
		# Preserve current health percentage when max HP changes
		var old_max: float = entity.max_health
		entity.max_health = (base_max_health + hp_flat) * final_health_mult
		var percent: float = 1.0
		if old_max > 0:
			percent = clamp(float(entity.current_health) / float(old_max), 0.0, 1.0)
		# Keep same percentage of the new max; if entity is fresh (0 health), fill to max
		entity.current_health = entity.max_health * percent
		if entity.current_health <= 0:
			entity.current_health = entity.max_health
		
		# Apply damage with rarity multiplier
		var final_damage_mult = 1.0 + ((upgrades.get("damage_multiplier", 1.0) - 1.0) * rarity_multiplier)
		entity.damage = base_damage * final_damage_mult
		
		# Apply speed modifiers (flat bonus system)
		var speed_flat = upgrades.get("bonus_move_speed", 0.0) * rarity_multiplier
		entity.move_speed = base_move_speed + speed_flat
		
		# Apply attack speed (flat bonus to attacks per second)
		var attack_speed_bonus = upgrades.get("bonus_attack_speed", 0.0) * rarity_multiplier
		# Convert base cooldown to attacks per second, add bonus, then back to cooldown
		var base_attacks_per_sec = 1.0 / base_attack_cooldown if base_attack_cooldown > 0 else 1.0
		var new_attacks_per_sec = base_attacks_per_sec + attack_speed_bonus
		if new_attacks_per_sec > 0:
			entity.attack_cooldown = 1.0 / new_attacks_per_sec
		
		# Apply aggro radius
		if entity.has_method("set_aggro_multiplier"):
			var aggro_mult = upgrades.get("aggro_multiplier", 1.0)
			var final_aggro = 1.0 + ((aggro_mult - 1.0) * rarity_multiplier)
			entity.set_aggro_multiplier(final_aggro)
		
		# Apply regeneration
		if entity.has_method("set_regeneration"):
			var regen = upgrades.get("regen_flat_bonus", 0.0) * rarity_multiplier
			entity.set_regeneration(regen)
	
	# Apply boss buffs
	if BossBuffManager.instance:
		BossBuffManager.instance.apply_buffs_to_entity(entity)
	

## Update active entity with new upgrades
func _update_active_entity(username: String):
	# Update V2 enemies in EnemyManager
	if EnemyManager.instance:
		var enemy_manager = EnemyManager.instance
		var chatter_data_local = get_chatter_data(username)
		
		# Find all enemies belonging to this chatter
		for id in range(enemy_manager.chatter_usernames.size()):
			if enemy_manager.alive_flags[id] == 0:
				continue
			if enemy_manager.chatter_usernames[id] != username:
				continue
			
			# Get base stats for this enemy type
			var enemy_type = enemy_manager.entity_types[id]
			var base_hp = 10.0
			var base_speed = 80.0
			var base_cooldown = 2.0
			
			match enemy_type:
				0: # Rat
					base_hp = 10.0
					base_speed = 80.0
					base_cooldown = 0.5  # 2 attacks per second
				1: # Succubus
					base_hp = 25.0
					base_speed = 100.0
					base_cooldown = 2.5  # Ranged attacker - slower attack speed
				2: # Woodland Joe
					base_hp = 40.0
					base_speed = 80.0
					base_cooldown = 0.5  # 2 attacks per second
			
			# Apply HP bonus
			if chatter_data_local.upgrades.has("bonus_health"):
				var hp_bonus = chatter_data_local.upgrades["bonus_health"]
				enemy_manager.max_healths[id] = base_hp + hp_bonus
				# Also heal to new max if current health was at max
				if enemy_manager.healths[id] >= base_hp:
					enemy_manager.healths[id] = base_hp + hp_bonus
			
			# Apply speed bonus
			if chatter_data_local.upgrades.has("bonus_move_speed"):
				var speed_bonus = chatter_data_local.upgrades["bonus_move_speed"]
				enemy_manager.move_speeds[id] = base_speed + speed_bonus
			
			# Apply attack speed percentage bonus
			if chatter_data_local.upgrades.has("attack_speed_percent"):
				var percent_bonus = chatter_data_local.upgrades["attack_speed_percent"]
				var base_attacks_per_sec = 1.0 / base_cooldown
				var new_attacks_per_sec = base_attacks_per_sec * (1.0 + percent_bonus)
				enemy_manager.attack_cooldowns[id] = 1.0 / new_attacks_per_sec
			else:
				# Reset to base cooldown if no bonus
				enemy_manager.attack_cooldowns[id] = base_cooldown
			
			# Apply AOE bonus (stored for later use in abilities)
			if chatter_data_local.upgrades.has("bonus_aoe"):
				enemy_manager.aoe_scales[id] = 1.0 + chatter_data_local.upgrades["bonus_aoe"]
			
			# Apply regen bonus
			if chatter_data_local.upgrades.has("regen_flat_bonus"):
				var regen = chatter_data_local.upgrades["regen_flat_bonus"]
				enemy_manager.regen_rates[id] = regen
	
	# Find the active entities for this chatter using old system (if any remain)
	if TicketSpawnManager.instance:
		var entities = TicketSpawnManager.instance.get_alive_entities_for_chatter(username)
		for entity in entities:
			if is_instance_valid(entity):
				var _data = get_chatter_data(username)
				
				# Get rarity multiplier
				var _rarity_multiplier = 1.0
				var rarity_manager = NPCRarityManager.get_instance()
				if rarity_manager:
					_rarity_multiplier = rarity_manager.get_mxp_multiplier(entity)
				
				# Re-apply all upgrades so changes are instant and non-compounding
				apply_upgrades_to_entity(entity, username)

func _on_modifier_applied(username: String, _modifier_name: String, _result: Dictionary):
	# Called when a modifier is applied via MXPModifierManager
	_update_active_entity(username)

func _on_entity_upgraded(username: String, _upgrade_type: String, _effect_data):
	# Legacy path - ensure both signals keep entities synced
	_update_active_entity(username)

## Get upgrade cost for a specific upgrade type
func get_upgrade_cost(upgrade_type: String, _current_level: int = 0) -> int:
	# For now all upgrades cost 1 MXP
	# Can make this more complex later
	match upgrade_type:
		"size":
			return 1
		"aoe":
			return 1
		"speed":
			return 2
		"damage":
			return 3
		"health":
			return 2
		_:
			return 1

## Reset for new session
func reset_session():
	chatter_data.clear()
	print("🔄 Chatter Entity Manager reset - New session!")
