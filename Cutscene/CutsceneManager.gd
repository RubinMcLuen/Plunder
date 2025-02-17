extends Node

signal cutscene_finished

# References to nodes in your scene:
@export var player: Node        # Must have auto_move_to_position() and auto_move_completed signal
@export var camera: Camera2D    # The Camera2D node (we will tween its properties)
@export var npcs: Array[Node] = []  # Array of NPC nodes

# The list of actions to process.
var actions: Array = []
var current_action_index: int = 0

# Store original camera settings
var original_zoom: Vector2 = Vector2.ONE
var original_camera_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	if camera:
		original_zoom = camera.zoom
		original_camera_position = camera.global_position

# Called with an array of actions (parsed from JSON) to begin the cutscene.
func start_cutscene(action_list: Array) -> void:
	actions = action_list
	current_action_index = 0
	if player:
		player.disable_user_input = true
	process_next_action()

# Loads JSON file, parses it, and starts the cutscene.
func play_cutscene(cutscene_json_path: String) -> void:
	var file = FileAccess.open(cutscene_json_path, FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		file.close()
		var json_parser = JSON.new()
		var error_code = json_parser.parse(json_text)
		if error_code != OK:
			push_error("Error parsing JSON: " + str(error_code))
			return
		var action_list = json_parser.get_data()
		if typeof(action_list) != TYPE_ARRAY:
			push_error("Cutscene JSON must be an array of actions")
			return
		start_cutscene(action_list)
	else:
		push_error("Failed to open cutscene JSON file: " + cutscene_json_path)

func process_next_action() -> void:
	print("Processing action index: ", current_action_index)
	if current_action_index >= actions.size():
		finish_cutscene()
		return

	var action = actions[current_action_index]
	current_action_index += 1

	match action["type"]:
		"zoom":
			var zoom_array = action["zoom"]
			var target_zoom = Vector2(zoom_array[0], zoom_array[1])
			var duration: float = action.get("duration", 1.0)
			var tween = get_tree().create_tween()
			tween.tween_property(camera, "zoom", target_zoom, duration)
			tween.connect("finished", Callable(self, "_on_zoom_finished"), CONNECT_ONE_SHOT)
		
		"move_player":
			var pos_array = action["target_position"]
			var target_pos = Vector2(pos_array[0], pos_array[1])
			if action.has("speed"):
				var new_speed: float = action["speed"]
				var old_speed: float = player.speed
				player.speed = new_speed
				# Use a lambda so that every connection is unique.
				player.connect("auto_move_completed", func() -> void:
					_on_move_completed_with_speed_override(old_speed)
				, CONNECT_ONE_SHOT)
			else:
				player.connect("auto_move_completed", func() -> void:
					_on_move_completed()
				, CONNECT_ONE_SHOT)
			player.auto_move_to_position(target_pos)
		
		"move_npc":
			# Look up the NPC from the "npc" key.
			var target_npc: Node = null
			if action.has("npc"):
				var npc_identifier = action["npc"]
				if npc_identifier is String:
					for npc in npcs:
						if npc.name == npc_identifier:
							target_npc = npc
							break
				elif npc_identifier is int:
					if npc_identifier < npcs.size():
						target_npc = npcs[npc_identifier]
				if not target_npc:
					push_error("NPC not found for move_npc action with identifier: " + str(npc_identifier))
					process_next_action()
					return
			else:
				push_error("Missing npc key in move_npc action")
				process_next_action()
				return

			var pos_array = action["target_position"]
			var target_pos = Vector2(pos_array[0], pos_array[1])
			if action.has("speed"):
				var new_speed: float = action["speed"]
				var old_speed: float = target_npc.speed
				target_npc.speed = new_speed
				target_npc.connect("npc_move_completed", func() -> void:
					_on_move_completed_with_speed_override_npc(target_npc, old_speed)
				, CONNECT_ONE_SHOT)
			else:
				target_npc.connect("npc_move_completed", func() -> void:
					_on_move_completed_npc()
				, CONNECT_ONE_SHOT)
			target_npc.auto_move_to_position(target_pos)
		
		"move_camera":
			var target_pos: Vector2
			if action.has("target_npc"):
				var npc_name: String = action["target_npc"]
				var found_npc: Node = null
				for npc in npcs:
					if npc.name == npc_name:
						found_npc = npc
						break
				if found_npc:
					target_pos = found_npc.global_position
				else:
					push_error("NPC not found with name: " + npc_name)
					process_next_action()
					return
			else:
				var pos_array = action["target_position"]
				target_pos = Vector2(pos_array[0], pos_array[1])
			var duration: float = action.get("duration", 1.0)
			var tween = get_tree().create_tween()
			tween.tween_property(camera, "global_position", target_pos, duration)
			tween.connect("finished", Callable(self, "_on_camera_move_finished"), CONNECT_ONE_SHOT)
		
		"dialogue":
			var target_npc: Node = null
			if action.has("npc"):
				var npc_identifier = action["npc"]
				if npc_identifier is String:
					for npc in npcs:
						if npc.name == npc_identifier:
							target_npc = npc
							break
				elif npc_identifier is int:
					if npc_identifier < npcs.size():
						target_npc = npcs[npc_identifier]
				if not target_npc:
					push_error("NPC not found for dialogue action with identifier: " + str(npc_identifier))
					process_next_action()
					return
			else:
				push_error("Missing npc key in dialogue action")
				process_next_action()
				return
			var dialogue_key: String = action["dialogue_key"]
			var dialogue_balloon = target_npc.show_dialogue(dialogue_key)
			dialogue_balloon.connect("dialogue_finished", Callable(self, "_on_dialogue_finished"), CONNECT_ONE_SHOT)
		
		"npc_action":
			var target_npc: Node = null
			if action.has("npc"):
				var npc_identifier = action["npc"]
				if npc_identifier is String:
					for npc in npcs:
						if npc.name == npc_identifier:
							target_npc = npc
							break
				elif npc_identifier is int:
					if npc_identifier < npcs.size():
						target_npc = npcs[npc_identifier]
				if not target_npc:
					push_error("NPC not found for npc_action with identifier: " + str(npc_identifier))
					process_next_action()
					return
			else:
				push_error("npc key missing in npc_action")
				process_next_action()
				return
			var npc_action_name: String = action["action"]
			if target_npc.has_method(npc_action_name):
				target_npc.call(npc_action_name)
			else:
				push_error("NPC " + target_npc.name + " does not have method " + npc_action_name)
			process_next_action()
		
		"npc_hurt":
			var target_npc: Node = null
			if action.has("npc"):
				var npc_identifier = action["npc"]
				if npc_identifier is String:
					for npc in npcs:
						if npc.name == npc_identifier:
							target_npc = npc
							break
				elif npc_identifier is int:
					if npc_identifier < npcs.size():
						target_npc = npcs[npc_identifier]
				if not target_npc:
					push_error("NPC not found for npc_hurt action with identifier: " + str(npc_identifier))
					process_next_action()
					return
			else:
				push_error("Missing npc key in npc_hurt action")
				process_next_action()
				return

			if target_npc.has_method("play_hurt_animation"):
				target_npc.call("play_hurt_animation")
				var timer = Timer.new()
				timer.wait_time = 0.3
				timer.one_shot = true
				add_child(timer)
				timer.connect("timeout", Callable(self, "_on_delay_finished").bind(timer), CONNECT_ONE_SHOT)
				timer.start()
			else:
				push_error("NPC " + target_npc.name + " does not have method play_hurt_animation")
				process_next_action()
		
		"npc_idle_sword":
			var target_npc: Node = null
			if action.has("npc"):
				var npc_identifier = action["npc"]
				if npc_identifier is String:
					for npc in npcs:
						if npc.name == npc_identifier:
							target_npc = npc
							break
				elif npc_identifier is int:
					if npc_identifier < npcs.size():
						target_npc = npcs[npc_identifier]
				if not target_npc:
					push_error("NPC not found for npc_idle_sword action with identifier: " + str(npc_identifier))
					process_next_action()
					return
			else:
				push_error("Missing npc key in npc_idle_sword action")
				process_next_action()
				return

			if target_npc.has_method("set_idle_with_sword_mode"):
				target_npc.call("set_idle_with_sword_mode", true)
			else:
				push_error("NPC " + target_npc.name + " does not have method set_idle_with_sword_mode")
			process_next_action()
		
		"npc_idle":
			var target_npc: Node = null
			if action.has("npc"):
				var npc_identifier = action["npc"]
				if npc_identifier is String:
					for npc in npcs:
						if npc.name == npc_identifier:
							target_npc = npc
							break
				elif npc_identifier is int:
					if npc_identifier < npcs.size():
						target_npc = npcs[npc_identifier]
				if not target_npc:
					push_error("NPC not found for npc_idle action with identifier: " + str(npc_identifier))
					process_next_action()
					return
			else:
				push_error("Missing npc key in npc_idle action")
				process_next_action()
				return

			if target_npc.has_method("set_idle_with_sword_mode"):
				target_npc.call("set_idle_with_sword_mode", false)
			else:
				push_error("NPC " + target_npc.name + " does not have method set_idle_with_sword_mode")
			process_next_action()
		
		"delete_npc":
			# New action to delete an NPC from the scene.
			var target_npc: Node = null
			if action.has("npc"):
				var npc_identifier = action["npc"]
				if npc_identifier is String:
					for i in range(npcs.size()):
						if npcs[i].name == npc_identifier:
							target_npc = npcs[i]
							# Remove from our array as well
							npcs.remove_at(i)
							break
				elif npc_identifier is int:
					if npc_identifier < npcs.size():
						target_npc = npcs[npc_identifier]
						npcs.remove_at(npc_identifier)
				if not target_npc:
					push_error("NPC not found for delete_npc action with identifier: " + str(npc_identifier))
				else:
					print("Deleting NPC: ", target_npc.name)
					target_npc.queue_free()
			else:
				push_error("Missing npc key in delete_npc action")
			process_next_action()
		
		"delay":
			var delay_time: float = action["duration"]
			var timer = Timer.new()
			timer.wait_time = delay_time
			timer.one_shot = true
			add_child(timer)
			timer.connect("timeout", Callable(self, "_on_delay_finished").bind(timer), CONNECT_ONE_SHOT)
			timer.start()
		
		"turn_player":
			var turn_direction = action["direction"]
			if turn_direction == "left":
				player.set_facing_direction(true)
			elif turn_direction == "right":
				player.set_facing_direction(false)
			else:
				push_error("Invalid direction for turn_player: " + str(turn_direction))
			process_next_action()
		
		"turn_npc":
			var target_npc: Node = null
			if action.has("npc"):
				var npc_identifier = action["npc"]
				if npc_identifier is String:
					for npc in npcs:
						if npc.name == npc_identifier:
							target_npc = npc
							break
				elif npc_identifier is int:
					if npc_identifier < npcs.size():
						target_npc = npcs[npc_identifier]
				if not target_npc:
					push_error("NPC not found for turn_npc action with identifier: " + str(npc_identifier))
					process_next_action()
					return
			else:
				push_error("Missing npc key in turn_npc action")
				process_next_action()
				return
			var turn_direction = action["direction"]
			if turn_direction == "left":
				target_npc.set_facing_direction(true)
			elif turn_direction == "right":
				target_npc.set_facing_direction(false)
			else:
				push_error("Invalid direction for turn_npc: " + str(turn_direction))
			process_next_action()
		
		_:
			push_error("Unknown action type: " + str(action["type"]))
			process_next_action()

func _on_zoom_finished() -> void:
	print("Zoom finished")
	process_next_action()

func _on_move_completed() -> void:
	print("Player move completed")
	process_next_action()

func _on_move_completed_with_speed_override(old_speed: float) -> void:
	print("Player move completed with speed override; restoring speed to ", old_speed)
	player.speed = old_speed
	process_next_action()

func _on_move_completed_npc() -> void:
	print("NPC move completed (no speed override)")
	process_next_action()

func _on_move_completed_with_speed_override_npc(target_npc: Node, old_speed: float) -> void:
	print("NPC move completed with speed override; restoring ", target_npc.name, " speed to ", old_speed)
	target_npc.speed = old_speed
	process_next_action()

func _on_dialogue_finished() -> void:
	print("Dialogue finished")
	process_next_action()

func _on_camera_move_finished() -> void:
	print("Camera move finished")
	process_next_action()

func _on_delay_finished(timer: Timer) -> void:
	timer.queue_free()
	print("Delay finished")
	process_next_action()

func finish_cutscene() -> void:
	print("Cutscene finished!")
	if camera and player:
		var tween = get_tree().create_tween()
		tween.tween_property(camera, "zoom", original_zoom, 1.0)
		tween.tween_property(camera, "global_position", player.global_position, 1.0)
		tween.connect("finished", Callable(self, "_on_camera_reset_finished"), CONNECT_ONE_SHOT)
	else:
		print("No camera or player assigned to reset camera.")
		_on_camera_reset_finished()

func _on_camera_reset_finished() -> void:
	print("Camera has been reset to original settings.")
	$ColorRect.hide()
	if player:
		player.disable_user_input = false
	emit_signal("cutscene_finished")
