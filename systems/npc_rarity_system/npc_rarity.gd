extends Resource
class_name NPCRarity

## Enum for NPC rarity types
enum Type {
	COMMON,
	MAGIC,
	RARE,
	UNIQUE
}

## Configuration for NPC rarity
@export var type: Type = Type.COMMON
@export var display_name: String = "Common"
@export var color: Color = Color.WHITE
@export var mxp_buff_multiplier: float = 1.0
@export var ticket_weight: int = 80
@export var has_aura: bool = false
@export var aura_color: Color = Color.WHITE
@export var border_glow: bool = false
@export var scale_modifier: float = 1.0  # Visual scale modifier
@export var health_multiplier: float = 1.0  # Future-proofing for health scaling
@export var damage_multiplier: float = 1.0  # Future-proofing for damage scaling
@export var xp_value_multiplier: float = 1.0  # DEPRECATED - XP now scales with MXP spent

## Static method to get default rarity configurations
static func get_default_rarities() -> Dictionary:
	var rarities = {}
	
	# Common - Basic grey/white
	var common = NPCRarity.new()
	common.type = Type.COMMON
	common.display_name = "Common"
	common.color = Color(0.8, 0.8, 0.8, 1.0)
	common.mxp_buff_multiplier = 1.0
	common.ticket_weight = 80
	common.xp_value_multiplier = 1.0
	rarities[Type.COMMON] = common
	
	# Magic - Blue with slight aura
	var magic = NPCRarity.new()
	magic.type = Type.MAGIC
	magic.display_name = "Magic"
	magic.color = Color(0.4, 0.6, 1.0, 1.0)  # Soft blue
	magic.mxp_buff_multiplier = 1.2
	magic.ticket_weight = 20
	magic.has_aura = true
	magic.aura_color = Color(0.4, 0.6, 1.0, 0.3)
	magic.scale_modifier = 1.1
	magic.xp_value_multiplier = 2.0
	rarities[Type.MAGIC] = magic
	
	# Rare - Yellow/golden with strong aura
	var rare = NPCRarity.new()
	rare.type = Type.RARE
	rare.display_name = "Rare"
	rare.color = Color(1.0, 0.9, 0.3, 1.0)  # Golden yellow
	rare.mxp_buff_multiplier = 2.0
	rare.ticket_weight = 5
	rare.has_aura = true
	rare.aura_color = Color(1.0, 0.9, 0.3, 0.5)
	rare.border_glow = true
	rare.scale_modifier = 1.2
	rare.xp_value_multiplier = 5.0
	rarities[Type.RARE] = rare
	
	# Unique - Custom per entity, no ticket weight
	var unique = NPCRarity.new()
	unique.type = Type.UNIQUE
	unique.display_name = "Unique"
	unique.color = Color(1.0, 0.6, 0.2, 1.0)  # Orange
	unique.mxp_buff_multiplier = 1.0  # Varies per unique
	unique.ticket_weight = 0  # Not in ticket pool
	unique.has_aura = true
	unique.aura_color = Color(1.0, 0.6, 0.2, 0.6)
	unique.border_glow = true
	unique.scale_modifier = 1.0  # Varies per unique
	unique.xp_value_multiplier = 10.0
	rarities[Type.UNIQUE] = unique
	
	return rarities

## Get tag name for this rarity
func get_tag_name() -> String:
	return display_name + "Rarity"

## Apply visual effects to an entity
func apply_visual_effects(entity: Node2D) -> void:
	# Apply scale modifier
	if scale_modifier != 1.0:
		entity.scale *= scale_modifier
	
	# Apply color tint
	if entity.modulate != color and type != Type.COMMON:
		entity.modulate = entity.modulate.lerp(color, 0.3)
	
	# Create aura effect if needed
	if has_aura:
		_create_aura_effect(entity)
	
	# Add border glow if needed
	if border_glow:
		_create_border_glow(entity)

func _create_aura_effect(entity: Node2D) -> void:
	var aura = Node2D.new()
	aura.name = "RarityAura"
	aura.z_index = -1
	
	# Create pulsing circle
	var circle = ColorRect.new()
	circle.custom_minimum_size = Vector2(100, 100)
	circle.position = Vector2(-50, -50)
	circle.color = aura_color
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Add shader for circular gradient
	var shader = Shader.new()
	shader.code = """
	shader_type canvas_item;
	
	void fragment() {
		vec2 center = vec2(0.5, 0.5);
		float dist = distance(UV, center);
		float alpha = smoothstep(0.5, 0.0, dist) * COLOR.a;
		COLOR.a = alpha;
	}
	"""
	
	var material = ShaderMaterial.new()
	material.shader = shader
	circle.material = material
	
	aura.add_child(circle)
	entity.add_child(aura)
	
	# Animate pulsing
	var tween = entity.create_tween()
	tween.set_loops(-1)  # Infinite loops
	tween.set_trans(Tween.TRANS_SINE)
	
	# Store tween reference for cleanup
	aura.set_meta("tween", tween)
	
	# Kill tween when aura is freed
	aura.tree_exiting.connect(func(): 
		if tween and tween.is_valid():
			tween.kill()
	)
	
	tween.tween_property(circle, "scale", Vector2(1.2, 1.2), 1.0)
	tween.tween_property(circle, "scale", Vector2(1.0, 1.0), 1.0)

func _create_border_glow(_entity: Node2D) -> void:
	# This would add a glowing border effect
	# Implementation depends on entity sprite structure
	pass
