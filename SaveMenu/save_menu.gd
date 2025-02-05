extends Node2D

# ──────────────────────────────────────────────────────────────────────────────
# CONSTANTS & GLOBAL DECLARATIONS
# ──────────────────────────────────────────────────────────────────────────────
const BW_ANIMATIONS    = ["BW1", "BW2", "BW3", "BW4", "BW5", "BW6", "BW7", "BW8"]
const C_ANIMATIONS     = ["C1", "C2", "C3", "C4", "C5", "C6", "C7", "C8"]
const CANIM_ANIMATIONS = ["CAnim1", "CAnim2", "CAnim3", "CAnim4", "CAnim5", "CAnim6", "CAnim7", "CAnim8"]

const SAVE_FILE_PATH  = "user://save_data.json"

# Holds the main save data in memory
var save_data: Dictionary = {}
var active_slot_index: int = -1

# We keep a timer for each save slot to handle the "BW → CAnim → C" transition
var animation_timers: Array = []

@export var header_node: Node2D
@export var bw_noise: AudioStreamPlayer
@export var c_noise: AudioStreamPlayer
@export var add_noise: AudioStreamPlayer

var info_instance: Node = null
var InfoScene: PackedScene = preload("res://SaveMenu/Info/info.tscn")

# ──────────────────────────────────────────────────────────────────────────────
# SIGNALS
# ──────────────────────────────────────────────────────────────────────────────
signal show_character_creator(slot_index: int)
signal hide_character_creator()

# ──────────────────────────────────────────────────────────────────────────────
# GODOT LIFECYCLE
# ──────────────────────────────────────────────────────────────────────────────
func _ready():
	_load_save_data()
	_setup_save_slots()
	_initialize_slot_timers()
	# Note: deletebutton is not connected here because it is only present inside info_instance

# ──────────────────────────────────────────────────────────────────────────────
# FILE I/O: LOADING & SAVING
# ──────────────────────────────────────────────────────────────────────────────
func _load_save_data():
	if FileAccess.file_exists(SAVE_FILE_PATH):
		var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
		var json = JSON.new()
		var parse_result = json.parse(file.get_as_text())
		if parse_result == OK:
			save_data = json.data
		else:
			save_data = {}
		file.close()
	else:
		save_data = {}

func _save_save_data():
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(save_data))
	file.close()

# ──────────────────────────────────────────────────────────────────────────────
# SETUP & INITIALIZATION
# ──────────────────────────────────────────────────────────────────────────────
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
			slot_node.set_meta("BW", animations["BW"])
			slot_node.set_meta("C", animations["C"])
			slot_node.set_meta("CAnim", animations["CAnim"])
		elif i == save_data.size() and assigned_sets.size() < unique_sets.size():
			# Next "Add" slot: pick the next unassigned set
			for unique_set in unique_sets:
				if unique_set not in assigned_sets:
					anim_sprite.animation = "Add"
					slot_node.set_meta("BW", unique_set["BW"])
					slot_node.set_meta("C", unique_set["C"])
					slot_node.set_meta("CAnim", unique_set["CAnim"])
					assigned_sets.append(unique_set)
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

# ──────────────────────────────────────────────────────────────────────────────
# SAVE SLOT CLICK HANDLING
# ──────────────────────────────────────────────────────────────────────────────
func _on_save_slot_clicked(_viewport, event, _shape_idx, slot_index):
	if event is InputEventMouseButton and event.is_pressed():
		_reset_other_slots(slot_index)
		_handle_slot_click(slot_index)

# ──────────────────────────────────────────────────────────────────────────────
# INFO SCENE POSITIONING & INPUT
# ──────────────────────────────────────────────────────────────────────────────
func _position_info_scene(slot_index):
	var save_slots = $SaveSlots.get_children()
	var slot_node = save_slots[slot_index]
	# Get the slot's global position.
	var slot_pos = slot_node.global_position
	# Define an offset; adjust as needed.
	var offset = Vector2(115, 0)
	
	# For human slots 1,2,5,6, the indices are 0,1,4,5.
	if slot_index in [0, 1, 4, 5]:
		info_instance.global_position = slot_pos + offset
	else:
		# For human slots 3,4,7,8 (indices 2,3,6,7), position to the left.
		info_instance.global_position = slot_pos - offset

func _unhandled_input(event):
	if event is InputEventMouseButton and event.is_pressed():
		# If the click wasn’t consumed by the Info scene, remove it.
		if info_instance:
			info_instance.queue_free()
			info_instance = null

# ──────────────────────────────────────────────────────────────────────────────
# CLICK HANDLING LOGIC (ADD, BW->C, or existing "C" slot)
# ──────────────────────────────────────────────────────────────────────────────
func _handle_slot_click(slot_index):
	var save_slots = $SaveSlots.get_children()
	var slot_node = save_slots[slot_index]
	var anim_sprite = slot_node.get_node("AnimatedSprite2D")

	match anim_sprite.animation:
		"Add":
			add_noise.play()
			_handle_add_slot(slot_node, slot_index)
		_:
			if anim_sprite.animation.begins_with("BW"):
				bw_noise.play()
				_handle_bw_slot(slot_node, slot_index)
			elif anim_sprite.animation.begins_with("C"):
				c_noise.play()
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
	# Update the active slot BEFORE creating the new Info instance.
	Global.active_save_slot = slot_index
	active_slot_index = slot_index

	if info_instance and is_instance_valid(info_instance):
		info_instance.get_parent().remove_child(info_instance)
		info_instance.free()
		info_instance = null

	info_instance = InfoScene.instantiate()
	add_child(info_instance)
	_connect_info_instance_delete_button()  # Connect the delete button if available.
	_position_info_scene(slot_index)

	_cancel_existing_timer(slot_index)
	var timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = 0.5
	timer.connect("timeout", Callable(self, "_on_transition_complete").bind(slot_index))
	animation_timers[slot_index] = timer
	add_child(timer)

	var anim_sprite = slot_node.get_node("AnimatedSprite2D")
	var transition_anim = slot_node.get_meta("CAnim")
	anim_sprite.animation = transition_anim
	timer.start()

