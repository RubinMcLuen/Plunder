extends Area2D

@export var speed = 200
@export var max_distance = 80
@export var splash_scene: PackedScene
@export var hit_scene: PackedScene

# Use 'shooter' instead of 'owner' to avoid redefining Area2D.owner.
var shooter: Node = null

var velocity = Vector2.ZERO
var distance_traveled = 0.0

func start(pos: Vector2, direction: Vector2, max_distance: float, shooter: Node):
	position = pos
	velocity = direction * speed
	self.max_distance = max_distance  # Set max distance based on parameter
	distance_traveled = 0.0
	self.shooter = shooter  # Store the shooter reference

func _process(delta: float):
	var movement = velocity * delta
	position += movement
	distance_traveled += movement.length()
	
	if distance_traveled > max_distance:
		create_splash_effect()
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	# Ignore collisions with the shooter.
	if area == shooter:
		return
	# If the colliding area has a take_damage() method, apply damage.
	if area.has_method("take_damage"):
		area.take_damage(1)  # Default damage value; adjust as needed.
		create_hit_effect()
		queue_free()

func create_splash_effect():
	if splash_scene:
		var splash = splash_scene.instantiate()
		splash.position = position
		get_tree().current_scene.add_child(splash)

func create_hit_effect():
	if hit_scene:
		var hit = hit_scene.instantiate()
		hit.position = position
		get_tree().current_scene.add_child(hit)
