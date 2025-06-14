extends "res://KelptownInn/KelptownInn.gd"
class_name KelptownInnTutorial

@onready var fade_rect      : ColorRect     = $CanvasLayer/FadeRect
@onready var hint_keys      : RichTextLabel = $CanvasLayer/HintMoveKeys
@onready var hint_mouse     : RichTextLabel = $CanvasLayer/HintMoveMouse
@onready var hint_bartender : RichTextLabel = $CanvasLayer/HintBartender
@onready var hint_hire      : RichTextLabel = $CanvasLayer/HintHireBarnaby
@onready var barnaby        : NPC           = $Barnaby
@onready var arrow          : Sprite2D      = $Arrow

var moved_keys: bool = false
var moved_mouse: bool = false
var stage_two_started: bool = false
var stage_three_started: bool = false
var intro_walk_finished: bool = false
var _orig_speed: float = 0.0
var tutorial_complete: bool = false

func get_tutorial_state() -> Dictionary:
        var target := ""
        if arrow.target == bartender:
                target = "bartender"
        elif arrow.target == barnaby:
                target = "barnaby"

        return {
                "moved_keys": moved_keys,
                "moved_mouse": moved_mouse,
                "stage_two_started": stage_two_started,
                "stage_three_started": stage_three_started,
                "intro_walk_finished": intro_walk_finished,
                "orig_speed": _orig_speed,
                "player_speed": player.speed,
                "player_auto_move": player.auto_move,
                "player_auto_target": player.auto_target_position,
                "tutorial_complete": tutorial_complete,
                "bartender_state": bartender.state,
                "barnaby_state": barnaby.state,
                "barnaby_hired": barnaby.hired,
                "barnaby_pos": barnaby.global_position,
                "barnaby_auto_move": barnaby.auto_move,
                "barnaby_auto_target": barnaby.auto_target_position,
                "arrow_visible": arrow.visible,
                "arrow_target": target,
                "fade_alpha": fade_rect.modulate.a,
                "hint_keys": {"visible": hint_keys.visible,
                               "color": hint_keys.get_theme_color("default_color")},
                "hint_mouse": {"visible": hint_mouse.visible,
                                "color": hint_mouse.get_theme_color("default_color")},
                "hint_bartender": {"visible": hint_bartender.visible,
                                    "color": hint_bartender.get_theme_color("default_color")},
                "hint_hire": {"visible": hint_hire.visible,
                               "color": hint_hire.get_theme_color("default_color")},
        }

func apply_tutorial_state(state: Dictionary) -> void:
        moved_keys = state.get("moved_keys", false)
        moved_mouse = state.get("moved_mouse", false)
        stage_two_started = state.get("stage_two_started", false)
        stage_three_started = state.get("stage_three_started", false)
        intro_walk_finished = state.get("intro_walk_finished", false)
        _orig_speed = state.get("orig_speed", player.speed)
        player.speed = state.get("player_speed", player.speed)
        if state.get("player_auto_move", false):
                player.connect("auto_move_completed", Callable(self, "_on_intro_move_completed"), CONNECT_ONE_SHOT)
                player.auto_target_position = state.get("player_auto_target", player.auto_target_position)
                player.auto_move = true

        tutorial_complete = state.get("tutorial_complete", false)

        bartender.state = state.get("bartender_state", bartender.state)

        barnaby.state = state.get("barnaby_state", barnaby.state)
        barnaby.hired = state.get("barnaby_hired", barnaby.hired)
        barnaby.global_position = state.get("barnaby_pos", barnaby.global_position)
        barnaby.auto_move = state.get("barnaby_auto_move", false)
        barnaby.auto_target_position = state.get("barnaby_auto_target", barnaby.auto_target_position)

        var target_str = state.get("arrow_target", "")
        match target_str:
                "bartender":
                        arrow.target = bartender
                "barnaby":
                        arrow.target = barnaby
                _:
                        arrow.target = null
        arrow.visible = state.get("arrow_visible", false)
        if arrow.target:
                arrow.global_position = arrow.target.global_position + Vector2(arrow.x_offset, arrow.y_offset)

        fade_rect.modulate.a = state.get("fade_alpha", fade_rect.modulate.a)

        var hk = state.get("hint_keys", {})
        hint_keys.visible = hk.get("visible", false)
        hint_keys.add_theme_color_override("default_color", hk.get("color", hint_keys.get_theme_color("default_color")))

        var hm = state.get("hint_mouse", {})
        hint_mouse.visible = hm.get("visible", false)
        hint_mouse.add_theme_color_override("default_color", hm.get("color", hint_mouse.get_theme_color("default_color")))

        var hb = state.get("hint_bartender", {})
        hint_bartender.visible = hb.get("visible", false)
        hint_bartender.add_theme_color_override("default_color", hb.get("color", hint_bartender.get_theme_color("default_color")))

        var hh = state.get("hint_hire", {})
        hint_hire.visible = hh.get("visible", false)
        hint_hire.add_theme_color_override("default_color", hh.get("color", hint_hire.get_theme_color("default_color")))

func _ready() -> void:
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
	hint_keys.visible          = false
	hint_mouse.visible         = false
	hint_keys.modulate.a       = 0.0
	hint_mouse.modulate.a      = 0.0
	hint_bartender.modulate.a  = 0.0
        hint_hire.modulate.a       = 0.0

        # fade in
        get_tree().create_tween().tween_property(fade_rect, "modulate:a", 0.0, 2.0)

	# slow intro stroll
	_orig_speed = player.speed
	player.speed *= 0.5
        player.connect(
                "auto_move_completed",
                Callable(self, "_on_intro_move_completed"),
                CONNECT_ONE_SHOT
        )
        player.auto_move_to_position(Vector2(382, 88))

        if Global.kelptown_tutorial_state and Global.kelptown_tutorial_state.size() > 0:
                apply_tutorial_state(Global.kelptown_tutorial_state)
                Global.kelptown_tutorial_state = {}

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

		if not moved_mouse and player.mouse_move_active:
			moved_mouse = true
			hint_mouse.add_theme_color_override("default_color", Color.GREEN)
			_check_movement_complete()

func _check_movement_complete() -> void:
	if moved_keys and moved_mouse and not stage_two_started:
		stage_two_started = true
		await get_tree().create_timer(1.0).timeout
		_fade_out_hint(hint_keys)
		_fade_out_hint(hint_mouse)
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
	_fade_in_hint(hint_mouse)
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
        var balloon := DialogueManager.show_dialogue_balloon(
                bartender_dialogue_resource, section, [bartender]
        )
        balloon.connect(
                "dialogue_finished",
                Callable(self, "_on_dialogue_finished_tutorial")
        )

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

func _on_exit_body_entered(body: Node) -> void:
	if not tutorial_complete:
		return
	super._on_exit_body_entered(body)
