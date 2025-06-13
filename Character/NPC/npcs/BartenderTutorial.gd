extends NPC

signal dialogue_requested(dialogue_section: String)

var state: String = "TutorialRedirect"

func _on_area_input_event(_viewport, event, _shape_idx) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var dialogue_section = _get_dialogue_section_and_update_state()
		emit_signal("dialogue_requested", dialogue_section)

func _get_dialogue_section_and_update_state() -> String:
	var dialogue_section = state
	
	# If the bartender is "TutorialFinished", after talking once, we switch to "TutorialFinishedRepeat".
	if state == "TutorialFinished":
		state = "TutorialFinishedRepeat"
	
	return dialogue_section

func _on_pirate_dead() -> void:
	state = "TutorialFinished"

# We can leave get_state() if you still want local state logic, 
# but it's no longer used for saving.
func get_state() -> String:
	return state