func _handle_c_slot(_slot_node, slot_index):
	# Update the active slot BEFORE creating the new Info instance.
	Global.active_save_slot = slot_index
	active_slot_index = slot_index

	if info_instance and is_instance_valid(info_instance):
		info_instance.get_parent().remove_child(info_instance)
		info_instance.free()
		info_instance = null

	info_instance = InfoScene.instantiate()
	add_child(info_instance)
	_connect_info_instance_delete_button()  # Connect the delete button if available.
	_position_info_scene(slot_index)

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

# ──────────────────────────────────────────────────────────────────────────────
# SLOT RESET & TIMER CLEANUP
# ──────────────────────────────────────────────────────────────────────────────
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

# ──────────────────────────────────────────────────────────────────────────────
# TRANSITION COMPLETION
# ──────────────────────────────────────────────────────────────────────────────
func _on_transition_complete(slot_index):
	var save_slots = $SaveSlots.get_children()
	var slot_node = save_slots[slot_index]
	var anim_sprite = slot_node.get_node("AnimatedSprite2D")
	# Switch to the "C" animation
	var target_anim = slot_node.get_meta("C")
	anim_sprite.animation = target_anim
	_cancel_existing_timer(slot_index)

# ──────────────────────────────────────────────────────────────────────────────
# HEADER ANIMATION FUNCTION
# ──────────────────────────────────────────────────────────────────────────────
func animate_header():
	if not header_node:
		print("Header node is not assigned.")
		return
	
	# Create a new Tween
	var tween = create_tween()
	tween.tween_property(header_node, "position:y", 29, 0.4)
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_IN_OUT)

# ──────────────────────────────────────────────────────────────────────────────
# DELETION FUNCTIONALITY
# ──────────────────────────────────────────────────────────────────────────────
# This function is called when the delete button is pressed.
func delete_current_save():
	var slot_index = active_slot_index

	# 1. Delete the info_instance if it exists.
	if info_instance and is_instance_valid(info_instance):
		info_instance.queue_free()
		info_instance = null

	# 2. Remove the save data for this slot and update the JSON file.
	if save_data.has(str(slot_index)):
		save_data.erase(str(slot_index))
		_save_save_data()
	else:
		print("No saved data for slot", slot_index)

	# 3. Refresh all save slots to update their visuals.
	_refresh_save_slots()

# Helper function to rebuild slot animations based on the current save_data.
func _refresh_save_slots():
	var save_slots = $SaveSlots.get_children()

	# Build the list of unique animation sets.
	var unique_sets = []
	for i in range(BW_ANIMATIONS.size()):
		unique_sets.append({
			"BW":    BW_ANIMATIONS[i],
			"C":     C_ANIMATIONS[i],
			"CAnim": CANIM_ANIMATIONS[i]
		})

	# Build the list of assigned sets from save_data.
	var assigned_sets = []
	for key in save_data.keys():
		assigned_sets.append(save_data[key])

	# Determine the lowest available (empty) slot index.
	var add_index = -1
	for i in range(save_slots.size()):
		if not save_data.has(str(i)):
			add_index = i
			break

	# Loop over each slot and update its animation.
	for i in range(save_slots.size()):
		var slot_node = save_slots[i]
		var anim_sprite = slot_node.get_node("AnimatedSprite2D")
		
		if save_data.has(str(i)):
			# Slot has saved data: use its "BW" animation.
			var animations = save_data[str(i)]
			anim_sprite.animation = animations["BW"]
			slot_node.set_meta("BW", animations["BW"])
			slot_node.set_meta("C", animations["C"])
			slot_node.set_meta("CAnim", animations["CAnim"])
		elif i == add_index and assigned_sets.size() < unique_sets.size():
			# The first available slot becomes "Add".
			for unique_set in unique_sets:
				if unique_set not in assigned_sets:
					anim_sprite.animation = "Add"
					slot_node.set_meta("BW", unique_set["BW"])
					slot_node.set_meta("C", unique_set["C"])
					slot_node.set_meta("CAnim", unique_set["CAnim"])
					assigned_sets.append(unique_set)
					break
		else:
			# All other empty slots are marked "Empty".
			anim_sprite.animation = "Empty"

# ──────────────────────────────────────────────────────────────────────────────
# HELPER: CONNECT DELETE BUTTON IN info_instance (if it exists)
# ──────────────────────────────────────────────────────────────────────────────
func _connect_info_instance_delete_button():
	# Check if the info_instance has a child named "deletebutton"
	if info_instance and info_instance.has_node("deletebutton"):
		var del_btn = info_instance.get_node("deletebutton")
		var callable_delete = Callable(self, "delete_current_save")
		# Connect only if not already connected.
		if not del_btn.is_connected("pressed", callable_delete):
			del_btn.pressed.connect(delete_current_save)
