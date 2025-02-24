extends NPC

signal dialogue_requested(dialogue_section: String)

var state: String = "OutsideKelptownInn"

func _on_area_input_event(_viewport, event, _shape_idx) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var dialogue_section = _get_dialogue_section_and_update_state()
		emit_signal("dialogue_requested", dialogue_section)

# Simply return the current state for dialogue.
func _get_dialogue_section_and_update_state() -> String:
	return state

# This function will be called when the dialogue balloon finishes.
var move_targets: Array[Vector2] = []

func _on_dialogue_finished() -> void:
	# Only perform the state change if still in the initial state.
	if state == "OutsideKelptownInn":
		if not QuestManager.quests.has("ShipTutorial"):
			QuestManager.add_quest("ShipTutorial", 1)
		# Queue the move targets
		move_targets = [
			Vector2(-32, -19),
			Vector2(-32, 573),
			Vector2(-173, 573),
			Vector2(-173, 600)
		]
		# Connect the signal if not already connected
		if not is_connected("npc_move_completed", Callable(self, "_on_npc_move_completed")):
			connect("npc_move_completed", Callable(self, "_on_npc_move_completed"))

		# Start the first move
		auto_move_to_next()

func auto_move_to_next() -> void:
	if move_targets.size() > 0:
		var next_target = move_targets.pop_front()
		auto_move_to_position(next_target)
	else:
		# Disconnect the signal once all moves are done.
		if is_connected("npc_move_completed", Callable(self, "_on_npc_move_completed")):
			disconnect("npc_move_completed", Callable(self, "_on_npc_move_completed"))

		# Update state after all moves are completed.
		if QuestManager.is_quest_finished("TutorialQuest"):
			state = "OnShipReady"
		else:
			state = "OnShipNotReady"

func _on_npc_move_completed() -> void:
	# Called each time a move finishes.
	auto_move_to_next()



func get_state() -> String:
	return state
