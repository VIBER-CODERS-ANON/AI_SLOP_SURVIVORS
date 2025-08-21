extends Node
class_name EnemyConfigManager

## DATA-DRIVEN ENEMY CONFIGURATION SYSTEM
## Centralizes all enemy definitions, stats, abilities, and behaviors
## Integrates with EnemyManager for data-oriented spawning

static var instance: EnemyConfigManager

# Enemy configuration database
var enemy_configs: Dictionary = {}
var ability_configs: Dictionary = {}

func _ready():
	instance = self
	_load_enemy_configurations()
	_load_ability_configurations()
	print("📋 EnemyConfigManager initialized with %d enemy types" % enemy_configs.size())

func _load_enemy_configurations():
	# REGULAR ENEMIES
	enemy_configs["twitch_rat"] = {
		"display_name": "Twitch Rat",
		"type": "regular",
		"evolution_from": null,
		"evolution_cost": 0,
		"base_stats": {
			"health": 10.0,
			"damage": 1.0,
			"move_speed": 80.0,
			"attack_range": 60.0,
			"attack_cooldown": 1.0,
			"attack_type": "melee",
			"scale": 1.6
		},
		"abilities": [
			# Explosion, fart, and boost are command-triggered only, not automatic abilities
		],
		"tags": ["Lesser", "TwitchMob", "Rat", "Melee"],
		"visuals": {
			"sprite_path": "res://entities/enemies/regular/twitch_rat/twitch_rat.png",
			"scale": 0.8,
			"light_enabled": false
		},
		"special_mechanics": {
			"boss_buff_affected": true,
			"auto_explode_on_death": false,
			"drops_xp": true,
			"xp_value": 1
		},
		"sounds": {
			"spawn": null,
			"death": null,
			"attack": null
		}
	}
	
	enemy_configs["succubus"] = {
		"display_name": "Succubus",
		"type": "evolved",
		"evolution_from": "twitch_rat",
		"evolution_cost": 10,
		"base_stats": {
			"health": 50.0,
			"damage": 0.0,  # Ability-only damage
			"move_speed": 180.0,
			"attack_range": 300.0,
			"attack_cooldown": 2.0,
			"attack_type": "ranged",
			"scale": 1.0
		},
		"abilities": [
			{"id": "heart_projectile", "cooldown": 2.0, "damage": 10.0},
			{"id": "suction", "cooldown": 5.0, "channel_time": 2.0, "drain_rate": 5.0}
		],
		"tags": ["Enemy", "Flying", "Evolved", "Succubus", "TwitchMob", "Ranged"],
		"visuals": {
			"sprite_path": "res://entities/enemies/regular/succubus/succubus_spritesheet.png",
			"scale": 1.0,
			"light_enabled": false
		},
		"special_mechanics": {
			"boss_buff_affected": true,
			"flying": true,
			"stops_movement_when_channeling": true,
			"drops_xp": true,
			"xp_value": 5
		},
		"sounds": {
			"spawn": null,
			"death": null,
			"attack": null
		}
	}
	
	enemy_configs["woodland_joe"] = {
		"display_name": "Woodland Joe",
		"type": "mini_boss",
		"evolution_from": null,
		"evolution_cost": 0,
		"base_stats": {
			"health": 200.0,
			"damage": 10.0,  # Nerfed from 30.0
			"move_speed": 50.0,
			"attack_range": 60.0,
			"attack_cooldown": 2.0,
			"attack_type": "melee",
			"scale": 2.4  # Doubled from 1.2
		},
		"abilities": [],
		"tags": ["Enemy", "TwitchMob", "WoodlandJoe", "Melee", "Boss"],
		"visuals": {
			"sprite_path": "res://entities/enemies/woodland_joe.png",
			"scale": 2.4,  # Doubled from 1.2
			"light_enabled": true
		},
		"special_mechanics": {
			"boss_buff_affected": false,
			"juggernaut": true,
			"drops_xp": true,
			"xp_value": 5,  # Drops 5 XP orbs
			"multi_xp_drop": true
		},
		"sounds": {
			"spawn": null,
			"death": null,
			"attack": null
		}
	}
	
	enemy_configs["ugandan_warrior"] = {
		"display_name": "Ugandan Warrior",
		"type": "minion",
		"evolution_from": null,
		"evolution_cost": 0,
		"base_stats": {
			"health": 1.0,
			"damage": 1.0,
			"move_speed": 350.0,
			"attack_range": 120.0,
			"attack_cooldown": 0.1,
			"attack_type": "explosive",
			"scale": 0.7
		},
		"abilities": [
			{"id": "suicide_bomb", "damage": 100.0, "radius": 120.0, "telegraph_time": 0.4}
		],
		"tags": ["Enemy", "TwitchMob", "Minion", "UgandanWarrior", "Melee", "Explosive", "Lesser"],
		"visuals": {
			"sprite_path": "res://entities/enemies/special/ugandan_warrior/ugandan_warrior.png",
			"scale": 0.7,
			"light_enabled": false
		},
		"special_mechanics": {
			"boss_buff_affected": false,
			"auto_yell_on_spawn": "GWA GWA GWA GWA!",
			"proximity_explode": true,
			"explode_chance_per_frame": 0.15,
			"drops_xp": false
		},
		"sounds": {
			"spawn": "res://audio/gwa.wav",
			"death": null,
			"attack": null
		}
	}
	
	enemy_configs["horse_enemy"] = {
		"display_name": "Charging Horse",
		"type": "summon",
		"evolution_from": null,
		"evolution_cost": 0,
		"base_stats": {
			"health": 100.0,
			"damage": 50.0,
			"move_speed": 200.0,  # Normal speed
			"attack_range": 1000.0,
			"attack_cooldown": 1.0,  # Telegraph time
			"attack_type": "charge",
			"scale": 1.0
		},
		"abilities": [
			{"id": "telegraph_charge", "telegraph_time": 1.0, "charge_speed": 400.0}
		],
		"tags": ["Enemy", "Horse", "Summon", "Charger", "Lesser"],
		"visuals": {
			"sprite_path": "res://entities/enemies/special/horse_enemy/horse_enemy.png",
			"scale": 1.0,
			"light_enabled": false,
			"telegraph_line": true
		},
		"special_mechanics": {
			"boss_buff_affected": false,
			"single_use_attack": true,
			"despawn_after_attack": true,
			"drops_xp": false
		},
		"sounds": {
			"spawn": null,
			"death": null,
			"attack": "res://audio/horse_charge.wav"
		}
	}
	
	# BOSS ENEMIES
	enemy_configs["thor_enemy"] = {
		"display_name": "Thor",
		"type": "boss",
		"evolution_from": null,
		"evolution_cost": 0,
		"base_stats": {
			"health": 100.0,
			"damage": 1.0,
			"move_speed": 150.0,
			"attack_range": 40.0,
			"attack_cooldown": 1.0,
			"attack_type": "melee",
			"scale": 1.5
		},
		"abilities": [],
		"tags": ["Thor", "Boss", "Melee"],
		"visuals": {
			"sprite_path": "res://entities/enemies/thor_enemy.png",
			"scale": 1.5,
			"light_enabled": true,
			"boss_health_bar": true
		},
		"special_mechanics": {
			"boss_buff_affected": false,
			"voice_lines_interval": 10.0,
			"voice_line_count": 25,
			"drops_xp": true,
			"xp_value": 10
		},
		"sounds": {
			"spawn": null,
			"death": "res://audio/thor_death.wav",
			"attack": null
		},
		"boss_data": {
			"phases": [],
			"death_dialogue": "I... I have been defeated...",
			"spawn_announcement": "Thor has appeared!"
		}
	}
	
	enemy_configs["mika_boss"] = {
		"display_name": "Mika",
		"type": "boss",
		"evolution_from": null,
		"evolution_cost": 0,
		"base_stats": {
			"health": 100.0,
			"damage": 4.0,
			"move_speed": 120.0,
			"attack_range": 50.0,
			"attack_cooldown": 1.0,
			"attack_type": "melee",
			"scale": 1.3
		},
		"abilities": [
			{"id": "dash_attack", "cooldown": 8.0, "range": 200.0, "speed_multiplier": 3.0, "damage_multiplier": 1.5},
			{"id": "summon_allies", "cooldown": 20.0, "minion_count": 3, "minion_type": "twitch_rat"},
			{"id": "enrage", "trigger_hp_percent": 30.0, "speed_multiplier": 1.5, "attack_speed_multiplier": 2.0}
		],
		"tags": ["Boss", "Melee"],
		"visuals": {
			"sprite_path": "res://entities/enemies/mika_boss.png",
			"scale": 1.3,
			"light_enabled": true,
			"boss_health_bar": true
		},
		"special_mechanics": {
			"boss_buff_affected": false,
			"counter_attack_chance": 0.15,
			"phase_system": true,
			"drops_xp": true,
			"xp_value": 15
		},
		"sounds": {
			"spawn": null,
			"death": "res://audio/mika_death.wav",
			"attack": null
		},
		"boss_data": {
			"phases": [
				{"hp_threshold": 100.0, "abilities_unlocked": []},
				{"hp_threshold": 70.0, "abilities_unlocked": ["dash_attack"]},
				{"hp_threshold": 50.0, "abilities_unlocked": ["summon_allies"]},
				{"hp_threshold": 30.0, "abilities_unlocked": ["enrage"]}
			],
			"death_dialogue": "This isn't over...",
			"spawn_announcement": "Mika Boss has entered the arena!"
		}
	}
	
	enemy_configs["zzran_boss"] = {
		"display_name": "ZZran",
		"type": "boss",
		"evolution_from": null,
		"evolution_cost": 0,
		"base_stats": {
			"health": 100.0,
			"damage": 5.0,
			"move_speed": 80.0,
			"attack_range": 70.0,
			"attack_cooldown": 1.5,
			"attack_type": "melee",
			"scale": 1.4
		},
		"abilities": [
			{"id": "oxygen_thief_aura", "radius": 200.0, "damage_percent": 0.30, "tick_rate": 1.0}
		],
		"tags": ["Boss", "Melee"],
		"visuals": {
			"sprite_path": "res://entities/enemies/zzran_boss.png",
			"scale": 1.4,
			"light_enabled": true,
			"boss_health_bar": true,
			"animated": true
		},
		"special_mechanics": {
			"boss_buff_affected": false,
			"voice_lines_with_audio": true,
			"drops_xp": true,
			"xp_value": 20
		},
		"sounds": {
			"spawn": "res://audio/zzran_spawn.wav",
			"death": "res://audio/zzran_death.wav",
			"attack": null
		},
		"boss_data": {
			"phases": [],
			"death_dialogue": "The oxygen... runs... out...",
			"spawn_announcement": "ZZran the Oxygen Thief has awakened!"
		}
	}
	
	enemy_configs["forsen_boss"] = {
		"display_name": "Forsen",
		"type": "major_boss",
		"evolution_from": null,
		"evolution_cost": 0,
		"base_stats": {
			"health": 700.0,
			"damage": 20.0,
			"move_speed": 100.0,
			"attack_range": 60.0,
			"attack_cooldown": 1.0,
			"attack_type": "melee",
			"scale": 1.6
		},
		"abilities": [
			{"id": "summon_swarm", "cooldown": 25.0, "channel_time": 10.0, "chat_interactive": true},
			{"id": "horse_charge", "cooldown": 15.0, "horse_count": 5},
			{"id": "transform_horsen", "trigger_hp_percent": 20.0}
		],
		"tags": ["Forsen", "Melee"],
		"visuals": {
			"sprite_path": "res://entities/enemies/forsen_boss.png",
			"scale": 1.6,
			"light_enabled": true,
			"boss_health_bar": true,
			"super_saiyan_effects": true
		},
		"special_mechanics": {
			"boss_buff_affected": false,
			"chat_integration": true,
			"boss_buff_provider": true,
			"two_phase_fight": true,
			"screen_shake_on_abilities": true,
			"drops_xp": true,
			"xp_value": 50
		},
		"sounds": {
			"spawn": "res://audio/forsen_spawn.wav",
			"death": "res://audio/forsen_death.wav",
			"attack": null
		},
		"boss_data": {
			"phases": [
				{"hp_threshold": 700.0, "form": "forsen"},
				{"hp_threshold": 140.0, "form": "horsen", "health": 200.0, "damage": 10.0, "move_speed": 200.0}
			],
			"death_dialogue": "I was... just pretending...",
			"spawn_announcement": "FORSEN HAS ARRIVED! forsenE",
			"voice_lines": ["I'm not losing to a weebs game dude", "Chat is this real?"]
		}
	}

