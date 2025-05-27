# Info.gd — Godot 4.22
extends Node2D
class_name SaveInfo

@onready var btn_play:   TextureButton = $PlayButton
@onready var btn_delete: TextureButton = $DeleteButton
@onready var lbl_name:   RichTextLabel  = $Name
@onready var player:     Node   = $Control/Player

const DEFAULT_SCENE     := "res://CharacterCreator/CharacterCreator.tscn"
const SAVE_PATH_FORMAT  := "user://saveslot%d.json"
const SAVE_DATA_PATH    := "user://save_data.json"

func _ready() -> void:
	btn_play.pressed.connect(_on_play_pressed)
	btn_delete.pressed.connect(_on_delete_pressed)
	await get_tree().process_frame  # ensure player node is ready
	lbl_name.text = "Captain %s" % player.name_input

func _on_play_pressed() -> void:
	var slot_idx = Global.active_save_slot
	var save_data = _load_json(SAVE_PATH_FORMAT % slot_idx)

	if save_data.has("scene"):
		var scene_info = save_data["scene"]
		var scene_path = scene_info.get("name", DEFAULT_SCENE)
		var pos_map    = scene_info.get("position", {})
		var x = pos_map.get("x", 381)
		var y = pos_map.get("y", 23)
		SceneSwitcher.switch_scene(scene_path, Vector2(x, y), "fade")
	else:
		get_tree().change_scene_to_file(DEFAULT_SCENE)

func _on_delete_pressed() -> void:
	var slot_idx = Global.active_save_slot
	var path = SAVE_PATH_FORMAT % slot_idx

	if FileAccess.file_exists(path):
		var dir = DirAccess.open("user://")
		if dir:
			dir.remove("saveslot%d.json" % slot_idx)

	_update_save_registry(slot_idx)
	queue_free()

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	var text := file.get_as_text()
	file.close()

	# parse_string() returns the data (Dictionary/Array) or null on failure
	var data = JSON.parse_string(text)
	return data if data is Dictionary else {}


func _write_json(path: String, data: Dictionary) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func _update_save_registry(slot_idx: int) -> void:
	if not FileAccess.file_exists(SAVE_DATA_PATH):
		return
	var registry = _load_json(SAVE_DATA_PATH)
	registry.erase(str(slot_idx))
	_write_json(SAVE_DATA_PATH, registry)
