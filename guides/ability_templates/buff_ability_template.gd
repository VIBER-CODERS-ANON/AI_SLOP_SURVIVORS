class_name BuffAbilityTemplate
extends BaseAbility

## Template for buff/debuff abilities (Haste, Shield, Poison, Slow, etc.)
## Copy this file and rename for your specific buff/debuff ability

# Buff properties
@export_group("Buff/Debuff Settings")
@export var is_buff: bool = true  # true = buff, false = debuff
@export var duration: float = 10.0
@export var stack_limit: int = 1  # Max stacks, 0 = infinite
@export var refresh_on_reapply: bool = true

# Stat modifications (use negative values for debuffs)
@export_group("Stat Modifications")
@export var health_bonus: float = 0.0
@export var speed_multiplier: float = 1.0  # 1.5 = 50% faster, 0.5 = 50% slower
@export var damage_multiplier: float = 1.0
@export var defense_bonus: float = 0.0
@export var attack_speed_multiplier: float = 1.0

# Special effects
@export_group("Special Effects")
@export var damage_over_time: float = 0.0  # Damage per second
@export var heal_over_time: float = 0.0  # Healing per second
@export var grants_immunity_tags: Array[String] = []  # e.g., ["Poison", "Stun"]
@export var applies_status: String = ""  # e.g., "Stunned", "Silenced"

# Visual/Audio
@export_group("Visual and Audio")
@export var buff_icon_path: String = ""
@export var effect_scene_path: String = "res://entities/effects/your_buff_effect.tscn"
@export var apply_sound_path: String = ""
@export var loop_sound_path: String = ""  # Continuous sound while active
@export var apply_animation: String = "buff_apply"
@export var buff_color: Color = Color.WHITE  # Tint while buffed

# Targeting
@export_group("Targeting Options")
@export var can_target_self: bool = true
@export var can_target_allies: bool = true
@export var can_target_enemies: bool = false
@export var aoe_application: bool = false  # Apply to all in radius
@export var aoe_radius: float = 200.0

# Cached resources
var buff_icon: Texture2D
var effect_scene: PackedScene
var apply_sound: AudioStream
var loop_sound: AudioStream

func _init() -> void:
    # TODO: Set unique ability ID
    ability_id = "buff_template"
    ability_name = "Buff Template"
    ability_description = "Applies a beneficial effect to the target"
    
    # TODO: Set appropriate tags
    ability_tags = ["Buff", "Support"]  # or ["Debuff", "Curse"] for debuffs
    
    ability_type = 0  # ACTIVE
    base_cooldown = 8.0
    
    # TODO: Adjust resource costs
    resource_costs = {
        "mana": 20.0
    }
    
    # Set targeting based on configuration
    if aoe_application:
        targeting_type = 5  # AREA_AROUND_SELF or 3 for ground-targeted
        base_range = aoe_radius
    else:
        targeting_type = 0 if can_target_self and not can_target_allies else 1  # SELF or SINGLE_TARGET
        base_range = 300.0  # For targeted buffs

func on_added(holder) -> void:
    super.on_added(holder)
    
    # Preload resources
    if buff_icon_path != "":
        buff_icon = load(buff_icon_path)
    if effect_scene_path != "":
        effect_scene = load(effect_scene_path)
    if apply_sound_path != "":
        apply_sound = load(apply_sound_path)
    if loop_sound_path != "":
        loop_sound = load(loop_sound_path)
    
    print("✨ ", ability_name, " added to ", _get_entity_name(holder))

func can_execute(holder, target_data) -> bool:
    if not super.can_execute(holder, target_data):
        return false
    
    var entity = _get_entity(holder)
    if not entity:
        return false
    
    # Check if entity is alive
    if entity.has_method("is_alive") and not entity.is_alive:
        return false
    
    # Validate target for single-target buffs
    if targeting_type == 1 and target_data:  # SINGLE_TARGET
        var target = target_data.primary_target
        if not _is_valid_target(entity, target):
            return false
    
    return true

func _is_valid_target(caster, target) -> bool:
    if not target or not is_instance_valid(target):
        return false
    
    # Check if target is alive
    if target.has_method("is_alive") and not target.is_alive:
        return false
    
    # Check team restrictions
    var is_ally = _are_allies(caster, target)
    var is_self = caster == target
    
    if is_self and not can_target_self:
        return false
    elif is_ally and not is_self and not can_target_allies:
        return false
    elif not is_ally and not can_target_enemies:
        return false
    
    return true

func _are_allies(entity1, entity2) -> bool:
    # Check if both are players
    if entity1.is_in_group("player") and entity2.is_in_group("player"):
        return true
    # Check if both are enemies
    if entity1.is_in_group("enemies") and entity2.is_in_group("enemies"):
        return true
    # Otherwise they're on different teams
    return false

