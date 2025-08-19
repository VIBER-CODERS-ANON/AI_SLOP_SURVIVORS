class_name GameConfig
extends Resource

## Centralized game configuration and constants
## This class holds all game-wide constants and configuration values

# Screen and viewport settings
const SCREEN_WIDTH: int = 2560
const SCREEN_HEIGHT: int = 1440
const DEFAULT_VIEWPORT_SIZE: Vector2 = Vector2(2560, 1440)

# Player settings
const PLAYER_BASE_HEALTH: float = 20.0
const PLAYER_BASE_SPEED: float = 300.0
const PLAYER_BASE_PICKUP_RANGE: float = 100.0
const PLAYER_BASE_CRIT_CHANCE: float = 0.05
const PLAYER_BASE_CRIT_DAMAGE: float = 2.0
const PLAYER_BASE_MANA: float = 100.0
const PLAYER_MANA_REGEN_PER_SECOND: float = 1.0
const PLAYER_INVINCIBILITY_TIME: float = 0.1
const PLAYER_SPRITE_SCALE: float = 0.9

# Enemy settings
const ENEMY_DEFAULT_AGGRO_RADIUS: float = 1500.0  # Screen-sized
const ENEMY_DEFAULT_DEAGGRO_RADIUS: float = 2000.0
const ENEMY_DEFAULT_WANDER_RADIUS: float = 100.0
const ENEMY_DEFAULT_WANDER_SPEED: float = 50.0
const ENEMY_DEFAULT_WANDER_INTERVAL: float = 2.0

# Combat settings
const COMBAT_TIMEOUT: float = 3.0  # Exit combat after 3 seconds of no damage
const DOT_HIT_SOUND_COOLDOWN: float = 2.0  # Cooldown between DoT hit sounds
const DEFAULT_KNOCKBACK_FORCE: float = 200.0
const DEFAULT_STUN_DURATION: float = 0.5

# Ability settings
const ABILITY_DEFAULT_COOLDOWN: float = 1.0
const DASH_BASE_COOLDOWN: float = 2.0
const DASH_BASE_DISTANCE: float = 300.0
const DASH_BASE_DURATION: float = 0.2

# Weapon settings
const WEAPON_BASE_DAMAGE: float = 5.0
const WEAPON_BASE_ATTACK_SPEED: float = 1.0
const WEAPON_BASE_RANGE: float = 100.0

# Pickup settings
const XP_ORB_VALUE: int = 1
const XP_ORB_ATTRACTION_RANGE: float = 150.0
const XP_ORB_ATTRACTION_SPEED: float = 500.0
const HEALTH_ORB_HEAL_AMOUNT: float = 5.0

# Boss settings
const BOSS_HEALTH_MULTIPLIER: float = 10.0
const BOSS_DAMAGE_MULTIPLIER: float = 2.0
const BOSS_SPAWN_INTERVAL: float = 60.0

# Wave settings
const WAVE_SPAWN_INTERVAL: float = 30.0
const WAVE_BASE_ENEMY_COUNT: int = 5
const WAVE_ENEMY_INCREMENT: int = 2

# Experience and leveling
const XP_BASE_REQUIREMENT: int = 10
const XP_REQUIREMENT_MULTIPLIER: float = 1.5
const XP_REQUIREMENT_ADDITIVE: int = 5

# UI settings
const UI_ANIMATION_DURATION: float = 0.3
const UI_FADE_DURATION: float = 0.5
const DAMAGE_NUMBER_RISE_SPEED: float = 100.0
const DAMAGE_NUMBER_LIFETIME: float = 1.0

# Audio settings
const AUDIO_MASTER_VOLUME: float = 0.0  # in dB
const AUDIO_MUSIC_VOLUME: float = -10.0  # in dB
const AUDIO_SFX_VOLUME: float = -5.0  # in dB

# Collision layers
enum CollisionLayer {
	WORLD = 1,
	PLAYER = 2,
	ENEMIES = 4,
	PROJECTILES = 8,
	PICKUPS = 16,
	ENVIRONMENT = 32
}

# Collision masks - what each layer collides with
const PLAYER_COLLISION_MASK: int = CollisionLayer.WORLD | CollisionLayer.ENEMIES | CollisionLayer.PICKUPS
const ENEMY_COLLISION_MASK: int = CollisionLayer.WORLD | CollisionLayer.PLAYER | CollisionLayer.PROJECTILES
const PROJECTILE_COLLISION_MASK: int = CollisionLayer.WORLD | CollisionLayer.ENEMIES
const PICKUP_COLLISION_MASK: int = CollisionLayer.PLAYER

# Groups
const GROUP_PLAYER: String = "player"
const GROUP_ENEMIES: String = "enemies"
const GROUP_PROJECTILES: String = "projectiles"
const GROUP_PICKUPS: String = "pickups"
const GROUP_UI: String = "ui"

# Tags
const TAG_PLAYER: String = "Player"
const TAG_ENEMY: String = "Enemy"
const TAG_BOSS: String = "Boss"
const TAG_ELITE: String = "Elite"
const TAG_LESSER: String = "Lesser"
const TAG_UNIQUE: String = "Unique"

# Resource paths
const PATH_XP_ORB_SCENE: String = "res://entities/pickups/xp_orb.tscn"
const PATH_HEALTH_ORB_SCENE: String = "res://entities/pickups/health_orb.tscn"
const PATH_DAMAGE_NUMBER_SCENE: String = "res://ui/damage_number.tscn"

# Helper functions for experience calculation
static func calculate_experience_to_next_level(level: int) -> int:
	return int(XP_BASE_REQUIREMENT * pow(XP_REQUIREMENT_MULTIPLIER, level - 1)) + (XP_REQUIREMENT_ADDITIVE * (level - 1))

# Helper function for boss stats
static func calculate_boss_health(base_health: float) -> float:
	return base_health * BOSS_HEALTH_MULTIPLIER

static func calculate_boss_damage(base_damage: float) -> float:
	return base_damage * BOSS_DAMAGE_MULTIPLIER