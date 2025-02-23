extends Node

var active_save_slot: int = -1
var spawn_position: Vector2 = Vector2.ZERO

# We assume you have a QuestManager somewhere in the tree, e.g. /root/QuestManager.
# Adjust the node path if yours is different.
func get_quest_manager():
	return get_node("/root/QuestManager")

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game_state()
		get_tree().quit()

func save_game_state():
	var slot = active_save_slot
	var save_file_path = "user://saveslot" + str(slot) + ".json"

	# Get current scene path. If on title screen or a save menu, do nothing.
	var current_scene_node = get_tree().current_scene
	var current_scene = current_scene_node.scene_file_path
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

	# Prepare a blank dictionary or load existing one.
	var save_data = {}
	if FileAccess.file_exists(save_file_path):
		var file_read = FileAccess.open(save_file_path, FileAccess.READ)
		var json = JSON.new()
		var parse_result = json.parse(file_read.get_as_text())
		file_read.close()

		if parse_result == OK:
			save_data = json.data

	# Update scene data
	save_data["scene"] = {}
	save_data["scene"]["name"] = current_scene
	save_data["scene"]["position"] = position

	# Store the entire quests dictionary from QuestManager
	var quest_manager = get_quest_manager()
	save_data["quests"] = quest_manager.quests

	# Write out
	var file_write = FileAccess.open(save_file_path, FileAccess.WRITE)
	file_write.store_string(JSON.stringify(save_data))
	file_write.close()

	print("Game saved! Scene =", current_scene, "Position =", position)


func load_quest_data_from_save():
	# This can be called once at game start or whenever you switch slots.
	var slot = active_save_slot
	var save_file_path = "user://saveslot" + str(slot) + ".json"

	if not FileAccess.file_exists(save_file_path):
		print("No save file found for slot", slot, "- no quest data to load.")
		return

	var file_read = FileAccess.open(save_file_path, FileAccess.READ)
	var json = JSON.new()
	var error = json.parse(file_read.get_as_text())
	file_read.close()

	if error == OK:
		var save_data = json.data
		if "quests" in save_data:
			get_quest_manager().quests = save_data["quests"]
			print("Quest data loaded from save:", save_data["quests"])
	else:
		print("Failed to parse quest data from save file.")
