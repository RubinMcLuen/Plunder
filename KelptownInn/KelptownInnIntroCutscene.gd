extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var bartender: BartenderTutorial = $Bartender
@onready var pirate: TutorialPirate = $Pirate
@onready var patron: CharacterBody2D = $Patron

var scene_state: String = ""  # We'll set this based on the quest step.

@export var dialogue_resource: Resource
@export var dialogue_scene: PackedScene = preload("res://Dialogue/balloon.tscn")

# We'll assume you have a single quest called "TutorialQuest" with 4 steps:
# 1) default
# 2) cutscene_finished
# 3) pirate_dead
# 4) bartender_talked

func _ready() -> void:
	# 1) Load player position from your save file.
	load_player_position()

	# 2) Explicitly reload quest data (in case QuestManager._ready ran too early)
	var quest_manager = get_node("/root/QuestManager")
	quest_manager.reload_quest_data()

	# 3) Connect signals.
	bartender.dialogue_requested.connect(_on_bartender_dialogue_requested)
	if pirate:
		pirate.pirate_dead.connect(_on_pirate_dead)
		pirate.pirate_dead.connect(bartender._on_pirate_dead)  # Bartender listens for pirate death.
	$Exit.body_entered.connect(_on_exit_body_entered)
	$CutsceneManager.cutscene_finished.connect(_on_cutscene_manager_cutscene_finished)

	# 4) Apply scene state & NPC states from quest step.
	apply_scene_state_from_quest()


func load_player_position():
	var slot = Global.active_save_slot
	var save_file_path = "user://saveslot" + str(slot) + ".json"
	if FileAccess.file_exists(save_file_path):
		var file = FileAccess.open(save_file_path, FileAccess.READ)
		var json = JSON.new()
		var parse_result = json.parse(file.get_as_text())
		file.close()
		if parse_result == OK:
			var save_data = json.data
			if save_data.has("scene") and save_data["scene"].has("position"):
				var pos = save_data["scene"]["position"]
				if player:
					player.position = Vector2(pos["x"], pos["y"])
					print("Loaded player position:", player.position)
				else:
					print("Player node not found in scene.")
		else:
			print("Failed to parse save file for loading position.")
	else:
		print("No save file found, using default position.")


func apply_scene_state_from_quest():
	var quest_manager = get_node("/root/QuestManager")
	var quest_id = "TutorialQuest"

	# If the quest doesn't exist in the log, add it.
	if not quest_id in quest_manager.quests:
		quest_manager.add_quest(quest_id, 4)
	
	var step = quest_manager.quests[quest_id]["current_step"]
	print(step)
	var step_int = int(step)  # Cast the value to an integer.
	
	match step_int:
		1:
			# default
			scene_state = "default"
			if bartender:
				bartender.state = "TutorialRedirect"
			$CutsceneManager.play_cutscene("res://Cutscene/cutscenes/KelpTownIntroCutscene.json")
		2:
			# cutscene_finished
			scene_state = "cutscene_finished"
			print("e")
			if bartender:
				bartender.state = "TutorialRedirect"  # Maintain same initial state.
				print("here")
			if is_instance_valid(patron):
				print("yuh")
				patron.queue_free()
			$Arrow.visible = true
			$CanvasLayer/TutorialHint1.visible = true
		3:
			# pirate_dead
			scene_state = "pirate_dead"
			if is_instance_valid(pirate):
				pirate.queue_free()
			if is_instance_valid(patron):
				patron.queue_free()
			if bartender:
				bartender.state = "TutorialFinished"
			$Arrow.visible = false
			$CanvasLayer/TutorialHint1.visible = false
			$CanvasLayer/TutorialHint2.visible = true
		4:
			# bartender_talked
			scene_state = "bartender_talked"
			if is_instance_valid(pirate):
				pirate.queue_free()
			if is_instance_valid(patron):
				patron.queue_free()
			if bartender:
				bartender.state = "TutorialFinished"
			$CanvasLayer/TutorialHint2.visible = false



func _on_cutscene_manager_cutscene_finished():
	# When cutscene finishes, move from step 1 => step 2.
	var quest_manager = get_node("/root/QuestManager")
	var quest_id = "TutorialQuest"
	if quest_manager.quests[quest_id]["current_step"] == 1:
		quest_manager.advance_quest_step(quest_id)  # sets step to 2
	Global.save_game_state()
	apply_scene_state_from_quest()


func _on_bartender_dialogue_requested(dialogue_section: String) -> void:
	$CanvasLayer/TutorialHint2.visible = false
	if player:
		player.disable_user_input = true
	# When bartender is spoken to on step 3, advance to step 4.
	var quest_manager = get_node("/root/QuestManager")
	var quest_id = "TutorialQuest"
	if quest_manager.quests[quest_id]["current_step"] == 3:
		quest_manager.advance_quest_step(quest_id)  # sets step to 4
	Global.save_game_state()
	var balloon = DialogueManager.show_dialogue_balloon(dialogue_resource, dialogue_section, [bartender])
	balloon.connect("dialogue_finished", Callable(self, "_on_dialogue_finished"))


func _on_dialogue_finished() -> void:
	if player:
		player.disable_user_input = false


func _on_pirate_dead():
	# When pirate dies on step 2, advance to step 3.
	var quest_manager = get_node("/root/QuestManager")
	var quest_id = "TutorialQuest"
	if quest_manager.quests[quest_id]["current_step"] == 2:
		quest_manager.advance_quest_step(quest_id)  # sets step to 3
	Global.save_game_state()
	apply_scene_state_from_quest()


func _on_exit_body_entered(body):
	if body == player:
		if scene_state == "bartender_talked" or scene_state == "pirate_dead":
			SceneSwitcher.switch_scene("res://Island/island.tscn", Vector2(64, -42), "fade")
