extends Node

const ISLAND_SONG_1 := preload("res://SFX/islandsong1.ogg")
const ISLAND_SONG_2 := preload("res://SFX/islandsong2.mp3")
const BOARDING_BATTLE := preload("res://SFX/boardingbattle.ogg")
const SUCCESS_SFX := preload("res://SFX/success.wav")

@onready var music_player: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var sfx_player: AudioStreamPlayer = AudioStreamPlayer.new()

var _island_index: int = 0

func _ready() -> void:
	add_child(music_player)
	add_child(sfx_player)
	music_player.finished.connect(_on_music_finished)
       # In some versions of Godot the signal is named `scene_changed`.
       # Use this to remain compatible across releases.
       get_tree().connect("scene_changed", Callable(self, "_on_scene_changed"))

func _on_scene_changed(scene: Node) -> void:
	var path := scene.scene_file_path if scene else ""
	if path.ends_with("KelptownInnTutorial.tscn") or path.ends_with("islandtutorial.tscn"):
		_start_island_music()
	elif path.ends_with("BoardingBattleTutorial.tscn"):
		_start_boarding_music()
	else:
		stop_music()

func _start_island_music() -> void:
	if music_player.stream == ISLAND_SONG_1 or music_player.stream == ISLAND_SONG_2:
		if music_player.playing:
			return
	_island_index = 0
	music_player.stream = ISLAND_SONG_1
	music_player.stream.loop = false
	music_player.play()

func _start_boarding_music() -> void:
	music_player.stream = BOARDING_BATTLE
	music_player.stream.loop = true
	music_player.play()

func _on_music_finished() -> void:
	if music_player.stream == ISLAND_SONG_1 or music_player.stream == ISLAND_SONG_2:
		_island_index = 1 - _island_index
		music_player.stream = ISLAND_SONG_1 if _island_index == 0 else ISLAND_SONG_2
		music_player.play()

func stop_music() -> void:
	music_player.stop()

func play_success() -> void:
	sfx_player.stream = SUCCESS_SFX
	sfx_player.play()
