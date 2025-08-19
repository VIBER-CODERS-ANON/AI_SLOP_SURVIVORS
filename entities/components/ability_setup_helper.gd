class_name AbilitySetupHelper
extends Node

static func setup_abilities(entity: BaseEntity, ability_configs: Array) -> void:
	if not entity:
		push_error("AbilitySetupHelper: Entity is null")
		return
	
	var ability_manager = entity.get_node_or_null("AbilityManager")
	var ability_holder = entity.get_node_or_null("AbilityHolder")
	
	if not ability_manager or not ability_holder:
		push_error("AbilitySetupHelper: AbilityManager or AbilityHolder not found on " + entity.name)
		return
	
	ability_manager.ability_holder = ability_holder
	
	for config in ability_configs:
		if config is Dictionary:
			_add_ability(ability_manager, config)
		elif config is String:
			_add_ability(ability_manager, {"ability_id": config})

static func _add_ability(ability_manager: Node, config: Dictionary) -> void:
	var ability_id = config.get("ability_id", "")
	if ability_id.is_empty():
		push_error("AbilitySetupHelper: Empty ability_id in config")
		return
	
	var cooldown = config.get("cooldown", -1.0)
	var auto_cast = config.get("auto_cast", true)
	
	ability_manager.add_ability(ability_id)
	
	var ability = ability_manager.get_ability(ability_id)
	if ability:
		if cooldown > 0:
			ability.cooldown = cooldown
		if ability.has_method("set_auto_cast"):
			ability.set_auto_cast(auto_cast)

static func setup_single_ability(entity: BaseEntity, ability_id: String, cooldown: float = -1.0, auto_cast: bool = true) -> void:
	setup_abilities(entity, [{"ability_id": ability_id, "cooldown": cooldown, "auto_cast": auto_cast}])

static func clear_abilities(entity: BaseEntity) -> void:
	var ability_manager = entity.get_node_or_null("AbilityManager")
	if ability_manager and ability_manager.has_method("clear_abilities"):
		ability_manager.clear_abilities()