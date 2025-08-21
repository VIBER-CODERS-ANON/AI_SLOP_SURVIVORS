extends Node
class_name SystemInitializer

## Handles initialization of all game systems in proper order

signal systems_initialized()

func initialize_all_systems(parent: Node):
	# Audio Manager
	_create_and_add_system(parent, "AudioManager", AudioManager.new())
	
	# NPC Rarity Manager
	_create_and_add_system(parent, "NPCRarityManager", 
		preload("res://systems/npc_rarity_system/npc_rarity_manager.gd").new())
	
	# Impact Sound System
	_create_and_add_system(parent, "ImpactSoundSystem", 
		preload("res://systems/weapon_system/impact_sound_system.gd").new())
	
	# MXP Manager
	_create_and_add_system(parent, "MXPManager", MXPManager.new())
	
	# MXP Modifier Manager
	_create_and_add_system(parent, "MXPModifierManager", MXPModifierManager.new())
	
	# Chatter Entity Manager
	_create_and_add_system(parent, "ChatterEntityManager", ChatterEntityManager.new())
	
	# Settings Manager
	_create_and_add_system(parent, "SettingsManager", 
		preload("res://systems/managers/settings_manager.gd").new())
	
	# Camera Shake System
	_create_and_add_system(parent, "CameraShake", 
		preload("res://systems/core/camera_shake.gd").new())
	
	# Boss Vote Manager
	_create_and_add_system(parent, "BossVoteManager", 
		preload("res://systems/managers/boss_vote_manager.gd").new())
	
	# Ticket Spawn Manager
	_create_and_add_system(parent, "TicketSpawnManager", 
		preload("res://systems/core/ticket_spawn_manager.gd").new())
	
	# Enemy Config Manager
	_create_and_add_system(parent, "EnemyConfigManager", 
		preload("res://systems/core/enemy_config_manager.gd").new())
	
	# Enemy Manager
	_create_and_add_system(parent, "EnemyManager", 
		preload("res://systems/core/enemy_manager.gd").new())
	
	# Enemy Bridge
	_create_and_add_system(parent, "EnemyBridge", 
		preload("res://systems/core/enemy_bridge.gd").new())
	
	# Enemy Nameplate Manager
	_create_and_add_system(parent, "EnemyNameplateManager", 
		preload("res://systems/detection/enemy_nameplate_manager.gd").new())
	
	# Flocking System
	_create_and_add_system(parent, "FlockingSystem", 
		preload("res://systems/detection/flocking_system.gd").new())
	
	# Boss Buff Manager
	_create_and_add_system(parent, "BossBuffManager", 
		preload("res://systems/managers/boss_buff_manager.gd").new())
	
	# Evolution System
	_create_and_add_system(parent, "EvolutionSystem", 
		preload("res://systems/evolution_system/evolution_system.gd").new())
	
	systems_initialized.emit()
	print("🔧 All game systems initialized!")

func _create_and_add_system(parent: Node, system_name: String, system_instance: Node):
	system_instance.name = system_name
	parent.add_child(system_instance)
	print("   ✓ %s initialized" % system_name)