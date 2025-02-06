extends Area2D

@export_file var dialogue_file: String
@export_file("*.png") var texture_path: String # Export file path for texture
var resource

func _ready():
	resource = load(dialogue_file)
	print("yes")

func _on_input_event(_viewport, event, _shape_idx):
	print("yes2")
	if event is InputEventMouseButton:
		print("yes3")
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var texture = load(texture_path) # Load the texture from the file path
			DialogueManager.show_dialogue_balloon(resource, "introduction", [texture])
			print("yes4")

