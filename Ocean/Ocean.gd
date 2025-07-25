extends Node2D

signal board_enemy_request(enemy: Node2D)

@export var player_ship_path: NodePath
var player_ship     : Node2D = null
var _enemy_to_board : Node2D = null
var enemy_ship    : Area2D = null
var _enemy_layer  : int    = 0
var _enemy_mask   : int    = 0

func _enter_tree() -> void:
		if Global.restore_sails_next:
				if has_node("Waves"):
						$Waves.modulate.a = 0.0
				if has_node("KelptownIsland/Foam"):
						$"KelptownIsland/Foam".modulate.a = 0.0
		else:
				if has_node("Waves"):
						$Waves.modulate.a = 1.0
				if has_node("KelptownIsland/Foam"):
						$"KelptownIsland/Foam".modulate.a = 1.0

func _ready() -> void:
	if player_ship_path.is_empty():
			if has_node("PlayerShip"):
					player_ship_path = NodePath("PlayerShip")
	if has_node(player_ship_path):
			player_ship = get_node(player_ship_path) as Node2D
	else:
			player_ship = null

	if Global.spawn_position != Vector2.ZERO:
		if player_ship == null:
			player_ship = get_node(player_ship_path) as Node2D
		if player_ship:
			player_ship.global_position = Global.spawn_position
		Global.spawn_position = Vector2.ZERO  # consume it

		if Global.ship_state:
			if player_ship == null:
				player_ship = get_node(player_ship_path) as Area2D
			if player_ship:
				if "frame" in Global.ship_state:
					player_ship.current_frame = int(Global.ship_state["frame"])
					player_ship.update_frame()  # refresh sprite
				if "moving" in Global.ship_state:
					player_ship.moving_forward = bool(Global.ship_state["moving"])
				if "health" in Global.ship_state:
					player_ship.health = int(Global.ship_state["health"])
			Global.ship_state = {}  # clear after use

	if Global.restore_sails_next:
		Global.restore_sails_next = false
		if player_ship == null and has_node(player_ship_path):
			player_ship = get_node(player_ship_path) as Node2D
		if player_ship:
			_restore_ship_sails(player_ship, 0.0)

		await get_tree().process_frame
		_fade_environment_in(1.0)
	else:
			_show_environment()

	if Global.board_zoom_out_next:
					Global.board_zoom_out_next = false
					if player_ship:
									var hull : CanvasItem = null
									if player_ship.has_node("NoSails"):
													hull = player_ship.get_node("NoSails") as CanvasItem
													hull.visible = true
													hull.modulate.a = 1.0

									var sail: CanvasItem = null
									if player_ship.has_node("Boat"):
													sail = player_ship.get_node("Boat") as CanvasItem
									elif player_ship.has_node("ShipSprite"):
													sail = player_ship.get_node("ShipSprite") as CanvasItem
									if sail:
													sail.modulate.a = 0.0

									start_restore_sails(1.5)
									if player_ship.has_node("ShipCamera"):
													var cam := player_ship.get_node("ShipCamera") as Camera2D
													cam.zoom = Vector2(16,16)
													cam.create_tween().tween_property(cam, "zoom", Vector2(1,1), 1.5)

	# Listen for boarding requests
	connect("board_enemy_request", Callable(self, "_on_board_enemy_request"))
	if player_ship and player_ship.has_signal("player_docked"):
		player_ship.connect("player_docked", _on_player_docked)


func _on_board_enemy_request(enemy: Node2D) -> void:
		_enemy_to_board = enemy
		Global.enemy_spawn_position = enemy.global_position
		if player_ship:
				player_ship.dock_with_enemy(enemy.global_position)

func _on_player_docked() -> void:
	if _enemy_to_board and is_instance_valid(_enemy_to_board):
		if _enemy_to_board.get("ready_for_boarding"):
			UIManager.show_begin_raid_menu()

func start_boarding_transition(fade_time: float = 1.5) -> void:
	if player_ship == null or _enemy_to_board == null:
					return
	_fade_ship_sails(player_ship, fade_time)


