extends AnimatedSprite2D

var velocity: Vector2 = Vector2.ZERO

func start(boat_velocity: Vector2) -> void:
	velocity = boat_velocity * 0.5
	play()

func _process(delta: float) -> void:
	position += velocity * delta

func _on_animation_finished() -> void:
	queue_free()
