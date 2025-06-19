extends "res://KelptownInn/KelptownInn.gd"
class_name KelptownInnTutorial

@onready var fade_rect      : ColorRect     = $CanvasLayer/FadeRect
@onready var hint_keys      : RichTextLabel = $CanvasLayer/HintMoveKeys
@onready var hint_bartender : RichTextLabel = $CanvasLayer/HintBartender
@onready var hint_hire      : RichTextLabel = $CanvasLayer/HintHireBarnaby
@onready var hint_exit      : RichTextLabel = $CanvasLayer/HintExit
@onready var exit_area      : Area2D        = $Exit
@onready var barnaby        : NPC           = $Barnaby
@onready var arrow          : Sprite2D      = $Arrow

var moved_keys: bool = false
var stage_two_started: bool = false
var stage_three_started: bool = false
var stage_exit_started: bool = false
var intro_walk_finished: bool = false
var _orig_speed: float = 0.0
var tutorial_complete: bool = false

func get_tutorial_state() -> Dictionary:
	var target := ""
	if is_instance_valid(arrow) and arrow.target == bartender:
			target = "bartender"
	elif is_instance_valid(arrow) and arrow.target == barnaby:
			target = "barnaby"
	elif is_instance_valid(arrow) and arrow.target == exit_area:
			target = "exit"

	return {
		"moved_keys": moved_keys,
		"stage_two_started": stage_two_started,
		"stage_three_started": stage_three_started,
				"intro_walk_finished": intro_walk_finished,
				"stage_exit_started": stage_exit_started,
				"orig_speed": _orig_speed,
		"player_speed": player.speed,
		"player_auto_move": player.auto_move,
		"player_auto_target": player.auto_target_position,
		"tutorial_complete": tutorial_complete,
		"bartender_state": bartender.state if is_instance_valid(bartender) else "",
		"barnaby_state": barnaby.state if is_instance_valid(barnaby) else "",
		"barnaby_hired": barnaby.hired if is_instance_valid(barnaby) else false,
		"barnaby_pos": {
			"x": barnaby.global_position.x,
			"y": barnaby.global_position.y
		} if is_instance_valid(barnaby) else {},
		"barnaby_auto_move": barnaby.auto_move if is_instance_valid(barnaby) else false,
		"barnaby_auto_target": barnaby.auto_target_position if is_instance_valid(barnaby) else Vector2.ZERO,
		"arrow_visible": arrow.visible if is_instance_valid(arrow) else false,
		"arrow_target": target,
		"fade_alpha": fade_rect.modulate.a,
				"hint_keys": {
								"visible": hint_keys.visible,
								"color": hint_keys.get_theme_color("default_color").to_html(true),
								"alpha": hint_keys.modulate.a
				},
				"hint_bartender": {
								"visible": hint_bartender.visible,
								"color": hint_bartender.get_theme_color("default_color").to_html(true),
								"alpha": hint_bartender.modulate.a
				},
								"hint_hire": {
																"visible": hint_hire.visible,
																"color": hint_hire.get_theme_color("default_color").to_html(true),
																"alpha": hint_hire.modulate.a
								},
								"hint_exit": {
																"visible": hint_exit.visible,
																"color": hint_exit.get_theme_color("default_color").to_html(true),
																"alpha": hint_exit.modulate.a
								}
		}

