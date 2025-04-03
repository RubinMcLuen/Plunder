extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var monte_coral: CharacterBody2D = $MonteCoral
@onready var first_mate: NPC = $FirstMate
var skip_fade: bool = false

@export var monte_coral_dialogue: Resource
@export var first_mate_dialogue: Resource
@export var dialogue_scene: PackedScene = preload("res://Dialogue/balloon.tscn")

var scene_state: String = "pre_shiptutorial"

func _ready() -> void:
	$Exit.body_entered.connect(_on_exit_body_entered)
	
	# Connect dialogue signals.
	first_mate.dialogue_requested.connect(_on_first_mate_dialogue_requested)
	if monte_coral.has_method("dialogue_requested"):
		monte_coral.dialogue_requested.connect(_on_monte_coral_dialogue_requested)
	
	apply_scene_state()

func apply_scene_state() -> void:
	# Determine scene state based on the ShipTutorial quest's step.
	if QuestManager.quests.has("ShipTutorial"):
		var step = QuestManager.quests["ShipTutorial"]["current_step"]
		if step >= 1:
			scene_state = "shiptutorial_started"
			# Place First Mate at the ship coordinates.
			first_mate.position = Vector2(-173, 600)
			# Check if the TutorialQuest is complete.
			if QuestManager.is_quest_finished("TutorialQuest"):
				first_mate.state = "OnShipReady"
			else:
				first_mate.state = "OnShipNotReady"
		else:
			scene_state = "pre_shiptutorial"
	else:
		scene_state = "pre_shiptutorial"


func _on_exit_body_entered(body):
	if body == player:
		SceneSwitcher.switch_scene("res://KelptownInn/KelptownInn.tscn", Vector2(269, 220), "fade")

func load_player_position() -> void:
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

func _on_monte_coral_dialogue_requested(dialogue_section: String) -> void:
	player.disable_user_input = true
	var balloon = DialogueManager.show_dialogue_balloon(monte_coral_dialogue, dialogue_section, [monte_coral])
	balloon.connect("dialogue_finished", Callable(self, "_on_dialogue_finished"))
	# Advance TutorialQuest if needed.
	if QuestManager.quests.has("TutorialQuest") and QuestManager.quests["TutorialQuest"]["current_step"] == 4:
		QuestManager.advance_quest_step("TutorialQuest")
		if first_mate.get_state() == "OnShipNotReady":
			first_mate.state = "OnShipReady"
		

func _on_first_mate_dialogue_requested(dialogue_section: String) -> void:
	player.disable_user_input = true
	var balloon = DialogueManager.show_dialogue_balloon(first_mate_dialogue, dialogue_section, [first_mate])
	# Let the First Mate handle his own state change when dialogue finishes.
	balloon.connect("dialogue_finished", Callable(first_mate, "_on_dialogue_finished"))
	# Also re-enable player input after dialogue completes.
	balloon.connect("dialogue_finished", Callable(self, "_on_dialogue_finished"))

func _on_dialogue_finished() -> void:
	player.disable_user_input = false
