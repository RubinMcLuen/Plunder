# Global.gd (autoload)
extends Node

const KelptownInnTutorial = preload("res://KelptownInn/KelptownInnTutorial.gd")
const IslandTutorial    = preload("res://Island/IslandTutorial.gd")

var active_save_slot: int = -1
var spawn_position: Vector2 = Vector2.ZERO
var enemy_spawn_position: Vector2 = Vector2.ZERO
var crew: Array[String] = []
var ship_state: Dictionary = {}   # holds extra data just for PlayerShip
var kelptown_tutorial_state: Dictionary = {}
var island_tutorial_state: Dictionary = {}
var ocean_tutorial_complete: bool = false
var restore_sails_next: bool = false
var skip_player_fade: bool = false
var board_zoom_out_next: bool = false
var island_intro_next: bool = false
var return_scene_path: String = ""


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

func save_game_state() -> void:
	var slot = active_save_slot
	var save_file_path = "user://saveslot" + str(slot) + ".json"

	var current_scene_node = get_tree().current_scene
	var current_scene      = current_scene_node.scene_file_path

	# Don’t save on title or save-menu screens
	if current_scene.ends_with("title_screen.tscn") \
		or current_scene.ends_with("save_menu.tscn"):
		print("Not saving on title / save-menu screen.")
		return

	# ------------------------------------------------------------------
	# 1)  Gather position + optional ship data
	# ------------------------------------------------------------------
	var pos_dict = {"x": 0, "y": 0}
	ship_state   = {}                         # clear every save

	if current_scene_node.has_node("Player"):
		var p = current_scene_node.get_node("Player")
		pos_dict = {"x": p.position.x, "y": p.position.y}

	elif current_scene_node.has_node("PlayerShip"):
		var ship = current_scene_node.get_node("PlayerShip")
		pos_dict = {"x": ship.global_position.x, "y": ship.global_position.y}

		# Extra data worth keeping
		ship_state = {
			"frame":   ship.current_frame,
			"moving":  ship.moving_forward,
			"health":  ship.health
		}

	# ------------------------------------------------------------------
	# 2)  Merge with any existing save-file contents
	# ------------------------------------------------------------------
	var save_data: Dictionary = {}
	if FileAccess.file_exists(save_file_path):
				var r = FileAccess.open(save_file_path, FileAccess.READ)
				var j = JSON.new()
				if j.parse(r.get_as_text()) == OK:
						save_data = j.data
				r.close()

	save_data["scene"]      = {"name": current_scene, "position": pos_dict}
	save_data["ship_state"] = ship_state
	save_data["quests"]     = get_quest_manager().quests
	save_data["crew"]       = crew

	if current_scene_node is KelptownInnTutorial:
							save_data["kelptown_tutorial"] = current_scene_node.get_tutorial_state()
	elif current_scene_node is IslandTutorial:
							save_data["island_tutorial"] = current_scene_node.get_tutorial_state()

	var w = FileAccess.open(save_file_path, FileAccess.WRITE)
	w.store_string(JSON.stringify(save_data))
	w.close()

	print("Game saved →", current_scene, " | pos:", pos_dict, " | ship:", ship_state)

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

func load_game_state() -> void:
	var slot = active_save_slot
	var fname = "user://saveslot%d.json" % slot
	if not FileAccess.file_exists(fname):
		print("No save file for slot", slot)
		return

	# 1) Read & parse
	var f = FileAccess.open(fname, FileAccess.READ)
	var j = JSON.new()
	if j.parse(f.get_as_text()) != OK:
		push_error("Failed to parse save file.")
		return
	var data: Dictionary = j.data
	f.close()

	# 2) Restore quests, crew
	if "quests" in data:
		get_quest_manager().quests = data["quests"]
		if "crew" in data:
				crew = []
				for c in data["crew"]:
						crew.append(str(c))

				if "kelptown_tutorial" in data:
								kelptown_tutorial_state = data["kelptown_tutorial"]
				else:
								kelptown_tutorial_state = {}
				if "island_tutorial" in data:
								island_tutorial_state = data["island_tutorial"]
				else:
								island_tutorial_state = {}

		# 3) Scene + spawn + ship_state
	var scene_info = data.get("scene", {})
	var pos_dict   = scene_info.get("position", {})
	ship_state     = data.get("ship_state", {})

	spawn_position = Vector2(pos_dict.get("x", 0), pos_dict.get("y", 0))

	var scene_path = scene_info.get("name", "")
	if scene_path != "":
		get_tree().change_scene_to_file(scene_path)

	print("Game loaded →", scene_path,
		"| spawn:", spawn_position,
		"| ship_state:", ship_state)
