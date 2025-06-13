extends "res://KelptownInn/KelptownInn.gd"
class_name KelptownInnTutorial

@onready var fade_rect      : ColorRect     = $CanvasLayer/FadeRect
@onready var hint_keys      : RichTextLabel = $CanvasLayer/HintMoveKeys
@onready var hint_mouse     : RichTextLabel = $CanvasLayer/HintMoveMouse
@onready var hint_bartender : RichTextLabel = $CanvasLayer/HintBartender
@onready var hint_hire      : RichTextLabel = $CanvasLayer/HintHireBarnaby
@onready var barnaby        : NPC           = $Barnaby
@onready var arrow          : Sprite2D      = $Arrow

var moved_keys: bool          = false
var moved_mouse: bool         = false
var stage_two_started: bool   = false
var stage_three_started: bool = false
var intro_walk_finished: bool = false
var _orig_speed: float        = 0.0
var tutorial_complete: bool   = false

func _ready() -> void:
	super._ready()

	# make sure we never double-connect
	if bartender.dialogue_requested.is_connected(_on_bartender_dialogue_requested):
		bartender.dialogue_requested.disconnect(_on_bartender_dialogue_requested)
	if bartender.dialogue_requested.is_connected(_on_bartender_dialogue_requested_tutorial):
		bartender.dialogue_requested.disconnect(_on_bartender_dialogue_requested_tutorial)
	bartender.dialogue_requested.connect(_on_bartender_dialogue_requested_tutorial)

	barnaby.npc_hired.connect(_on_barnaby_hired_tutorial)

	fade_rect.modulate.a = 1.0
	arrow.visible       = false
	arrow.target        = null
	hint_bartender.visible = false
	hint_hire.visible      = false
	hint_keys.visible      = false
	hint_mouse.visible     = false

	# fade in
	get_tree().create_tween().tween_property(fade_rect, "modulate:a", 0.0, 2.0)

	# slow intro stroll
	_orig_speed      = player.speed
	player.speed    *= 0.5
	player.connect("auto_move_completed",
		Callable(self, "_on_intro_move_completed"),
		CONNECT_ONE_SHOT)
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

		if not moved_mouse and player.mouse_move_active:
			moved_mouse = true
			hint_mouse.add_theme_color_override("default_color", Color.GREEN)
			_check_movement_complete()

func _check_movement_complete() -> void:
	if moved_keys and moved_mouse and not stage_two_started:
		stage_two_started = true
		await get_tree().create_timer(1.0).timeout
		hint_keys.visible  = false
		hint_mouse.visible = false

		arrow.target   = bartender
		arrow.visible  = true
		hint_bartender.visible = true

func _on_intro_move_completed() -> void:
	player.speed = _orig_speed
	hint_keys.visible  = true
	hint_mouse.visible = true
	intro_walk_finished = true

func _on_bartender_dialogue_requested_tutorial(section: String) -> void:
	arrow.visible  = false
	arrow.target   = null
	hint_bartender.add_theme_color_override("default_color", Color.GREEN)
	player.disable_user_input = true

	var balloon := DialogueManager.show_dialogue_balloon(
		bartender_dialogue_resource, section, [bartender])
	balloon.connect("dialogue_finished",
		Callable(self, "_on_dialogue_finished_tutorial"))

func _on_dialogue_finished_tutorial() -> void:
        hint_bartender.visible = false
        # Prevent the click that closed the balloon from immediately
        # reopening the dialogue by waiting a short moment.
        await get_tree().create_timer(0.1).timeout
        player.disable_user_input = false
        stage_three_started       = true

	arrow.target  = barnaby
	arrow.visible = true
	hint_hire.visible = true

func _on_barnaby_hired_tutorial(_b: NPC) -> void:
	hint_hire.add_theme_color_override("default_color", Color.GREEN)
	await get_tree().create_timer(1.0).timeout
	hint_hire.visible  = false
	arrow.visible      = false
	arrow.target       = null
	tutorial_complete  = true

func _on_exit_body_entered(body: Node) -> void:
	if not tutorial_complete:
		return
	super._on_exit_body_entered(body)
