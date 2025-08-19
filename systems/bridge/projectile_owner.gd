extends Node
class_name ProjectileOwner

## PROJECTILE OWNER FOR DATA-ORIENTED ENEMIES
## Provides death attribution methods for projectiles fired by data-oriented enemies
## Since enemies are data arrays, not Node objects, this creates a proxy for projectile ownership

var enemy_id: int = -1
var username: String = ""

func setup(id: int, chatter_name: String):
	enemy_id = id
	username = chatter_name

func get_killer_display_name() -> String:
	if username.is_empty():
		return "Someone"
	return username

func get_chatter_username() -> String:
	return username

func get_display_name() -> String:
	return username

func get_attack_name() -> String:
	return get_meta("attack_name", "attack")

# Note: V2 enemies use standard Node methods like is_in_group() and has_method()
# No custom overrides needed - Node's built-in methods work fine
