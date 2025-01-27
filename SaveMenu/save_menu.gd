# SaveMenu.gd
extends Node2D

#
# ──────────────────────────────────────────────────────────────────────────────
#  CONSTANTS & GLOBAL DECLARATIONS
# ──────────────────────────────────────────────────────────────────────────────
#
const BW_ANIMATIONS    = ["BW1", "BW2", "BW3", "BW4", "BW5", "BW6", "BW7", "BW8"]
const C_ANIMATIONS     = ["C1", "C2", "C3", "C4", "C5", "C6", "C7", "C8"]
const CANIM_ANIMATIONS = ["CAnim1", "CAnim2", "CAnim3", "CAnim4", "CAnim5", "CAnim6", "CAnim7", "CAnim8"]

const SAVE_FILE_PATH  = "user://save_data.json"

# Holds the main save data in memory
var save_data: Dictionary = {}
var active_slot_index: int = -1

# We keep a timer for each save slot to handle the "BW → CAnim → C" transition
var animation_timers: Array = []

# Scene assigned for character creation (Not directly manipulated now)
@export var character_creator_scene: Node2D
@export var header_node: Node2D

#
# ──────────────────────────────────────────────────────────────────────────────
#  SIGNALS
# ──────────────────────────────────────────────────────────────────────────────
#
signal show_character_creator(slot_index: int)
signal hide_character_creator()

#
# ──────────────────────────────────────────────────────────────────────────────
#  GODOT LIFECYCLE
# ──────────────────────────────────────────────────────────────────────────────
#
func _ready():
	_load_save_data()
	_setup_save_slots()
	_initialize_slot_timers()

#
# ──────────────────────────────────────────────────────────────────────────────
#  FILE I/O: LOADING & SAVING
# ──────────────────────────────────────────────────────────────────────────────
#
func _load_save_data():
	if FileAccess.file_exists(SAVE_FILE_PATH):
		var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
		var json = JSON.new()
		var parse_result = json.parse(file.get_as_text())

		if parse_result == OK:
			save_data = json.data
		else:
			save_data = {}  # If parsing fails, start empty

		file.close()
	else:
		save_data = {}  # If no file, start empty


func _save_save_data():
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(save_data))
	file.close()

#
# ──────────────────────────────────────────────────────────────────────────────
#  SETUP & INITIALIZATION
# ──────────────────────────────────────────────────────────────────────────────
#
func _setup_save_slots():
	var save_slots = $SaveSlots.get_children()

	# Create 8 unique sets of animations (aligned by index)
	var unique_sets = []
	for i in range(8):
		unique_sets.append({
			"BW":    BW_ANIMATIONS[i],
			"C":     C_ANIMATIONS[i],
			"CAnim": CANIM_ANIMATIONS[i]
		})

	# Collect sets that are already assigned in save_data
	var assigned_sets = []
	for key in save_data.keys():
		var used_set = {
			"BW":    save_data[key]["BW"],
			"C":     save_data[key]["C"],
			"CAnim": save_data[key]["CAnim"]
		}
		assigned_sets.append(used_set)

	# Assign animations or mark as "Add"/"Empty" for each slot
	for i in range(save_slots.size()):
		var slot_node = save_slots[i]
		var anim_sprite = slot_node.get_node("AnimatedSprite2D")

		if save_data.has(str(i)):
			# We have saved info, use it
			var animations = save_data[str(i)]
			anim_sprite.animation = animations["BW"]
			slot_node.set_meta("BW",    animations["BW"])
			slot_node.set_meta("C",     animations["C"])
			slot_node.set_meta("CAnim", animations["CAnim"])

		elif i == save_data.size() and len(assigned_sets) < unique_sets.size():
			# Next "Add" slot: pick the next unassigned set
			for unique_set in unique_sets:
				if unique_set not in assigned_sets:
					anim_sprite.animation = "Add"
					slot_node.set_meta("BW",    unique_set["BW"])
					slot_node.set_meta("C",     unique_set["C"])
					slot_node.set_meta("CAnim", unique_set["CAnim"])
					break
		else:
			# Empty slot
			anim_sprite.animation = "Empty"

		# Connect the click event for each slot
		slot_node.connect("input_event", Callable(self, "_on_save_slot_clicked").bind(i))


func _initialize_slot_timers():
	var save_slots = $SaveSlots.get_children()
	animation_timers.resize(save_slots.size())

	for i in range(animation_timers.size()):
		animation_timers[i] = null

#
# ──────────────────────────────────────────────────────────────────────────────
#  SAVE SLOT CLICK HANDLING
# ──────────────────────────────────────────────────────────────────────────────
#
func _on_save_slot_clicked(_viewport, event, _shape_idx, slot_index):
	if event is InputEventMouseButton and event.is_pressed():
		_reset_other_slots(slot_index)
		_handle_slot_click(slot_index)

