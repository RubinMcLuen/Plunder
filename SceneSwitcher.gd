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

# Separate zoom controls:
var old_camera_zoom: Vector2 = Vector2.ONE      # For the camera in the *old* scene (e.g. tween from 1→16)
var new_camera_zoom: Vector2 = Vector2.ONE      # For the camera in the *new* scene (e.g. force 1× on island)
var pending_transition_type: String = "none"
var specific_position: Vector2 = Vector2.ZERO

##
# Fade canvas/rect for fade transitions (unused if you just do "zoom" or "none," but left here for completeness).
##
var fade_canvas: CanvasLayer
var fade_rect: ColorRect

func _ready():
	# 1) Build a CanvasLayer for fade transitions (always on top).
	fade_canvas = CanvasLayer.new()
	fade_canvas.name = "FadeCanvas"
	fade_canvas.layer = 100
	fade_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(fade_canvas)

	# 2) Fullscreen ColorRect to handle fade-out/fade-in
	fade_rect = ColorRect.new()
	fade_rect.name = "FadeRect"
	fade_rect.color = Color(0, 0, 0, 0)  # alpha = 0 initially
	fade_rect.anchor_left = 0.0
	fade_rect.anchor_top = 0.0
	fade_rect.anchor_right = 1.0
	fade_rect.anchor_bottom = 1.0
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.process_mode = Node.PROCESS_MODE_ALWAYS
	fade_canvas.add_child(fade_rect)

	# 3) If we're playing a scene that wasn't loaded via switch_scene(),
	#    see if we can detect it in the root. That way you don't have to
	#    manually call set_initial_scene() in test scenes.
	if not active_scene:
		_try_detect_current_scene()

func _try_detect_current_scene():
	var root = get_tree().root
	for child in root.get_children():
		# Skip ourselves (the autoload) and the fade canvas, etc.
		if child == self or child == fade_canvas:
			continue
		# We found a node that might be your "active_scene."
		if child is Node2D or child is Control:
			active_scene = child
			print("SceneSwitcher: Auto-detected active_scene =", child.name)
			break

func set_initial_scene(scene: Node):
	active_scene = scene
	print("SceneSwitcher: set_initial_scene:", scene.name)


##
# The main function, matching your original signature but with an extra param for the new scene's zoom.
# Example usage:
#   SceneSwitcher.switch_scene("res://MyScene.tscn", Vector2(100,200), "zoom", Vector2(16,16), Vector2.ZERO, Vector2(1,1))
##
func switch_scene(
	scene_path: String,
	player_position: Vector2,
	transition_type: String = "none",
	old_scene_zoom_level: Vector2 = Vector2(1.0, 1.0),
	specific_position_override: Vector2 = Vector2(),
	new_scene_zoom_level: Vector2 = Vector2(1.0, 1.0)
):
	if transition_in_progress:
		print("SceneSwitcher: Scene switch requested but one is already in progress. Ignoring.")
		return

	transition_in_progress = true

	target_scene_path = scene_path
	target_position = player_position
	old_camera_zoom = old_scene_zoom_level
	new_camera_zoom = new_scene_zoom_level
	pending_transition_type = transition_type
	specific_position = specific_position_override

	# If a "specific_position" was provided, we first tween the old camera to that location (if any),
	# then do the chosen transition. If it's Vector2.ZERO, we skip that step.
	if specific_position != Vector2():
		_translate_camera(specific_position, transition_type)
	else:
		match transition_type:
			"fade":
				_start_fade_transition()
			"zoom":
				_start_zoom_transition()
			"none":
				_start_direct_transition()
			_:
				print("SceneSwitcher: Unknown transition type:", transition_type)
				_start_direct_transition()

# -----------------------------------------------------------
# CAMERA TRANSLATION (optional)
# -----------------------------------------------------------
func _translate_camera(target_camera_position: Vector2, transition_type: String):
	var camera = _get_camera_node()
	if camera:
		var tween = create_tween()
		tween.tween_property(camera, "global_position", target_camera_position, 1.0)
		tween.connect("finished", Callable(self, "_on_camera_translation_finished").bind(transition_type))
	else:
		# No camera to move? Go straight to the chosen transition.
		_on_camera_translation_finished(transition_type)

func _on_camera_translation_finished(transition_type: String):
	match transition_type:
		"fade":
			_start_fade_transition()
		"zoom":
			_start_zoom_transition()
		"none":
			_start_direct_transition()
		_:
			print("SceneSwitcher: Unknown transition type:", transition_type)
			_start_direct_transition()

# -----------------------------------------------------------
# FADE TRANSITION (unused if you don't call "fade," but left in for completeness)
# -----------------------------------------------------------
func _start_fade_transition():
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.visible = true

	print("SceneSwitcher: FADE OUT START")
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, 1.0)
	tween.connect("finished", Callable(self, "_on_fade_out_finished"))

func _on_fade_out_finished():
	print("SceneSwitcher: FADE OUT FINISHED")
	var delay_tween = create_tween()
	delay_tween.tween_interval(0.2)
	delay_tween.connect("finished", Callable(self, "_on_fade_out_delay_finished"))

