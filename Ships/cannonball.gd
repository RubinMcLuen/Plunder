extends Area2D

@export var speed = 200
@export var max_distance = 80
@export var splash_scene: PackedScene
@export var hit_scene: PackedScene
@export var trail_scene: PackedScene  # Assign your TrailPixel.tscn here

var shooter: Node = null
var velocity = Vector2.ZERO
var distance_traveled = 0.0
var last_trail_position: Vector2 = Vector2.ZERO

func start(pos: Vector2, direction: Vector2, max_distance: float, shooter: Node, boat_velocity: Vector2 = Vector2.ZERO):
	add_to_group("cannonball2")
	position = pos
	# Add the boat's velocity so the cannonball inherits the ship's movement
	velocity = (boat_velocity * 0.5) + (direction * speed)
	self.max_distance = max_distance
	distance_traveled = 0.0
	self.shooter = shooter
	last_trail_position = pos

func _process(delta: float) -> void:
	var movement = velocity * delta
	position += movement
	distance_traveled += movement.length()

	# Spawn trail pixels along the path
	if trail_scene:
		var distance_since_last = position.distance_to(last_trail_position)
		while distance_since_last >= 1.0:
			var direction_vector = (position - last_trail_position).normalized()
			last_trail_position += direction_vector  # Move 1 pixel along the direction
			var trail = trail_scene.instantiate()
			trail.position = last_trail_position
			get_tree().current_scene.add_child(trail)
			distance_since_last = position.distance_to(last_trail_position)

	if distance_traveled > max_distance:
		create_splash_effect()
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	# Ignore collisions with the shooter
	if area == shooter:
		return
	# If the colliding area has a take_damage() method, apply damage.
	if area.has_method("take_damage"):
		area.take_damage(1)
		create_hit_effect()
		queue_free()

func create_splash_effect() -> void:
	if splash_scene:
		var splash = splash_scene.instantiate()
		splash.position = position
		get_tree().current_scene.add_child(splash)
	#if shooter and shooter.has_method("request_splash_sound"):
		#shooter.request_splash_sound()

func create_hit_effect() -> void:
	if hit_scene:
		var hit = hit_scene.instantiate()
		hit.position = position
		get_tree().current_scene.add_child(hit)
	if shooter and shooter.has_method("request_hit_sound"):
		shooter.request_hit_sound()
