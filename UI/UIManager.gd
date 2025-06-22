# UIManager.gd — Godot 4.22
extends CanvasLayer

# ──────────────────────────
# Node references
# ──────────────────────────
@onready var location_notification : Control       = $UIManager/LocationNotification
@onready var set_sail_menu         : Control       = $UIManager/SetSailMenu
@onready var dock_ship_menu        : Control       = $UIManager/DockShipMenu
@onready var begin_raid_menu       : Control       = $UIManager/BeginRaidMenu
@onready var begin_raid_button     : TextureButton = $UIManager/BeginRaidMenu/BeginRaidButton

# ──────────────────────────
# Constants & state
# ──────────────────────────
const NOTIF_HOME_POS := Vector2(191, -32)
const INFO_BUTTON_SFX := preload("res://SFX/infobuttons.wav")

var _board_mode : bool                 = false
var _current_ocean  : Node             = null
var _current_player : Node2D           = null
var _location_notify_tween : Tween     = null

# ──────────────────────────
# Ready
# ──────────────────────────
func _ready() -> void:
	# connect our UI button once
	begin_raid_button.pressed.connect(Callable(self, "_on_begin_raid_button_pressed"))

	# initial wiring
	_rewire_to_scene(get_tree().current_scene)
	set_process(true)
	
	hide_location_notification()
	hide_set_sail_menu()
	hide_dock_ship_menu()
	hide_begin_raid_menu()

# ──────────────────────────
# Per-frame: detect scene swaps
# ──────────────────────────
func _process(_delta: float) -> void:
	var cs = get_tree().current_scene
	if cs != _current_ocean:
		_rewire_to_scene(cs)

# ──────────────────────────
# Scene wiring / unwiring
# ──────────────────────────
func _rewire_to_scene(ocean: Node) -> void:
	# ── disconnect old ocean signal ────────────────────────
	if _current_ocean and is_instance_valid(_current_ocean) and _current_ocean.has_signal("board_enemy_request"):
		if _current_ocean.is_connected("board_enemy_request", Callable(self, "_on_board_enemy_request")):
			_current_ocean.disconnect("board_enemy_request", Callable(self, "_on_board_enemy_request"))

	# ── disconnect old player signals ───────────────────────
        if _current_player and is_instance_valid(_current_player):
                if _current_player.is_connected("movement_started", Callable(self, "_on_player_started_moving")):
                        _current_player.disconnect("movement_started", Callable(self, "_on_player_started_moving"))
                if _current_player.is_connected("manual_rotation_started", Callable(self, "_on_player_started_moving")):
                        _current_player.disconnect("manual_rotation_started", Callable(self, "_on_player_started_moving"))
                if _current_player.is_connected("player_docked", Callable(self, "_on_player_docked")):
                        _current_player.disconnect("player_docked", Callable(self, "_on_player_docked"))

	# ── update refs ─────────────────────────────────────────
	_current_ocean  = ocean
	_current_player = null

	# ── now wire up the new ocean only if it really has that signal ──
	if ocean and ocean.has_signal("board_enemy_request"):
		ocean.connect("board_enemy_request", Callable(self, "_on_board_enemy_request"))

	# ── wire up the new PlayerShip if present ──────────────────────
                if ocean and ocean.has_node("PlayerShip"):
                                var player = ocean.get_node("PlayerShip") as Node2D
                                if player.has_signal("movement_started"):
                                                player.connect("movement_started", Callable(self, "_on_player_started_moving"))
                                if player.has_signal("manual_rotation_started"):
                                                player.connect("manual_rotation_started", Callable(self, "_on_player_started_moving"))
                                if player.has_signal("player_docked"):
                                                player.connect("player_docked", Callable(self, "_on_player_docked"))
                                _current_player = player

# ──────────────────────────
# Boarding / docking logic
# ──────────────────────────
func _on_board_enemy_request(_enemy: Node2D) -> void:
	_board_mode = true
	hide_set_sail_menu()
	hide_dock_ship_menu()
	hide_location_notification()
	hide_begin_raid_menu()

func _on_player_docked() -> void:
	if _board_mode:
		show_begin_raid_menu()
	else:
		show_dock_ship_menu()

func _on_player_started_moving() -> void:
	hide_begin_raid_menu()
	_board_mode = false

