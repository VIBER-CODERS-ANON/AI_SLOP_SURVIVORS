extends Area2D
class_name SwordHitbox

## Simple sword collision that follows the animated sword sprite

signal hit_enemy(enemy: Node)

@export var damage: float = 10.0
@export var knockback_force: float = 200.0
@export var hit_cooldown: float = 0.1  # Minimum time between hits on same enemy

# Track hit cooldowns per enemy
var enemy_hit_timers: Dictionary = {}

func _ready():
	# Set up collision layers
	collision_layer = 4  # Weapon layer
	collision_mask = 2   # Only detect enemies
	
	# Connect signals
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	
	

func _physics_process(_delta):
	# Clean up expired timers
	var to_remove = []
	for enemy in enemy_hit_timers:
		enemy_hit_timers[enemy] -= _delta
		if enemy_hit_timers[enemy] <= 0:
			to_remove.append(enemy)
	
	for enemy in to_remove:
		enemy_hit_timers.erase(enemy)

func _on_area_entered(area: Area2D):
	var parent = area.get_parent()
	if parent and parent.has_method("take_damage") and parent.is_in_group("enemies"):
		_try_hit_enemy(parent)

func _on_body_entered(body: Node2D):
	if body.has_method("take_damage") and body.is_in_group("enemies"):
		_try_hit_enemy(body)

func _try_hit_enemy(enemy: Node):
	# Check if enemy is on cooldown
	if enemy in enemy_hit_timers:
		return  # Still on cooldown
	
	# Add to cooldown
	enemy_hit_timers[enemy] = hit_cooldown
	
	# Deal damage - ensure we have a valid parent
	var damage_source = get_parent()
	if not is_instance_valid(damage_source):
		damage_source = self  # Fallback to self if parent is invalid
	
	enemy.take_damage(damage, damage_source, ["Melee", "Physical", "AoE"])
	
	# Play impact sound
	if ImpactSoundSystem.instance:
		ImpactSoundSystem.instance.play_impact(self, enemy, enemy.global_position, ["sword", "Melee"])
	
	# Apply knockback
	if enemy.has_method("apply_knockback"):
		var direction = enemy.global_position - global_position
		enemy.apply_knockback(direction.normalized(), knockback_force)
	
	# Visual feedback - flash the sword
	var sword_sprite = get_node_or_null("../SpriteContainer/Sword")
	if sword_sprite:
		var original_modulate = sword_sprite.modulate
		sword_sprite.modulate = Color(2, 2, 2, 1)  # Bright flash
		await get_tree().create_timer(0.05).timeout
		sword_sprite.modulate = original_modulate
	
	# Emit signal
	hit_enemy.emit(enemy)

## Get weapon type for impact sound system
func get_weapon_type() -> String:
	return "sword"
