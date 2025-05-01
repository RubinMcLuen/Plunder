extends Node2D

func _ready():
	var waves = get_node("Waves")
	waves.modulate.a = 0.0
	get_tree().create_tween().tween_property(waves, "modulate:a", 1.0, 1.0)


func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var camera = get_node("PlayerShip/ShipCamera")
		get_tree().create_tween().tween_property(camera, "zoom", Vector2(0.4, 0.4), 5.0)
