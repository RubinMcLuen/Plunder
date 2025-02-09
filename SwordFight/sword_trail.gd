extends Line2D

# Maximum number of points in the trail
const MAX_POINTS = 6
# How quickly the trail fades (adjust as needed)
const FADE_SPEED = 1.5

var is_drawing = false
var trail_opacity = 1.0

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_drawing = true
				trail_opacity = 1.0  # Reset opacity when starting a new trail
				modulate = Color(1, 1, 1, trail_opacity)  # Apply full opacity
				clear_points()  # Start with a fresh trail
				add_trail_point(to_local(get_global_mouse_position()))


			else:
				is_drawing = false
	elif event is InputEventMouseMotion and is_drawing:
		add_trail_point(to_local(get_global_mouse_position()))



func add_trail_point(position: Vector2):
	# Add a new point to the trail
	add_point(position)
	if points.size() > MAX_POINTS:
		remove_point(0)

func _process(delta):
	if not is_drawing and points.size() > 0:
		# Gradually fade out the trail
		trail_opacity -= FADE_SPEED * delta
		if trail_opacity <= 0:
			clear_points()
		else:
			modulate = Color(1, 1, 1, trail_opacity)
