# UIManager.gd — Godot 4.22
extends CanvasLayer

# ──────────────────────────
# Node references
# ──────────────────────────
@onready var location_notification : Control	   = $UIManager/LocationNotification
@onready var set_sail_menu	   : Control	   = $UIManager/SetSailMenu
@onready var dock_ship_menu	   : Control	   = $UIManager/DockShipMenu
@onready var begin_raid_menu	   : Control	   = $UIManager/BeginRaidMenu
@onready var begin_raid_button	   : TextureButton = $UIManager/BeginRaidMenu/BeginRaidButton
@onready var enemy_toggle_button   : TextureButton = $UIManager/SpawnEnemyButton

# ──────────────────────────
# Constants & state
# ──────────────────────────
const NOTIF_HOME_POS := Vector2(191, -32)
const INFO_BUTTON_SFX := preload("res://SFX/infobuttons.wav")
const BOARDING_BATTLE_SCENE := preload("res://Battle/BoardingBattle.tscn")
const BOARDING_BATTLE_TUTORIAL_SCENE := preload("res://Battle/BoardingBattleTutorial.tscn")
const OCEAN_SCENE := preload("res://Ocean/oceantutorial.tscn")
const ISLAND_SCENE := preload("res://Island/islandtutorial.tscn")

var _board_mode : bool		       = false
var _current_ocean  : Node	       = null
var _current_player : Node2D	       = null
var _current_enemy  : Node2D	       = null
var _player_docked  : bool	       = false
var _island_dock_next : bool	       = false
var _location_notify_tween : Tween     = null

# ──────────────────────────
# Ready
# ──────────────────────────
func _ready() -> void:
				# connect our UI buttons once
				if not begin_raid_button.pressed.is_connected(Callable(self, "_on_begin_raid_button_pressed")):
								begin_raid_button.pressed.connect(Callable(self, "_on_begin_raid_button_pressed"))

				# The enemy toggle button is already connected in the scene. Avoid
				# attempting to connect again which would raise an error.
				if not enemy_toggle_button.pressed.is_connected(Callable(self, "_on_spawn_enemy_button_pressed")):
								enemy_toggle_button.pressed.connect(Callable(self, "_on_spawn_enemy_button_pressed"))

				enemy_toggle_button.hide()

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
		_update_enemy_button_visibility()

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

	# ── disconnect old enemy signal ─────────────────────────
	if _current_enemy and is_instance_valid(_current_enemy):
		if _current_enemy.is_connected("ready_for_boarding_changed", Callable(self, "_on_enemy_ready_for_boarding")):
			_current_enemy.disconnect("ready_for_boarding_changed", Callable(self, "_on_enemy_ready_for_boarding"))

	# ── update refs ─────────────────────────────────────────
	_current_ocean	= ocean
	_current_player = null

	   # Reset boarding state whenever we switch scenes so stray flags from
	   # the previous scene don't trigger the wrong UI.
	_board_mode = false
	_player_docked = false
	hide_begin_raid_menu()
	hide_dock_ship_menu()

	# Ensure the Begin Raid button is connected to our handler in case a
	# previous scene disconnected it (e.g. the tutorial).
	if not begin_raid_button.pressed.is_connected(Callable(self, "_on_begin_raid_button_pressed")):
		begin_raid_button.pressed.connect(Callable(self, "_on_begin_raid_button_pressed"))

	# ── now wire up the new ocean only if it really has that signal ──
	if ocean and ocean.has_signal("board_enemy_request"):
		if not ocean.is_connected("board_enemy_request", Callable(self, "_on_board_enemy_request")):
			ocean.connect("board_enemy_request", Callable(self, "_on_board_enemy_request"))

	# ── wire up the enemy ship if present ──────────────────────
	_current_enemy = null
	if ocean and ocean.has_node("EnemyShip"):
		var enemy = ocean.get_node("EnemyShip") as Node2D
		if enemy.has_signal("ready_for_boarding_changed") and not enemy.is_connected("ready_for_boarding_changed", Callable(self, "_on_enemy_ready_for_boarding")):
			enemy.connect("ready_for_boarding_changed", Callable(self, "_on_enemy_ready_for_boarding"))
		_current_enemy = enemy

	# ── wire up the new PlayerShip if present ──────────────────────
		if ocean and ocean.has_node("PlayerShip"):
				var player = ocean.get_node("PlayerShip") as Node2D
				if player.has_signal("movement_started") and not player.is_connected("movement_started", Callable(self, "_on_player_started_moving")):
						player.connect("movement_started", Callable(self, "_on_player_started_moving"))
				if player.has_signal("manual_rotation_started") and not player.is_connected("manual_rotation_started", Callable(self, "_on_player_started_moving")):
						player.connect("manual_rotation_started", Callable(self, "_on_player_started_moving"))
				if player.has_signal("player_docked") and not player.is_connected("player_docked", Callable(self, "_on_player_docked")):
						player.connect("player_docked", Callable(self, "_on_player_docked"))
				_current_player = player

