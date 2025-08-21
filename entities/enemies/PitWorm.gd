extends CharacterBody2D
class_name PitWorm

@export var emerge_range: float = 200.0  # Distance to player to trigger emergence
@export var retreat_range: float = 250.0  # Distance to retreat back to pit
@export var attack_range: float = 50.0  # Distance to damage player
@export var move_speed: float = 80.0
@export var damage: float = 1.0
@export var max_health: float = 30.0

var home_pit_position: Vector2
var player_ref: Node2D
var current_health: float
var state: String = "hidden"  # hidden, emerging, active, retreating

# Animation states
var emerge_progress: float = 0.0
var retreat_progress: float = 0.0
var last_attack_time: float = 0.0
var attack_cooldown: float = 1.0  # Attack once per second

func _ready():
    current_health = max_health
    add_to_group("enemies")
    
    # Create animated sprite
    var sprite = AnimatedSprite2D.new()
    sprite.name = "Sprite"
    
    # Create SpriteFrames resource
    var frames = SpriteFrames.new()
    frames.add_animation("idle")
    frames.add_animation("move")
    
    # Load your sprite sheet
    var texture = load("res://entities/enemies/worm.png")
    
    # Correct dimensions for your sprite
    var frame_width = 48   # Each frame is 48 pixels wide
    var frame_height = 48  # Each frame is 48 pixels tall
    
    # Add idle frame (top-left frame)
    var idle_frame = AtlasTexture.new()
    idle_frame.atlas = texture
    idle_frame.region = Rect2(0, 0, frame_width, frame_height)
    frames.add_frame("idle", idle_frame)
    
    # Add movement frames (all 6 frames for smooth animation)
    for row in range(3):  # 3 rows
        for col in range(2):  # 2 columns
            var atlas = AtlasTexture.new()
            atlas.atlas = texture
            atlas.region = Rect2(col * frame_width, row * frame_height, frame_width, frame_height)
            frames.add_frame("move", atlas)
    
    frames.set_animation_speed("move", 8)  # Adjust speed as needed
    
    sprite.sprite_frames = frames
    sprite.play("idle")
    sprite.scale = Vector2(0.75, 0.75)  # Scale down a bit (48px might be too big)
    sprite.z_index = 68  # Make sure it's visible above ground
    add_child(sprite)
    
    # Update collision to match sprite size
    var collision = CollisionShape2D.new()
    var shape = CapsuleShape2D.new()
    shape.radius = 12  # Smaller collision for 48px sprite scaled to 0.75
    shape.height = 24
    collision.shape = shape
    add_child(collision)
    
    # Store reference to sprite for animation
    set_meta("sprite", sprite)
    
    # Start hidden
    visible = false
    collision_layer = 0

func initialize(pit_pos: Vector2, player: Node2D):
    home_pit_position = pit_pos
    player_ref = player
    global_position = pit_pos
func _physics_process(delta):
    print(player_ref)
    if not player_ref or not is_instance_valid(player_ref):
        return
    
    var distance_to_player = global_position.distance_to(player_ref.global_position)

    match state:
        "hidden":
            if distance_to_player < emerge_range:
                _start_emerging()
        
        "emerging":
            _update_emerging(delta)
        
        "active":
            var distance_from_home = global_position.distance_to(home_pit_position)
            if distance_to_player > retreat_range or distance_from_home > 150.0:
                _start_retreating()
            else:
                _chase_player(delta)
                _check_attack()
        
        "retreating":
            _update_retreating(delta)

func _start_emerging():
    state = "emerging"
    visible = true
    emerge_progress = 0.0
    
    var sprite = get_node("Sprite")
    sprite.play("move")  # Start animation when emerging
    
    # Create emerge particles/effect
    _create_dirt_effect()

func _update_emerging(delta):
    emerge_progress += delta * 2.0
    
    if emerge_progress >= 1.0:
        emerge_progress = 1.0
        state = "active"
        collision_layer = 2  # Enable collision
    
    # Animate emerging
    var sprite = get_meta("sprite")
    sprite.position.y = lerp(40.0, 0.0, emerge_progress)  # Rise from ground
    modulate.a = emerge_progress
    sprite.scale = Vector2.ONE * emerge_progress

func _chase_player(delta):
    if not player_ref:
        return
    
    var direction = (player_ref.global_position - global_position).normalized()
    velocity = direction * move_speed
    move_and_slide()
    
    # Get animated sprite and play animation
    var sprite = get_node("Sprite")  # Get it as node, not from meta
    sprite.play("move")  # Play the move animation!
    
    # Face player (AnimatedSprite2D uses flip_h differently)
    if direction.x < 0:
        sprite.scale.x = abs(sprite.scale.x) * -1  # Flip by scaling
    else:
        sprite.scale.x = abs(sprite.scale.x)  # Normal direction

func _check_attack():
    # Check if enough time has passed since last attack
    var current_time = Time.get_ticks_msec() / 1000.0
    if current_time - last_attack_time < attack_cooldown:
        return  # Still on cooldown
    
    if global_position.distance_to(player_ref.global_position) < attack_range:
        if player_ref.has_method("take_damage"):
            player_ref.take_damage(damage)  # Use actual damage value (not 0)
            last_attack_time = current_time  # Reset cooldown
            
            # Optional: Visual feedback for attack
            var sprite = get_node("Sprite")
            sprite.modulate = Color(1.5, 1.0, 1.0)  # Flash red
            create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.2)

func _start_retreating():
    state = "retreating"
    retreat_progress = 0.0
    collision_layer = 0
    
    var sprite = get_node("Sprite")
    sprite.play("idle")  # or sprite.stop() to pause

func _update_retreating(delta):
    retreat_progress += delta * 2.0
    
    # Move back to pit
    global_position = global_position.lerp(home_pit_position, delta * 3.0)
    
    # Animate burrowing
    var sprite = get_meta("sprite")
    sprite.position.y = lerp(0.0, 20.0, retreat_progress)
    modulate.a = 1.0 - retreat_progress
    
    if retreat_progress >= 1.0:
        state = "hidden"
        visible = false
        global_position = home_pit_position

func _create_dirt_effect():
    # Create particle effect for emerging
    var particles = CPUParticles2D.new()
    particles.emitting = true
    particles.amount = 20
    particles.lifetime = 0.5
    particles.one_shot = true
    particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
    particles.spread = 45.0
    particles.initial_velocity_min = 50.0
    particles.initial_velocity_max = 100.0
    particles.angular_velocity_min = -180.0
    particles.angular_velocity_max = 180.0
    particles.scale_amount_min = 0.5
    particles.scale_amount_max = 1.0
    particles.color = Color(0.4, 0.3, 0.2, 1.0)  # Brown dirt
    add_child(particles)
    
    # Auto-remove particles
    particles.finished.connect(func(): particles.queue_free())

func take_damage(amount: float):
    current_health -= amount
    
    # Flash red when hit
    modulate = Color(1.5, 0.5, 0.5, 1.0)
    create_tween().tween_property(self, "modulate", Color.WHITE, 0.2)
    
    if current_health <= 0:
        _die()

func _die():
    # Death effect and cleanup
    queue_free()