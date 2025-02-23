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
var target_zoom: Vector2 = Vector2.ONE
var pending_transition_type: String = "none"
var specific_position: Vector2 = Vector2.ZERO

##
# Fade canvas/rect for fade transitions.
##
var fade_canvas: CanvasLayer
var fade_rect: ColorRect


func _ready():
	# 1) Build a CanvasLayer for fade transitions (always on top).
	fade_canvas = CanvasLayer.new()
	fade_canvas.name = "FadeCanvas"
	fade_canvas.layer = 100
	# In Godot 4, 'process_mode = Node.PROCESS_MODE_ALWAYS' means it ignores pause.
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


##
# If you start the game in the editor from some arbitrary scene, this tries
# to detect that scene in the root so SceneSwitcher can remove it later.
##
func _try_detect_current_scene():
	var root = get_tree().root
	for child in root.get_children():
		# Skip ourselves (the autoload), skip the fade canvas, etc.
		if child == self or child == fade_canvas:
			continue
		# We found a node that might be your "active_scene."
		# If you only ever load Node2D or Control as a top-level scene, you might check for that:
		if child is Node2D or child is Control:
			active_scene = child
			print("SceneSwitcher: Auto-detected active_scene =", child.name)
			break


##
# If you prefer manual control, you can call this once in your _ready():
#   SceneSwitcher.set_initial_scene(self)
# ... so the SceneSwitcher knows which scene to remove next.
##
func set_initial_scene(scene: Node):
	active_scene = scene
	print("SceneSwitcher: set_initial_scene:", scene.name)


##
# The main function, matching your original signature.
# Example usage:
#   SceneSwitcher.switch_scene("res://KelptownInn/MyScene.tscn", Vector2(100,200), "fade")
##
func switch_scene(
	scene_path: String,
	player_position: Vector2,
	transition_type: String = "none",
	zoom_level: Vector2 = Vector2(1.0, 1.0),
	specific_position_override: Vector2 = Vector2()
):
	if transition_in_progress:
		print("SceneSwitcher: Scene switch requested but one is already in progress. Ignoring.")
		return

	transition_in_progress = true

	target_scene_path = scene_path
	target_position = player_position
	target_zoom = zoom_level
	pending_transition_type = transition_type
	specific_position = specific_position_override

	if specific_position != Vector2():
		# If you provided a "specific_position," we do a camera tween first,
		# then fade or zoom or none.
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
# FADE TRANSITION
# -----------------------------------------------------------
func _start_fade_transition():
	fade_rect.color = Color(0, 0, 0, 0)  # reset alpha
	fade_rect.visible = true

	print("SceneSwitcher: FADE OUT START")
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, 1.0)
	tween.connect("finished", Callable(self, "_on_fade_out_finished"))

func _on_fade_out_finished():
	print("SceneSwitcher: FADE OUT FINISHED")
	# Short pause at full black
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
	print("SceneSwitcher: ZOOM transition start. We'll tween the camera's zoom if it exists.")
	var camera = _get_camera_node()
	if camera:
		var tween = create_tween()
		tween.tween_property(camera, "zoom", target_zoom, 2.0)
		tween.connect("finished", Callable(self, "_on_zoom_finished"))
	else:
		_on_zoom_finished()  # no camera, skip to finishing

	# Example: if you have "MixSprite" or "Waves" in your scene for fade effects
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
			get_tree().root.add_child(new_scene)
			_set_player_position(new_scene)
			active_scene = new_scene
			get_tree().current_scene = new_scene  # Optional
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
		print(target_position)
	elif scene.has_node("PlayerShip"):
		scene.get_node("PlayerShip").global_position = target_position


# -----------------------------------------------------------
# CAMERA HELPER
# -----------------------------------------------------------
func _get_camera_node() -> Camera2D:
	if active_scene:
		if active_scene.has_node("PlayerShip/ShipCamera"):
			return active_scene.get_node("PlayerShip/ShipCamera")
		elif active_scene.has_node("Player/Camera2D"):
			return active_scene.get_node("Player/Camera2D")
	return null


func _exit_tree():
	pass
