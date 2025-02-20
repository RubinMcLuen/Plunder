extends Node2D

@export var player: CharacterBody2D
@export var bartender: BartenderTutorial
@export var pirate: TutorialPirate

# Tracks which "phase" of the scene we are in:
# "default", "cutscene_finished", "bartender_talked", or "pirate_dead".
@export var scene_state: String = "default"

var bartender_talked = false

@export var dialogue_resource: Resource
@export var dialogue_scene: PackedScene = preload("res://Dialogue/balloon.tscn")

func _ready() -> void:
	# 1) Load player position.
	load_player_position()

	# 2) Connect signals first so the NPCs remain interactive no matter what scene_state is.
	bartender.dialogue_requested.connect(_on_bartender_dialogue_requested)
	pirate.pirate_dead.connect(_on_pirate_dead)
	pirate.pirate_dead.connect(bartender._on_pirate_dead)  # Let bartender update if needed

	$Exit.body_entered.connect(_on_exit_body_entered)

	# 3) Load and apply the scene_state.
	load_scene_state()

	# 4) Load NPC data.
	load_npcs()


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


func load_scene_state():
	var slot = Global.active_save_slot
	var save_file_path = "user://saveslot" + str(slot) + ".json"

	if FileAccess.file_exists(save_file_path):
		var file = FileAccess.open(save_file_path, FileAccess.READ)
		var json = JSON.new()
		var error = json.parse(file.get_as_text())
		file.close()

		if error == OK:
			var save_data = json.data
			# Read 'scene_state' from file, if it exists.
			if save_data.has("scene") and save_data["scene"].has("state"):
				scene_state = save_data["scene"]["state"]

	# Now apply the loaded state.
	apply_scene_state(scene_state)


func load_npcs() -> void:
	var slot = Global.active_save_slot
	var save_file_path = "user://saveslot" + str(slot) + ".json"
	if FileAccess.file_exists(save_file_path):
		var file = FileAccess.open(save_file_path, FileAccess.READ)
		var json = JSON.new()
		var parse_result = json.parse(file.get_as_text())
		file.close()
		if parse_result == OK:
			var save_data = json.data
			if save_data.has("npcs"):
				var saved_npcs = save_data["npcs"]
				# For each NPC in the scene (group "npc"):
				for npc in get_tree().get_nodes_in_group("npc"):
					if npc.npc_name in saved_npcs:
						var npc_save = saved_npcs[npc.npc_name]
						if npc_save.has("position"):
							var pos = npc_save["position"]
							npc.global_position = Vector2(pos["x"], pos["y"])
						if npc_save.has("state") and npc.has_method("get_state"):
							# Optionally update the NPC's state.
							npc.state = npc_save["state"]
					else:
						# If the NPC is not in the saved data, assume it died previously.
						npc.queue_free()


func apply_scene_state(state: String) -> void:
	match state:
		"default":
			# The cutscene hasn't been played yet, so play it now.
			$CutsceneManager.play_cutscene("res://Cutscene/cutscenes/KelpTownIntroCutscene.json")
		"cutscene_finished":
			# Skip playing the cutscene. Show arrow & tutorial hint 1 if desired.
			$Arrow.visible = true
			$CanvasLayer/TutorialHint1.visible = true
		"bartender_talked":
			pass
		"pirate_dead":
			# The pirate is already dead. Remove it and update UI.
			if pirate:
				pirate.queue_free()
			$CanvasLayer/TutorialHint2.visible = true
			# Additional pirate-dead logic can be added here.


func _on_bartender_dialogue_requested(dialogue_section: String) -> void:
	$CanvasLayer/TutorialHint2.visible = false
	# Disable player input.
	player.disable_user_input = true
	scene_state = "bartender_talked"
	Global.save_game_state()
	# Create and show the dialogue balloon.
	var balloon = DialogueManager.show_dialogue_balloon(dialogue_resource, dialogue_section, [bartender])
	balloon.connect("dialogue_finished", Callable(self, "_on_dialogue_finished"))


func _on_dialogue_finished() -> void:
	# Re-enable player input.
	player.disable_user_input = false
	bartender_talked = true


func _on_exit_body_entered(body):
	if bartender_talked and body == player:
		Global.spawn_position = Vector2(-88, -59)
		var tween = create_tween()
		tween.tween_property($Player/Camera2D/exit, "color:a", 1.0, 1.0)
		await tween.finished
		get_tree().change_scene_to_file("res://Island/island.tscn")


func get_scene_state() -> String:
	return scene_state


func _on_cutscene_manager_cutscene_finished():
	# The cutscene just finished; update UI accordingly.
	$Arrow.visible = true
	$CanvasLayer/TutorialHint1.visible = true

	# Update the scene_state to "cutscene_finished" and save.
	scene_state = "cutscene_finished"
	Global.save_game_state()


func _on_pirate_dead() -> void:
	# The pirate just died; update UI accordingly.
	$CanvasLayer/TutorialHint2.visible = true

	# Update the scene_state and save.
	scene_state = "pirate_dead"
	Global.save_game_state()
