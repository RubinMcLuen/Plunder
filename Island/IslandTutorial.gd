extends "res://Island/island.gd"

@onready var hint_label: RichTextLabel = $CanvasLayer/HintLabel
@onready var arrow      : Sprite2D      = $Arrow
@onready var ship_area  : Area2D        = $ShipControlArea

var step: int = 0
var _advancing: bool = false

func get_tutorial_state() -> Dictionary:
				return {"step": step}

func apply_tutorial_state(state: Dictionary) -> void:
				step = int(state.get("step", step))

func _ready() -> void:
				await super._ready()

				ship_area.body_entered.connect(_on_ship_area_entered)
				var btn = UIManager.get_node("UIManager/SetSailMenu/SetSailButton")
				if btn:
								if btn.pressed.is_connected(UIManager._on_set_sail_button_pressed):
												btn.pressed.disconnect(UIManager._on_set_sail_button_pressed)
								if not btn.pressed.is_connected(_on_set_sail_pressed):
												btn.pressed.connect(_on_set_sail_pressed)

				if Global.island_tutorial_state and Global.island_tutorial_state.size() > 0:
								apply_tutorial_state(Global.island_tutorial_state)
								Global.island_tutorial_state = {}

				_show_step()

func _show_step() -> void:
		arrow.visible = false
		arrow.target = null
		hint_label.add_theme_color_override("default_color", Color.WHITE)

		match step:
				0:
						arrow.target = ship_area
						arrow.global_position = ship_area.global_position + Vector2(arrow.x_offset, arrow.y_offset)
						arrow.visible = true
						hint_label.text = "[center]Walk onto your ship at the end of the dock[/center]"
						_fade_in_hint(hint_label)
				1:
						hint_label.text = "[center]Press Set Sail[/center]"
						_fade_in_hint(hint_label)
				_:
						hint_label.hide()

func _fade_in_hint(label: CanvasItem, duration: float = 0.5) -> void:
		label.visible = true
		label.modulate.a = 0.0
		get_tree().create_tween().tween_property(label, "modulate:a", 1.0, duration)

func _fade_out_hint(label: CanvasItem, duration: float = 0.5) -> void:
		var tw = get_tree().create_tween()
		tw.tween_property(label, "modulate:a", 0.0, duration)
		await tw.finished
		label.hide()

func _on_ship_area_entered(body: Node) -> void:
		if body == player and step == 0 and not _advancing:
				_advance_step(1)

func _on_set_sail_pressed() -> void:
		if step == 1 and not _advancing:
				_advance_step(2)
				var tw = get_tree().create_tween()
				tw.tween_interval(1.0)
				tw.connect("finished", Callable(self, "start_leave_island_transition").bind(1.0))
				Global.restore_sails_next = true
                                SceneSwitcher.switch_scene(
                                                "res://Ocean/oceantutorial.tscn",
                                                Vector2(-2, 39),
                                                "zoom",
                                                Vector2(0.0625, 0.0625), Vector2(-32, 624),
                                                Vector2(1, 1), true
                                )
				UIManager.hide_set_sail_menu()

func _advance_step(next_step: int) -> void:
				_advancing = true
				hint_label.add_theme_color_override("default_color", Color.GREEN)
				SoundManager.play_success()
				await _fade_out_hint(hint_label)
				step = next_step
				_show_step()
				_advancing = false

func _on_exit_body_entered(body: Node) -> void:
				if body == player:
								Global.island_tutorial_state = get_tutorial_state()
								SceneSwitcher.switch_scene(
												"res://KelptownInn/KelptownInnTutorial.tscn",
												Vector2(269, 220),
												"fade",
												Vector2.ONE,
												Vector2.ZERO,
												Vector2(1.5, 1.5)
								)

func _exit_tree() -> void:
				Global.island_tutorial_state = get_tutorial_state()

