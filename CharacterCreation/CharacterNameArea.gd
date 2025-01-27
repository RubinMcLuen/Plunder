extends Node2D

@onready var name_input = $NameInput
var is_default_text = true  # Track if the default text is still showing

func _ready():
	# Set up the placeholder text
	name_input.text = "Enter Name..."
	# Connect signals with the correct syntax
	name_input.focus_entered.connect(_on_name_focus_entered)
	name_input.focus_exited.connect(_on_name_focus_exited)

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		# Check if the click happened outside the LineEdit
		if not name_input.get_global_rect().has_point(event.position):
			name_input.release_focus()
			
func _on_name_focus_entered():
	# Clear the text only if it's the default placeholder
	if is_default_text:
		name_input.text = ""
		is_default_text = false

func _on_name_focus_exited():
	# Restore the placeholder text if the field is empty
	if name_input.text.strip_edges() == "":
		name_input.text = "Enter Name"
		is_default_text = true
	name_input.release_focus()
