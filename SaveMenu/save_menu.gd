extends Node2D

@onready var header_node: Node2D = $Header
@onready var save_slot_click_noise: AudioStreamPlayer = $SaveSlotClickNoise
@onready var add_save_slot_noise: AudioStreamPlayer = $AddSaveSlotNoise

var info_instance: Node = null
var InfoScene: PackedScene = preload("res://SaveMenu/Info/info.tscn")
var active_slot_index: int = -1

signal show_character_creator(slot_index: int)
signal hide_character_creator()

func _ready() -> void:
	_setup_save_slots()


# ──────────────────────────────────────────────────────────────────────────────
# SETUP & REFRESH SAVE SLOTS
# ──────────────────────────────────────────────────────────────────────────────
func _setup_save_slots() -> void:
	var save_slots = $SaveSlots.get_children()
	var saved_status = []
	
	# Determine saved status for each slot.
	for i in range(save_slots.size()):
		saved_status.append(FileAccess.file_exists("user://saveslot%s.json" % i))
	var first_unsaved = saved_status.find(false)
	
	# Update visuals and connect input events.
	for i in range(save_slots.size()):
		var slot = save_slots[i]
		var sprite = slot.get_node("Sprite2D")
		
		if saved_status[i]:
			# For a saved slot, load the texture matching its number (using i+1).
			sprite.texture = load("res://SaveMenu/assets/saveslot%dicon.png" % (i + 1))
			slot.set_meta("slot_type", "saved")
		else:
			if first_unsaved == i:
				# The first unsaved slot shows the "add" icon.
				sprite.texture = load("res://SaveMenu/assets/addsavesloticon.png")
				slot.set_meta("slot_type", "add")
			else:
				# Other unsaved slots show the "empty" icon.
				sprite.texture = load("res://SaveMenu/assets/emptysavesloticon.png")
				slot.set_meta("slot_type", "empty")
		
		# Connect the input event, binding the slot index.
		slot.connect("input_event", Callable(self, "_on_save_slot_clicked").bind(i))


func _refresh_save_slots() -> void:
	var save_slots = $SaveSlots.get_children()
	var saved_status = []
	
	for i in range(save_slots.size()):
		saved_status.append(FileAccess.file_exists("user://saveslot%s.json" % i))
	var first_unsaved = saved_status.find(false)
	
	for i in range(save_slots.size()):
		var slot = save_slots[i]
		var sprite = slot.get_node("Sprite2D")
		
		if saved_status[i]:
			sprite.texture = load("res://SaveMenu/assets/saveslot%dicon.png" % (i + 1))
			slot.set_meta("slot_type", "saved")
		else:
			if first_unsaved == i:
				sprite.texture = load("res://SaveMenu/assets/addsavesloticon.png")
				slot.set_meta("slot_type", "add")
			else:
				sprite.texture = load("res://SaveMenu/assets/emptysavesloticon.png")
				slot.set_meta("slot_type", "empty")


# ──────────────────────────────────────────────────────────────────────────────
# INPUT & SLOT HANDLING
# ──────────────────────────────────────────────────────────────────────────────
func _on_save_slot_clicked(_viewport, event, _shape_idx, slot_index: int) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		_handle_slot_click(slot_index)


func _handle_slot_click(slot_index: int) -> void:
	var slot = $SaveSlots.get_children()[slot_index]
	var slot_type = slot.get_meta("slot_type")
	
	match slot_type:
		"add":
			add_save_slot_noise.play()
			_handle_add_slot(slot, slot_index)
		"empty":
			# Ignore clicks on inactive unsaved slots.
			pass
		_:
			# For a saved slot.
			save_slot_click_noise.play()
			_handle_c_slot(slot, slot_index)


func _handle_add_slot(slot: Node, slot_index: int) -> void:
	# Save initial data for this slot.
	var save_data = {"slot": slot_index}
	var path = "user://saveslot%s.json" % slot_index
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()
	
	Global.active_save_slot = slot_index
	QuestManager.load_quest_data()
	active_slot_index = slot_index
	
	# Update the slot's texture.
	var sprite = slot.get_node("Sprite2D")
	sprite.texture = load("res://SaveMenu/assets/saveslot%dicon.png" % (slot_index + 1))
	slot.set_meta("slot_type", "saved")
	await get_tree().create_timer(0.5).timeout
	# Animate the header upward by 29 pixels (global position).
	var tween = animate_header(true)
	await tween.finished
	
	# Once the animation is complete, show the character creator.
	emit_signal("show_character_creator", slot_index)


func _handle_c_slot(slot: Node, slot_index: int) -> void:
	Global.active_save_slot = slot_index
	QuestManager.load_quest_data()
	active_slot_index = slot_index
	
	if info_instance and is_instance_valid(info_instance):
		info_instance.queue_free()
		info_instance = null
	
	info_instance = InfoScene.instantiate()
	add_child(info_instance)
	_connect_info_instance_delete_button()
	
	# Position the info scene at (240, -48).
	info_instance.global_position = Vector2(240, -48)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed() and info_instance:
		info_instance.queue_free()
		info_instance = null


# ──────────────────────────────────────────────────────────────────────────────
# HEADER ANIMATION & SAVE DELETION
# This function simply adds or subtracts 29 pixels to the header's global y position.
func animate_header(reverse: bool = false) -> Tween:
	# If reverse is false, move down by 29 pixels; if true, move up by 29 pixels.
	var offset: int = -17 if not reverse else 17
	var tween = create_tween()
	tween.tween_property(header_node, "global_position:y", header_node.global_position.y + offset, 0.3) \
		.set_trans(Tween.TRANS_LINEAR) \
		.set_ease(Tween.EASE_IN_OUT)
	return tween


func delete_current_save() -> void:
	var slot_index = active_slot_index
	
	if info_instance and is_instance_valid(info_instance):
		info_instance.queue_free()
		info_instance = null
	
	var path = "user://saveslot%s.json" % slot_index
	if FileAccess.file_exists(path):
		var dir = DirAccess.open("user://")
		if dir:
			dir.remove_file("saveslot%s.json" % slot_index)
	else:
		print("No save file for slot", slot_index)
	
	_refresh_save_slots()


func _connect_info_instance_delete_button() -> void:
	var del_btn = info_instance.get_node("DeleteButton")
	var delete_callable = Callable(self, "delete_current_save")
	if not del_btn.is_connected("pressed", delete_callable):
		del_btn.pressed.connect(delete_callable)
