extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var monte_coral: CharacterBody2D = $MonteCoral
var skip_fade: bool = false
@export var dialogue_resource: Resource
@export var dialogue_scene: PackedScene = preload("res://Dialogue/balloon.tscn")

func _ready():
	#load_player_position()
	$Exit.body_entered.connect(_on_exit_body_entered)


func _on_exit_body_entered(body):
	if body == player:
		SceneSwitcher.switch_scene("res://KelptownInn/KelptownInn.tscn", Vector2(269, 220), "fade")

func load_player_position():
		
	var slot = Global.active_save_slot
	var save_file_path = "user://saveslot" + str(slot) + ".json"

	if FileAccess.file_exists(save_file_path):
		var file = FileAccess.open(save_file_path, FileAccess.READ)
		var json = JSON.new()  # Instantiate JSON object
		var parse_result = json.parse(file.get_as_text())
		file.close()

		if parse_result == OK:
			var save_data = json.data  # Access parsed JSON data
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


func _on_monte_coral_dialogue_requested(dialogue_section):
	player.disable_user_input = true
	var balloon = DialogueManager.show_dialogue_balloon(dialogue_resource, dialogue_section, [monte_coral])
	balloon.connect("dialogue_finished", Callable(self, "_on_dialogue_finished"))
	
func _on_dialogue_finished() -> void:
	# Re-enable player input.
	player.disable_user_input = false
