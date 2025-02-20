extends Node

var active_save_slot: int = -1
var spawn_position = null

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game_state()
		get_tree().quit()

func save_game_state():
	var slot = Global.active_save_slot
	var save_file_path = "user://saveslot" + str(slot) + ".json"

	# Get current scene and its node.
	var current_scene_node = get_tree().current_scene
	var current_scene = current_scene_node.scene_file_path

	# Skip saving for title screen or save menu.
	if current_scene.ends_with("title_screen.tscn"):
		print("Not saving game state on title screen.")
		return
	if current_scene.ends_with("save_menu.tscn"):
		print("Not saving game state on save menu screen.")
		return

	# Get player position.
	var player = current_scene_node.get_node_or_null("Player")
	var position = {"x": 0, "y": 0}
	if player:
		position = {"x": player.position.x, "y": player.position.y}

	# Load existing save data if present.
	var save_data = {}
	if FileAccess.file_exists(save_file_path):
		var file = FileAccess.open(save_file_path, FileAccess.READ)
		var json = JSON.new()
		var parse_result = json.parse(file.get_as_text())
		file.close()
		if parse_result == OK:
			save_data = json.data

	# Update scene data.
	if not save_data.has("scene"):
		save_data["scene"] = {}
	save_data["scene"]["name"] = current_scene
	save_data["scene"]["position"] = position
	
	# Use a getter if available to retrieve the scene state.
	if current_scene_node and current_scene_node.has_method("get_scene_state"):
		save_data["scene"]["state"] = current_scene_node.get_scene_state()
	else:
		if not save_data["scene"].has("state"):
			save_data["scene"]["state"] = "default"

	# Save NPC data.
	var npc_data = {}
	# Iterate over NPC nodes in the "npc" group.
	for npc in get_tree().get_nodes_in_group("npc"):
		var entry = {}
		entry["position"] = {"x": npc.global_position.x, "y": npc.global_position.y}
		# If the NPC implements get_state(), save its dialogue state.
		if npc.has_method("get_state"):
			entry["state"] = npc.get_state()
		npc_data[npc.npc_name] = entry
	save_data["npcs"] = npc_data

	# Write back to the save file.
	var file_write = FileAccess.open(save_file_path, FileAccess.WRITE)
	file_write.store_string(JSON.stringify(save_data))
	file_write.close()

	print("Game saved: Scene =", current_scene, "Position =", position, "State =", save_data["scene"].get("state", "???"))
