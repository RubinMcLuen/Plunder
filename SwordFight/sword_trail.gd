extends Line2D

#
# ---------------------- CONSTANTS ----------------------
#
const MAX_POINTS: int = 6
const FADE_SPEED: float = 1.5

#
# ---------------------- VARIABLES ----------------------
#
var is_drawing: bool = false
var trail_opacity: float = 1.0

#
# ---------------------- LIFECYCLE ----------------------
#

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Begin drawing
				is_drawing = true
				trail_opacity = 1.0
				modulate = Color(1, 1, 1, trail_opacity)
				clear_points()
				add_trail_point(to_local(get_global_mouse_position()))
			else:
				# Mouse button released
				is_drawing = false

	elif event is InputEventMouseMotion:
		if is_drawing:
			add_trail_point(to_local(get_global_mouse_position()))


func _process(delta: float) -> void:
	# If not drawing, fade out the current trail until fully transparent.
	if not is_drawing and points.size() > 0:
		trail_opacity -= FADE_SPEED * delta
		if trail_opacity <= 0.0:
			clear_points()
		else:
			modulate = Color(1, 1, 1, trail_opacity)

#
# ---------------------- METHODS ------------------------
#

func add_trail_point(position: Vector2) -> void:
	add_point(position)
	if points.size() > MAX_POINTS:
		remove_point(0)
