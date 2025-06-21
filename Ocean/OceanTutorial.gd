extends "res://Ocean/Ocean.gd"

@onready var hint_label: RichTextLabel = $CanvasLayer/HintLabel
@onready var island     : Node2D        = $KelptownIsland
@onready var arrow      : Sprite2D      = $Arrow
@onready var enemy_ship : Area2D        = $EnemyShip

var step: int = 0
var left_done: bool = false
var right_done: bool = false
var shoot_left_done: bool = false
var shoot_right_done: bool = false
var enemy_hit: bool = false
var _advancing: bool = false
var _orig_max_speed: float = 0.0
var _orig_target_speed: float = 0.0
var _enemy_layer: int = 0
var _enemy_mask: int = 0

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

func _apply_allowed_actions():
	if player_ship and player_ship.has_method("set_allowed_actions"):
		player_ship.set_allowed_actions(_allowed_actions_for_step(step))

func _ready() -> void:
				await super._ready()
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
									var tw = get_tree().create_tween()
									tw.tween_interval(2.0)
									tw.tween_property(enemy_ship, "modulate:a", 0.0, 2.0)
									tw.parallel().tween_property(enemy_ship.get_node("Trail"), "modulate:a", 0.0, 4.0)
									var sprite := enemy_ship.get_node("Trail/Sprite2D")
									if sprite.material is ShaderMaterial:
										tw.parallel().tween_property(sprite.material,
										"shader_parameter/InitialAlpha", 0.0, 4.0)
									tw.tween_callback(Callable(enemy_ship, "queue_free"))
									tw.tween_callback(Callable(self, "_clear_enemy_ship"))
									return
				if player_ship:
												_orig_max_speed = player_ship.max_speed
												_orig_target_speed = player_ship.target_speed
												# Slightly faster tutorial ship speed
												player_ship.max_speed *= 0.5
												player_ship.target_speed *= 0.5
				if player_ship.has_signal("player_docked"):
						player_ship.connect("player_docked", _on_player_docked)

				if enemy_ship:
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

										arrow.visible = false
										arrow.target  = null
										arrow.self_modulate = Color.WHITE
										_show_step_text()
										_apply_allowed_actions()

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
						if Input.is_action_just_pressed("shoot_left"):
								shoot_left_done = true
								_update_hint_text()
						if Input.is_action_just_pressed("shoot_right"):
								shoot_right_done = true
								_update_hint_text()
						if shoot_left_done and shoot_right_done and not _advancing:
								_advance_step(4)
				4:
								pass
				5:
								pass
				6:
								pass

func _on_player_docked() -> void:
                if step == 5 and not _advancing:
                                _advance_step(6)

func _on_board_enemy_request(enemy: Node2D) -> void:
                if step == 5 and not _advancing:
                                _advance_step(6)
                super._on_board_enemy_request(enemy)

func _on_enemy_area_entered(area: Area2D) -> void:
		if step == 4 and not _advancing and area.is_in_group("cannonball2"):
				if player_ship and player_ship.current_speed > 0:
						enemy_hit = true
						_advance_step(5)

func _show_step_text() -> void:
		_update_hint_text()
		hint_label.add_theme_color_override("default_color", Color.WHITE)
		_fade_in_hint(hint_label)

func _update_hint_text() -> void:
		var text := ""
		match step:
			0:
											text = "Press W to increase speed"
			1:
											text = "Press S to slow and stop the ship"
			2:
				var l1 = "Press A or Left Arrow to turn to port"
				var l2 = "Press D or Right Arrow to turn starboard"
				if left_done:
						l1 = "[color=green]%s[/color]" % l1
				if right_done:
						l2 = "[color=green]%s[/color]" % l2
				text = "%s\n%s" % [l1, l2]
			3:
												var sl = "Press O to shoot port side"
												var sr = "Press P to shoot starboard side"
												if shoot_left_done:
																sl = "[color=green]%s[/color]" % sl
												if shoot_right_done:
																sr = "[color=green]%s[/color]" % sr
												text = "%s\n%s" % [sl, sr]
			4:
							text = "While moving, hit the wreck with a cannonball"
			5:
							text = "Click on the wreck to dock"
			6:
							text = "Click the Begin Raid button to board"
		hint_label.text = "[center]%s[/center]" % text

func _fade_in_hint(label: CanvasItem, duration: float = 0.5) -> void:
		label.visible = true
		label.modulate.a = 0.0
		get_tree().create_tween().tween_property(label, "modulate:a", 1.0, duration)

func _fade_out_hint(label: CanvasItem, duration: float = 0.5) -> void:
				var tw = get_tree().create_tween()
				tw.tween_property(label, "modulate:a", 0.0, duration)
				await tw.finished
				label.hide()

func _advance_step(next_step: int) -> void:
		_advancing = true
		hint_label.add_theme_color_override("default_color", Color.GREEN)
		SoundManager.play_success()
		await _fade_out_hint(hint_label)
		step = next_step
		left_done = false
		right_done = false
		shoot_left_done = false
		shoot_right_done = false

		if step == 4:
				if enemy_ship and player_ship:
					enemy_ship.global_position = player_ship.global_position + Vector2(100, 0)
					enemy_ship.visible = true
					enemy_ship.ready_for_boarding = false
					enemy_ship.input_pickable = false
					enemy_ship.collision_layer = _enemy_layer
					enemy_ship.collision_mask  = _enemy_mask
					enemy_ship.set_process(true)
					enemy_ship.set_physics_process(true)
					if enemy_ship.has_node("Trail/SubViewport/Line2D"):
							enemy_ship.get_node("Trail/SubViewport/Line2D").reset_line()
							arrow.self_modulate = Color.RED
							arrow.target = enemy_ship
							arrow.global_position = enemy_ship.global_position + Vector2(arrow.x_offset, arrow.y_offset)
							arrow.visible = true
		elif step == 5:
															arrow.self_modulate = Color.WHITE
															arrow.target = enemy_ship
															arrow.global_position = enemy_ship.global_position + Vector2(arrow.x_offset, arrow.y_offset)
															arrow.visible = true
															if enemy_ship:
																	enemy_ship.input_pickable = true
		elif step == 6:
						arrow.visible = false
						arrow.target = null
						arrow.self_modulate = Color.WHITE
						if player_ship:
										player_ship.max_speed = _orig_max_speed
										player_ship.target_speed = _orig_target_speed

		_show_step_text()
		_apply_allowed_actions()
		_advancing = false

func begin_raid_pressed() -> void:
                                                                if step == 6 and not _advancing:
                                                                               _advance_step(7)

func _clear_enemy_ship() -> void:
	enemy_ship = null