# ──────────────────────────
# Boarding / docking logic
# ──────────────────────────
func queue_island_dock() -> void:
		_island_dock_next = true

func _on_board_enemy_request(_enemy: Node2D) -> void:
		_board_mode = true
		hide_set_sail_menu()
		hide_dock_ship_menu()
		hide_location_notification()
		hide_begin_raid_menu()

func _on_player_docked() -> void:
				_player_docked = true
				var ocean = get_tree().current_scene
				var enemy_ready := false
				if ocean and ocean.has_node("EnemyShip"):
								var enemy = ocean.get_node("EnemyShip")
								if enemy.has_method("get"):
												enemy_ready = enemy.get("ready_for_boarding")

				if _island_dock_next:
								show_dock_ship_menu()
								_island_dock_next = false
								_board_mode = false
				elif _board_mode or enemy_ready:
								show_begin_raid_menu()
								_board_mode = true
				else:
								show_dock_ship_menu()

func _on_player_started_moving() -> void:
		var was_visible := begin_raid_menu.visible
		hide_begin_raid_menu()
		_player_docked = false
		if was_visible:
			_board_mode = false
			_island_dock_next = false

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
											ocean.begin_raid_pressed()

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

var scene := BOARDING_BATTLE_SCENE
		var in_ocean_tutorial = ocean is Global.OceanTutorial or ocean.scene_file_path.ends_with("oceantutorial.tscn")
		var special_shipwreck := false
		if ocean.has_node("EnemyShip"):
			var enemy = ocean.get_node("EnemyShip")
			special_shipwreck = not enemy.spawn_dock_arrow_on_death
		if (in_ocean_tutorial and not Global.ocean_tutorial_complete) or special_shipwreck:
scene = BOARDING_BATTLE_TUTORIAL_SCENE

SceneSwitcher.switch_scene(
scene,
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

func _on_enemy_ready_for_boarding(ready: bool) -> void:
		if ready and _player_docked and not begin_raid_menu.visible:
				show_begin_raid_menu()
				_board_mode = true

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
OCEAN_SCENE,
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

var target_scene := ISLAND_SCENE

SceneSwitcher.switch_scene(
target_scene,
																	Vector2(-190, 648), "zoom",
																			   Vector2(16, 16), Vector2(-11.875, 40.5),
																			   Vector2(1, 1), true
				   )
		hide_dock_ship_menu()

# ──────────────────────────
# Enemy spawn toggle button
# ──────────────────────────
func _update_enemy_button_visibility() -> void:
		var scene = get_tree().current_scene
		if scene and scene.scene_file_path.ends_with("oceantutorial.tscn") and Global.ocean_tutorial_complete:
				enemy_toggle_button.show()
		else:
				enemy_toggle_button.hide()

func _on_spawn_enemy_button_pressed() -> void:
		var scene = get_tree().current_scene
		if scene and scene.has_method("toggle_enemy_ship"):
				scene.toggle_enemy_ship()
