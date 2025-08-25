extends Resource
class_name BaseAbilityBehavior

## Base interface for custom ability behaviors
## Each ability can have its own behavior script that implements the execution logic
## This keeps AbilityExecutor generic while allowing complex ability-specific functionality

## Execute the ability behavior
## @param entity_id: The ID of the entity using the ability (-1 for player, >= 0 for enemies)
## @param ability: The AbilityResource containing ability configuration
## @param pos: The world position where the ability is being cast
## @param target_data: Dictionary containing targeting information (direction, target_position, etc.)
## @returns: true if the ability executed successfully, false otherwise
func execute(entity_id: int, ability: AbilityResource, pos: Vector2, target_data: Dictionary) -> bool:
	push_error("BaseAbilityBehavior.execute() must be overridden in subclass")
	return false

## Helper method to get the entity node from entity_id
func _get_entity(entity_id: int) -> Node:
	if entity_id == -1:
		# Player entity
		if GameController.instance and GameController.instance.player:
			return GameController.instance.player
	elif entity_id >= 0:
		# Enemy entity - would need enemy manager integration
		# For now, return null as enemies use data-oriented approach
		pass
	
	return null

## Helper method to play sound at position
func _play_sound_at(sound: AudioStream, position: Vector2):
	if AudioManager.instance and AudioManager.instance.has_method("play_sound_at"):
		AudioManager.instance.play_sound_at(sound, position)
	else:
		# Fallback: create a simple audio player
		var player = AudioStreamPlayer2D.new()
		player.stream = sound
		player.global_position = position
		player.autoplay = true
		player.finished.connect(player.queue_free)
		if GameController.instance:
			GameController.instance.add_child(player)
		else:
			Engine.get_main_loop().current_scene.add_child(player)

## Helper method to create visual effects
func _create_effect(scene: PackedScene, position: Vector2) -> Node:
	if not scene:
		return null
	
	var effect = scene.instantiate()
	effect.global_position = position
	
	if GameController.instance:
		GameController.instance.add_child(effect)
	else:
		Engine.get_main_loop().current_scene.add_child(effect)
	
	return effect