func apply_tutorial_state(state: Dictionary) -> void:
		moved_keys = state.get("moved_keys", false)
		stage_two_started = state.get("stage_two_started", false)
		stage_three_started = state.get("stage_three_started", false)
		intro_walk_finished = state.get("intro_walk_finished", false)
		_orig_speed = state.get("orig_speed", player.speed)
		player.speed = state.get("player_speed", player.speed)
		if state.get("player_auto_move", false):
						player.connect("auto_move_completed", Callable(self, "_on_intro_move_completed"), CONNECT_ONE_SHOT)

						var pat = state.get("player_auto_target", null)
						if typeof(pat) == TYPE_DICTIONARY and pat.has("x") and pat.has("y"):
										player.auto_target_position = Vector2(pat["x"], pat["y"])
						elif typeof(pat) == TYPE_VECTOR2:
										player.auto_target_position = pat
						elif typeof(pat) == TYPE_STRING:
										var tmp = str_to_var(pat)
										if typeof(tmp) == TYPE_VECTOR2:
														player.auto_target_position = tmp
						player.auto_move = true

		tutorial_complete = state.get("tutorial_complete", false)

		bartender.state = state.get("bartender_state", bartender.state)

		barnaby.state = state.get("barnaby_state", barnaby.state)
		barnaby.hired = state.get("barnaby_hired", barnaby.hired)
		var bpos = state.get("barnaby_pos", null)
		if typeof(bpos) == TYPE_DICTIONARY and bpos.has("x") and bpos.has("y"):
						barnaby.global_position = Vector2(bpos["x"], bpos["y"])
		elif typeof(bpos) == TYPE_VECTOR2:
						barnaby.global_position = bpos
		elif typeof(bpos) == TYPE_STRING:
						var tmp = str_to_var(bpos)
						if typeof(tmp) == TYPE_VECTOR2:
										barnaby.global_position = tmp
		barnaby.auto_move = state.get("barnaby_auto_move", false)

		var bat = state.get("barnaby_auto_target", null)
		if typeof(bat) == TYPE_DICTIONARY and bat.has("x") and bat.has("y"):
						barnaby.auto_target_position = Vector2(bat["x"], bat["y"])
		elif typeof(bat) == TYPE_VECTOR2:
						barnaby.auto_target_position = bat
		elif typeof(bat) == TYPE_STRING:
						var tmp2 = str_to_var(bat)
						if typeof(tmp2) == TYPE_VECTOR2:
										barnaby.auto_target_position = tmp2
		else:
				barnaby.auto_target_position = barnaby.auto_target_position

				stage_exit_started = state.get("stage_exit_started", false)
				var target_str = state.get("arrow_target", "")
				match target_str:
								"bartender":
												arrow.target = bartender
								"barnaby":
												arrow.target = barnaby
								"exit":
												arrow.target = exit_area
								_:
												arrow.target = null
		arrow.visible = state.get("arrow_visible", false)
		if arrow.target:
				arrow.global_position = arrow.target.global_position + Vector2(arrow.x_offset, arrow.y_offset)

		fade_rect.modulate.a = state.get("fade_alpha", fade_rect.modulate.a)

		var hk = state.get("hint_keys", {})
		hint_keys.visible = hk.get("visible", false)
		var hk_col = hk.get("color", hint_keys.get_theme_color("default_color"))
		if typeof(hk_col) == TYPE_STRING:
										hk_col = Color(hk_col)
		hint_keys.add_theme_color_override("default_color", hk_col)
		hint_keys.modulate.a = hk.get("alpha", 1.0 if hint_keys.visible else 0.0)


		var hb = state.get("hint_bartender", {})
		hint_bartender.visible = hb.get("visible", false)
		var hb_col = hb.get("color", hint_bartender.get_theme_color("default_color"))
		if typeof(hb_col) == TYPE_STRING:
										hb_col = Color(hb_col)
		hint_bartender.add_theme_color_override("default_color", hb_col)
		hint_bartender.modulate.a = hb.get("alpha", 1.0 if hint_bartender.visible else 0.0)

		var hh = state.get("hint_hire", {})
		hint_hire.visible = hh.get("visible", false)
		var hh_col = hh.get("color", hint_hire.get_theme_color("default_color"))
		if typeof(hh_col) == TYPE_STRING:
								hh_col = Color(hh_col)
		hint_hire.add_theme_color_override("default_color", hh_col)
		hint_hire.modulate.a = hh.get("alpha", 1.0 if hint_hire.visible else 0.0)

		var he = state.get("hint_exit", {})
		hint_exit.visible = he.get("visible", false)
		var he_col = he.get("color", hint_exit.get_theme_color("default_color"))
		if typeof(he_col) == TYPE_STRING:
								he_col = Color(he_col)
		hint_exit.add_theme_color_override("default_color", he_col)
		hint_exit.modulate.a = he.get("alpha", 1.0 if hint_exit.visible else 0.0)

		   # If Barnaby has already been hired, he should no longer be
		   # present in the inn when reloading the tutorial scene.
		if barnaby.hired:
						if arrow.target == barnaby:
										arrow.visible = false
										arrow.target = null
						barnaby.queue_free()

