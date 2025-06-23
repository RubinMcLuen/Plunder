# SceneSwitcher.gd
# ─────────────────────────────────────────────────────────────
extends Node

##
# Tracks the currently active "gameplay scene."
# Whenever we load a new scene, we remove/free this old one.
##
var active_scene: Node = null

##
# Guard to prevent multiple transitions overlapping.
##
var transition_in_progress: bool = false

##
# We'll stash these transition parameters each time you call switch_scene.
##
var target_scene: PackedScene = null
var target_position: Vector2 = Vector2.ZERO

# Zoom levels:
#  - tween_target_zoom = what the CURRENT scene’s camera will tween TO
#  - load_camera_zoom   = what the NEW scene’s camera will be set TO
var tween_target_zoom: Vector2 = Vector2.ONE
var load_camera_zoom: Vector2  = Vector2.ONE

# Transition type & optional camera translation
var pending_transition_type: String = "none"
var specific_position: Vector2 = Vector2.ZERO

# Whether to reposition the player in the new scene
var pending_move_player: bool = true

# Fade‐canvas and rectangle
var fade_canvas: CanvasLayer
var fade_rect: ColorRect

func _ready() -> void:
	# Build fade canvas
	fade_canvas = CanvasLayer.new()
	fade_canvas.name = "FadeCanvas"
	fade_canvas.layer = 100
	add_child(fade_canvas)

	# Build fade rect
	fade_rect = ColorRect.new()
	fade_rect.name = "FadeRect"
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.anchor_left = 0.0
	fade_rect.anchor_top = 0.0
	fade_rect.anchor_right = 1.0
	fade_rect.anchor_bottom = 1.0
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_canvas.add_child(fade_rect)

	_detect_current_scene()
	set_process(true)

func _process(_delta: float) -> void:
	var cs: Node = get_tree().current_scene
	if cs and cs != active_scene:
		active_scene = cs

func _detect_current_scene() -> void:
	for child in get_tree().root.get_children():
		if child == self or child == fade_canvas:
			continue
		if child is Node2D or child is Control:
			active_scene = child
			break

##
# switch_scene(
#    scene_path,
#    player_position,
#    transition_type,           # "none", "fade", or "zoom"
#    old_scene_zoom_level,      # what CURRENT camera should tween TO
#    specific_position_override,# optional first pan
#    new_scene_zoom_level,      # what NEW camera should start at
#    move_player                # whether to reposition the player
# )
##
func switch_scene(
	scene: PackedScene,
			player_position: Vector2,
			transition_type: String = "none",
			old_scene_zoom_level: Vector2 = Vector2.ONE,
			specific_position_override: Vector2 = Vector2.ZERO,
			new_scene_zoom_level: Vector2 = Vector2.ONE,
			move_player: bool = true
) -> void:
	if transition_in_progress:
		print("SceneSwitcher: already in transition")
			return
	
	transition_in_progress    = true
	target_scene              = scene
	target_position           = player_position
		tween_target_zoom         = old_scene_zoom_level
		load_camera_zoom          = new_scene_zoom_level
		pending_transition_type   = transition_type
		specific_position         = specific_position_override
		pending_move_player       = move_player
	
	if specific_position != Vector2.ZERO:
		_translate_camera(specific_position, transition_type)
	else:
		match transition_type:
			"fade": _start_fade_transition()
			"zoom": _start_zoom_transition()
			_:     _start_direct_transition()

# -----------------------------------------------------------
# OPTIONAL CAMERA PAN
# -----------------------------------------------------------
func _translate_camera(target_cam_pos: Vector2, transition_type: String) -> void:
	var cam = _get_camera_node()
	if cam:
		var tw = create_tween()
		tw.tween_property(cam, "global_position", target_cam_pos, 1.0)
		tw.connect("finished", Callable(self, "_on_cam_pan_done").bind(transition_type))
	else:
		_on_cam_pan_done(transition_type)

func _on_cam_pan_done(transition_type: String) -> void:
	match transition_type:
		"fade": _start_fade_transition()
		"zoom": _start_zoom_transition()
		_:     _start_direct_transition()