# ──────────────────────────
# “Begin Raid” button
# ──────────────────────────
func _on_begin_raid_button_pressed() -> void:
		var ocean = get_tree().current_scene
		if not ocean or not ocean.has_node("PlayerShip"):
				return

				var ship = ocean.get_node("PlayerShip") as Node2D
				if ship:
								Global.spawn_position = ship.global_position
								Global.ship_state = {
												"frame": ship.current_frame,
												"moving": ship.moving_forward,
												"health": ship.health
								}
								if ocean.has_node("EnemyShip"):
												Global.enemy_spawn_position = ocean.get_node("EnemyShip").global_position
								else:
												Global.enemy_spawn_position = Vector2.ZERO

								Global.return_scene_path = ocean.scene_file_path
								if ocean.has_method("begin_raid_pressed"):
												await ocean.begin_raid_pressed()

		# fade sails
		if ocean.has_method("start_boarding_transition"):
				ocean.start_boarding_transition(1.5)

	# zoom camera
		var cam = ocean.get_node("PlayerShip/ShipCamera") as Camera2D
		if cam:
			cam.create_tween().tween_property(cam, "zoom", Vector2(16,16), 1.5)

		# hide UI, reset flag, then switch
		hide_begin_raid_menu()
		_board_mode = false

		var tw = get_tree().create_tween()
		tw.tween_interval(1.5)
		tw.connect("finished", Callable(self, "_switch_to_boarding"))

func _switch_to_boarding() -> void:
		var ocean = get_tree().current_scene
		if not ocean or not ocean.has_node("PlayerShip"):
				return

		var player_ship = ocean.get_node("PlayerShip") as Node2D
		var pos = player_ship.global_position
		Global.spawn_position = pos
		if ocean.has_node("EnemyShip"):
				Global.enemy_spawn_position = ocean.get_node("EnemyShip").global_position
		else:
				Global.enemy_spawn_position = Vector2.ZERO

		var scene_path = "res://Battle/BoardingBattle.tscn"
		if ocean.scene_file_path.ends_with("oceantutorial.tscn"):
						scene_path = "res://Battle/BoardingBattleTutorial.tscn"

		SceneSwitcher.switch_scene(
				scene_path,
				pos, "none",
				Vector2(), Vector2(), Vector2(), false
		)

# ──────────────────────────
# Location notification
# ──────────────────────────
func show_location_notification(txt: String) -> void:
	if _board_mode:
		return

	if _location_notify_tween:
		_location_notify_tween.kill()
		_location_notify_tween = null

	var label = location_notification.get_node("LocationName") as Label
	label.text = txt
	location_notification.position = NOTIF_HOME_POS
	location_notification.show()

	_location_notify_tween = get_tree().create_tween()
	_location_notify_tween.tween_property(
		location_notification, "position",
		NOTIF_HOME_POS + Vector2(0, 40), 0.3
	)
	_location_notify_tween.tween_interval(2.0)
	_location_notify_tween.tween_property(
		location_notification, "position",
		NOTIF_HOME_POS, 0.3
	)
	_location_notify_tween.connect("finished", Callable(self, "_on_location_notify_tween_finished"))

func _on_location_notify_tween_finished() -> void:
	hide_location_notification()
	_location_notify_tween = null

func hide_location_notification() -> void:
	location_notification.hide()

# ──────────────────────────
# Simple menu show/hide
# ──────────────────────────
func show_set_sail_menu() -> void:
	set_sail_menu.show()

func hide_set_sail_menu() -> void:
	set_sail_menu.hide()

func show_dock_ship_menu() -> void:
	if _board_mode:
		return
	dock_ship_menu.show()

func hide_dock_ship_menu() -> void:
	dock_ship_menu.hide()

func show_begin_raid_menu() -> void:
	begin_raid_menu.show()

func hide_begin_raid_menu() -> void:
	begin_raid_menu.hide()

# ──────────────────────────
# Editor-wired buttons (if any)
# ──────────────────────────
func _on_set_sail_button_pressed() -> void:
		SoundManager.play_sfx(INFO_BUTTON_SFX)
		var island = get_tree().current_scene
		if island and island.has_method("start_leave_island_transition"):
				var tw = get_tree().create_tween()
				tw.tween_interval(1.0)
				tw.connect("finished", Callable(island, "start_leave_island_transition").bind(1.0))

				Global.restore_sails_next = true

				SceneSwitcher.switch_scene(
								"res://Ocean/ocean.tscn",
								Vector2(-2, 39), "zoom",
								Vector2(0.0625, 0.0625), Vector2(-32, 624),
		Vector2(1, 1), true
)
				hide_set_sail_menu()

func _on_dock_ship_button_pressed() -> void:
		SoundManager.play_sfx(INFO_BUTTON_SFX)
		var ocean = get_tree().current_scene
		if ocean and ocean.has_method("start_dock_transition"):
				# Delay the sail fade until the camera begins zooming
				var tw = get_tree().create_tween()
				tw.tween_interval(1.0)
				tw.connect("finished", Callable(ocean, "start_dock_transition").bind(1.0))

		var target_scene := "res://Island/island.tscn"
		if ocean and ocean.scene_file_path.ends_with("oceantutorial.tscn"):
				target_scene = "res://Island/islandtutorial.tscn"

		SceneSwitcher.switch_scene(
								   target_scene,
								   Vector2(-190, 648), "zoom",
								   Vector2(16, 16), Vector2(-11.875, 40.5),
								   Vector2(1, 1), true
		)
		hide_dock_ship_menu()