func _ready() -> void:
	if player == null and has_node("Player"):
				player = get_node("Player") as CharacterBody2D

		# ───────────────────────────────────── 0) Spawn position if loading from a save
	if Global.spawn_position != Vector2.ZERO:
				player.global_position = Global.spawn_position
				Global.spawn_position  = Vector2.ZERO

	# 1) Spawn crew for this scene
	CrewManager.populate_scene(self)
	await get_tree().process_frame

	# 2) Hook up the bartender (tutorial variant)
	if bartender.dialogue_requested.is_connected(_on_bartender_dialogue_requested):
		bartender.dialogue_requested.disconnect(_on_bartender_dialogue_requested)
	if bartender.dialogue_requested.is_connected(_on_bartender_dialogue_requested_tutorial):
		bartender.dialogue_requested.disconnect(_on_bartender_dialogue_requested_tutorial)
	bartender.dialogue_requested.connect(_on_bartender_dialogue_requested_tutorial)
	bartender.state = "move_first"
	barnaby.state = "wait_bartender"

	# 3) Hook up Barnaby for dialogue and hiring
	barnaby.dialogue_requested.connect(_on_barnaby_dialogue_requested_tutorial)
	barnaby.npc_hired.connect(_on_barnaby_hired_tutorial)

	# 4) UI, camera & exit
	UIManager.show_location_notification(location_name)
	$Player/Camera2D.zoom = Vector2(1.5, 1.5)
	$Exit.body_entered.connect(_on_exit_body_entered)

	fade_rect.modulate.a       = 1.0
	arrow.visible              = false
	arrow.target               = null
	hint_bartender.visible     = false
	hint_hire.visible          = false
	hint_exit.visible          = false
	hint_keys.visible          = false
	hint_keys.modulate.a       = 0.0
	hint_bartender.modulate.a  = 0.0
	hint_hire.modulate.a       = 0.0
	hint_exit.modulate.a       = 0.0

	var loaded_state := false
	if Global.kelptown_tutorial_state and Global.kelptown_tutorial_state.size() > 0:
			apply_tutorial_state(Global.kelptown_tutorial_state)
			Global.kelptown_tutorial_state = {}
			loaded_state = true

	get_tree().create_tween().tween_property(fade_rect, "modulate:a", 0.0, 2.0)

	if not loaded_state:
			_orig_speed = player.speed
			player.speed *= 0.5
			player.connect(
					"auto_move_completed",
					Callable(self, "_on_intro_move_completed"),
					CONNECT_ONE_SHOT
			)
			player.auto_move_to_position(Vector2(382, 88))

func _process(_delta: float) -> void:
	if intro_walk_finished:
		if not moved_keys and (
			Input.is_action_pressed("ui_up")
			or Input.is_action_pressed("ui_down")
			or Input.is_action_pressed("ui_left")
			or Input.is_action_pressed("ui_right")
		):
			moved_keys = true
			hint_keys.add_theme_color_override("default_color", Color.GREEN)
			_check_movement_complete()



func _check_movement_complete() -> void:
	if moved_keys and not stage_two_started:
			stage_two_started = true
			await get_tree().create_timer(1.0).timeout
			_fade_out_hint(hint_keys)
			await get_tree().create_timer(0.5).timeout

	arrow.target = bartender
	arrow.global_position = bartender.global_position + Vector2(arrow.x_offset, arrow.y_offset)
	arrow.visible = true
	_fade_in_hint(hint_bartender)
	bartender.state = "introduction"

func _on_intro_move_completed() -> void:
	player.speed = _orig_speed
	await get_tree().create_timer(1.0).timeout
	_fade_in_hint(hint_keys)
	intro_walk_finished = true

func _fade_in_hint(label: CanvasItem, duration: float = 0.5) -> void:
	label.visible = true
	label.modulate.a = 0.0
	get_tree().create_tween().tween_property(label, "modulate:a", 1.0, duration)

