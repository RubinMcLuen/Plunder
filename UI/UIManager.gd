extends CanvasLayer

@onready var location_notification : Control   = $UIManager/LocationNotification
@onready var set_sail_menu        : Control   = $UIManager/SetSailMenu
@onready var dock_ship_menu       : Control   = $UIManager/DockShipMenu
@onready var begin_raid_menu      : Control   = $UIManager/BeginRaidMenu
@onready var begin_raid_button    : TextureButton = $UIManager/BeginRaidMenu/BeginRaidButton

var _board_mode := false

func _ready():
	var root = get_tree().current_scene
	if root.has_signal("board_enemy_request"):
		root.connect("board_enemy_request", Callable(self, "_on_board_enemy_request"))
	var player = root.get_node("PlayerShip")
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

func _on_board_enemy_request(_pos: Vector2):
	_board_mode = true
	hide_set_sail_menu()
	hide_dock_ship_menu()
	hide_location_notification()
	show_begin_raid_menu()

func _on_player_started_moving():
	hide_begin_raid_menu()
	_board_mode = false

func _on_player_docked():
	if _board_mode:
		return
	show_dock_ship_menu()

func _on_set_sail_button_pressed():
	SceneSwitcher.switch_scene("res://Ocean/ocean.tscn",
		Vector2(-2,41), "zoom", Vector2(0.0625,0.0625), Vector2(-32,656))
	hide_set_sail_menu()

func _on_dock_ship_button_pressed():
	SceneSwitcher.switch_scene("res://Island/island.tscn",
		Vector2(-190,648), "zoom", Vector2(16,16), Vector2(-11.875,40.5), Vector2(1,1))
	hide_dock_ship_menu()

func _on_begin_raid_button_pressed():
	var player_ship = get_tree().current_scene.get_node("PlayerShip")
	var ship_pos = player_ship.global_position if player_ship else Vector2.ZERO
	SceneSwitcher.switch_scene("res://Battle/BoardingBattle.tscn",
		ship_pos, "zoom", Vector2(16, 16), ship_pos)
	hide_begin_raid_menu()
	_board_mode = false

func show_location_notification(txt: String):
	if _board_mode:
		return
	var label = location_notification.get_node("LocationName") as Label
	label.text = txt
	location_notification.show()
	var orig = location_notification.position
	var tw = get_tree().create_tween()
	tw.tween_property(location_notification, "position", orig + Vector2(0,40), 0.3)
	tw.tween_interval(2.0)
	tw.tween_property(location_notification, "position", orig, 0.3)
	tw.tween_callback(Callable(self, "hide_location_notification"))

func hide_location_notification():
	location_notification.hide()

func show_set_sail_menu():   set_sail_menu.show()
func hide_set_sail_menu():   set_sail_menu.hide()

func show_dock_ship_menu():
	if _board_mode:
		return
	dock_ship_menu.show()
func hide_dock_ship_menu():  dock_ship_menu.hide()

func show_begin_raid_menu(): begin_raid_menu.show()
func hide_begin_raid_menu(): begin_raid_menu.hide()
