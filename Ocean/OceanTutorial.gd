extends "res://Ocean/Ocean.gd"

@onready var hint_label : RichTextLabel = $CanvasLayer/HintLabel
@onready var island      : Node2D        = $KelptownIsland
@onready var arrow       : Sprite2D      = $Arrow
@onready var enemy_ship  : Area2D        = $EnemyShip
@onready var waves       : TileMap       = $Waves
@onready var water       : ColorRect     = $Water

var step               : int   = 0
var left_done          : bool  = false
var right_done         : bool  = false
var shoot_left_done    : bool  = false
var shoot_right_done   : bool  = false
var enemy_hit          : bool  = false
var _advancing         : bool  = false
var _orig_max_speed    : float = 0.0
var _orig_target_speed : float = 0.0
var _enemy_layer       : int   = 0
var _enemy_mask        : int   = 0

func get_tutorial_state() -> Dictionary:
	var es := {}
	if enemy_ship and is_instance_valid(enemy_ship):
                       es = {
                                       "exists": true,
                                       "position": enemy_ship.global_position,
                                       "frame": enemy_ship.current_frame,
                                       "state": int(enemy_ship.current_state),
                                       "health": enemy_ship.health,
                                       "ready": enemy_ship.ready_for_boarding,
                                       "visible": enemy_ship.visible,
                       }
	else:
			es = {"exists": false}

	var s := step
	if s == 6:
			# Saving on the final step drops you back one step so the
			# player remains docked when reloading.
			s = 5

	return {
					"step": s,
		"left_done": left_done,
		"right_done": right_done,
		"shoot_left_done": shoot_left_done,
		"shoot_right_done": shoot_right_done,
		"enemy_hit": enemy_hit,
		"enemy": es,
   }

func apply_tutorial_state(state: Dictionary) -> void:
        step = int(state.get("step", step))
	left_done = bool(state.get("left_done", left_done))
	right_done = bool(state.get("right_done", right_done))
	shoot_left_done = bool(state.get("shoot_left_done", shoot_left_done))
	shoot_right_done = bool(state.get("shoot_right_done", shoot_right_done))
	enemy_hit = bool(state.get("enemy_hit", enemy_hit))

        var es: Dictionary = state.get("enemy", {})
        if es.get("exists", false):
                if enemy_ship == null or not is_instance_valid(enemy_ship):
                        _spawn_normal_enemy(false)
                if _enemy_layer == 0 and _enemy_mask == 0 and enemy_ship:
                        _enemy_layer = enemy_ship.collision_layer
                        _enemy_mask  = enemy_ship.collision_mask

		var pos = es.get("position", enemy_ship.global_position)
		if typeof(pos) == TYPE_DICTIONARY and pos.has("x") and pos.has("y"):
			enemy_ship.global_position = Vector2(pos["x"], pos["y"])
		elif typeof(pos) == TYPE_VECTOR2:
			enemy_ship.global_position = pos
		elif typeof(pos) == TYPE_STRING:
			var tmp = str_to_var(pos)
			if typeof(tmp) == TYPE_VECTOR2:
				enemy_ship.global_position = tmp

               enemy_ship.current_frame = es.get("frame", enemy_ship.current_frame)
               enemy_ship.current_state = int(es.get("state", enemy_ship.current_state))
               enemy_ship.health = int(es.get("health", enemy_ship.health))
               enemy_ship.ready_for_boarding = bool(es.get("ready", enemy_ship.ready_for_boarding))
               enemy_ship.visible = bool(es.get("visible", enemy_ship.visible))
		if enemy_ship.has_method("_update_frame"):
			enemy_ship._update_frame()
	elif enemy_ship:
		enemy_ship.queue_free()
		enemy_ship = null

        _show_step_text()
        _apply_allowed_actions()
       _apply_loaded_step()



func _allowed_actions_for_step(s: int) -> Array[String]:
	var actions: Array[String] = []
	if s >= 0:
		actions.append("ui_up")
	if s >= 1:
		actions.append("ui_down")
	if s >= 2:
		actions.append_array(["ui_left", "ui_right"])
	if s >= 3:
		actions.append_array(["shoot_left", "shoot_right"])
	if s >= 7:
		actions.append("move")
	return actions


func _apply_allowed_actions() -> void:
	if player_ship and player_ship.has_method("set_allowed_actions"):
		player_ship.set_allowed_actions(_allowed_actions_for_step(step))


