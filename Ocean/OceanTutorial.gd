extends "res://Ocean/Ocean.gd"

@onready var hint_label: RichTextLabel = $CanvasLayer/HintLabel
@onready var player_ship: Node = $PlayerShip

var step: int = 0
var left_done: bool = false
var right_done: bool = false
var shoot_left_done: bool = false
var shoot_right_done: bool = false

func _ready() -> void:
    await super._ready()
    if player_ship.has_signal("player_docked"):
        player_ship.connect("player_docked", _on_player_docked)
    _show_step_text()

func _process(_delta: float) -> void:
    match step:
        0:
            if Input.is_action_just_pressed("ui_select"):
                step = 1
                _show_step_text()
        1:
            if Input.is_action_just_pressed("ui_select"):
                step = 2
                _show_step_text()
        2:
            if Input.is_action_just_pressed("ui_left"):
                left_done = true
            if Input.is_action_just_pressed("ui_right"):
                right_done = true
            if left_done and right_done:
                step = 3
                _show_step_text()
        3:
            if Input.is_action_just_pressed("shoot_left"):
                shoot_left_done = true
            if Input.is_action_just_pressed("shoot_right"):
                shoot_right_done = true
            if shoot_left_done and shoot_right_done:
                step = 4
                _show_step_text()
        4:
            pass
        5:
            pass

func _on_player_docked() -> void:
    if step == 4:
        step = 5
        _show_step_text()

func _show_step_text() -> void:
    var text := ""
    match step:
        0:
            text = "Press spacebar to start the ship"
        1:
            text = "Press spacebar while moving to anchor the ship"
        2:
            text = "Press A or Left Arrow to turn to port\nPress D or Right Arrow to turn starboard"
        3:
            text = "Press K to shoot port side\nPress L to shoot starboard side"
        4:
            text = "Click on the island to automatically dock your ship"
        5:
            text = "Tutorial complete!"
    hint_label.text = text
