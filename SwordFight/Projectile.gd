extends Area2D
class_name Projectile

var speed: float = 20.0
var velocity: Vector2 = Vector2.ZERO
var target_coordinates: Vector2 = Vector2(240, 135)
var is_dragging: bool = false
var has_entered: bool = false

signal reached_target

func _ready():
	print("DEBUG: Projectile _ready() called; rotation =", rotation)
	velocity = Vector2.LEFT.rotated(rotation) * speed

	# Mouse signals for "slash" logic
	connect("mouse_entered", Callable(self, "_on_mouse_entered"))
	connect("mouse_exited", Callable(self, "_on_mouse_exited"))

	# Check if the mouse is already pressed at spawn
	is_dragging = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

func _process(delta: float) -> void:
	position += velocity * delta

	if is_at_target_position():
		print("DEBUG: Projectile reached target position at", position)
		emit_signal("reached_target", self)
		queue_free()

func is_at_target_position() -> bool:
	return position.distance_to(target_coordinates) < 1.0


func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		is_dragging = event.pressed
		if not is_dragging:
			has_entered = false

func _on_mouse_entered():
	if is_dragging:
		has_entered = true
		print("DEBUG: Mouse entered projectile; is_dragging =", is_dragging)

func _on_mouse_exited():
	if is_dragging and has_entered:
		print("DEBUG: Mouse exited projectile after entering; queuing free")
		queue_free()

func _exit_tree():
	print("DEBUG: Projectile _exit_tree called")
