extends Node2D

## Simple visual drawer for attack areas
## Used by abilities to show attack ranges/areas

var points: PackedVector2Array = []
var color: Color = Color.RED
var duration: float = 0.2
var fade_time: float = 0.1

var time_remaining: float = 0.0
var current_alpha: float = 1.0

func _ready() -> void:
	z_index = 100  # Draw on top
	time_remaining = duration
	set_process(true)

func _process(delta: float) -> void:
	time_remaining -= delta
	
	# Start fading when time is almost up
	if time_remaining < fade_time:
		current_alpha = time_remaining / fade_time
	
	# Remove when done
	if time_remaining <= 0:
		queue_free()
	
	queue_redraw()

func _draw() -> void:
	if points.size() < 3:
		return
	
	# Draw filled polygon with current alpha
	var draw_color = color
	draw_color.a *= current_alpha
	draw_polygon(points, [draw_color])
	
	# Draw outline
	var outline_color = draw_color
	outline_color.a = min(1.0, draw_color.a * 2)
	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], outline_color, 2.0)
	if points.size() > 2:
		draw_line(points[points.size() - 1], points[0], outline_color, 2.0)