func _load_ability_configurations():
	# MOVEMENT/UTILITY ABILITIES
	ability_configs["boost"] = {
		"type": "self_buff",
		"duration": 3.0,
		"effects": {
			"speed_multiplier": 3.0
		},
		"visuals": {
			"particle_effect": "res://effects/boost_trail.tscn",
			"color_tint": Color.YELLOW
		}
	}
	
	# OFFENSIVE ABILITIES
	ability_configs["explosion"] = {
		"type": "area_damage",
		"damage": 20.0,
		"radius": 80.0,
		"telegraph_time": 0.2,
		"visuals": {
			"effect_scene": "res://entities/effects/explosion_effect.tscn"
		},
		"sounds": {
			"cast": "res://audio/explosion.wav"
		}
	}
	
	ability_configs["fart"] = {
		"type": "area_damage_over_time",
		"damage": 5.0,
		"radius": 60.0,
		"duration": 5.0,
		"tick_rate": 1.0,
		"visuals": {
			"effect_scene": "res://entities/effects/poison_cloud.tscn"
		},
		"sounds": {
			"cast": "res://audio/fart.wav"
		}
	}
	
	ability_configs["heart_projectile"] = {
		"type": "projectile",
		"damage": 10.0,
		"speed": 200.0,
		"lifetime": 3.0,
		"homing": false,
		"visuals": {
			"projectile_scene": "res://entities/enemies/abilities/heart_projectile.tscn"
		},
		"sounds": {
			"cast": "res://audio/heart_shot.wav"
		}
	}
	
	ability_configs["suction"] = {
		"type": "channeled_drain",
		"channel_time": 2.0,
		"drain_rate": 5.0,
		"range": 150.0,
		"stops_movement": true,
		"visuals": {
			"channel_effect": "res://effects/suction_beam.tscn"
		}
	}
	
	ability_configs["suicide_bomb"] = {
		"type": "self_destruct",
		"damage": 100.0,
		"radius": 120.0,
		"telegraph_time": 0.4,
		"proximity_trigger": true,
		"trigger_chance_per_frame": 0.15,
		"visuals": {
			"telegraph_effect": "res://effects/bomb_warning.tscn",
			"explosion_effect": "res://entities/effects/explosion_effect.tscn"
		}
	}

