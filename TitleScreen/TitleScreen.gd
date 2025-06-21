# TitleScreen.gd  — Godot 4.22
extends Node2D
class_name TitleScreen

@onready var cam:           Camera2D           = $Camera2D
@onready var btn_start:     Button             = $StartButton
@onready var menu_save:     SaveMenu           = $SaveMenu      # <-- cast to SaveMenu
@onready var creator:       Node2D             = $CharacterCreator
@onready var sfx_start:     AudioStreamPlayer  = $StartButton/StartSound
@onready var timer_delay:   Timer              = $DelayTimer
@onready var fade_anim:     AnimationPlayer    = $MenuFade/AnimationPlayer

const CAMERA_OFFSET  := Vector2(0, -270)
const CAMERA_TWEEN_S := 1.5

func _ready() -> void:
	btn_start.pressed.connect(_on_start_pressed)
	timer_delay.timeout.connect(_on_delay_timeout)
	menu_save.show_character_creator.connect(_on_show_creator)
	menu_save.hide_character_creator.connect(_on_hide_creator)

func _on_start_pressed() -> void:
	btn_start.disabled = true

	var tw = create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(cam, "position", cam.position + CAMERA_OFFSET, CAMERA_TWEEN_S)

	sfx_start.play()
	await tw.finished
	timer_delay.start()

func _on_delay_timeout() -> void:
	menu_save.animate_header(false)

# Save-slot  →  Character-creator transition
func _on_show_creator(_slot: int) -> void:
	fade_anim.play("fade")                      # starts 0 → 1 → 0 alpha

	# Wait until the animation is halfway (screen fully black)
	var half_time := fade_anim.current_animation_length * 0.5
	await get_tree().create_timer(half_time).timeout

	menu_save.visible = false                   # hide old UI while screen is black
       creator.visible   = true                    # show new UI
       creator.animate_header(true)

	await fade_anim.animation_finished          # let fade back to transparent finish


func _on_hide_creator() -> void:
               creator.animate_header(false)
		creator.visible = false
		menu_save.visible = true
		menu_save.animate_header(true)
		fade_anim.play_backwards("fade")
