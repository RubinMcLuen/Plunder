extends Node2D

@export var player: CharacterBody2D
@export var location_name: String = "Kelptown Inn"
@onready var bartender: Bartender = $Bartender
@onready var paid_actor_1: PaidActor = $PaidActor1
@onready var paid_actor_2: PaidActor = $PaidActor2
@export var bartender_dialogue_resource: Resource
@export var paid_actor_dialogue_resource: Resource
@export var dialogue_scene: PackedScene = preload("res://Dialogue/balloon.tscn")


# Island.gd (or any scene with the player)
func _ready():
	#load_player_position()
	bartender.dialogue_requested.connect(_on_bartender_dialogue_requested)
	paid_actor_1.dialogue_requested.connect(_on_paid_actor_1_dialogue_requested)
	paid_actor_2.dialogue_requested.connect(_on_paid_actor_2_dialogue_requested)
	$Exit.body_entered.connect(_on_exit_body_entered)
	UIManager.show_location_notification(location_name)
	$Player/Camera2D.zoom = Vector2(1.5, 1.5)

	
	
func _on_exit_body_entered(body):
	if body == player:
		SceneSwitcher.switch_scene("res://Island/island.tscn", Vector2(64, -42), "fade")



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


func _on_bartender_dialogue_requested(dialogue_section: String) -> void:
	if player:
		player.disable_user_input = true
	var balloon = DialogueManager.show_dialogue_balloon(bartender_dialogue_resource, dialogue_section, [bartender])
	balloon.connect("dialogue_finished", Callable(self, "_on_dialogue_finished"))
	
func _on_paid_actor_1_dialogue_requested(dialogue_section: String) -> void:
	if player:
		player.disable_user_input = true
	var balloon = DialogueManager.show_dialogue_balloon(paid_actor_dialogue_resource, dialogue_section, [paid_actor_1])
	balloon.connect("dialogue_finished", Callable(self, "_on_dialogue_finished"))
	
func _on_paid_actor_2_dialogue_requested(dialogue_section: String) -> void:
	if player:
		player.disable_user_input = true
	var balloon = DialogueManager.show_dialogue_balloon(paid_actor_dialogue_resource, dialogue_section, [paid_actor_2])
	balloon.connect("dialogue_finished", Callable(self, "_on_dialogue_finished"))
	
func _on_dialogue_finished() -> void:
	if player:
		player.disable_user_input = false