# Public API
func get_enemy_config(enemy_type: String) -> Dictionary:
	return enemy_configs.get(enemy_type, {})

func get_ability_config(ability_id: String) -> Dictionary:
	return ability_configs.get(ability_id, {})

func get_all_enemy_types() -> Array[String]:
	var types: Array[String] = []
	types.assign(enemy_configs.keys())
	return types

func get_enemies_by_category(category: String) -> Array[String]:
	var result: Array[String] = []
	for enemy_id in enemy_configs:
		var config = enemy_configs[enemy_id]
		if config.get("type", "") == category:
			result.append(enemy_id)
	return result

func get_base_stats(enemy_type: String) -> Dictionary:
	var config = get_enemy_config(enemy_type)
	return config.get("base_stats", {})

func get_enemy_abilities(enemy_type: String) -> Array:
	var config = get_enemy_config(enemy_type)
	return config.get("abilities", [])

func validate_config(enemy_type: String) -> bool:
	var config = get_enemy_config(enemy_type)
	if config.is_empty():
		print("❌ Enemy config not found: %s" % enemy_type)
		return false
	
	var required_fields = ["display_name", "type", "base_stats"]
	for field in required_fields:
		if not config.has(field):
			print("❌ Enemy config missing field '%s': %s" % [field, enemy_type])
			return false
	
	return true

# Integration helpers for V2 system
func apply_config_to_enemy(enemy_id: int, enemy_type: String, enemy_manager: EnemyManager):
	var config = get_enemy_config(enemy_type)
	if config.is_empty():
		print("⚠️ No config found for enemy type: %s" % enemy_type)
		return
	
	var stats = config.get("base_stats", {})
	
	# Apply base stats
	if stats.has("health"):
		enemy_manager.max_healths[enemy_id] = stats.health
		enemy_manager.healths[enemy_id] = stats.health
	if stats.has("damage"):
		enemy_manager.attack_damages[enemy_id] = stats.damage
	if stats.has("move_speed"):
		enemy_manager.move_speeds[enemy_id] = stats.move_speed
	if stats.has("attack_cooldown"):
		enemy_manager.attack_cooldowns[enemy_id] = stats.attack_cooldown
	if stats.has("scale"):
		enemy_manager.scales[enemy_id] = stats.scale
