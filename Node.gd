extends Node

@export var target_scene_path: String = "res://Ocean/ocean.tscn"
@export var target_position: Vector2 = Vector2(-32, 109)
@export var transition_type: String = "none"  # You can later add transitions if needed.
@export var target_zoom: Vector2 = Vector2(0.0625, 0.0625)

var current_scene: Node = null

@onready var debug_label: Label = get_node_or_null("DebugLabel")

func _ready() -> void:
	var root = get_tree().root
	current_scene = root.get_child(root.get_child_count() - 1)
	debug_print("Current scene at _ready(): " + current_scene.name)

func _on_button_pressed() -> void:
	debug_print("Button pressed. Starting scene switch to: " + target_scene_path)
	switch_scene(target_scene_path, target_position, transition_type, target_zoom)

func switch_scene(scene_path: String, global_position: Vector2, transition_type: String = "none", zoom_level: Vector2 = Vector2(1, 1)) -> void:
	debug_print("Attempting to load scene: " + scene_path)
	
	var loaded_scene: PackedScene = ResourceLoader.load(scene_path) as PackedScene
	if not loaded_scene:
		debug_print("Error: Could not load scene: " + scene_path)
		return
	
	debug_print("Scene loaded successfully.")
	_load_and_replace_scene(loaded_scene, global_position)

func _load_and_replace_scene(loaded_scene: PackedScene, target_pos: Vector2) -> void:
	if current_scene:
		debug_print("Queueing current scene for free: " + current_scene.name)
		current_scene.queue_free()
		# Wait one frame to ensure the scene is cleared.
		await get_tree().process_frame
	
	current_scene = loaded_scene.instantiate()
	get_tree().root.add_child(current_scene)
	get_tree().current_scene = current_scene
	debug_print("New scene instantiated: " + current_scene.name)
	
	# Check for an active camera
	var camera = _get_camera_node()
	if camera:
		debug_print("Found camera: " + camera.name)
	else:
		debug_print("Warning: No camera found in the new scene. Add a Camera2D and set it to 'current'.")
		
	_set_player_position(target_pos)

func _set_player_position(target_pos: Vector2) -> void:
	var player: Node = null
	if current_scene.has_node("CharacterPlayer"):
		player = current_scene.get_node("CharacterPlayer")
	elif current_scene.has_node("BoatPlayer"):
		player = current_scene.get_node("BoatPlayer")
	
	if player:
		player.global_position = target_pos
		debug_print("Player position set to: " + str(target_pos))
	else:
		debug_print("Error: No valid player node found in the new scene.")

func _get_camera_node() -> Camera2D:
	# Try different node paths based on your scene structure
	if current_scene.has_node("PlayerShip/ShipCamera"):
		return current_scene.get_node("PlayerShip/ShipCamera") as Camera2D
	elif current_scene.has_node("Player/Camera2D"):
		return current_scene.get_node("Player/Camera2D") as Camera2D
	# Optionally, search for any Camera2D in the scene
	for child in current_scene.get_children():
		if child is Camera2D and child.current:
			return child
	return null

func debug_print(message: String) -> void:
	print(message)
	if debug_label:
		debug_label.text += message + "\n"