func _on_fade_out_delay_finished():
	print("SceneSwitcher: FADE DELAY FINISHED - removing old scene & loading new.")
	call_deferred("_remove_old_scene_and_load_new_scene_fade")

func _remove_old_scene_and_load_new_scene_fade():
	_remove_active_scene_if_valid()
	_load_and_instantiate_new_scene()
	_fade_back_in()

func _fade_back_in():
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 0.0, 1.0)
	tween.connect("finished", Callable(self, "_on_fade_in_finished"))

func _on_fade_in_finished():
	print("SceneSwitcher: FADE IN FINISHED")
	fade_rect.visible = false
	transition_in_progress = false

# -----------------------------------------------------------
# ZOOM TRANSITION
# -----------------------------------------------------------
func _start_zoom_transition():
	print("SceneSwitcher: ZOOM transition start. We'll tween the *old* scene's camera if it exists.")
	var camera = _get_camera_node()
	if camera:
		var tween = create_tween()
		tween.tween_property(camera, "zoom", old_camera_zoom, 2.0)
		tween.connect("finished", Callable(self, "_on_zoom_finished"))
	else:
		_on_zoom_finished()  # no camera, skip to finishing

	# If your active_scene has some fade sprites, this is an example:
	if active_scene and active_scene.has_node("MixSprite"):
		var mix_sprite = active_scene.get_node("MixSprite")
		mix_sprite.modulate.a = 0.0
		var mix_tween = create_tween()
		mix_tween.tween_property(mix_sprite, "modulate:a", 1.0, 2.0)
	
	if active_scene and active_scene.has_node("Waves"):
		var wave_sprite = active_scene.get_node("Waves")
		wave_sprite.modulate.a = 1.0
		var wave_tween = create_tween()
		wave_tween.tween_property(wave_sprite, "modulate:a", 0.0, 2.0)

func _on_zoom_finished():
	print("SceneSwitcher: ZOOM transition finished, removing old scene & loading new.")
	call_deferred("_remove_old_scene_and_load_new_scene_zoom")

func _remove_old_scene_and_load_new_scene_zoom():
	_remove_active_scene_if_valid()
	_load_and_instantiate_new_scene()
	transition_in_progress = false

# -----------------------------------------------------------
# NO TRANSITION
# -----------------------------------------------------------
func _start_direct_transition():
	call_deferred("_remove_old_scene_and_load_new_scene_none")

func _remove_old_scene_and_load_new_scene_none():
	_remove_active_scene_if_valid()
	_load_and_instantiate_new_scene()
	transition_in_progress = false

# -----------------------------------------------------------
# ACTUAL REMOVE & LOAD
# -----------------------------------------------------------
func _remove_active_scene_if_valid():
	if is_instance_valid(active_scene):
		print("SceneSwitcher: Removing old scene:", active_scene.name)
		active_scene.get_parent().remove_child(active_scene)
		active_scene.call_deferred("free")
	else:
		print("SceneSwitcher: No old scene to remove (null or invalid).")
	active_scene = null

func _load_and_instantiate_new_scene():
	print("SceneSwitcher: Loading scene:", target_scene_path)
	var packed = ResourceLoader.load(target_scene_path) as PackedScene
	if packed:
		var new_scene = packed.instantiate()
		if new_scene:
			print("SceneSwitcher: Instantiating new scene:", new_scene.name)
			
			# 1) Set the player's position, so it doesn't spawn at default (0,0).
			_set_player_position(new_scene)

			# 2) Force the new scene's camera to new_camera_zoom before adding to the tree.
			var new_cam = _find_camera_in_scene(new_scene)
			if new_cam:
				new_cam.zoom = new_camera_zoom
				# If you also want to ensure it starts at a particular position, do so here:
				#   new_cam.global_position = some_position

			# 3) Now add to the tree
			get_tree().root.add_child(new_scene)
			active_scene = new_scene
			get_tree().current_scene = new_scene  # optional
		else:
			print("SceneSwitcher: Error instantiating new scene.")
	else:
		print("SceneSwitcher: Error loading resource:", target_scene_path)

# -----------------------------------------------------------
# PLAYER POSITION
# -----------------------------------------------------------
func _set_player_position(scene: Node):
	if scene.has_node("Player"):
		scene.get_node("Player").global_position = target_position
	elif scene.has_node("PlayerShip"):
		scene.get_node("PlayerShip").global_position = target_position

# -----------------------------------------------------------
# CAMERA HELPER
# -----------------------------------------------------------
func _get_camera_node() -> Camera2D:
	if active_scene:
		if active_scene.has_node("PlayerShip/ShipCamera"):
			return active_scene.get_node("PlayerShip/ShipCamera") as Camera2D
		elif active_scene.has_node("Player/Camera2D"):
			return active_scene.get_node("Player/Camera2D") as Camera2D
	return null

func _find_camera_in_scene(scene: Node) -> Camera2D:
	# This helper is used to set the new scene's camera before it appears.
	if scene.has_node("PlayerShip/ShipCamera"):
		return scene.get_node("PlayerShip/ShipCamera") as Camera2D
	elif scene.has_node("Player/Camera2D"):
		return scene.get_node("Player/Camera2D") as Camera2D
	return null

func _exit_tree():
	pass
