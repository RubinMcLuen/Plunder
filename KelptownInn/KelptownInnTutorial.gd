extends "res://KelptownInn/KelptownInn.gd"
class_name KelptownInnTutorial

@onready var fade_rect: ColorRect = $CanvasLayer/FadeRect
@onready var hint_keys: RichTextLabel = $CanvasLayer/HintMoveKeys
@onready var hint_mouse: RichTextLabel = $CanvasLayer/HintMoveMouse
@onready var hint_bartender: RichTextLabel = $CanvasLayer/HintBartender
@onready var arrow: Sprite2D = $Arrow

var moved_keys: bool = false
var moved_mouse: bool = false
var stage_two_started: bool = false

func _ready() -> void:
    super._ready()
    fade_rect.modulate.a = 1.0
    arrow.visible = false
    hint_bartender.visible = false
    hint_keys.visible = true
    hint_mouse.visible = true
    # Start player slightly up the stairs
    player.position += Vector2(0, -100)
    # Fade in
    var tween = get_tree().create_tween()
    tween.tween_property(fade_rect, "modulate:a", 0.0, 1.0)
    player.auto_move_to_position(player.position + Vector2(0, 100))


func _process(_delta: float) -> void:
    if not moved_keys and (
            Input.is_action_pressed("ui_up") or
            Input.is_action_pressed("ui_down") or
            Input.is_action_pressed("ui_left") or
            Input.is_action_pressed("ui_right")):
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
        hint_keys.visible = false
        hint_mouse.visible = false
        arrow.visible = true
        hint_bartender.visible = true

func _on_bartender_dialogue_requested(section: String) -> void:
    arrow.visible = false
    hint_bartender.add_theme_color_override("default_color", Color.GREEN)
    player.disable_user_input = true
    var balloon = DialogueManager.show_dialogue_balloon(
        bartender_dialogue_resource, section, [bartender]
    )
    balloon.connect("dialogue_finished", Callable(self, "_on_dialogue_finished_tutorial"))

func _on_dialogue_finished_tutorial() -> void:
    hint_bartender.visible = false
    player.disable_user_input = false
