extends CanvasLayer

@onready var location_notification : Control       = $UIManager/LocationNotification
@onready var set_sail_menu         : Control       = $UIManager/SetSailMenu
@onready var dock_ship_menu        : Control       = $UIManager/DockShipMenu
@onready var begin_raid_menu       : Control       = $UIManager/BeginRaidMenu
@onready var begin_raid_button     : TextureButton = $UIManager/BeginRaidMenu/BeginRaidButton

var _board_mode : bool = false

func _ready() -> void:
	var ocean : Node = get_tree().current_scene

	if ocean.has_signal("board_enemy_request"):
		ocean.connect("board_enemy_request", Callable(self, "_on_board_enemy_request"))

	var player = ocean.get_node_or_null("PlayerShip")
	if player:
		if player.has_signal("movement_started"):
			player.connect("movement_started", Callable(self, "_on_player_started_moving"))
		if player.has_signal("player_docked"):
			player.connect("player_docked", Callable(self, "_on_player_docked"))

	begin_raid_button.connect("pressed", Callable(self, "_on_begin_raid_button_pressed"))

	hide_location_notification()
	hide_set_sail_menu()
	hide_dock_ship_menu()
	hide_begin_raid_menu()


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


func _on_begin_raid_button_pressed() -> void:
	var ocean : Node2D = get_tree().current_scene as Node2D

	# 1) Fade sails over 1.5s
	if ocean.has_method("start_boarding_transition"):
		ocean.start_boarding_transition(1.5)

	# 2) Zoom camera over 1.5s
	var cam = ocean.get_node_or_null("PlayerShip/ShipCamera") as Camera2D
	if cam:
		cam.create_tween().tween_property(cam, "zoom", Vector2(16,16), 1.5)

	# 3) Hide UI
	hide_begin_raid_menu()
	_board_mode = false

	# 4) After 1.5s, load the boarding scene
	var tw := get_tree().create_tween()
	tw.tween_interval(1.5)
	tw.connect("finished", Callable(self, "_switch_to_boarding"))


func _switch_to_boarding() -> void:
	var ocean       : Node2D  = get_tree().current_scene as Node2D
	var player_ship : Node2D  = ocean.get_node("PlayerShip") as Node2D
	var pos         : Vector2 = player_ship.global_position

	SceneSwitcher.switch_scene(
		"res://Battle/BoardingBattle.tscn",
		pos, "none",
		Vector2(), Vector2(),
		Vector2(), false
	)


func show_location_notification(txt: String) -> void:
	if _board_mode:
		return
	var label : Label = location_notification.get_node("LocationName") as Label
	label.text = txt
	location_notification.show()
	var orig : Vector2 = location_notification.position
	var tw   := get_tree().create_tween()
	tw.tween_property(location_notification, "position", orig + Vector2(0,40), 0.3)
	tw.tween_interval(2.0)
	tw.tween_property(location_notification, "position", orig, 0.3)
	tw.connect("finished", Callable(self, "hide_location_notification"))

func hide_location_notification() -> void:
	location_notification.hide()

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
