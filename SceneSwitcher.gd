extends Node

var current_scene: Node = null
var target_scene_path: String = ""
var target_zoom: Vector2 = Vector2(1.0, 1.0)
var target_position: Vector2 = Vector2()  # Position for the Player node
var loader_thread: Thread = null
var loaded_scene: PackedScene = null
var fade_in_progress: bool = false

# Dedicated CanvasLayer for fade transitions
var fade_canvas: CanvasLayer

# A single fade ColorRect used for both fade out and fade in
var fade_rect: ColorRect

func _ready():
	var root = get_tree().root
	current_scene = root.get_child(root.get_child_count() - 1)
	print("Current scene at ready: ", current_scene.get_name())
	
	# Create the CanvasLayer but defer adding it to avoid busy-parent errors.
	fade_canvas = CanvasLayer.new()
	fade_canvas.name = "FadeCanvas"
	fade_canvas.layer = 100  # Higher layer to appear on top
	call_deferred("_add_fade_layer")

func _add_fade_layer():
	get_tree().root.add_child(fade_canvas)

func switch_scene(
	scene_path: String,
	player_position: Vector2,
	transition_type: String = "none",
	zoom_level: Vector2 = Vector2(1.0, 1.0),
	specific_position: Vector2 = Vector2()
):
	target_scene_path = scene_path
	target_position = player_position
	target_zoom = zoom_level
	
	if loader_thread:
		loader_thread.wait_to_finish()
		loader_thread = null
	
	# Start loading the target scene in a separate thread.
	loader_thread = Thread.new()
	loader_thread.start(Callable(self, "_load_scene_thread").bind(scene_path))
	
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
				print("Unknown transition type: ", transition_type)

func _translate_camera(target_camera_position: Vector2, transition_type: String):
	var camera = _get_camera_node()
	if camera:
		var tween = create_tween()
		tween.tween_property(camera, "global_position", target_camera_position, 1.0)
		tween.connect("finished", Callable(self, "_on_camera_translation_finished").bind(transition_type))

func _on_camera_translation_finished(transition_type: String):
	match transition_type:
		"fade":
			_start_fade_transition()
		"zoom":
			_start_zoom_transition()
		"none":
			_start_direct_transition()
		_:
			print("Unknown transition type: ", transition_type)

# -----------------------------------------------------------
# F A D E   T R A N S I T I O N   (Using a Single CanvasLayer Fade Rect)
# -----------------------------------------------------------
func _start_fade_transition():
	if fade_in_progress:
		return
	fade_in_progress = true
	
	# Create the fade ColorRect (starting fully transparent)
	fade_rect = ColorRect.new()
	fade_rect.name = "FadeRect"
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.anchor_left = 0.0
	fade_rect.anchor_top = 0.0
	fade_rect.anchor_right = 1.0
	fade_rect.anchor_bottom = 1.0
	fade_rect.z_index = 1
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Add to the dedicated fade_canvas so it stays on top during the transition.
	fade_canvas.add_child(fade_rect)
	
	# Tween from transparent to fully opaque (fade out) over 1 second.
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, 1.0)
	tween.connect("finished", Callable(self, "_on_fade_out_finished"))

func _on_fade_out_finished():
	# Do not free fade_rect so it remains fully black.
	# Wait 0.2 seconds at full black using a tween interval.
	var delay_tween = create_tween()
	delay_tween.tween_interval(0.2)
	delay_tween.connect("finished", Callable(self, "_on_delay_finished"))

func _on_delay_finished():
	_deferred_switch_scene_with_fade()

func _deferred_switch_scene_with_fade() -> void:
	if loader_thread and loader_thread.is_alive():
		loader_thread.wait_to_finish()
	_load_and_replace_scene()
	
	# Fade in: Tween the same fade_rect from fully opaque to transparent over 1 second.
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 0.0, 1.0)
	tween.connect("finished", Callable(self, "_on_fade_in_finished"))

