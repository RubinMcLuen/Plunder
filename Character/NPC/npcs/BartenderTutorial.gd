extends NPC
class_name BartenderTutorial

signal talked_to_bartender

func _on_area_input_event(_viewport, event, _shape_idx) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_tree().get_current_scene().get_node("CanvasLayer/TutorialHint2").visible = false
		var balloon = DialogueManager.show_dialogue_balloon(dialogue_resource, "introduction", [self])
		balloon.connect("dialogue_finished", Callable(self, "_on_dialogue_finished"))

func _on_dialogue_finished() -> void:
	emit_signal("talked_to_bartender")
