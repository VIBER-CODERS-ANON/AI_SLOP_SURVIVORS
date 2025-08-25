extends Node
class_name BossBuffManager

static var instance: BossBuffManager

signal buff_applied(boss_name: String, buff_description: String)

# Active buffs for the session (no stacking - each boss spawns only once)
var active_buffs: Dictionary = {
	"zzran_death_explode_chance": 0.0,  # 25% chance when ZZran spawns (nerfed from 50%)
	"mika_speed_multiplier": 1.0,        # 1.5x speed when Mika spawns
	"thor_coward_applied": false,        # Coward tag applied when THOR spawns
	"forsen_warrior_summon_enabled": false  # 1% chance to summon warriors on forsen emotes
}

# Boss buff definitions
var boss_buffs: Dictionary = {
	"zzran": {
		"name": "Death Explosion",
		"description": "25% chance to auto-explode on death",
		"apply_func": "_apply_zzran_buff"
	},
	"mika": {
		"name": "Swift Strike", 
		"description": "1.5x movement speed for all entities",
		"apply_func": "_apply_mika_buff"
	},
	"thor": {
		"name": "Cowardice Curse",
		"description": "All entities gain the Coward tag",
		"apply_func": "_apply_thor_buff"
	},
	"forsen": {
		"name": "Forsen's Influence",
		"description": "1% chance to summon warriors on Forsen emotes",
		"apply_func": "_apply_forsen_buff"
	}
}

func _ready():
	instance = self
	print("🎯 Boss Buff Manager initialized!")

func apply_boss_buff(boss_id: String):
	var buff_data = boss_buffs.get(boss_id)
	if not buff_data:
		print("⚠️ No buff defined for boss: ", boss_id)
		return
	
	# Call the appropriate buff function
	call(buff_data.apply_func)
	
	# Announce the buff
	var action_feed = _get_action_feed()
	if action_feed:
		action_feed.add_message("💪 BOSS BUFF: %s - %s" % [buff_data.name, buff_data.description], Color(1, 0.8, 0))
	
	buff_applied.emit(boss_id, buff_data.description)
	print("💪 Applied boss buff for %s: %s" % [boss_id, buff_data.name])
	
	# Apply to all existing entities
	_apply_to_existing_entities()

func _apply_zzran_buff():
	# Set 25% death explosion chance (no stacking) - nerfed from 50%
	active_buffs.zzran_death_explode_chance = 0.25
	print("💥 Death explosion chance activated: 25%")

func _apply_mika_buff():
	# Set speed to 1.5x (no stacking)
	active_buffs.mika_speed_multiplier = 1.5
	print("💨 Speed multiplier activated: 1.5x")

func _apply_thor_buff():
	# Apply coward tag (only once)
	active_buffs.thor_coward_applied = true
	print("😱 Coward tag applied to all entities")

func _apply_forsen_buff():
	# Enable warrior summons from chat
	active_buffs.forsen_warrior_summon_enabled = true
	print("🎮 Forsen emote warrior summons enabled!")
	
	# Connect to chat system for monitoring
	_setup_forsen_chat_listener()

func _apply_to_existing_entities():
	# Apply buffs to all existing twitch rats
	var entities = get_tree().get_nodes_in_group("twitch_rats")
	for entity in entities:
		if is_instance_valid(entity):
			apply_buffs_to_entity(entity)

func apply_buffs_to_entity(entity: Node):
	# Apply speed multiplier
	if active_buffs.mika_speed_multiplier > 1.0 and entity.has_method("set_boss_speed_multiplier"):
		entity.set_boss_speed_multiplier(active_buffs.mika_speed_multiplier)
	
	# Apply coward tag if THOR has spawned
	if active_buffs.thor_coward_applied:
		var taggable = entity.get_node_or_null("Taggable")
		if taggable and not taggable.has_tag("Coward"):
			taggable.add_tag("Coward")
	
	# Death explosion is handled in the entity's die() method

func should_auto_explode_on_death() -> bool:
	if active_buffs.zzran_death_explode_chance <= 0:
		return false
	return randf() < active_buffs.zzran_death_explode_chance

func get_total_speed_multiplier() -> float:
	return active_buffs.mika_speed_multiplier

func get_active_buff_summary() -> String:
	var summary = []
	
	if active_buffs.zzran_death_explode_chance > 0:
		summary.append("💥 25% death explosion")
	
	if active_buffs.mika_speed_multiplier > 1.0:
		summary.append("💨 1.5x speed")
	
	if active_buffs.thor_coward_applied:
		summary.append("😱 Coward tag")
	
	if active_buffs.forsen_warrior_summon_enabled:
		summary.append("🎮 Forsen warrior summons")
	
	if summary.is_empty():
		return "No active boss buffs"
	
	return "Boss Buffs: " + ", ".join(summary)

func _get_action_feed() -> Node:
	var game_controller = get_node_or_null("/root/GameController")
	if game_controller:
		return game_controller.get_node_or_null("UILayer/ActionFeed")
	return null

func _setup_forsen_chat_listener():
	# Connect to game controller's chat system
	var game_controller = get_node_or_null("/root/GameController")
	if game_controller and game_controller.has_signal("chat_message_received"):
		if not game_controller.is_connected("chat_message_received", _on_forsen_buff_chat_message):
			game_controller.chat_message_received.connect(_on_forsen_buff_chat_message)

func _on_forsen_buff_chat_message(username: String, message: String, _user_color: Color):
	if not active_buffs.forsen_warrior_summon_enabled:
		return
	
	# Check if message contains forsen emotes
	var forsen_emotes = ["forsen", "forsene", "forsenE", "OMEGALUL", "LULW", "ZULUL", "Pepega"]
	var has_forsen_emote = false
	
	for emote in forsen_emotes:
		if emote.to_lower() in message.to_lower():
			has_forsen_emote = true
			break
	
	if has_forsen_emote:
		# 1% chance to summon warrior
		if randf() < 0.01:
			_summon_forsen_buff_warrior(username)

func _summon_forsen_buff_warrior(summoner_name: String):
	# Find a random chatter entity to spawn the warrior near
	var chatters = get_tree().get_nodes_in_group("twitch_mob")
	if chatters.is_empty():
		return
	
	var random_chatter = chatters[randi() % chatters.size()]
	
	# Spawn ugandan warrior using resource system
	var warrior_resource = load("res://resources/enemies/ugandan_warrior.tres")
	if warrior_resource:
		# Position near the random chatter
		var angle = randf() * TAU
		var distance = randf_range(50, 100)
		var offset = Vector2(cos(angle), sin(angle)) * distance
		var spawn_position = random_chatter.global_position + offset
		
		# Spawn via EnemyManager
		if EnemyManager.instance:
			var warrior_id = EnemyManager.instance.spawn_from_resource(warrior_resource, spawn_position, summoner_name + "'s Buff Warrior")
			if warrior_id >= 0:
				print("✅ Boss buff spawned Ugandan Warrior for %s" % summoner_name)
			else:
				print("❌ Failed to spawn boss buff Ugandan Warrior for %s" % summoner_name)
		
		# Announce in action feed
		var action_feed = _get_action_feed()
		if action_feed:
			action_feed.add_message("🎮 %s summoned a warrior! (Forsen Buff)" % summoner_name, Color(0.8, 0.2, 0.8))
