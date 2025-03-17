extends Node2D

@export var fade_time: float = 0.5  # Duration for the fade (in seconds)
var elapsed: float = 0.0

func _ready() -> void:
	z_index = -2  # Lower than the cannonball's z_index (assumed 0)

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()  # Use queue_redraw() in Godot 4
	if elapsed >= fade_time:
		queue_free()

func _draw() -> void:
	# Start at 50% opacity and fade linearly to 0 over fade_time seconds.
	var alpha = 0.1 * (1.0 - elapsed / fade_time)
	# Offset the rectangle by (-0.5, -0.5) to center the 1x1 pixel on the node's position.
	draw_rect(Rect2(Vector2(-0.5, -0.5), Vector2.ONE), Color(1, 1, 1, alpha))

