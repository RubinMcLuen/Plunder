extends "res://Battle/BoardingBattle.gd"

@onready var hint_label : RichTextLabel = $CanvasLayer/HintLabel
@onready var arrow      : Sprite2D      = $Arrow
@onready var manager    : BattleManagerTutorial = $BattleManager
@onready var crew_container : Node2D = $CrewContainer
@onready var cam : Camera2D = $Camera2D

var _orig_cam_y: float = 0.0

var step : int = 0
var _advancing : bool = false
var barnaby : CrewMemberNPC = null
var enemy   : EnemyNPC = null

func _ready() -> void:
				await super._ready()
				_orig_cam_y = cam.global_position.y
				for c in crew_container.get_children():
								if c is BarnabyCrew:
												barnaby = c
												break
				await get_tree().create_timer(2.0).timeout
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
			if enemy and not is_instance_valid(enemy):
				_advance_step(4)

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
												hint_label.text = "[center]Click Barnaby to deploy him[/center]"
												_fade_in_hint(hint_label)
								1:
									hint_label.text = "[center]Click and drag Barnaby to move him[/center]"
									_fade_in_hint(hint_label)
								2:
										enemy = manager.spawn_single_enemy()
										_toggle_ranges(true)
										if enemy:
												arrow.self_modulate = Color.RED
												arrow.target = enemy
												arrow.visible = true
										hint_label.text = "[center]Move Barnaby next to the enemy[/center]"
										_fade_in_hint(hint_label)
								3:
									hint_label.text = "[center]Defeat the enemy[/center]"
									_fade_in_hint(hint_label)
								4:
									_toggle_ranges(false)
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

func _finish_tutorial() -> void:
		var tw := fade_out_all(2.0)
		var cam_tw = create_tween()
		cam_tw.tween_property(cam, "global_position:y", _orig_cam_y, 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		await tw.finished
		await cam_tw.finished
		Global.board_zoom_out_next = true
		Global.ocean_tutorial_complete = true
		var scene = Global.return_scene_path if Global.return_scene_path != "" else "res://Ocean/oceantutorial.tscn"
		Global.return_scene_path = ""
		SceneSwitcher.switch_scene(scene, Global.spawn_position, "none", Vector2(), Vector2(), Vector2(16,16), true)

