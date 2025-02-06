extends Node2D

@export var player: CharacterBody2D
# Island.gd (or any scene with the player)
func _ready():
	load_player_position()
	$Exit.body_entered.connect(_on_exit_body_entered)


func _on_exit_body_entered(body):
	if body == player:
		Global.spawn_position = Vector2(-88, -59)  # Save spawn coordinate
		var tween = create_tween()
		tween.tween_property($Player/Camera2D/ColorRect, "color:a", 1.0, 1.0)
		await tween.finished  # Wait until the tween is done
		get_tree().change_scene_to_file("res://Island/island.tscn")



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


