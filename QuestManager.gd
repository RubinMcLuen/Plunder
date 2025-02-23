extends Node

var quests: Dictionary = {}

func _ready() -> void:
	# If Global.active_save_slot isn’t set yet, this might be too early.
	if Global.active_save_slot >= 0:
		load_quest_data()
	else:
		print("QuestManager: active_save_slot not set yet; please call reload_quest_data() later.")

func load_quest_data() -> void:
	var slot = Global.active_save_slot
	var save_file_path = "user://saveslot" + str(slot) + ".json"
	if FileAccess.file_exists(save_file_path):
		var file = FileAccess.open(save_file_path, FileAccess.READ)
		var json = JSON.new()
		var parse_result = json.parse(file.get_as_text())
		file.close()
		if parse_result == OK:
			var save_data = json.data
			if save_data.has("quests"):
				quests = save_data["quests"]
				print("QuestManager: Loaded quest data:", quests)
			else:
				print("QuestManager: No quest data found in save file, starting fresh.")
		else:
			print("QuestManager: Error parsing quest data from save file.")
	else:
		print("QuestManager: No save file found, starting with empty quest log.")

func reload_quest_data() -> void:
	load_quest_data()

func add_quest(quest_id: String, max_steps: int) -> void:
	if quest_id in quests:
		print("Quest '", quest_id, "' already exists!")
	else:
		quests[quest_id] = {
			"completed": false,
			"current_step": 1,
			"max_steps": max_steps
		}
		print("Added quest '", quest_id, "' with ", max_steps, " steps.")

func advance_quest_step(quest_id: String) -> void:
	if quest_id in quests:
		var quest = quests[quest_id]
		if quest["completed"]:
			print("Quest '", quest_id, "' is already completed.")
			return
		quest["current_step"] += 1
		if quest["current_step"] > quest["max_steps"]:
			quest["completed"] = true
			quest["current_step"] = quest["max_steps"]
			print("Quest '", quest_id, "' is now completed.")
		else:
			print("Quest '", quest_id, "' advanced to step ", quest["current_step"])
	else:
		print("Quest '", quest_id, "' not found.")

func set_quest_step(quest_id: String, step: int) -> void:
	if quest_id in quests:
		var quest = quests[quest_id]
		if step > quest["max_steps"]:
			step = quest["max_steps"]
		quest["current_step"] = step
		if quest["current_step"] >= quest["max_steps"]:
			quest["completed"] = true
			print("Quest '", quest_id, "' is now completed.")
		else:
			quest["completed"] = false
			print("Quest '", quest_id, "' set to step ", quest["current_step"])
	else:
		print("Quest '", quest_id, "' not found.")

func complete_quest(quest_id: String) -> void:
	if quest_id in quests:
		quests[quest_id]["completed"] = true
		quests[quest_id]["current_step"] = quests[quest_id]["max_steps"]
		print("Quest '", quest_id, "' is now completed.")
	else:
		print("Quest '", quest_id, "' not found.")

func is_quest_finished(quest_id: String) -> bool:
	if quest_id in quests:
		return quests[quest_id]["completed"]
	print("Quest '", quest_id, "' not found.")
	return false

func print_quests() -> void:
	for quest_id in quests.keys():
		var quest = quests[quest_id]
		var status = "Completed" if quest["completed"] else "Incomplete"
		print("Quest '", quest_id, "': Step ", quest["current_step"], "/", quest["max_steps"], " - ", status)