#
# ──────────────────────────────────────────────────────────────────────────────
#  CLICK HANDLING LOGIC (ADD, BW->C, or existing "C" slot)
# ──────────────────────────────────────────────────────────────────────────────
#
func _handle_slot_click(slot_index):
	var save_slots = $SaveSlots.get_children()
	var slot_node = save_slots[slot_index]
	var anim_sprite = slot_node.get_node("AnimatedSprite2D")

	match anim_sprite.animation:
		"Add":
			_handle_add_slot(slot_node, slot_index)
		_:
			if anim_sprite.animation.begins_with("BW"):
				_handle_bw_slot(slot_node, slot_index)
			elif anim_sprite.animation.begins_with("C"):
				_handle_c_slot(slot_node, slot_index)
			else:
				print("Unhandled animation state:", anim_sprite.animation)

func _handle_add_slot(slot_node, slot_index):
	# Use pre-assigned unique animations stored in meta
	var animations = {
		"BW":    slot_node.get_meta("BW"),
		"C":     slot_node.get_meta("C"),
		"CAnim": slot_node.get_meta("CAnim")
	}
	save_data[str(slot_index)] = animations
	_save_save_data()

	# Set active slot
	Global.active_save_slot = slot_index
	active_slot_index = slot_index

	# Emit a signal to show character creator
	emit_signal("show_character_creator", slot_index)

func _handle_bw_slot(slot_node, slot_index):
	# Prepare a transition from BW -> CAnim -> C
	_cancel_existing_timer(slot_index)

	# Create a new timer for the transition
	var timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = 0.5
	timer.connect("timeout", Callable(self, "_on_transition_complete").bind(slot_index))
	animation_timers[slot_index] = timer
	add_child(timer)

	# Switch to the "CAnimX" animation for the half-second transition
	var anim_sprite = slot_node.get_node("AnimatedSprite2D")
	var transition_anim = slot_node.get_meta("CAnim")
	anim_sprite.animation = transition_anim
	timer.start()

	# Update the active slot
	Global.active_save_slot = slot_index
	active_slot_index = slot_index

func _handle_c_slot(_slot_node, slot_index):
	# For "C*" animations, we might have a corresponding save file
	var save_file_path = "user://saveslot%s.json" % slot_index

	if FileAccess.file_exists(save_file_path):
		var file = FileAccess.open(save_file_path, FileAccess.READ)
		var json = JSON.new()
		var parse_result = json.parse(file.get_as_text())
		if parse_result == OK:
			var save_file_data = json.data
			if save_file_data.has("character") and save_file_data["character"] != {}:
				# Valid character data: jump to Island scene
				Global.active_save_slot = slot_index
				active_slot_index = slot_index
				get_tree().change_scene_to_file("res://Island/Island.tscn")
			else:
				_create_new_save_file(slot_index, save_file_data)
		else:
			print("Failed to parse save file for slot %s" % slot_index)
		file.close()
	else:
		# If no file, create one
		var new_save_data = {"character": {}}
		_create_new_save_file(slot_index, new_save_data)

func _create_new_save_file(slot_index, save_file_data):
	# Store initial data to the save file
	var save_file_path = "user://saveslot%s.json" % slot_index
	var file_write = FileAccess.open(save_file_path, FileAccess.WRITE)
	file_write.store_string(JSON.stringify(save_file_data))
	file_write.close()

	# Update active slot
	Global.active_save_slot = slot_index
	active_slot_index = slot_index

	# Emit a signal to show character creator
	emit_signal("show_character_creator", slot_index)

#
# ──────────────────────────────────────────────────────────────────────────────
#  SLOT RESET & TIMER CLEANUP
# ──────────────────────────────────────────────────────────────────────────────
#
func _reset_other_slots(except_index):
	var save_slots = $SaveSlots.get_children()
	for i in range(save_slots.size()):
		if i != except_index:
			var other_slot_node = save_slots[i]
			var other_anim_sprite = other_slot_node.get_node("AnimatedSprite2D")

			# If this slot is showing "C" or "CAnim", revert to "BW" animations
			if other_anim_sprite.animation.begins_with("C"):
				other_anim_sprite.animation = other_slot_node.get_meta("BW")

			_cancel_existing_timer(i)

func _cancel_existing_timer(slot_index):
	# If there's an active timer, free it and clear the reference
	if animation_timers[slot_index]:
		animation_timers[slot_index].queue_free()
		animation_timers[slot_index] = null

#
# ──────────────────────────────────────────────────────────────────────────────
#  TRANSITION COMPLETION
# ──────────────────────────────────────────────────────────────────────────────
#
func _on_transition_complete(slot_index):
	var save_slots = $SaveSlots.get_children()
	var slot_node = save_slots[slot_index]
	var anim_sprite = slot_node.get_node("AnimatedSprite2D")

	# Switch to the "C" animation
	var target_anim = slot_node.get_meta("C")
	anim_sprite.animation = target_anim

	_cancel_existing_timer(slot_index)

#
# ──────────────────────────────────────────────────────────────────────────────
#  HEADER ANIMATION FUNCTION
# ──────────────────────────────────────────────────────────────────────────────
#
func animate_header():
	if not header_node:
		print("Header node is not assigned.")
		return
	
	# Create a new Tween
	var tween = create_tween()
	
	# Animate the y position from 46 to 29 over 1 second
	tween.tween_property(header_node, "position:y", 29, 0.4)
	
	# Set the transition type (optional)
	tween.set_trans(Tween.TRANS_LINEAR)
	
	# Set the easing type (optional)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	# Optional: Handle completion if needed
	# tween.finished.connect(_on_header_animation_complete)
