extends CanvasLayer

@onready var location_notification: Control = $UIManager/LocationNotification
@onready var set_sail_menu: Control = $UIManager/SetSailMenu
@onready var dock_ship_menu: Control = $UIManager/DockShipMenu

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _on_set_sail_button_pressed():
	SceneSwitcher.switch_scene("res://Ocean/ocean.tscn", Vector2(-2, 41), "zoom", Vector2(0.0625, 0.0625), Vector2(-32, 656))
	hide_set_sail_menu()
	
func _on_dock_ship_button_pressed():
	SceneSwitcher.switch_scene("res://Island/island.tscn", Vector2(-190, 648), "zoom", Vector2(16,16), Vector2(-11.875, 40.5), Vector2(1,1))
	hide_dock_ship_menu()

# Moves location_notification down 40 pixels over 0.3 seconds, waits 3 seconds, then moves it back up.
func show_location_notification():
	var tween = get_tree().create_tween()
	var original_pos = location_notification.position
	tween.tween_property(location_notification, "position", original_pos + Vector2(0, 40), 0.3)
	tween.tween_interval(3)
	tween.tween_property(location_notification, "position", original_pos, 0.3)

# Functions to toggle the set_sail_menu visibility.
func show_set_sail_menu():
	set_sail_menu.visible = true

func hide_set_sail_menu():
	set_sail_menu.visible = false

# Functions to toggle the dock_ship_menu visibility.
func show_dock_ship_menu():
	dock_ship_menu.visible = true

func hide_dock_ship_menu():
	dock_ship_menu.visible = false
