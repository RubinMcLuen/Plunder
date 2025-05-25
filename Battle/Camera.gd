extends Camera2D
class_name BoardingCamera

@export_range(1.0, 2.0, 0.1) var min_zoom: float = 1.0
@export_range(1.0, 2.0, 0.1) var max_zoom: float = 2.0
@export var zoom_speed: float = 0.1
@export var boundary_area_path: NodePath

var _dragging := false
var _boundary_rect: Rect2

func _ready() -> void:
	zoom = Vector2.ONE
	var area  := get_node(boundary_area_path) as Area2D
	var cs    := area.get_node("CollisionShape2D") as CollisionShape2D
	var shape := cs.shape as RectangleShape2D
	var world_center: Vector2 = cs.global_position
	var extents: Vector2      = shape.extents
	_boundary_rect = Rect2(world_center - extents, extents * 2)

	# Slide camera up to y = 121 over 1 second
	var tween = create_tween()
	tween.tween_property(self, "global_position:y", 121, 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


# Camera cares only about RIGHT button & wheel → normal _input is fine
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = event.pressed          # start / stop pan
			return

		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom_toward_cursor( zoom_speed)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_toward_cursor(-zoom_speed)
			return

	if event is InputEventMouseMotion and _dragging:
		global_position -= event.relative / zoom.x
		_clamp_camera_edges()

# ---------------- helpers ----------------
func _zoom_toward_cursor(delta: float) -> void:
	var old_z: float = zoom.x
	var new_z: float = clamp(old_z + delta, min_zoom, max_zoom)
	var world_before := get_global_mouse_position()
	zoom = Vector2(new_z, new_z)
	var world_after  := get_global_mouse_position()
	global_position += (world_before - world_after)
	_clamp_camera_edges()

func _clamp_camera_edges() -> void:
	var screen_size  := get_viewport_rect().size
	var half_extents := screen_size * 0.5 / zoom.x
	var left   = _boundary_rect.position.x + half_extents.x
	var right  = _boundary_rect.position.x + _boundary_rect.size.x - half_extents.x
	var top    = _boundary_rect.position.y + half_extents.y
	var bottom = _boundary_rect.position.y + _boundary_rect.size.y - half_extents.y
	global_position.x = clamp(global_position.x, left,  right)
	global_position.y = clamp(global_position.y, top,   bottom)