func _ready() -> void:
	await super._ready()
	_setup_environment()

	if Global.enemy_spawn_position != Vector2.ZERO and enemy_ship:
		enemy_ship.global_position = Global.enemy_spawn_position
		Global.enemy_spawn_position = Vector2.ZERO

	if Global.ocean_tutorial_complete:
		step = 7
		arrow.visible = false
		hint_label.hide()
		_apply_allowed_actions()

		if enemy_ship:
			enemy_ship.visible = true
			enemy_ship.ready_for_boarding = false
			enemy_ship.input_pickable = false
			enemy_ship.collision_layer = 0
			enemy_ship.collision_mask = 0
			enemy_ship.set_process(false)
			enemy_ship.set_physics_process(false)
			enemy_ship.modulate.a = 1.0

			var tw := get_tree().create_tween()
			tw.tween_interval(2.0)
			tw.tween_property(enemy_ship, "modulate:a", 0.0, 2.0)
			tw.parallel().tween_property(enemy_ship.get_node("Trail"), "modulate:a", 0.0, 4.0)

			var sprite := enemy_ship.get_node("Trail/Sprite2D")
			if sprite.material is ShaderMaterial:
				tw.parallel().tween_property(sprite.material, "shader_parameter/InitialAlpha", 0.0, 4.0)

			tw.tween_callback(Callable(enemy_ship, "queue_free"))
			tw.tween_callback(Callable(self, "_clear_enemy_ship"))
			return

	var loaded_state := false
	if Global.ocean_tutorial_state and Global.ocean_tutorial_state.size() > 0:
			apply_tutorial_state(Global.ocean_tutorial_state)
			Global.ocean_tutorial_state = {}
			loaded_state = true

	if player_ship:
		_orig_max_speed    = player_ship.max_speed
		_orig_target_speed = player_ship.target_speed
		# Slightly slower tutorial ship speed
		player_ship.max_speed    *= 0.5
		player_ship.target_speed *= 0.5

	if player_ship.has_signal("player_docked"):
		player_ship.connect("player_docked", _on_player_docked)
	if player_ship.has_signal("cannons_fired_left"):
		player_ship.connect("cannons_fired_left", _on_cannons_fired_left)
	if player_ship.has_signal("cannons_fired_right"):
		player_ship.connect("cannons_fired_right", _on_cannons_fired_right)

		if enemy_ship and not loaded_state:
				_enemy_layer = enemy_ship.collision_layer
				_enemy_mask  = enemy_ship.collision_mask
				enemy_ship.visible = false
				enemy_ship.ready_for_boarding = false
				enemy_ship.input_pickable = false
				enemy_ship.collision_layer = 0
				enemy_ship.collision_mask = 0
				enemy_ship.set_process(false)
				enemy_ship.set_physics_process(false)

				if not enemy_ship.is_connected("area_entered", Callable(self, "_on_enemy_area_entered")):
						enemy_ship.connect("area_entered", _on_enemy_area_entered)

	arrow.visible       = false
	arrow.target        = null
	arrow.self_modulate = Color.WHITE

	_show_step_text()
	_apply_allowed_actions()

	# Rewire the Begin Raid button so we can track tutorial progress
	var btn := UIManager.get_node("UIManager/BeginRaidMenu/BeginRaidButton")
	if btn:
		if btn.pressed.is_connected(UIManager._on_begin_raid_button_pressed):
			btn.pressed.disconnect(UIManager._on_begin_raid_button_pressed)
		if not btn.pressed.is_connected(_on_begin_raid_pressed):
			btn.pressed.connect(_on_begin_raid_pressed)


func _process(_delta: float) -> void:
	if enemy_ship and is_instance_valid(enemy_ship):
		enemy_ship.input_pickable = step >= 5
	else:
		enemy_ship = null

	match step:
		0:
			if Input.is_action_just_pressed("ui_up") and not _advancing:
				_advance_step(1)

		1:
			if Input.is_action_just_pressed("ui_down") and not _advancing:
				_advance_step(2)

		2:
			if Input.is_action_just_pressed("ui_left"):
				left_done = true
				_update_hint_text()
			if Input.is_action_just_pressed("ui_right"):
				right_done = true
				_update_hint_text()

			if left_done and right_done and not _advancing:
				_advance_step(3)

		3:
			pass

		4:
			pass

		5:
			pass

		6:
			pass


# ─────────────────────────────
#  Signal callbacks
# ─────────────────────────────

func _on_player_docked() -> void:
	if step == 5 and not _advancing:
		_advance_step(6)


func _on_cannons_fired_left() -> void:
	if step == 3:
		shoot_left_done = true
		_update_hint_text()
		if shoot_left_done and shoot_right_done and not _advancing:
			_advance_step(4)


func _on_cannons_fired_right() -> void:
	if step == 3:
		shoot_right_done = true
		_update_hint_text()
		if shoot_left_done and shoot_right_done and not _advancing:
			_advance_step(4)