func _on_fade_in_finished():
	# Safely free fade_rect and reset the fade flag.
	if is_instance_valid(fade_rect):
		fade_rect.queue_free()
	fade_in_progress = false

# -----------------------------------------------------------
# Z O O M   T R A N S I T I O N
# -----------------------------------------------------------
func _start_zoom_transition():
	var camera = _get_camera_node()
	if camera:
		var tween = create_tween()
		tween.tween_property(camera, "zoom", target_zoom, 2.0)
		tween.connect("finished", Callable(self, "_on_zoom_finished"))
	
	# Animate MixSprite's opacity from transparent (0) to fully opaque (1)
	if current_scene and current_scene.has_node("MixSprite"):
		var mix_sprite = current_scene.get_node("MixSprite")
		# Ensure the sprite starts fully transparent.
		mix_sprite.modulate.a = 0.0
		var mix_tween = create_tween()
		mix_tween.tween_property(mix_sprite, "modulate:a", 1.0, 2.0)
	
	if current_scene and current_scene.has_node("Waves"):
		var mix_sprite = current_scene.get_node("Waves")
		# Ensure the sprite starts fully transparent.
		mix_sprite.modulate.a = 1.0
		var mix_tween = create_tween()
		mix_tween.tween_property(mix_sprite, "modulate:a", 0.0, 2.0)
	

func _on_zoom_finished():
	if loader_thread and loader_thread.is_alive():
		loader_thread.wait_to_finish()
	_load_and_replace_scene()

func _deferred_switch_scene_with_zoom() -> void:
	if loader_thread and loader_thread.is_alive():
		loader_thread.wait_to_finish()
	_load_and_replace_scene()

# -----------------------------------------------------------
# N O   T R A N S I T I O N
# -----------------------------------------------------------
func _start_direct_transition():
	_deferred_switch_scene()

func _deferred_switch_scene() -> void:
	if loader_thread and loader_thread.is_alive():
		loader_thread.wait_to_finish()
	_load_and_replace_scene()

# -----------------------------------------------------------
# SCENE LOADING / UTILITY
# -----------------------------------------------------------
func _load_and_replace_scene():
	print("Deferred scene switch to: ", target_scene_path)
	# Check if current_scene is valid before attempting to free it.
	if is_instance_valid(current_scene):
		current_scene.queue_free()
		await get_tree().process_frame  # Ensure the current frame finishes before proceeding
	print("Loaded scene: ", loaded_scene)
	if loaded_scene:
		current_scene = loaded_scene.instantiate()
		if current_scene:
			get_tree().root.add_child(current_scene)
			get_tree().current_scene = current_scene
			print("New scene instantiated: ", current_scene.get_name())
			_set_player_position()
		else:
			print("Error: Unable to instantiate the new scene.")
	else:
		print("Error: Loaded scene is null. Check if the path is correct and the scene exists.")

func _load_scene_thread(scene_path: String):
	print("Loading scene: ", scene_path)
	loaded_scene = ResourceLoader.load(scene_path) as PackedScene
	print("Scene loaded in thread: ", loaded_scene)
	return 0

func _set_player_position():
	# Look for a node named "Player" and set its global_position.
	var player
	if current_scene.has_node("Player"):
		player = current_scene.get_node("Player")
	elif current_scene.has_node("PlayerShip"):
		player = current_scene.get_node("PlayerShip")
	if player:
		player.global_position = target_position
		print("Set player position: ", target_position)
	else:
		print("Error: No valid player node found in the current scene.")

func _get_camera_node() -> Camera2D:
	if current_scene.has_node("PlayerShip/ShipCamera"):
		return current_scene.get_node("PlayerShip/ShipCamera")
	elif current_scene.has_node("Player/Camera2D"):
		return current_scene.get_node("Player/Camera2D")
	return null

func _exit_tree():
	if loader_thread and loader_thread.is_alive():
		loader_thread.wait_to_finish()
	if loader_thread:
		loader_thread = null
