extends Camera2D
class_name BoardingCamera

@export_range(1.0, 2.0, 0.1) var min_zoom: float = 1.0
@export_range(1.0, 2.0, 0.1) var max_zoom: float = 2.0
@export var zoom_speed: float = 0.1
@export var boundary_area_path: NodePath

var _dragging: bool = false
var _boundary_rect: Rect2

func _ready() -> void:
	zoom = Vector2.ONE
	# Build the world‐space clamp rect from the Area2D + CollisionShape2D
	var area = get_node(boundary_area_path) as Area2D
	var cs   = area.get_node("CollisionShape2D") as CollisionShape2D
	var shape = cs.shape as RectangleShape2D
	# Use the collision shape's global_position:
	var world_center = cs.global_position
	var extents      = shape.extents
	_boundary_rect = Rect2(world_center - extents, extents * 2)
	# Optional debug
	# print("_boundary_rect = ", _boundary_rect)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
			return
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom_toward_cursor( zoom_speed)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_toward_cursor(-zoom_speed)
			return

	if event is InputEventMouseMotion and _dragging:
		# slower pan when zoomed in, faster when zoomed out
		global_position -= event.relative / zoom.x

		# then clamp to edges as before
		var screen_size: Vector2  = get_viewport_rect().size
		var half_extents: Vector2 = screen_size * 0.5 / zoom.x

		var left   = _boundary_rect.position.x + half_extents.x
		var right  = _boundary_rect.position.x + _boundary_rect.size.x - half_extents.x
		var top    = _boundary_rect.position.y + half_extents.y
		var bottom = _boundary_rect.position.y + _boundary_rect.size.y - half_extents.y

		global_position.x = clamp(global_position.x, left,  right)
		global_position.y = clamp(global_position.y, top,   bottom)



func _zoom_toward_cursor(delta: float) -> void:
	var old_z: float = zoom.x
	var new_z: float = clamp(old_z + delta, min_zoom, max_zoom)
	var world_before: Vector2 = get_global_mouse_position()
	zoom = Vector2(new_z, new_z)
	var world_after: Vector2  = get_global_mouse_position()
	global_position += (world_before - world_after)
	_clamp_camera_edges()  # ← clamp after zoom so you can't overshoot

func _clamp_camera_edges() -> void:
	var screen_size: Vector2    = get_viewport_rect().size
	var half_extents: Vector2   = screen_size * 0.5 / zoom.x
	var left   = _boundary_rect.position.x + half_extents.x
	var right  = _boundary_rect.position.x + _boundary_rect.size.x - half_extents.x
	var top    = _boundary_rect.position.y + half_extents.y
	var bottom = _boundary_rect.position.y + _boundary_rect.size.y - half_extents.y

	global_position.x = clamp(global_position.x, left,  right)
	global_position.y = clamp(global_position.y, top,   bottom)

