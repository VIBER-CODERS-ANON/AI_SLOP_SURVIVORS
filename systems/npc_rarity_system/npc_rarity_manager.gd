extends Node
class_name NPCRarityManager

## Manages NPC rarity system including ticket draws and rarity assignment

signal rarity_assigned(entity: Node, rarity: NPCRarity)

# Rarity configurations
var rarities: Dictionary = {}

# Ticket pool for random draws
var ticket_pool: Array[NPCRarity.Type] = []

# Statistics tracking
var rarity_spawn_counts: Dictionary = {
	NPCRarity.Type.COMMON: 0,
	NPCRarity.Type.MAGIC: 0,
	NPCRarity.Type.RARE: 0,
	NPCRarity.Type.UNIQUE: 0
}

func _ready():
	add_to_group("npc_rarity_manager")
	_initialize_rarities()
	_build_ticket_pool()

func _initialize_rarities():
	rarities = NPCRarity.get_default_rarities()
	print("🎲 NPC Rarity system initialized with %d rarities" % rarities.size())

func _build_ticket_pool():
	ticket_pool.clear()
	
	for rarity_type in rarities:
		var rarity = rarities[rarity_type]
		# Skip unique rarities (0 ticket weight)
		if rarity.ticket_weight > 0:
			for i in range(rarity.ticket_weight):
				ticket_pool.append(rarity_type)
	
	# Shuffle for better distribution
	ticket_pool.shuffle()
	# NPC rarity ticket pool built
	
	# Print distribution
	var distribution = {}
	for ticket in ticket_pool:
		if not distribution.has(ticket):
			distribution[ticket] = 0
		distribution[ticket] += 1
	
	for rarity_type in distribution:
		var _rarity = rarities[rarity_type]
		var _percentage = (distribution[rarity_type] / float(ticket_pool.size())) * 100
		# Rarity distribution calculated

## Draw a random rarity from the ticket pool
func draw_random_rarity() -> NPCRarity:
	if ticket_pool.is_empty():
		_build_ticket_pool()
	
	var index = randi() % ticket_pool.size()
	var rarity_type = ticket_pool[index]
	
	# Track statistics
	rarity_spawn_counts[rarity_type] += 1
	
	return rarities[rarity_type]

## Assign a specific rarity to an entity
func assign_rarity(entity: Node, rarity: NPCRarity) -> void:
	if not entity:
		push_error("Cannot assign rarity to null entity")
		return
	
	# Store rarity on entity
	entity.set_meta("npc_rarity", rarity)
	
	# Add rarity tag if entity has taggable component
	if entity.has_node("Taggable"):
		var taggable = entity.get_node("Taggable") as Taggable
		if taggable:
			# Remove any existing rarity tags
			_remove_rarity_tags(taggable)
			# Add new rarity tag
			taggable.add_tag(rarity.get_tag_name())
	
	# Apply visual effects
	rarity.apply_visual_effects(entity)
	
	# Apply stat modifiers if entity is BaseEnemy
	if entity.has_method("apply_rarity_modifiers"):
		entity.apply_rarity_modifiers(rarity)
	
	# Emit signal
	rarity_assigned.emit(entity, rarity)
	
	# Rarity assigned

## Assign a random rarity to an entity
func assign_random_rarity(entity: Node) -> NPCRarity:
	var rarity = draw_random_rarity()
	assign_rarity(entity, rarity)
	return rarity

## Assign a specific rarity type to an entity
func assign_rarity_type(entity: Node, rarity_type: NPCRarity.Type) -> void:
	if rarities.has(rarity_type):
		assign_rarity(entity, rarities[rarity_type])
	else:
		push_error("Unknown rarity type: %d" % rarity_type)

## Clear rarity from an entity (on death/despawn)
func clear_rarity(entity: Node) -> void:
	if not entity:
		return
	
	# Remove rarity meta
	if entity.has_meta("npc_rarity"):
		entity.remove_meta("npc_rarity")
	
	# Remove rarity tags
	if entity.has_node("Taggable"):
		var taggable = entity.get_node("Taggable") as Taggable
		if taggable:
			_remove_rarity_tags(taggable)
	
	# Remove visual effects
	if entity.has_node("RarityAura"):
		entity.get_node("RarityAura").queue_free()

## Get rarity of an entity
func get_entity_rarity(entity: Node) -> NPCRarity:
	if entity and entity.has_meta("npc_rarity"):
		return entity.get_meta("npc_rarity")
	return null

## Check if entity has specific rarity
func has_rarity(entity: Node, rarity_type: NPCRarity.Type) -> bool:
	var rarity = get_entity_rarity(entity)
	return rarity != null and rarity.type == rarity_type

## Get MXP buff multiplier for entity
func get_mxp_multiplier(entity: Node) -> float:
	var rarity = get_entity_rarity(entity)
	if rarity:
		return rarity.mxp_buff_multiplier
	return 1.0

## Remove all rarity tags from taggable
func _remove_rarity_tags(taggable: Taggable) -> void:
	var tags_to_remove = []
	for tag in taggable.get_tags():
		if tag.ends_with("Rarity"):
			tags_to_remove.append(tag)
	
	for tag in tags_to_remove:
		taggable.remove_tag(tag)

## Get spawn statistics
func get_spawn_statistics() -> Dictionary:
	var total_spawns = 0
	for count in rarity_spawn_counts.values():
		total_spawns += count
	
	var stats = {}
	for rarity_type in rarity_spawn_counts:
		var count = rarity_spawn_counts[rarity_type]
		var percentage = 0.0
		if total_spawns > 0:
			percentage = (count / float(total_spawns)) * 100
		
		var rarity_name = "Unknown"
		if rarities.has(rarity_type):
			rarity_name = rarities[rarity_type].display_name
		
		stats[rarity_name] = {
			"count": count,
			"percentage": percentage
		}
	
	return stats

## Get singleton instance
static func get_instance() -> NPCRarityManager:
	var tree = Engine.get_main_loop() as SceneTree
	if tree:
		var existing = tree.get_nodes_in_group("npc_rarity_manager")
		if not existing.is_empty():
			return existing[0]
	return null
