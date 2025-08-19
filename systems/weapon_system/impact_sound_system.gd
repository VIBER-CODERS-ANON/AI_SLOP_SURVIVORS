extends Node
class_name ImpactSoundSystem

## Modular impact sound system for weapon hits
## Handles different impact sounds based on weapon type, material hit, and other factors

# Singleton instance
static var instance: ImpactSoundSystem

## Impact sound configuration for different weapon types
@export var impact_configs: Dictionary = {}

## Default impact volume in dB
@export var default_volume_db: float = -10.0

## Volume variation range
@export var volume_variation: float = 2.0

## Pitch variation range  
@export var pitch_variation: float = 0.1

func _ready():
	instance = self
	_initialize_default_configs()

func _initialize_default_configs():
	# Initialize default impact sound configurations
	# This is where we define the base sounds for each weapon type
	
	# Sword impacts - subtle 8-bit style
	impact_configs["sword"] = ImpactConfig.new()
	impact_configs["sword"].base_sounds = [
		"res://audio/sfx_subtl_20250813_072019.mp3",
		"res://audio/sfx_8-bit_20250813_072029.mp3", 
		"res://audio/sfx_light_20250813_072038.mp3"
	]
	impact_configs["sword"].volume_db = -12.0  # Quieter since it plays a lot
	impact_configs["sword"].pitch_range = Vector2(0.95, 1.05)
	
	# Future weapon types can be added here
	# impact_configs["hammer"] = ImpactConfig.new()
	# impact_configs["magic"] = ImpactConfig.new()
	# impact_configs["arrow"] = ImpactConfig.new()

## Play an impact sound based on the damage context
func play_impact(damage_source: Node, target: Node, impact_position: Vector2, damage_tags: Array = []):
	var config = _get_impact_config(damage_source, damage_tags)
	if not config:
		return
		
	var sound_path = _select_sound(config, target)
	if not sound_path or sound_path == "":
		return
		
	var volume = config.volume_db + randf_range(-volume_variation, volume_variation)
	var pitch = randf_range(config.pitch_range.x, config.pitch_range.y)
	
	# Material-based modifications
	volume += _get_material_volume_modifier(target)
	pitch *= _get_material_pitch_modifier(target)
	
	# Play the sound
	if AudioManager.instance:
		var stream = load(sound_path)
		if stream:
			AudioManager.instance.play_sfx_at_position(stream, impact_position, volume, pitch)

## Get the appropriate impact configuration for a damage source
func _get_impact_config(damage_source: Node, damage_tags: Array) -> ImpactConfig:
	# Check if source has explicit weapon type
	if damage_source.has_method("get_weapon_type"):
		var weapon_type = damage_source.get_weapon_type()
		if weapon_type in impact_configs:
			return impact_configs[weapon_type]
	
	# Check damage tags for weapon type hints
	for tag in damage_tags:
		var tag_lower = tag.to_lower()
		if tag_lower in impact_configs:
			return impact_configs[tag_lower]
	
	# Default to sword for now (most common weapon)
	if "sword" in impact_configs:
		return impact_configs["sword"]
		
	return null

## Select a sound from the configuration based on target properties
func _select_sound(config: ImpactConfig, _target: Node) -> String:
	if config.base_sounds.is_empty():
		return ""
		
	# Future: Could select different sounds based on target material
	# For now, just pick randomly from available sounds
	return config.base_sounds[randi() % config.base_sounds.size()]

## Get volume modifier based on target material
func _get_material_volume_modifier(target: Node) -> float:
	# Check target tags for material types
	if not target.has_node("Taggable"):
		return 0.0
		
	var taggable = target.get_node("Taggable")
	
	# Armored enemies = louder metallic hits
	if taggable.has_tag("Armored") or taggable.has_tag("Metal"):
		return 3.0
		
	# Soft/fleshy enemies = quieter hits
	if taggable.has_tag("Flesh") or taggable.has_tag("Soft"):
		return -2.0
		
	# Stone/hard enemies = slightly louder
	if taggable.has_tag("Stone") or taggable.has_tag("Hard"):
		return 1.0
		
	return 0.0

## Get pitch modifier based on target material  
func _get_material_pitch_modifier(target: Node) -> float:
	if not target.has_node("Taggable"):
		return 1.0
		
	var taggable = target.get_node("Taggable")
	
	# Metal = higher pitch
	if taggable.has_tag("Armored") or taggable.has_tag("Metal"):
		return 1.15
		
	# Large enemies = lower pitch
	if taggable.has_tag("Large") or taggable.has_tag("Boss"):
		return 0.85
		
	# Small enemies = higher pitch
	if taggable.has_tag("Small"):
		return 1.1
		
	return 1.0

## Register a new weapon type with its impact sounds
func register_weapon_type(weapon_type: String, config: ImpactConfig):
	impact_configs[weapon_type] = config

## Update sounds for an existing weapon type
func update_weapon_sounds(weapon_type: String, sound_paths: Array):
	if weapon_type in impact_configs:
		impact_configs[weapon_type].base_sounds = sound_paths
	else:
		push_warning("Trying to update sounds for unregistered weapon type: " + weapon_type)
