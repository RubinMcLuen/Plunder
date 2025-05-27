# Global.gd (autoload)
extends Node

var active_save_slot: int = -1
var spawn_position: Vector2 = Vector2.ZERO
var crew: Array[String] = []

func add_crew(npc_name: String) -> void:
	if npc_name in crew:
		return
	crew.append(npc_name)

func get_quest_manager():
	return get_node("/root/QuestManager")

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game_state()
		get_tree().quit()

func save_game_state():
	var slot = active_save_slot
	var save_file_path = "user://saveslot" + str(slot) + ".json"

	var current_scene_node = get_tree().current_scene
	var current_scene = current_scene_node.scene_file_path
	if current_scene.ends_with("title_screen.tscn"):
		print("Not saving game state on title screen.")
		return
	if current_scene.ends_with("save_menu.tscn"):
		print("Not saving game state on save menu screen.")
		return

	var player = current_scene_node.get_node_or_null("Player")
	var position = {"x": 0, "y": 0}
	if player:
		position = {"x": player.position.x, "y": player.position.y}

	var save_data = {}
	if FileAccess.file_exists(save_file_path):
		var file_read = FileAccess.open(save_file_path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file_read.get_as_text()) == OK:
			save_data = json.data
		file_read.close()

	save_data["scene"] = {
		"name": current_scene,
		"position": position
	}
	save_data["quests"] = get_quest_manager().quests
	save_data["crew"]   = crew

	var file_write = FileAccess.open(save_file_path, FileAccess.WRITE)
	file_write.store_string(JSON.stringify(save_data))
	file_write.close()

	print("Game saved! Scene =", current_scene, "Position =", position)

func load_quest_data_from_save():
	var slot = active_save_slot
	var save_file_path = "user://saveslot" + str(slot) + ".json"

	if not FileAccess.file_exists(save_file_path):
		print("No save file found for slot", slot, "- no quest data to load.")
		return

	var file_read = FileAccess.open(save_file_path, FileAccess.READ)
	var text = file_read.get_as_text()
	file_read.close()

	var json = JSON.new()
	if json.parse(text) == OK:
		var save_data = json.data
		if "quests" in save_data:
			get_quest_manager().quests = save_data["quests"]
			print("Quest data loaded from save:", save_data["quests"])
	else:
		print("Failed to parse quest data from save file.")

func load_crew_from_save() -> void:
	var slot = active_save_slot
	var save_file_path = "user://saveslot%d.json" % slot
	if not FileAccess.file_exists(save_file_path):
		return

	var file = FileAccess.open(save_file_path, FileAccess.READ)
	var text = file.get_as_text()
	file.close()

	var j = JSON.new()
	if j.parse(text) == OK and "crew" in j.data:
		var raw_crew = j.data["crew"] as Array
		crew.clear()
		for entry in raw_crew:
			crew.append(str(entry))

