extends Node
class_name PlayerAbilityManager

## Manages player ability input and execution
## Bridges player input to the AbilityExecutor system for consistent ability handling

signal ability_triggered(ability_id: String)
signal ability_failed(ability_id: String, reason: String)

# Player entity reference
var player: Player
var player_entity_id: int = -1

# Input mappings: input_action -> ability_id
var ability_bindings: Dictionary = {
	"dash": "dash"
	# Future bindings:
	# "right_click": "fireball",
	# "ability_1": "heal", 
	# "ability_2": "teleport"
}

# Ability resources to register with player
@export var player_abilities: Array[AbilityResource] = []

func _ready():
	# Connect to AbilityExecutor signals
	if AbilityExecutor.instance:
		AbilityExecutor.instance.ability_executed.connect(_on_ability_executed)
		AbilityExecutor.instance.ability_failed.connect(_on_ability_failed)

func setup_player(player_node: Player):
	player = player_node
	
	# Get or assign player entity ID for AbilityExecutor
	# Players use negative IDs to distinguish from enemy IDs
	player_entity_id = -1
	
	# Load default player abilities
	_load_default_abilities()
	
	# Register player with AbilityExecutor
	_register_player_abilities()
	
	print("🎮 PlayerAbilityManager setup complete for player with entity ID: %d" % player_entity_id)

func _load_default_abilities():
	"""Load default player abilities from resource files"""
	var default_abilities = [
		"res://resources/abilities/player/dash.tres"
	]
	
	player_abilities.clear()
	for ability_path in default_abilities:
		if ResourceLoader.exists(ability_path):
			var ability_res = load(ability_path) as AbilityResource
			if ability_res:
				player_abilities.append(ability_res)
				print("  ✅ Loaded player ability: %s" % ability_res.ability_id)
		else:
			print("  ⚠️ Player ability not found: %s" % ability_path)

func _register_player_abilities():
	"""Register player abilities with AbilityExecutor"""
	if AbilityExecutor.instance and player_abilities.size() > 0:
		AbilityExecutor.instance.register_entity_abilities(player_entity_id, player_abilities)

func _unhandled_input(event: InputEvent):
	if not player or not player.is_alive:
		return
	
	# Handle ability input
	for input_action in ability_bindings:
		if Input.is_action_just_pressed(input_action):
			var ability_id = ability_bindings[input_action]
			_trigger_ability(ability_id)
			get_viewport().set_input_as_handled()

func _trigger_ability(ability_id: String):
	"""Trigger an ability through AbilityExecutor"""
	if not AbilityExecutor.instance:
		ability_failed.emit(ability_id, "AbilityExecutor not available")
		return
	
	# Create target data for player abilities
	var target_data = _create_player_target_data(ability_id)
	
	# Execute through AbilityExecutor
	var success = AbilityExecutor.instance.execute_ability_by_id(player_entity_id, ability_id, target_data)
	
	if not success:
		ability_failed.emit(ability_id, "Execution failed")

func _create_player_target_data(ability_id: String) -> Dictionary:
	"""Create target data for player ability execution"""
	var mouse_pos = player.get_global_mouse_position()
	var player_pos = player.global_position
	
	return {
		"target_position": mouse_pos,
		"target_enemy": null,  # Player abilities don't target enemies directly
		"direction": (mouse_pos - player_pos).normalized(),
		"source_entity": player
	}

# Signal callbacks
func _on_ability_executed(entity_id: int, ability_id: String):
	if entity_id == player_entity_id:
		ability_triggered.emit(ability_id)
		print("🎮 Player ability executed: %s" % ability_id)

func _on_ability_failed(entity_id: int, ability_id: String, reason: String):
	if entity_id == player_entity_id:
		ability_failed.emit(ability_id, reason)
		print("❌ Player ability failed: %s (%s)" % [ability_id, reason])

# Utility methods
func add_ability(ability_res: AbilityResource):
	"""Add a new ability to the player"""
	if ability_res and ability_res not in player_abilities:
		player_abilities.append(ability_res)
		_register_player_abilities()

func remove_ability(ability_id: String):
	"""Remove an ability from the player"""
	for i in range(player_abilities.size() - 1, -1, -1):
		if player_abilities[i].ability_id == ability_id:
			player_abilities.remove_at(i)
			break
	_register_player_abilities()

func has_ability(ability_id: String) -> bool:
	"""Check if player has a specific ability"""
	for ability in player_abilities:
		if ability.ability_id == ability_id:
			return true
	return false

func get_ability_cooldown(ability_id: String) -> float:
	"""Get remaining cooldown for an ability"""
	if AbilityExecutor.instance and AbilityExecutor.instance.entity_cooldowns.has(player_entity_id):
		var cooldowns = AbilityExecutor.instance.entity_cooldowns[player_entity_id]
		return cooldowns.get(ability_id, 0.0)
	return 0.0

func is_ability_on_cooldown(ability_id: String) -> bool:
	"""Check if ability is on cooldown"""
	return get_ability_cooldown(ability_id) > 0.0