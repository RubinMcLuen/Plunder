extends Node

var active_save_slot: int = -1

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# Call your function to save the game state
		save_game_state()
		# Accept the quit request to close the application
		get_tree().quit()


func save_game_state():
	var slot = Global.active_save_slot
	var save_file_path = "user://saveslot" + str(slot) + ".json"

	# Get current scene
	var current_scene = get_tree().current_scene.scene_file_path

	# Get player position
	var player = get_tree().current_scene.get_node_or_null("Player")  # Adjust if necessary
	var position = { "x": 0, "y": 0 }
	if player:
		position = { "x": player.position.x, "y": player.position.y }

	# Load existing save data
	var save_data = {}
	if FileAccess.file_exists(save_file_path):
		var file = FileAccess.open(save_file_path, FileAccess.READ)
		var json = JSON.new()
		var parse_result = json.parse(file.get_as_text())  # Returns an error code
		file.close()

		if parse_result == OK:  # Check if parsing was successful
			save_data = json.data  # Extract parsed data

	# Update scene data
	save_data["scene"] = {
		"name": current_scene,
		"position": position
	}

	# Save back to file
	var file_write = FileAccess.open(save_file_path, FileAccess.WRITE)
	file_write.store_string(JSON.stringify(save_data))
	file_write.close()

	print("Game saved: Scene =", current_scene, "Position =", position)