func _on_board_enemy_request(enemy: Node2D) -> void:
	if step == 5 and not _advancing:
		_advance_step(6)
	super._on_board_enemy_request(enemy)


func _on_enemy_area_entered(area: Area2D) -> void:
	if step == 4 and not _advancing and area.is_in_group("cannonball2"):
		if player_ship and player_ship.current_speed > 0:
			enemy_hit = true
			_advance_step(5)


# ─────────────────────────────
#  UI helpers
# ─────────────────────────────

func _show_step_text() -> void:
	_update_hint_text()
	hint_label.add_theme_color_override("default_color", Color.WHITE)
	_fade_in_hint(hint_label)


func _update_hint_text() -> void:
	var text := ""
	match step:
		0:
			text = "Hold W to increase speed"
		1:
			text = "Hold S to decrease speed"
		2:
			var l1 := "Hold A to rotate counter-clockwise"
			var l2 := "Hold D to rotate clockwise"
			if left_done:
				l1 = "[color=green]%s[/color]" % l1
			if right_done:
				l2 = "[color=green]%s[/color]" % l2
			text = "%s\n%s" % [l1, l2]
		3:
			var sl := "Press O to fire cannons port side (left)"
			var sr := "Press P to fire cannons starboard side (right)"
			if shoot_left_done:
				sl = "[color=green]%s[/color]" % sl
			if shoot_right_done:
				sr = "[color=green]%s[/color]" % sr
			text = "%s\n%s" % [sl, sr]
		4:
			text = "While moving, hit the shipwreck with a cannonball\n[color=orange]WASD to move, OP to shoot[/color]"
		5:
			text = "Click on the shipwreck to dock"
		6:
			text = "Click the Begin Raid button to board the ship"

	hint_label.text = "[center]%s[/center]" % text


func _fade_in_hint(label: CanvasItem, duration: float = 0.5) -> void:
	label.visible = true
	label.modulate.a = 0.0
	get_tree().create_tween().tween_property(label, "modulate:a", 1.0, duration)


func _fade_out_hint(label: CanvasItem, duration: float = 0.5) -> void:
	var tw := get_tree().create_tween()
	tw.tween_property(label, "modulate:a", 0.0, duration)
	await tw.finished
	label.hide()


# ─────────────────────────────
#  Step progression
# ─────────────────────────────

func _advance_step(next_step: int) -> void:
	_advancing = true
	hint_label.add_theme_color_override("default_color", Color.GREEN)
	SoundManager.play_success()
	await _fade_out_hint(hint_label)

	step               = next_step
	left_done          = false
	right_done         = false
	shoot_left_done    = false
	shoot_right_done   = false

	match step:
		4:
			if enemy_ship and player_ship:
				enemy_ship.global_position = player_ship.global_position + Vector2(100, 0)
				enemy_ship.visible          = true
				enemy_ship.ready_for_boarding = false
				enemy_ship.input_pickable   = false
				enemy_ship.collision_layer  = _enemy_layer
				enemy_ship.collision_mask   = _enemy_mask
				enemy_ship.set_process(true)
				enemy_ship.set_physics_process(true)

				if enemy_ship.has_node("Trail/SubViewport/Line2D"):
					enemy_ship.get_node("Trail/SubViewport/Line2D").reset_line()

				arrow.self_modulate  = Color.RED
				arrow.target         = enemy_ship
				arrow.global_position = enemy_ship.global_position + Vector2(arrow.x_offset, arrow.y_offset)
				arrow.visible        = true

		5:
			arrow.self_modulate  = Color.WHITE
			arrow.target         = enemy_ship
			arrow.global_position = enemy_ship.global_position + Vector2(arrow.x_offset, arrow.y_offset)
			arrow.visible        = true

			if enemy_ship:
				enemy_ship.input_pickable = true

		6:
			arrow.visible        = false
			arrow.target         = null
			arrow.self_modulate  = Color.WHITE

			if player_ship:
				player_ship.max_speed    = _orig_max_speed
				player_ship.target_speed = _orig_target_speed

	_show_step_text()
	_apply_allowed_actions()
	_advancing = false

