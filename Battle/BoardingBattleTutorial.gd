extends "res://Battle/BoardingBattle.gd"
class_name BoardingBattleTutorial

@onready var hint_label : RichTextLabel = $CanvasLayer/HintLabel
@onready var arrow      : Sprite2D      = $Arrow
@onready var manager    : BattleManagerTutorial = $BattleManager


var step : int = 0
var _advancing : bool = false
var barnaby : CrewMemberNPC = null
var enemy   : EnemyNPC = null

func _enter_tree() -> void:
	Global.crew_override = ["Barnaby"]
	
func get_tutorial_state() -> Dictionary:
	var barnaby_state := {}
	if barnaby:
		barnaby_state = {
			"pos": barnaby.global_position,
			"health": barnaby.health,
			"dragging": barnaby.dragging,
			"is_boarding": barnaby.is_boarding,
			"has_boarded": barnaby.has_boarded,
		}

	var enemy_state := {}
	if enemy and is_instance_valid(enemy):
		enemy_state = {
			"exists": true,
			"pos": enemy.global_position,
			"health": enemy.health,
		}
	else:
		enemy_state = {
			"exists": false,
		}

	var cam_state := {
		"pos": cam.global_position,
		"zoom": cam.zoom,
	}

	return {
		"step": step,
		"barnaby": barnaby_state,
		"enemy": enemy_state,
		"camera": cam_state,
	}


func apply_tutorial_state(state: Dictionary) -> void:
				step = int(state.get("step", step))
				var b = state.get("barnaby", {})
				if barnaby and b:
								var pos = b.get("pos", barnaby.global_position)
								if typeof(pos) == TYPE_DICTIONARY and pos.has("x") and pos.has("y"):
												barnaby.global_position = Vector2(pos["x"], pos["y"])
								elif typeof(pos) == TYPE_VECTOR2:
												barnaby.global_position = pos
								elif typeof(pos) == TYPE_STRING:
												var tmp = str_to_var(pos)
												if typeof(tmp) == TYPE_VECTOR2:
																barnaby.global_position = tmp

								barnaby.health = int(b.get("health", barnaby.health))
								barnaby.dragging = bool(b.get("dragging", barnaby.dragging))
								barnaby.is_boarding = bool(b.get("is_boarding", barnaby.is_boarding))
								barnaby.has_boarded = bool(b.get("has_boarded", barnaby.has_boarded))
				var e = state.get("enemy", {})
				if e.get("exists", false):
								if enemy == null or not is_instance_valid(enemy):
												enemy = manager.spawn_single_enemy()
								var epos = e.get("pos", enemy.global_position)
								if typeof(epos) == TYPE_DICTIONARY and epos.has("x") and epos.has("y"):
												enemy.global_position = Vector2(epos["x"], epos["y"])
								elif typeof(epos) == TYPE_VECTOR2:
												enemy.global_position = epos
								elif typeof(epos) == TYPE_STRING:
												var tmp2 = str_to_var(epos)
												if typeof(tmp2) == TYPE_VECTOR2:
																enemy.global_position = tmp2
								enemy.health = int(e.get("health", enemy.health))
				_show_step()

				var cam_info = state.get("camera", {})
				var cpos = cam_info.get("pos", cam.global_position)
				if typeof(cpos) == TYPE_DICTIONARY and cpos.has("x") and cpos.has("y"):
								cam.global_position = Vector2(cpos["x"], cpos["y"])
				elif typeof(cpos) == TYPE_VECTOR2:
								cam.global_position = cpos
				elif typeof(cpos) == TYPE_STRING:
								var tmp3 = str_to_var(cpos)
								if typeof(tmp3) == TYPE_VECTOR2:
												cam.global_position = tmp3

				var cz = cam_info.get("zoom", cam.zoom)
				if typeof(cz) == TYPE_DICTIONARY and cz.has("x") and cz.has("y"):
								cam.zoom = Vector2(cz["x"], cz["y"])
				elif typeof(cz) == TYPE_VECTOR2:
								cam.zoom = cz
				elif typeof(cz) == TYPE_STRING:
								var tmp4 = str_to_var(cz)
								if typeof(tmp4) == TYPE_VECTOR2:
												cam.zoom = tmp4

func _ready() -> void:
								await super._ready()
								_orig_cam_y = cam.global_position.y
								for c in crew_container.get_children():
												if c is BarnabyCrew:
																barnaby = c
																barnaby.health = 10000
																break
												await get_tree().create_timer(2.0).timeout
								if Global.boarding_battle_tutorial_state and Global.boarding_battle_tutorial_state.size() > 0:
										apply_tutorial_state(Global.boarding_battle_tutorial_state)
										Global.boarding_battle_tutorial_state = {}
								else:
										_show_step()
								set_process(true)

