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
# We'll store these transition parameters each time you call switch_scene.
##
var target_scene_path: String = ""
var target_position: Vector2 = Vector2.ZERO

# Camera zoom levels
var old_camera_zoom: Vector2 = Vector2.ONE
var new_camera_zoom: Vector2 = Vector2.ONE

# Transition type & optional camera translation
var pending_transition_type: String = "none"
var specific_position: Vector2 = Vector2.ZERO

# New flag: whether to reposition the player in the new scene
var pending_move_player: bool = true

# Fade‐canvas and rectangle
var fade_canvas: CanvasLayer
var fade_rect: ColorRect

func _ready():
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

	_try_detect_current_scene()

func _try_detect_current_scene():
	for child in get_tree().root.get_children():
		if child == self or child == fade_canvas:
			continue
		if child is Node2D or child is Control:
			active_scene = child
			break

##
# switch_scene parameters:
#   scene_path: path to .tscn
#   player_position: desired player global_position
#   transition_type: "none", "fade", or "zoom"
#   old_scene_zoom_level: camera zoom to tween *from*
#   specific_position_override: if non‐zero, camera first pans here
#   new_scene_zoom_level: camera zoom to set in new scene
#   move_player: if true, we'll set the player’s global_position; if false, we leave it.
##
func switch_scene(
		scene_path: String,
		player_position: Vector2,
		transition_type: String = "none",
		old_scene_zoom_level: Vector2 = Vector2.ONE,
		specific_position_override: Vector2 = Vector2.ZERO,
		new_scene_zoom_level: Vector2 = Vector2.ONE,
		move_player: bool = true
):
	if transition_in_progress:
		print("SceneSwitcher: already in transition")
		return

	transition_in_progress       = true
	target_scene_path            = scene_path
	target_position              = player_position
	old_camera_zoom              = old_scene_zoom_level
	new_camera_zoom              = new_scene_zoom_level
	pending_transition_type      = transition_type
	specific_position            = specific_position_override
	pending_move_player          = move_player

	if specific_position != Vector2.ZERO:
		_translate_camera(specific_position, transition_type)
	else:
		match transition_type:
			"fade": _start_fade_transition()
			"zoom": _start_zoom_transition()
			"none": _start_direct_transition()
			_:     _start_direct_transition()

# -----------------------------------------------------------
# CAMERA TRANSLATION (optional)
# -----------------------------------------------------------
func _translate_camera(target_camera_position: Vector2, transition_type: String):
	var camera = _get_camera_node()
	if camera:
		var tw = create_tween()
		tw.tween_property(camera, "global_position", target_camera_position, 1.0)
		tw.connect("finished", Callable(self, "_on_camera_translation_finished").bind(transition_type))
	else:
		_on_camera_translation_finished(transition_type)

func _on_camera_translation_finished(transition_type: String):
	match transition_type:
		"fade": _start_fade_transition()
		"zoom": _start_zoom_transition()
		"none": _start_direct_transition()
		_:     _start_direct_transition()

# -----------------------------------------------------------
# FADE TRANSITION
# -----------------------------------------------------------
func _start_fade_transition():
	fade_rect.visible = true
	fade_rect.color.a = 0.0
	var tw = create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0, 1.0)
	tw.connect("finished", Callable(self, "_on_fade_out_finished"))

func _on_fade_out_finished():
	var dtw = create_tween()
	dtw.tween_interval(0.2)
	dtw.connect("finished", Callable(self, "_on_fade_out_delay_finished"))

func _on_fade_out_delay_finished():
	call_deferred("_remove_old_scene_and_load_new_scene_fade")

func _remove_old_scene_and_load_new_scene_fade():
	_remove_active_scene_if_valid()
	_load_and_instantiate_new_scene()
	_fade_back_in()

func _fade_back_in():
	var tw = create_tween()
	tw.tween_property(fade_rect, "color:a", 0.0, 1.0)
	tw.connect("finished", Callable(self, "_on_fade_in_finished"))

func _on_fade_in_finished():
	fade_rect.visible = false
	transition_in_progress = false

# -----------------------------------------------------------
# ZOOM TRANSITION
# -----------------------------------------------------------
func _start_zoom_transition():
	var camera = _get_camera_node()
	if camera:
		# If we’re already at the requested zoom, skip the tween & load right away
		if camera.zoom == old_camera_zoom:
			_on_zoom_finished()
		else:
			var tw = create_tween()
			tw.tween_property(camera, "zoom", old_camera_zoom, 1.0)  # ← 1-second zoom
			tw.connect("finished", Callable(self, "_on_zoom_finished"))
	else:
		_on_zoom_finished()


func _on_zoom_finished():
	call_deferred("_remove_old_scene_and_load_new_scene_zoom")

func _remove_old_scene_and_load_new_scene_zoom():
	_remove_active_scene_if_valid()
	_load_and_instantiate_new_scene()
	transition_in_progress = false

# -----------------------------------------------------------
# DIRECT (no special transition)
# -----------------------------------------------------------
func _start_direct_transition():
	call_deferred("_remove_old_scene_and_load_new_scene_none")

func _remove_old_scene_and_load_new_scene_none():
	_remove_active_scene_if_valid()
	_load_and_instantiate_new_scene()
	transition_in_progress = false

# -----------------------------------------------------------
# REMOVE & LOAD
# -----------------------------------------------------------
func _remove_active_scene_if_valid():
	if is_instance_valid(active_scene):
		active_scene.get_parent().remove_child(active_scene)
		active_scene.call_deferred("free")
	active_scene = null

func _load_and_instantiate_new_scene():
	var packed = ResourceLoader.load(target_scene_path) as PackedScene
	if not packed:
		print("SceneSwitcher: failed to load ", target_scene_path)
		transition_in_progress = false
		return
	var new_scene = packed.instantiate()

	# Position player only if requested
	if pending_move_player:
		if new_scene.has_node("PlayerShip"):
			new_scene.get_node("PlayerShip").global_position = target_position
		elif new_scene.has_node("Player"):
			new_scene.get_node("Player").global_position = target_position

	# Set new scene camera zoom
	var nc = _find_camera_in_scene(new_scene)
	if nc:
		nc.zoom = new_camera_zoom

	# Add scene to tree
	get_tree().root.add_child(new_scene)
	active_scene = new_scene
	get_tree().current_scene = new_scene

# -----------------------------------------------------------
# CAMERA HELPERS
# -----------------------------------------------------------
func _get_camera_node() -> Camera2D:
	if active_scene and active_scene.has_node("PlayerShip/ShipCamera"):
		return active_scene.get_node("PlayerShip/ShipCamera") as Camera2D
	return null

func _find_camera_in_scene(scene: Node) -> Camera2D:
	if scene.has_node("PlayerShip/ShipCamera"):
		return scene.get_node("PlayerShip/ShipCamera") as Camera2D
	return null