func _apply_loaded_step() -> void:
	match step:
		4:
			if enemy_ship and player_ship:
				enemy_ship.collision_layer = _enemy_layer
				enemy_ship.collision_mask = _enemy_mask
				enemy_ship.set_process(true)
				enemy_ship.set_physics_process(true)
				enemy_ship.input_pickable = false
				enemy_ship.visible = true
				arrow.self_modulate = Color.RED
				arrow.target = enemy_ship
				arrow.global_position = enemy_ship.global_position + Vector2(arrow.x_offset, arrow.y_offset)
				arrow.visible = true
		5:
			if enemy_ship:
				enemy_ship.collision_layer = _enemy_layer
				enemy_ship.collision_mask = _enemy_mask
				enemy_ship.set_process(true)
				enemy_ship.set_physics_process(true)
				enemy_ship.input_pickable = true
				enemy_ship.visible = true
				arrow.self_modulate = Color.WHITE
				arrow.target = enemy_ship
				arrow.global_position = enemy_ship.global_position + Vector2(arrow.x_offset, arrow.y_offset)
				arrow.visible = true
		6:
			arrow.visible = false
			arrow.target = null
			arrow.self_modulate = Color.WHITE
			if player_ship:
				player_ship.max_speed = _orig_max_speed
				player_ship.target_speed = _orig_target_speed

# ─────────────────────────────
#  UI callbacks
# ─────────────────────────────

func begin_raid_pressed() -> void:
	if step == 6 and not _advancing:
		_advance_step(7)


func _on_begin_raid_pressed() -> void:
	if step == 6 and not _advancing:
		_advance_step(7)
	UIManager._on_begin_raid_button_pressed()


# ─────────────────────────────
#  Enemy helpers
# ─────────────────────────────

func _clear_enemy_ship() -> void:
	enemy_ship = null


func _spawn_normal_enemy(record_spawned: bool = true) -> void:
	if record_spawned and Global.post_tutorial_enemy_spawned:
		return

	if record_spawned:
		Global.post_tutorial_enemy_spawned = true

	var scene := preload("res://Ships/EnemyShip.tscn")
	enemy_ship = scene.instantiate()
	enemy_ship.start_dead_for_testing = false
	add_child(enemy_ship)

	if player_ship:
		var radius := 100.0
		var angle  := randf() * TAU
		enemy_ship.global_position = player_ship.global_position + Vector2(cos(angle), sin(angle)) * radius
		enemy_ship.player = player_ship

	enemy_ship.full_speed       = 40.0
	enemy_ship.health           = 10
	enemy_ship.visible          = true
	enemy_ship.ready_for_boarding = false
	enemy_ship.input_pickable   = false

	_enemy_layer = enemy_ship.collision_layer
	_enemy_mask  = enemy_ship.collision_mask

	enemy_ship.set_process(true)
	enemy_ship.set_physics_process(true)

	if not enemy_ship.is_connected("area_entered", Callable(self, "_on_enemy_area_entered")):
		enemy_ship.connect("area_entered", _on_enemy_area_entered)

	Global.crew_override        = ["Barnaby", "Barnaby", "Barnaby", "Barnaby", "Barnaby"]
	Global.enemy_count_override = 3


func toggle_enemy_ship() -> void:
	if enemy_ship and is_instance_valid(enemy_ship) and enemy_ship.current_state != enemy_ship.EnemyState.DEAD:
		if enemy_ship.has_method("_die"):
			enemy_ship._die()
		return

	_spawn_normal_enemy(false)


# ─────────────────────────────
#  Environment setup
# ─────────────────────────────

func _setup_environment() -> void:
	var center := island.position
	var size   := 10 * 128
	var half   := size * 0.5

	if waves:
		waves.position = center
		waves.clear()
		for x in range(-5, 5):
			for y in range(-5, 5):
				waves.set_cell(0, Vector2i(x, y), 0, Vector2i.ZERO, 0)

	if water:
		water.position = center - Vector2(half, half)
		water.size     = Vector2(size, size)

	_create_borders(center, size)


func _create_borders(center: Vector2, size: int) -> void:
	var half      := size * 0.5
	var thickness := 20.0

	var border := Node2D.new()
	border.name = "Borders"
	add_child(border)

	_add_wall(border, Vector2(center.x,                center.y - half - thickness * 0.5), Vector2(half,           thickness * 0.5))
	_add_wall(border, Vector2(center.x,                center.y + half + thickness * 0.5), Vector2(half,           thickness * 0.5))
	_add_wall(border, Vector2(center.x - half - thickness * 0.5, center.y),               Vector2(thickness * 0.5, half))
	_add_wall(border, Vector2(center.x + half + thickness * 0.5, center.y),               Vector2(thickness * 0.5, half))


func _add_wall(parent: Node, pos: Vector2, extents: Vector2) -> void:
	var body  := StaticBody2D.new()
	body.position = pos

	var shape := CollisionShape2D.new()
	var rect  := RectangleShape2D.new()
	rect.extents = extents
	shape.shape  = rect

	body.add_child(shape)
	parent.add_child(body)

func _exit_tree() -> void:
		Global.ocean_tutorial_state = get_tutorial_state()
