extends Node
class_name AbilityManager

signal ability_added(ability, slot)
signal ability_removed(ability, slot)
signal ability_executed(ability, target_data)

var abilities: Dictionary = {}  # slot -> ability
var ability_keybinds: Dictionary = {}  # input_action -> slot
var owner_entity: Node
var ability_holder = null

func _ready() -> void:
	owner_entity = get_parent()
	if owner_entity and owner_entity.has_method("get_ability_holder"):
		ability_holder = owner_entity.get_ability_holder()
	set_process(true)
	set_process_unhandled_input(true)

func _process(delta: float) -> void:
	for slot in abilities:
		var ability = abilities[slot]
		if ability and ability_holder:
			ability.update(delta, ability_holder)

func _unhandled_input(event: InputEvent) -> void:
	for action in ability_keybinds:
		if event.is_action_pressed(action):
			var slot = ability_keybinds[action]
			execute_ability_by_slot(slot)
			get_viewport().set_input_as_handled()

func add_ability(ability, slot: int = -1) -> bool:
	
	if not ability:
		return false
	
	if slot < 0:
		slot = 0
		while abilities.has(slot):
			slot += 1
	
	abilities[slot] = ability
	
	if ability_holder:
		ability.on_added(ability_holder)
	else:
		pass
	
	ability_added.emit(ability, slot)
	return true

func remove_ability_by_id(ability_id: String) -> bool:
	for slot in abilities:
		var ability = abilities[slot]
		if ability and ability.get_id() == ability_id:
			abilities.erase(slot)
			if ability_holder:
				ability.on_removed(ability_holder)
			ability_removed.emit(ability, slot)
			return true
	return false

func get_ability_by_id(ability_id: String):
	for slot in abilities:
		var ability = abilities[slot]
		if ability and ability.get_id() == ability_id:
			return ability
	return null

func execute_ability_by_id(ability_id: String, target_data = null) -> bool:
	var ability = get_ability_by_id(ability_id)
	if not ability:
		return false
	
	
	if not target_data:
		var default_direction: Vector2 = ability_holder.get_facing_direction() if ability_holder else Vector2.RIGHT
		if ability and ability.get_targeting_type() == 4 and owner_entity:
			var mc = owner_entity.get_node_or_null("PlayerMovementController")
			if not mc:
				mc = owner_entity.get_node_or_null("MovementController")
			if mc and mc.has_method("get_direction"):
				var dir: Vector2 = mc.get_direction()
				if dir.length() > 0.1:
					default_direction = dir
			# else keep facing direction
			target_data = AbilityTargetData.create_direction_target(
				owner_entity.global_position,
				default_direction
			)
	
	if ability.execute(ability_holder, target_data):
		ability_executed.emit(ability, target_data)
		return true
	return false

func execute_ability_by_slot(slot: int, target_data = null) -> bool:
	var ability = abilities.get(slot)
	if not ability:
		return false
	
	if not target_data:
		var default_direction: Vector2 = ability_holder.get_facing_direction() if ability_holder else Vector2.RIGHT
		if ability and ability.get_targeting_type() == 4 and owner_entity:
			var mc = owner_entity.get_node_or_null("PlayerMovementController")
			if not mc:
				mc = owner_entity.get_node_or_null("MovementController")
			if mc and mc.has_method("get_direction"):
				var dir: Vector2 = mc.get_direction()
				if dir.length() > 0.1:
					default_direction = dir
			# else keep facing direction
			target_data = AbilityTargetData.create_direction_target(
				owner_entity.global_position,
				default_direction
			)
	
	if ability.execute(ability_holder, target_data):
		ability_executed.emit(ability, target_data)
		return true
	return false

func set_ability_keybind(slot: int, input_action: String) -> void:
	ability_keybinds[input_action] = slot

func has_ability(ability_id: String) -> bool:
	return get_ability_by_id(ability_id) != null
