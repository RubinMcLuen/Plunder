# Bartender script

extends NPC
class_name Bartender

signal dialogue_requested(dialogue_section: String)

var state: String = "introduction"

func _on_area_input_event(_viewport, event, _shape_idx) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var section := _get_dialogue_section_and_update_state()
		emit_signal("dialogue_requested", section)

func _get_dialogue_section_and_update_state() -> String:
	var current := state
	match state:
			"move_first":
					state = "introduction"
			"introduction":
					state = "introduction_repeat"
			"introduction_repeat":
					pass # stay on introduction_repeat
			_:
					pass
	return current

# Used by your save system
func get_state() -> String:
	return state
