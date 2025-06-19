extends Node2D

signal board_enemy_request(enemy: Node2D)

@export var player_ship_path: NodePath
var player_ship     : Node2D = null
var _enemy_to_board : Node2D = null

func _ready() -> void:
	if Global.spawn_position != Vector2.ZERO:
		if player_ship == null:
			player_ship = get_node(player_ship_path) as Node2D
		if player_ship:
			player_ship.global_position = Global.spawn_position
		Global.spawn_position = Vector2.ZERO          # consume it

	if Global.ship_state:
		if player_ship == null:
			player_ship = get_node(player_ship_path) as Area2D
		if player_ship:
			if "frame"  in Global.ship_state:
				player_ship.current_frame = int(Global.ship_state["frame"])
				player_ship.update_frame()              # refresh sprite
			if "moving" in Global.ship_state:
				player_ship.moving_forward = bool(Global.ship_state["moving"])
			if "health" in Global.ship_state:
				player_ship.health = int(Global.ship_state["health"])
		Global.ship_state = {}                         # clear after use

		if Global.restore_sails_next:
				Global.restore_sails_next = false
				if player_ship == null:
						player_ship = get_node(player_ship_path) as Node2D
				if player_ship:
						_restore_ship_sails(player_ship, 1.0)
        # Fade in the water regardless of how we entered this scene
        if has_node("Waves"):
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


func start_dock_transition(fade_time: float = 1.0) -> void:
				if player_ship == null:
						if has_node(player_ship_path):
										player_ship = get_node(player_ship_path) as Node2D
				if player_ship:
						_fade_ship_sails(player_ship, fade_time)
				if has_node("Waves"):
						get_tree().create_tween().tween_property($Waves, "modulate:a", 0.0, fade_time)

func start_restore_sails(fade_time: float = 1.0) -> void:
		if player_ship == null:
				if has_node(player_ship_path):
						player_ship = get_node(player_ship_path) as Node2D
		if player_ship:
				_restore_ship_sails(player_ship, fade_time)


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

func _restore_ship_sails(ship: Node2D, t: float) -> void:
		if ship.has_node("NoSails"):
				var hull := ship.get_node("NoSails") as CanvasItem
				hull.visible = false

		var sail : CanvasItem = null
		if ship.has_node("Boat"):
				sail = ship.get_node("Boat") as CanvasItem
		elif ship.has_node("ShipSprite"):
				sail = ship.get_node("ShipSprite") as CanvasItem

		if sail:
				sail.modulate.a = 0.0
				get_tree().create_tween().tween_property(sail, "modulate:a", 1.0, t)