func start_dock_transition(fade_time: float = 1.0) -> void:
		if player_ship == null:
				if has_node(player_ship_path):
						player_ship = get_node(player_ship_path) as Node2D
		if player_ship:
				_fade_ship_sails(player_ship, fade_time)
		_fade_environment_out(fade_time)

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

	   # 3) Fade trail if present
	if ship.has_node("Trail/Sprite2D"):
			var trail_sprite := ship.get_node("Trail/Sprite2D") as Sprite2D
			var mat := trail_sprite.material
			if mat is ShaderMaterial:
					if t <= 0.0:
							mat.set_shader_parameter("InitialAlpha", 0.0)
					else:
							get_tree().create_tween().tween_property(mat, "shader_parameter/InitialAlpha", 0.0, t)

func _restore_ship_sails(ship: Node2D, t: float) -> void:
	var hull: CanvasItem = null
	if ship.has_node("NoSails"):
			hull = ship.get_node("NoSails") as CanvasItem
			hull.visible = true

	var sail: CanvasItem = null
	if ship.has_node("Boat"):
			sail = ship.get_node("Boat") as CanvasItem
	elif ship.has_node("ShipSprite"):
			sail = ship.get_node("ShipSprite") as CanvasItem

	if sail:
			if t <= 0.0:
					sail.modulate.a = 1.0
					if hull:
							hull.visible = false
			else:
					sail.modulate.a = 0.0
					var tw = get_tree().create_tween()
					tw.tween_property(sail, "modulate:a", 1.0, t)
					if hull:
							tw.tween_callback(Callable(hull, "hide"))

	   # Restore trail opacity
	if ship.has_node("Trail/Sprite2D"):
			var trail_sprite := ship.get_node("Trail/Sprite2D") as Sprite2D
			var mat := trail_sprite.material
			if mat is ShaderMaterial:
					var target_alpha = 0.6
					if t <= 0.0:
							mat.set_shader_parameter("InitialAlpha", target_alpha)
					else:
							get_tree().create_tween().tween_property(mat, "shader_parameter/InitialAlpha", target_alpha, t)

func _fade_environment_in(t: float) -> void:
		var tw = get_tree().create_tween().set_parallel(true)
		if has_node("Waves"):
				tw.tween_property($Waves, "modulate:a", 1.0, t)
		if has_node("KelptownIsland/Foam"):
				tw.tween_property($"KelptownIsland/Foam", "modulate:a", 1.0, t)

func _fade_environment_out(t: float) -> void:
		var tw = get_tree().create_tween().set_parallel(true)
		if has_node("Waves"):
				tw.tween_property($Waves, "modulate:a", 0.0, t)
		if has_node("KelptownIsland/Foam"):
				tw.tween_property($"KelptownIsland/Foam", "modulate:a", 0.0, t)

func _show_environment() -> void:
		if has_node("Waves"):
				$Waves.modulate.a = 1.0
		if has_node("KelptownIsland/Foam"):
				$"KelptownIsland/Foam".modulate.a = 1.0

func _spawn_normal_enemy() -> void:
	var scene := preload("res://Ships/EnemyShip.tscn")
	enemy_ship = scene.instantiate()
	add_child(enemy_ship)
	if player_ship:
		var radius := 100.0
		var angle := randf() * TAU
		enemy_ship.global_position = player_ship.global_position + Vector2(cos(angle), sin(angle)) * radius
		enemy_ship.player = player_ship
	enemy_ship.full_speed = 40.0
	enemy_ship.health = 10
	enemy_ship.visible = true
	enemy_ship.ready_for_boarding = false
	enemy_ship.input_pickable = false
	_enemy_layer = enemy_ship.collision_layer
	_enemy_mask = enemy_ship.collision_mask
	enemy_ship.set_process(true)
	enemy_ship.set_physics_process(true)
	if not enemy_ship.is_connected("area_entered", Callable(self, "_on_enemy_area_entered")):
		enemy_ship.connect("area_entered", _on_enemy_area_entered)
	Global.crew_override = ["Barnaby", "Barnaby", "Barnaby", "Barnaby", "Barnaby"]
	Global.enemy_count_override = 3

func toggle_enemy_ship() -> void:
	if enemy_ship and is_instance_valid(enemy_ship) and enemy_ship.current_state != enemy_ship.EnemyState.DEAD:
		if enemy_ship.has_method("_die"):
			enemy_ship._die()
		return
	_spawn_normal_enemy()

func _on_enemy_area_entered(_area: Area2D) -> void:
	pass
