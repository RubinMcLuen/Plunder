# Root.gd
extends Node2D

# Exported variables to assign via the Inspector
@export var camera: Camera2D
@export var start_button_path: NodePath        # Path to the StartButton node
@export var save_menu_node_path: NodePath      # Path to the SaveMenu node
@export var character_creator_scene: Node2D    # Assign via Inspector

func _ready():
	# Ensure the camera is assigned
	if not camera:
		push_error("Camera2D not assigned in the Inspector.")

	# Get the StartButton node using the provided path
	var start_button = get_node_or_null(start_button_path)
	if start_button:
		# Connect the "pressed" signal to the _on_start_button_pressed function using Callable
		start_button.pressed.connect(Callable(self, "_on_start_button_pressed"))
	else:
		push_error("StartButton node not found at the specified path.")

	# Get the SaveMenu node using the provided path
	var save_menu_node = get_node_or_null(save_menu_node_path)
	if save_menu_node:
		# Connect the custom signals from SaveMenu to handler functions using Callable
		save_menu_node.show_character_creator.connect(Callable(self, "_on_show_character_creator"))
		save_menu_node.hide_character_creator.connect(Callable(self, "_on_hide_character_creator"))
	else:
		push_error("SaveMenu node not found at the specified path.")

func _on_start_button_pressed():
	# Ensure the camera is assigned
	if camera:
		# Calculate the target position by moving the camera up by 270 pixels
		var target_position = camera.position + Vector2(0, -270)
		
		# Create a new tween
		var tween = create_tween()
		
		# Configure the tween to move the camera's position smoothly over 1.5 seconds
		tween.tween_property(camera, "position", target_position, 1.5)
		tween.set_ease(Tween.EASE_IN_OUT)
		
		# Connect the 'finished' signal of the tween to the callback function using Callable
		tween.finished.connect(Callable(self, "_on_tween_completed"))
	else:
		push_error("Camera2D is not assigned.")

func _on_tween_completed():
	# Create a Timer node
	var timer = Timer.new()
	timer.wait_time = 0.5          # 0.5 seconds delay
	timer.one_shot = true          # Ensure the timer runs only once
	
	# Connect the 'timeout' signal of the timer to the _on_timer_timeout function using Callable
	timer.timeout.connect(Callable(self, "_on_timer_timeout"))
	
	# Add the Timer as a child to ensure it isn't freed immediately
	add_child(timer)
	
	# Start the Timer
	timer.start()

func _on_timer_timeout():
	# Attempt to retrieve the save_menu_node using its path
	var save_menu_node = get_node_or_null(save_menu_node_path)
	
	if save_menu_node:
		# Call the animate_header function on the save_menu_node
		save_menu_node.animate_header()
	else:
		push_error("Save menu node not found.")
	
	# Clean up the Timer node
	var timer = get_node_or_null("Timer")  # Ensure the Timer has a unique name if multiple timers exist
	if timer:
		timer.queue_free()

# Signal handler to show the character creator
func _on_show_character_creator(slot_index: int):
	if character_creator_scene:
		character_creator_scene.visible = true
	else:
		push_error("Character Creator scene is not assigned.")

	if save_menu_node_path:
		var save_menu_node = get_node_or_null(save_menu_node_path)
		if save_menu_node:
			save_menu_node.visible = false
		else:
			push_error("SaveMenu node not found at the specified path.")
	else:
		push_error("SaveMenu node path is not assigned.")

	print("Showing Character Creator for slot:", slot_index)

# Signal handler to hide the character creator
func _on_hide_character_creator():
	if character_creator_scene:
		character_creator_scene.visible = false
	else:
		push_error("Character Creator scene is not assigned.")

	if save_menu_node_path:
		var save_menu_node = get_node_or_null(save_menu_node_path)
		if save_menu_node:
			save_menu_node.visible = true
		else:
			push_error("SaveMenu node not found at the specified path.")
	else:
		push_error("SaveMenu node path is not assigned.")

	print("Hiding Character Creator")
