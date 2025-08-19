extends Resource
class_name ImpactConfig

## Configuration for weapon impact sounds
## Defines how a specific weapon type should sound when hitting targets

## Array of sound file paths for this weapon type
@export var base_sounds: Array = []

## Base volume in decibels
@export var volume_db: float = -10.0

## Pitch variation range (x = min, y = max)
@export var pitch_range: Vector2 = Vector2(0.9, 1.1)

## Whether to play sounds in sequence or randomly
@export var sequential_playback: bool = false

## Current sequence index (for sequential playback)
var sequence_index: int = 0

## Get the next sound to play
func get_next_sound() -> String:
	if base_sounds.is_empty():
		return ""
		
	if sequential_playback:
		var sound = base_sounds[sequence_index]
		sequence_index = (sequence_index + 1) % base_sounds.size()
		return sound
	else:
		return base_sounds[randi() % base_sounds.size()]
