extends Node2D

signal board_enemy_request(enemy: Node2D)

@export var player_ship_path: NodePath
var player_ship     : Node2D = null
var _enemy_to_board : Node2D = null

func _ready() -> void:
	# Fade in the water
	$Waves.modulate.a = 0.0
	get_tree().create_tween().tween_property($Waves, "modulate:a", 1.0, 1.0)

	# Cache the player ship
	player_ship = get_node(player_ship_path) as Node2D

	# Listen for boarding requests
	connect("board_enemy_request", Callable(self, "_on_board_enemy_request"))


func _on_board_enemy_request(enemy: Node2D) -> void:
	_enemy_to_board = enemy
	if player_ship:
		player_ship.dock_with_enemy(enemy.global_position)


func start_boarding_transition(fade_time: float = 1.5) -> void:
	if player_ship == null or _enemy_to_board == null:
		return
	_fade_ship_sails(player_ship, fade_time)
	_fade_ship_sails(_enemy_to_board, fade_time)


func _fade_ship_sails(ship: Node2D, t: float) -> void:
	# 1) Reveal hull-only underlay
	if ship.has_node("NoSails"):
		var hull := ship.get_node("NoSails") as CanvasItem
		hull.visible    = true
		hull.modulate.a = 1.0

	# 2) Fade the sail sprite only
	var sail : CanvasItem = null
	if ship.has_node("Boat"):
		sail = ship.get_node("Boat") as CanvasItem
	elif ship.has_node("ShipSprite"):
		sail = ship.get_node("ShipSprite") as CanvasItem

	if sail:
		sail.modulate.a = 1.0
		get_tree().create_tween().tween_property(sail, "modulate:a", 0.0, t)
