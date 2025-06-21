# Info.gd — Godot 4.22
extends Node2D

@onready var btn_play:   TextureButton = $PlayButton
@onready var btn_delete: TextureButton = $DeleteButton
@onready var lbl_name:   RichTextLabel = $Name
@onready var player:     Node2D        = $Control/Player
@onready var sfx_button: AudioStreamPlayer = $ButtonSound

const SAVE_PATH_FORMAT  := "user://saveslot%d.json"

func _ready() -> void:
	btn_play.pressed.connect(Callable(self, "_on_play_pressed"))
	btn_delete.pressed.connect(Callable(self, "_on_delete_pressed"))
	await get_tree().process_frame  # ensure player node is ready
	lbl_name.text = "Captain %s" % player.name_input

func _on_play_pressed() -> void:
		if sfx_button:
				SoundManager.play_sfx(sfx_button.stream)
		# 1) Make sure the SaveMenu already set Global.active_save_slot
	# 2) Load everything (scene, player pos, crew, quests)
		Global.load_game_state()
		# 3) Close this popup immediately
		queue_free()

func _on_delete_pressed() -> void:
	if sfx_button:
			SoundManager.play_sfx(sfx_button.stream)
	var slot_idx = Global.active_save_slot
	var path = SAVE_PATH_FORMAT % slot_idx
	if FileAccess.file_exists(path):
		var dir = DirAccess.open("user://")
		if dir:
			dir.remove("saveslot%d.json" % slot_idx)

	# assume SaveMenu will refresh slots on popup close
	queue_free()
