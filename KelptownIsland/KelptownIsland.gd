extends Node2D

# Reference to the Sprite2D node
@export var sprite_node_path: NodePath
var sprite_node: Sprite2D

# Reference to the CollisionShape2D node
@export var collision_shape_node_path: NodePath
var collision_shape_node: CollisionShape2D

# Path to the player node
@export var player_node_path: NodePath

# Path to the button node
@export var button_node_path: NodePath
var button_node: Button

# Set the specific target position
@export var target_position: Vector2 = Vector2(-2, 41)


func _ready():
	# Get the reference to the Sprite2D node
	sprite_node = get_node(sprite_node_path)
	sprite_node.visible = false

	# Get the reference to the CollisionShape2D node
	collision_shape_node = get_node(collision_shape_node_path)

	# Get the reference to the Button node
	button_node = get_node(button_node_path)
	button_node.connect("pressed", Callable(self, "_on_dock_button_pressed"))

	# Connect to the player's signals
	var player = get_node(player_node_path)
	if player:
		player.connect("position_updated", Callable(self, "_on_player_position_updated"))
		player.connect("movement_started", Callable(self, "_on_player_movement_started"))
		player.connect("player_docked", Callable(self, "_on_player_docked"))
		player.connect("manual_rotation_started", Callable(self, "_on_manual_rotation_started"))

	set_process_input(true)

func _input(event):
	# Check if the "move" action is pressed
	if Input.is_action_pressed("move"):
		var click_position_global = get_global_mouse_position()
		print("Click position (global): ", click_position_global)
		if is_point_in_collision(click_position_global):
			print("Click is within the collision box.")
			print("Moving player to predefined target position: ", target_position)
			move_player_to_target(target_position)
		else:
			print("Click is outside the collision box.")

func is_point_in_collision(point: Vector2) -> bool:
	# Create a query parameter for the point
	var query = PhysicsPointQueryParameters2D.new()
	query.position = point

	# Use the direct space state to perform the query
	var space_state = get_world_2d().direct_space_state
	var result = space_state.intersect_point(query)
	
	var collision_found = false
	for item in result:
		if item.collider == collision_shape_node.get_parent():  # Adjusted for three children down
			collision_found = true
			break

	return collision_found

func move_player_to_target(target_pos: Vector2):
	# Get the player node
	var player = get_node(player_node_path)
	if player:
		print("Driving player to target position: ", target_pos)
		player.call("drive_to_target_position", target_pos)
	else:
		print("Player node not found.")

func _on_player_docked():
	sprite_node.visible = true
	print("Sprite made visible due to player docking.")

func _on_player_movement_started():
	if sprite_node.visible:
		sprite_node.visible = false
		print("Sprite made invisible due to player starting to move.")

func _on_manual_rotation_started():
	if sprite_node.visible:
		sprite_node.visible = false
		print("Sprite made invisible due to player starting to rotate manually.")

# Script where _on_dock_button_pressed is defined

# Declare current_scene as a global variable if not already declared
var current_scene: Node = null

func _on_dock_button_pressed():
	# Access the current scene directly or from an appropriate context
	if current_scene == null:
		var root = get_tree().root
		current_scene = root.get_child(root.get_child_count() - 1)
	
	# Save the current boat position and frame to GlobalState
	var boat = current_scene.get_node("PlayerShip")

	# Set specific coordinates for switching to the character scene
	print("pressed")
	var specific_position = Vector2(-11.875, 40.5)  # Camera translation position
	var player_position = Vector2(-190, 648)  # Position in the new scene

	SceneSwitcher.switch_scene("res://Island/island.tscn", player_position, "zoom", Vector2(16, 16), specific_position)
	print("Dock button pressed, switching to character scene.")




