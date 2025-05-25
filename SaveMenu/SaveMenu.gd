# SaveMenu.gd ─ Godot 4.22
extends Node2D
class_name SaveMenu

signal show_character_creator(slot_index: int)
signal hide_character_creator()

@onready var header:           Node2D            = $Header
@onready var slots_container:  Node              = $SaveSlots
@onready var sfx_slot_click:   AudioStreamPlayer = $SaveSlotClickNoise
@onready var sfx_add_slot:     AudioStreamPlayer = $AddSaveSlotNoise

const SAVE_PATH_FORMAT    := "user://saveslot%d.json"
const ICON_PATH_FORMAT    := "res://SaveMenu/SaveSlot/assets/%s"
const HEADER_MOVE_Y       := 17.0
const HEADER_TWEEN_TIME   := 0.3

enum SlotType { SAVED, ADD, EMPTY }

const ADD_ICON:   Texture2D = preload("res://SaveMenu/SaveSlot/assets/addsavesloticon.png")
const EMPTY_ICON: Texture2D = preload("res://SaveMenu/SaveSlot/assets/emptysavesloticon.png")

var saved_icons: Array[Texture2D] = []
var info_popup:  Node2D          = null
var InfoScene:   PackedScene     = preload("res://SaveMenu/Info/Info.tscn")
var active_slot: int             = -1

func _ready() -> void:
	# load numbered slot icons dynamically
	for i in range(slots_container.get_child_count()):
		var p := ICON_PATH_FORMAT % ("saveslot%dicon.png" % (i + 1))
		saved_icons.append(load(p) as Texture2D)

	# connect each slot’s input_event
	for i in range(slots_container.get_child_count()):
		slots_container.get_child(i).connect("input_event", Callable(self, "_on_slot_input").bind(i))

	_refresh_slots()

func _refresh_slots() -> void:
	var count := slots_container.get_child_count()
	var has_save := []
	for i in range(count):
		has_save.append(FileAccess.file_exists(SAVE_PATH_FORMAT % i))
	var first_empty := has_save.find(false)

	for i in range(count):
		var slot   := slots_container.get_child(i)
		var sprite := slot.get_node("Sprite2D") as Sprite2D

		if has_save[i]:
			sprite.texture = saved_icons[i]
			slot.set_meta("slot_type", SlotType.SAVED)
		elif i == first_empty:
			sprite.texture = ADD_ICON
			slot.set_meta("slot_type", SlotType.ADD)
		else:
			sprite.texture = EMPTY_ICON
			slot.set_meta("slot_type", SlotType.EMPTY)

func _on_slot_input(_vp, event: InputEvent, _shape_idx, slot_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		_process_slot(slot_idx)

func _process_slot(slot_idx: int) -> void:
	var slot      := slots_container.get_child(slot_idx)
	var slot_type := slot.get_meta("slot_type") as int

	match slot_type:
		SlotType.ADD:
			sfx_add_slot.play()
			_create_save(slot_idx)
			var tw := animate_header(true)
			await tw.finished
			emit_signal("show_character_creator", slot_idx)

		SlotType.SAVED:
			sfx_slot_click.play()
			_open_info(slot_idx)

		SlotType.EMPTY:
			pass

func _create_save(slot_idx: int) -> void:
	var path := SAVE_PATH_FORMAT % slot_idx
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"slot": slot_idx}))
		file.close()

	active_slot = slot_idx
	Global.active_save_slot = slot_idx
	QuestManager.load_quest_data()
	_refresh_slots()

func _open_info(slot_idx: int) -> void:
	active_slot = slot_idx
	Global.active_save_slot = slot_idx
	QuestManager.load_quest_data()

	if info_popup and is_instance_valid(info_popup):
		info_popup.queue_free()

	info_popup = InfoScene.instantiate() as Node2D
	add_child(info_popup)
	info_popup.global_position = Vector2(240, -48)

	var del_btn := info_popup.get_node("DeleteButton") as TextureButton
	del_btn.connect("pressed", Callable(self, "_delete_current_save"))

func _delete_current_save() -> void:
	var path := SAVE_PATH_FORMAT % active_slot
	if FileAccess.file_exists(path):
		var dir := DirAccess.open("user://")
		if dir:
			dir.remove_file("saveslot%d.json" % active_slot)

	if info_popup and is_instance_valid(info_popup):
		info_popup.queue_free()
		info_popup = null

	_refresh_slots()

# Now public so TitleScreen can call it
func animate_header(down: bool) -> Tween:
	var delta := HEADER_MOVE_Y * (1 if down else -1)
	var tw := create_tween()
	tw.tween_property(header, "global_position:y",
		header.global_position.y + delta, HEADER_TWEEN_TIME
	)
	return tw

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and info_popup:
		info_popup.queue_free()
		info_popup = null