# -----------------------------------------------------------
# FADE TRANSITION
# -----------------------------------------------------------
func _start_fade_transition() -> void:
	fade_rect.visible = true
	fade_rect.color.a = 0.0
	var tw = create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0, 1.0)
	tw.connect("finished", Callable(self, "_on_fade_out_done"))

func _on_fade_out_done() -> void:
	var dtw = create_tween()
	dtw.tween_interval(0.2)
	dtw.connect("finished", Callable(self, "_load_scene_fade"))

func _load_scene_fade() -> void:
		if _load_new_scene():
				_remove_old_scene()
				_attach_loaded_scene()
		_fade_back_in()

func _fade_back_in() -> void:
	var tw = create_tween()
	tw.tween_property(fade_rect, "color:a", 0.0, 1.0)
	tw.connect("finished", Callable(self, "_on_fade_in_done"))

func _on_fade_in_done() -> void:
	fade_rect.visible = false
	transition_in_progress = false

# -----------------------------------------------------------
# ZOOM TRANSITION
# -----------------------------------------------------------
func _start_zoom_transition() -> void:
	var cam = _get_camera_node()
	if cam:
		var tw = create_tween()
		tw.tween_property(cam, "zoom", tween_target_zoom, 1.0)
		tw.connect("finished", Callable(self, "_on_zoom_done"))
	else:
		_on_zoom_done()

func _on_zoom_done() -> void:
		# Ensure the final zoom frame is rendered before swapping scenes
		var tw = create_tween()
		tw.tween_interval(0.1)
		tw.connect("finished", Callable(self, "_load_scene_zoom"))

func _load_scene_zoom() -> void:
		if _load_new_scene():
				_remove_old_scene()
				_attach_loaded_scene()
		transition_in_progress = false

# -----------------------------------------------------------
# DIRECT (no transition)
# -----------------------------------------------------------
func _start_direct_transition() -> void:
	call_deferred("_load_scene_direct")

func _load_scene_direct() -> void:
		if _load_new_scene():
				_remove_old_scene()
				_attach_loaded_scene()
		transition_in_progress = false

# -----------------------------------------------------------
# REMOVE & LOAD
# -----------------------------------------------------------
func _remove_old_scene() -> void:
	if is_instance_valid(active_scene):
		active_scene.get_parent().remove_child(active_scene)
		active_scene.call_deferred("free")
	active_scene = null

var _next_scene: Node = null

	
	func _load_new_scene() -> bool:
	var packed = target_scene
	if packed == null:
push_error("SceneSwitcher: no target scene")
	return false
		
				_next_scene = packed.instantiate()
	
			if pending_move_player:
						if _next_scene.has_node("PlayerShip"):
									_next_scene.get_node("PlayerShip").global_position = target_position
						elif _next_scene.has_node("Player"):
							_next_scene.get_node("Player").global_position = target_position
	
		var nc = _find_camera_for_scene(_next_scene)
		if nc:
				var target_zoom = load_camera_zoom
				if target_zoom.x == 0 or target_zoom.y == 0:
						target_zoom = Vector2.ONE
				nc.zoom = target_zoom

		return true

func _attach_loaded_scene() -> void:
		if not _next_scene:
				return
		get_tree().root.add_child(_next_scene)
		active_scene = _next_scene
		get_tree().current_scene = _next_scene
		SoundManager._on_scene_changed(_next_scene)
		_next_scene = null
# -----------------------------------------------------------
# CAMERA HELPERS
# -----------------------------------------------------------
func _get_camera_node() -> Camera2D:
	if not active_scene:
		return null
	if active_scene.has_node("PlayerShip/ShipCamera"):
		return active_scene.get_node("PlayerShip/ShipCamera") as Camera2D
	return _find_camera_recursive(active_scene)

func _find_camera_for_scene(scene: Node) -> Camera2D:
	if scene.has_node("PlayerShip/ShipCamera"):
		return scene.get_node("PlayerShip/ShipCamera") as Camera2D
	return _find_camera_recursive(scene)

func _find_camera_recursive(node: Node) -> Camera2D:
	if node is Camera2D:
		return node
	for c in node.get_children():
		var found = _find_camera_recursive(c)
		if found:
			return found
	return null