func _process(_delta: float) -> void:
	match step:
			0:
					if barnaby and barnaby.is_boarding and arrow.visible:
							arrow.visible = false
					if barnaby and barnaby.has_boarded and not _advancing:
							_advance_step(1)
			1:
					if barnaby and barnaby.dragging and not _advancing:
							_advance_step(2)
			2:
					if barnaby and enemy and barnaby.targets.has(enemy) and not _advancing:
							_advance_step(3)
			3:
					if enemy and not is_instance_valid(enemy) and not _advancing:
							_advance_step(4)
			4:
					pass

func _show_step() -> void:
							hint_label.add_theme_color_override("default_color", Color.WHITE)
							arrow.visible = false
							arrow.target = null
							arrow.self_modulate = Color.WHITE
							match step:
									0:
											if barnaby:
													arrow.target = barnaby
													arrow.visible = true
											hint_label.text = "[center]Click Barnaby to deploy him to the enemy ship[/center]"
											_fade_in_hint(hint_label)
									1:
											hint_label.text = "[center]Click and drag Barnaby around to move him[/center]"
											_fade_in_hint(hint_label)
									2:
											enemy = manager.spawn_single_enemy()
											_toggle_ranges(true)
											if enemy:
													arrow.self_modulate = Color.RED
													arrow.target = enemy
													arrow.visible = true
													enemy.end_fight.connect(_on_enemy_defeated)
											hint_label.text = "[center]Move Barnaby close to the enemy to begin auto-attacking[/center]"
											_fade_in_hint(hint_label)
									3:
											arrow.visible = false
											hint_label.text = "[center]Defeat the enemy![/center]"
											_fade_in_hint(hint_label)
									4:
											_toggle_ranges(false)
											hint_label.add_theme_color_override("default_color", Color.GREEN)
											hint_label.text = "[center]Tutorial complete![/center]"
											_fade_in_hint(hint_label)
											await get_tree().create_timer(2.0).timeout
											await _fade_out_hint(hint_label)
											await _finish_tutorial()

func _toggle_ranges(on: bool) -> void:
	_set_range_visible(barnaby, on, Color.CYAN)
	if enemy and is_instance_valid(enemy):
			_set_range_visible(enemy, on, Color.RED)

func _set_range_visible(ch, on: bool, color: Color) -> void:
		if not ch or not ch.has_node("MeleeRange/CollisionShape2D"):
			return
		var shape := ch.get_node("MeleeRange/CollisionShape2D") as CollisionShape2D
		shape.visible = on
		var sprite_path := "MeleeRange/RangeSprite"
		var sprite : Node2D
		if ch.has_node(sprite_path):
						sprite = ch.get_node(sprite_path)
		else:
						sprite = load("res://Battle/RangeCircle.gd").new()
						sprite.name = "RangeSprite"
						ch.get_node("MeleeRange").add_child(sprite)

		sprite.z_index = ch.z_index - 1
		# Ensure the range sprite ignores parent z_index
		sprite.z_as_relative = false
		var radius := 30.0
		if shape.shape is CircleShape2D:
						radius = shape.shape.radius
						sprite.radius = radius * 1.2
		sprite.fill_color = Color(color.r, color.g, color.b, 0.25)
		sprite.outline_color = color
		sprite.outline_width = 0.5
		sprite.visible = on
		sprite.queue_redraw()


func _advance_step(next_step: int) -> void:
	_advancing = true
	hint_label.add_theme_color_override("default_color", Color.GREEN)
	SoundManager.play_success()
	await _fade_out_hint(hint_label)
	step = next_step
	_show_step()
	_advancing = false

func _fade_in_hint(label: CanvasItem, duration: float = 0.5) -> void:
	label.visible = true
	label.modulate.a = 0.0
	get_tree().create_tween().tween_property(label, "modulate:a", 1.0, duration)

func _fade_out_hint(label: CanvasItem, duration: float = 0.5) -> void:
				var tw = get_tree().create_tween()
				tw.tween_property(label, "modulate:a", 0.0, duration)
				await tw.finished
				label.hide()

func _on_enemy_defeated() -> void:
	if step == 3:
			_advance_step(4)

func _finish_tutorial() -> void:
	var tw := fade_out_all(2.0)
	var cam_tw := create_tween()
	cam_tw.tween_property(cam, "global_position:y", _orig_cam_y, 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	await cam_tw.finished

	Global.board_zoom_out_next = true
	Global.ocean_tutorial_complete = true

	# now switch to the preloaded tutorial scene
	SceneSwitcher.switch_scene(
		OCEAN_TUTORIAL_SCENE,
		Global.spawn_position,
		"none",
		Vector2(),
		Vector2(),
		Vector2(16,16),
		true
	)

func _exit_tree() -> void:
	if _battle_over:
		Global.boarding_battle_tutorial_state = {}
	else:
		Global.boarding_battle_tutorial_state = get_tutorial_state()

