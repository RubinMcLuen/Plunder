extends Node2D

signal board_enemy_request(pos: Vector2)

@export var player_ship_path: NodePath
var player_ship : Node

func _ready():
	var waves = get_node("Waves")
	waves.modulate.a = 0.0
	get_tree().create_tween().tween_property(waves, "modulate:a", 1.0, 1.0)

	player_ship = get_node(player_ship_path)
	connect("board_enemy_request", Callable(player_ship, "dock_with_enemy"))
