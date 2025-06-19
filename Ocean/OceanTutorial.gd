extends "res://Ocean/Ocean.gd"

@onready var hint_label: RichTextLabel = $CanvasLayer/HintLabel
@onready var island     : Node2D        = $KelptownIsland
@onready var arrow      : Sprite2D      = $Arrow

var step: int = 0
var left_done: bool = false
var right_done: bool = false
var shoot_left_done: bool = false
var shoot_right_done: bool = false
var _advancing: bool = false

func _allowed_actions_for_step(s: int) -> Array[String]:
	match s:
		0:
			return ["ui_select"]
		1:
			return ["ui_select"]
		2:
			return ["ui_left", "ui_right"]
		3:
			return ["shoot_left", "shoot_right"]
		4:
			return ["move"]
		_:
			return []

func _apply_allowed_actions():
	if player_ship and player_ship.has_method("set_allowed_actions"):
		player_ship.set_allowed_actions(_allowed_actions_for_step(step))

func _ready() -> void:
		await super._ready()
		if player_ship.has_signal("player_docked"):
				player_ship.connect("player_docked", _on_player_docked)
		arrow.visible = false
		arrow.target  = null
		_show_step_text()
		_apply_allowed_actions()

func _process(_delta: float) -> void:
		match step:
				0:
						if Input.is_action_just_pressed("ui_select") and not _advancing:
								_advance_step(1)
				1:
						if Input.is_action_just_pressed("ui_select") and not _advancing:
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

func _on_player_docked() -> void:
		if step == 4 and not _advancing:
				_advance_step(5)

func _show_step_text() -> void:
		_update_hint_text()
		hint_label.add_theme_color_override("default_color", Color.WHITE)
		_fade_in_hint(hint_label)

func _update_hint_text() -> void:
		var text := ""
		match step:
				0:
						text = "Press spacebar to start the ship"
				1:
						text = "Press spacebar while moving to anchor the ship"
				2:
						var l1 = "Press A or Left Arrow to turn to port"
						var l2 = "Press D or Right Arrow to turn starboard"
						if left_done:
								l1 = "[color=green]%s[/color]" % l1
						if right_done:
								l2 = "[color=green]%s[/color]" % l2
						text = "%s\n%s" % [l1, l2]
				3:
						var sl = "Press K to shoot port side"
						var sr = "Press L to shoot starboard side"
						if shoot_left_done:
								sl = "[color=green]%s[/color]" % sl
						if shoot_right_done:
								sr = "[color=green]%s[/color]" % sr
						text = "%s\n%s" % [sl, sr]
				4:
						text = "Click on the island to automatically dock your ship"
				5:
						text = "Tutorial complete!"
		hint_label.text = "[center]%s[/center]" % text

func _fade_in_hint(label: CanvasItem, duration: float = 0.5) -> void:
		label.visible = true
		label.modulate.a = 0.0
		get_tree().create_tween().tween_property(label, "modulate:a", 1.0, duration)

func _fade_out_hint(label: CanvasItem, duration: float = 0.5) -> void:
		var tw = get_tree().create_tween()
		tw.tween_property(label, "modulate:a", 0.0, duration)
		tw.tween_callback(Callable(label, "hide"))

func _advance_step(next_step: int) -> void:
				_advancing = true
				hint_label.add_theme_color_override("default_color", Color.GREEN)
				_fade_out_hint(hint_label)
				await get_tree().create_timer(0.5).timeout
				step = next_step
				left_done = false
				right_done = false
				shoot_left_done = false
				shoot_right_done = false
				if step == 4:
						arrow.target = island
						arrow.global_position = island.global_position + Vector2(arrow.x_offset, arrow.y_offset)
						arrow.visible = true
				elif step == 5:
						arrow.visible = false
						arrow.target = null
						_show_step_text()
						_apply_allowed_actions()
						_advancing = false
						if step == 5:
										await get_tree().create_timer(3.0).timeout
										_fade_out_hint(hint_label)
