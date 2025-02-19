extends NPC
class_name BartenderTutorial

signal dialogue_requested(dialogue_section: String)

var state: String = "TutorialRedirect"

func _on_area_input_event(_viewport, event, _shape_idx) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var dialogue_section = _get_dialogue_section_and_update_state()
		emit_signal("dialogue_requested", dialogue_section)

# This function returns the current dialogue section and then updates the state if needed.
func _get_dialogue_section_and_update_state() -> String:
	var dialogue_section = state
	if state == "TutorialFinished":
		state = "TutorialFinishedRepeat"
	# Additional state logic can be added here in the future.
	return dialogue_section

func _on_pirate_dead() -> void:
	state = "TutorialFinished"
