extends Node2D

@onready var player: CharacterBody2D = $Player

var skip_fade: bool = false

func _ready():
	#load_player_position()
	$Exit.body_entered.connect(_on_exit_body_entered)


func _on_exit_body_entered(body):
	if body == player:
		SceneSwitcher.switch_scene("res://KelptownInn/KelptownInn.tscn", Vector2(269, 220), "fade")

func load_player_position():
	if Global.spawn_position != null:
		player.position = Global.spawn_position
		print("Loaded player position from Global:", player.position)
		Global.spawn_position = null  # Reset after using it
		return
		
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