func _execute_ability(holder, target_data) -> void:
    var entity = _get_entity(holder)
    if not entity:
        return
    
    # Report to action feed
    _report_to_action_feed(entity)
    
    # Play animation
    _play_animation(holder, apply_animation)
    
    # Play sound
    _play_apply_sound(entity)
    
    # Apply buff based on targeting type
    if aoe_application:
        _apply_aoe_buff(entity, holder, target_data)
    else:
        _apply_single_buff(entity, holder, target_data)
    
    # Start cooldown
    _start_cooldown(holder)
    
    # Notify systems
    holder.on_ability_executed(self)
    executed.emit(target_data)

func _apply_single_buff(caster, holder, target_data) -> void:
    var target = caster  # Default to self
    
    if targeting_type == 1 and target_data and target_data.primary_target:
        target = target_data.primary_target
    
    if not _is_valid_target(caster, target):
        return
    
    _apply_buff_to_target(target, caster, holder)

func _apply_aoe_buff(caster, holder, target_data) -> void:
    var center_pos = caster.global_position
    if targeting_type == 3 and target_data:  # Ground-targeted
        center_pos = target_data.target_position
    
    # Find all potential targets in radius
    var space_state = caster.get_world_2d().direct_space_state
    var query = PhysicsShapeQueryParameters2D.new()
    var circle = CircleShape2D.new()
    circle.radius = aoe_radius
    
    query.shape = circle
    query.transform = Transform2D(0, center_pos)
    query.collision_mask = 0
    
    # Set collision mask based on target settings
    if can_target_allies or can_target_self:
        query.collision_mask |= 1  # Player layer
    if can_target_enemies:
        query.collision_mask |= 2  # Enemy layer
    
    var results = space_state.intersect_shape(query)
    
    for result in results:
        var target = result.collider
        if _is_valid_target(caster, target):
            _apply_buff_to_target(target, caster, holder)

func _apply_buff_to_target(target, caster, holder) -> void:
    # Create buff instance
    var buff = preload("res://systems/buff_system/base_buff.gd").new()
    
    # Configure buff properties
    buff.buff_name = ability_name
    buff.duration = duration
    buff.is_buff = is_buff
    buff.source = caster
    buff.icon = buff_icon
    buff.stack_limit = stack_limit
    buff.refresh_on_reapply = refresh_on_reapply
    
    # Set stat modifications
    if speed_multiplier != 1.0:
        buff.stat_modifiers["move_speed"] = speed_multiplier
    if damage_multiplier != 1.0:
        buff.stat_modifiers["damage"] = damage_multiplier
    if attack_speed_multiplier != 1.0:
        buff.stat_modifiers["attack_speed"] = attack_speed_multiplier
    if defense_bonus != 0.0:
        buff.stat_modifiers["defense"] = defense_bonus
    if health_bonus != 0.0:
        buff.stat_modifiers["max_health"] = health_bonus
    
    # Set special effects
    buff.damage_per_second = damage_over_time
    buff.heal_per_second = heal_over_time
    buff.immunity_tags = grants_immunity_tags
    buff.applies_status = applies_status
    buff.visual_color = buff_color
    
    # Apply the buff
    if target.has_method("add_buff"):
        target.add_buff(buff)
    elif target.has_method("add_status_effect"):
        target.add_status_effect(buff)
    
    # Visual effect on target
    _spawn_buff_effect(target)
    
    # Notify ability hit
    holder.on_ability_hit(self, target)

func _spawn_buff_effect(target) -> void:
    if not effect_scene:
        return
    
    var effect = effect_scene.instantiate()
    target.add_child(effect)
    effect.position = Vector2.ZERO
    
    # Attach to target for duration
    if effect.has_method("attach_to_target"):
        effect.attach_to_target(target, duration)

func _play_apply_sound(entity) -> void:
    if apply_sound and AudioManager.instance:
        AudioManager.instance.play_sfx_on_node(
            apply_sound,
            entity,
            0.0,
            1.0
        )

# Helper methods
func _get_entity(holder):
    if holder.has_method("get_entity_node"):
        return holder.get_entity_node()
    return holder

func _get_entity_name(holder) -> String:
    var entity = _get_entity(holder)
    if entity:
        return entity.name
    return "Unknown"

func _report_to_action_feed(entity) -> void:
    if entity.has_method("get_chatter_username") and GameController.instance:
        var action_feed = GameController.instance.get_action_feed()
        if action_feed:
            var action_text = ability_name + " on "
            if targeting_type == 0:
                action_text += "self"
            elif aoe_application:
                action_text += "area"
            else:
                action_text += "target"
            
            if action_feed.has_method("custom_ability"):
                action_feed.custom_ability(entity.get_chatter_username(), action_text)

func _play_animation(holder, anim_name: String) -> void:
    if holder.has_method("play_animation"):
        holder.play_animation(anim_name)

# Override for range display
func get_range() -> float:
    if aoe_application:
        return aoe_radius
    else:
        return base_range
