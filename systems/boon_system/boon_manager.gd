extends Node
class_name BoonManager

## Manages the boon system including rarity tickets and boon selection

signal boon_applied(boon: BaseBoon, entity: BaseEntity)

# Boon pools by rarity
var common_boons: Array[BaseBoon] = []
var unique_boons: Array[BaseBoon] = []

# Rarity configurations
var rarities: Dictionary = {}

# Ticket system
var ticket_pool: Array[BoonRarity.Type] = []

# Track selected unique boons (one-time only)
var selected_unique_boon_ids: Array[String] = []

func _ready():
	_initialize_rarities()
	_initialize_boon_pools()
	_build_ticket_pool()

func _initialize_rarities():
	rarities = BoonRarity.get_default_rarities()

func _initialize_boon_pools():
	# Common boons
	common_boons = [
		preload("res://systems/boon_system/boons/health_boon.gd").new(),
		preload("res://systems/boon_system/boons/damage_boon.gd").new(),
		preload("res://systems/boon_system/boons/speed_boon.gd").new(),
		preload("res://systems/boon_system/boons/pickup_boon.gd").new(),
		preload("res://systems/boon_system/boons/crit_boon.gd").new(),
		preload("res://systems/boon_system/boons/aoe_boon.gd").new(),
		preload("res://systems/boon_system/boons/arc_extension_boon.gd").new()
	]
	
	# Unique boons
	unique_boons = [
		preload("res://systems/boon_system/boons/glass_cannon_boon.gd").new(),
		preload("res://systems/boon_system/boons/vampiric_boon.gd").new(),
		preload("res://systems/boon_system/boons/berserker_boon.gd").new(),
		preload("res://systems/boon_system/boons/double_strike_boon.gd").new()
	]

func _build_ticket_pool():
	ticket_pool.clear()
	
	for rarity_type in rarities:
		var rarity = rarities[rarity_type]
		for i in range(rarity.ticket_weight):
			ticket_pool.append(rarity_type)
	
	# Boon ticket pool built

## Get random boons for selection
func get_random_boons(count: int = 3) -> Array[Dictionary]:
	var selected_boons: Array[Dictionary] = []
	var used_ids: Array[String] = []
	
	for i in range(count):
		# Draw from ticket pool
		var rarity_type = _draw_rarity_ticket()
		var rarity = rarities[rarity_type]
		
		# Get a boon of that rarity
		var boon = _get_boon_of_rarity(rarity_type, used_ids)
		if boon:
			boon.rarity = rarity
			used_ids.append(boon.id)
			
			selected_boons.append({
				"boon": boon,
				"rarity": rarity
			})
	
	return selected_boons

func _draw_rarity_ticket() -> BoonRarity.Type:
	if ticket_pool.is_empty():
		_build_ticket_pool()
	
	var index = randi() % ticket_pool.size()
	return ticket_pool[index]

func _get_boon_of_rarity(rarity_type: BoonRarity.Type, excluded_ids: Array[String]) -> BaseBoon:
	var available_boons: Array[BaseBoon] = []
	
	# For non-unique rarities, use common boons
	if rarity_type != BoonRarity.Type.UNIQUE:
		for boon in common_boons:
			if boon.id not in excluded_ids:
				available_boons.append(boon)
	else:
		# For unique rarity, use unique boons (excluding already selected non-repeatable ones)
		for boon in unique_boons:
			if boon.id not in excluded_ids:
				# Allow repeatable unique boons or ones not yet selected
				if boon.is_repeatable or boon.id not in selected_unique_boon_ids:
					available_boons.append(boon)
	
	if available_boons.is_empty():
		# Fallback to any common boon if no uniques available
		if rarity_type == BoonRarity.Type.UNIQUE and not common_boons.is_empty():
			return common_boons[randi() % common_boons.size()]
		return null
	
	# Return a duplicate of the boon (so we can have multiple instances)
	var selected = available_boons[randi() % available_boons.size()]
	var boon_copy = selected.duplicate()
	boon_copy.rarity = rarities[rarity_type]
	return boon_copy

## Apply a boon to an entity
func apply_boon(boon: BaseBoon, entity: BaseEntity):
	boon.apply_to_entity(entity)
	
	# Track if this is a unique boon that's been selected (unless it's repeatable)
	if boon.rarity and boon.rarity.type == BoonRarity.Type.UNIQUE and not boon.is_repeatable:
		if boon.id not in selected_unique_boon_ids:
			selected_unique_boon_ids.append(boon.id)
			# Unique boon selected and removed from pool
	
	boon_applied.emit(boon, entity)

## Get singleton instance
static func get_instance() -> BoonManager:
	var tree = Engine.get_main_loop() as SceneTree
	if tree:
		var existing = tree.get_nodes_in_group("boon_manager")
		if not existing.is_empty():
			return existing[0]
	return null