func _fade_out_hint(label: CanvasItem, duration: float = 0.5) -> void:
	var tw = get_tree().create_tween()
	tw.tween_property(label, "modulate:a", 0.0, duration)
	tw.tween_callback(Callable(label, "hide"))

func _on_bartender_dialogue_requested_tutorial(section: String) -> void:
		# Tutorial completed → fallback to the normal bartender handler
		if tutorial_complete:
				super._on_bartender_dialogue_requested(section)
				return

		# Step 1: still teaching movement.  Simply show the line without
		# advancing the tutorial.
		if not stage_two_started:
				super._on_bartender_dialogue_requested(section)
				return

		# Step 3 already active → talking to the bartender shouldn't change
		# anything.
		if stage_three_started:
				super._on_bartender_dialogue_requested(section)
				return

		# Transition from step 2 (talk to bartender) to step 3 (hire Barnaby)
		arrow.visible = false
		arrow.target  = null
		hint_bartender.add_theme_color_override("default_color", Color.GREEN)
		_fade_out_hint(hint_bartender)

		player.disable_user_input = true
		var balloon := bartender.show_dialogue(section)
		if balloon:
						balloon.connect(
										"dialogue_finished",
										Callable(self, "_on_dialogue_finished_tutorial")
						)
		else:
						player.disable_user_input = false

func _on_dialogue_finished_tutorial() -> void:
		await get_tree().create_timer(0.1).timeout
		player.disable_user_input = false
		if stage_two_started and not stage_three_started:
				stage_three_started = true
				await get_tree().create_timer(0.5).timeout
				barnaby.state = "Hirable"

		arrow.target = barnaby
		arrow.global_position = barnaby.global_position + Vector2(arrow.x_offset, arrow.y_offset)
		arrow.visible = true
		_fade_in_hint(hint_hire)

func _on_barnaby_dialogue_requested_tutorial(section: String, b: NPC) -> void:
		# Only hide the arrow once we're on the hiring step
		if stage_three_started:
				arrow.visible = false
				arrow.target  = null

		player.disable_user_input = true
		var balloon := b.show_dialogue(section)
		balloon.connect(
				"dialogue_finished",
				Callable(self, "_on_dialogue_finished_barnaby_tutorial").bind(b)
		)

func _on_dialogue_finished_barnaby_tutorial(b: NPC) -> void:
		player.disable_user_input = false
		if stage_three_started and not b.hired:
				arrow.target = b
				arrow.global_position = b.global_position + Vector2(arrow.x_offset, arrow.y_offset)
				arrow.visible = true
				# Hint remains visible; simply restore the arrow

func _on_barnaby_hired_tutorial(_b: NPC) -> void:
				hint_hire.add_theme_color_override("default_color", Color.GREEN)
				await get_tree().create_timer(1.0).timeout
				_fade_out_hint(hint_hire)
				arrow.visible = false
				arrow.target  = null
				var exit_target = $Exit.global_position
				_b.auto_move_to_position(exit_target)
				_b.npc_move_completed.connect(Callable(_b, "queue_free"))
				bartender.state = "normal"
				tutorial_complete = true
				stage_exit_started = true
				arrow.target = exit_area
				arrow.global_position = exit_area.global_position + Vector2(arrow.x_offset, arrow.y_offset)
				arrow.visible = true
				_fade_in_hint(hint_exit)

func _on_exit_body_entered(body: Node) -> void:
		if not tutorial_complete:
						return
		if body == player:
						arrow.visible = false
						arrow.target  = null
						if hint_exit.visible:
										_fade_out_hint(hint_exit)
						Global.kelptown_tutorial_state = get_tutorial_state()
						SceneSwitcher.switch_scene(
										"res://Island/islandtutorial.tscn",
										Vector2( 64, -42),
										"fade",
										Vector2.ONE,
										Vector2.ZERO,
										Vector2(1.5, 1.5)
						   )

func _exit_tree() -> void:
		Global.kelptown_tutorial_state = get_tutorial_state()
