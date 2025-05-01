extends NPC

signal dialogue_requested(dialogue_section: String)

@export var state: String = "default"

func _on_area_input_event(_viewport, event, _shape_idx) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var dialogue_section = _get_dialogue_section_and_update_state()
		emit_signal("dialogue_requested", dialogue_section)

func _get_dialogue_section_and_update_state() -> String:
	return state


# This getter will be used during saving.
func get_state() -> String:
	return state
