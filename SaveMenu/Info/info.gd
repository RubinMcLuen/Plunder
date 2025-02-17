extends Node2D

# Adjust 'slot_index' as needed – you might want to get it dynamically or set a default.
var slot_index = -1

func _ready():
	$PlayButton.pressed.connect(self._on_playbutton_pressed)
	$DeleteButton.pressed.connect(self._on_deletebutton_pressed)  # <-- Add this line
	await $Control/Player  # Wait for the player node to be ready
	var player = $Control/Player
	var player_name = player.name_input
	$Name.text = "Captain " + player_name


func _on_playbutton_pressed():
	slot_index = Global.active_save_slot
	var save_file_path = "user://saveslot%s.json" % slot_index
	if FileAccess.file_exists(save_file_path):
		var file = FileAccess.open(save_file_path, FileAccess.READ)
		var json = JSON.new()
		var parse_result = json.parse(file.get_as_text())
		file.close()
		var save_file_data = {}
		if parse_result == OK:
			save_file_data = json.data
		if save_file_data.has("scene"):
			var scene_name = save_file_data["scene"].get("name", "res://Tavern/tavern.tscn")
			print("Loading saved scene:", scene_name)
			get_tree().change_scene_to_file(scene_name)
		else:
			print("No saved scene found. Defaulting to Tavern.")
			get_tree().change_scene_to_file("res://Tavern/tavern.tscn")
	else:
		print("No save file found, starting at Tavern.")
		get_tree().change_scene_to_file("res://Tavern/tavern.tscn")

func _on_deletebutton_pressed():
	slot_index = Global.active_save_slot
	var file_name = "saveslot%s.json" % slot_index
	var save_file_path = "user://" + file_name

	# Delete the save file if it exists using DirAccess.
	var dir = DirAccess.open("user://")
	if dir and dir.file_exists(file_name):
		var err = dir.remove(file_name)
		if err == OK:
			print("Save file deleted:", save_file_path)
		else:
			print("Failed to delete save file:", save_file_path)
	else:
		print("No save file found at", save_file_path)

	# Update save_data.json by removing the corresponding key
	var save_data_path = "user://save_data.json"
	if FileAccess.file_exists(save_data_path):
		var file = FileAccess.open(save_data_path, FileAccess.READ)
		var json_text = file.get_as_text()
		file.close()

		var json_parser = JSON.new()
		if json_parser.parse(json_text) == OK:
			var save_data = json_parser.data
			var key = str(slot_index)
			if save_data.has(key):
				save_data.erase(key)
				print("Removed slot", key, "from save_data.json")
				
				# Write the updated save_data back to file
				file = FileAccess.open(save_data_path, FileAccess.WRITE)
				file.store_string(JSON.stringify(save_data))
				file.close()
			else:
				print("Key", key, "not found in save_data.json")
		else:
			print("Failed to parse save_data.json")
	else:
		print("save_data.json not found")
