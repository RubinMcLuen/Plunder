extends Node

var current_scene: Node = null
var target_scene_path: String = ""
var target_zoom: Vector2 = Vector2(1.0, 1.0)
var target_position: Vector2 = Vector2()
var loader_thread: Thread = null
var loaded_scene: PackedScene = null
var fade_in_progress: bool = false

func _ready():
	var root = get_tree().root
	current_scene = root.get_child(root.get_child_count() - 1)
	print("Current scene at ready: ", current_scene.get_name())

func switch_scene(scene_path: String, global_position: Vector2, transition_type: String = "none", zoom_level: Vector2 = Vector2(1.0, 1.0), specific_position: Vector2 = Vector2()):
	target_scene_path = scene_path
	target_position = global_position
	target_zoom = zoom_level
	if loader_thread:
		loader_thread.wait_to_finish()
		loader_thread = null
	# Start loading the target scene in a separate thread
	loader_thread = Thread.new()
	loader_thread.start(Callable(self, "_load_scene_thread").bind(scene_path))
	if specific_position != Vector2():
		_translate_camera(specific_position, transition_type)
	else:
		match transition_type:
			"fade":
				_start_fade_transition()
			"zoom":
				print("zoom")
				_start_zoom_transition()
				print("zoom")
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

func _start_fade_transition():
	if fade_in_progress:
		return
	fade_in_progress = true
	var tween = create_tween()
	tween.tween_property(current_scene, "modulate:a", 0.0, 1.0)
	tween.connect("finished", Callable(self, "_on_fade_out_finished"))

func _on_fade_out_finished():
	_deferred_switch_scene_with_fade()

func _deferred_switch_scene_with_fade() -> void:
	if loader_thread and loader_thread.is_alive():
		loader_thread.wait_to_finish()

	_load_and_replace_scene()
	current_scene.modulate = Color(1, 1, 1, 0)
	var tween = create_tween()
	tween.tween_property(current_scene, "modulate:a", 1.0, 1.0)
	tween.connect("finished", Callable(self, "_on_fade_in_finished"))

func _on_fade_in_finished():
	fade_in_progress = false

func _start_zoom_transition():
	var camera = _get_camera_node()
	if camera:
		var tween = create_tween()
		tween.tween_property(camera, "zoom", target_zoom, 2.0)
		tween.connect("finished", Callable(self, "_on_zoom_finished"))

func _on_zoom_finished():
	if loader_thread and loader_thread.is_alive():
		loader_thread.wait_to_finish()

	_load_and_replace_scene()

func _deferred_switch_scene_with_zoom() -> void:
	if loader_thread and loader_thread.is_alive():
		loader_thread.wait_to_finish()

	_load_and_replace_scene()

func _start_direct_transition():
	_deferred_switch_scene()

func _deferred_switch_scene() -> void:
	if loader_thread and loader_thread.is_alive():
		loader_thread.wait_to_finish()

	_load_and_replace_scene()

func _load_and_replace_scene():
	print("Deferred scene switch to: ", target_scene_path)
	if current_scene:
		current_scene.queue_free()
		await get_tree().process_frame  # Ensure the current frame finishes before proceeding

	print("Loaded scene: ", loaded_scene)
	if loaded_scene:
		current_scene = loaded_scene.instantiate()
		if current_scene:
			get_tree().root.add_child(current_scene)
			get_tree().current_scene = current_scene
			print("New scene instantiated: ", current_scene.get_name())
			# Ensure the new scene is fully added before setting the position
			_set_player_position()
			
			# Show location notification whenever a scene is loaded
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
	var player = null

	# Check for the CharacterPlayer node
	if current_scene.has_node("CharacterPlayer"):
		player = current_scene.get_node("CharacterPlayer")
	# Check for the BoatPlayer node
	elif current_scene.has_node("BoatPlayer"):
		player = current_scene.get_node("BoatPlayer")
		

	if player:
		print(player.global_position)
		player.global_position = target_position
		player.target_position = player.global_position
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
