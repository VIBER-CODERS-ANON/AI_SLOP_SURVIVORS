extends BaseBoss
class_name ThorEnemy

## THOR - Simple tank boss with voice lines

@export var voice_line_cooldown: float = 10.0

var voice_line_timer: float = 0.0
var voice_lines = [
	"I'm out of mana!",
	"Run doesn't mean 'every man for himself.' Run means run as a team.",
	"They said run, he ran. They stayed to fight.",
	"Run means get the party out of the dungeon. As a group.",
	"You still try and help the others get out.",
	"He could've drop-ped a rank 1 Blizzard and gotten out safely.",
	"Mage in a panic? Nova, then run.",
	"Survivors survive.",
	"Roaches survive.",
	"Buddy, you do not play HC. Run means get out.",
	"If someone is just yelling 'run' over and over, most people will run for their lives.",
	"my dad works at blizzard",
	"7 years",
	"first second generation by the way",
	"i literally made mr robot tv show",
	"my third puberty is coming you better watch out"
]

func _ready():
	# Set Thor specific properties
	boss_name = "THOR"
	boss_title = "The Coward"
	boss_health = 100.0
	boss_damage = 1.0
	boss_move_speed = 150.0
	boss_attack_range = 40.0
	boss_attack_cooldown = 0.8
	boss_scale = 1.0
	custom_modulate = Color(0.8, 0.8, 1.0)
	
	# Set attack type
	attack_type = AttackType.MELEE
	
	# Load sprite
	sprite_texture = preload("res://entities/enemies/bosses/thor/pirate_skull.png")
	
	# Call parent ready
	super._ready()
	
	# Add tags
	if taggable:
		taggable.add_tag("Thor")
		taggable.add_tag("Boss")
		taggable.add_tag("Melee")
	
	# Start voice timer
	voice_line_timer = voice_line_cooldown

func _entity_physics_process(delta: float):
	super._entity_physics_process(delta)
	
	# Update voice line timer
	if voice_line_timer > 0:
		voice_line_timer -= delta
	else:
		_play_random_voice_line()
		voice_line_timer = voice_line_cooldown

func _play_random_voice_line():
	if voice_lines.is_empty():
		return
	var random_line = voice_lines[randi() % voice_lines.size()]
	speak_dialogue(random_line)

func die():
	speak_dialogue("Should've run...")
	super.die()
