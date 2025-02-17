# Root.gd
extends Node2D

@onready var main_camera: Camera2D = $Camera2D
@onready var start_button: Button = $StartButton
@onready var save_menu: Node = $SaveMenu
@onready var character_creator: Node2D = $CharacterCreator
@onready var audio_player: AudioStreamPlayer = $StartButton/StartSound
@onready var delay_timer: Timer = $DelayTimer
# New: Reference to MenuFade's AnimationPlayer
@onready var menu_fade_anim: AnimationPlayer = $MenuFade/AnimationPlayer

# Configuration constants
const CAMERA_MOVE_OFFSET: Vector2 = Vector2(0, -270)
const CAMERA_TWEEN_DURATION: float = 1.5

func _ready() -> void:
	# Signal connections should be set in the editor:
	# - StartButton's "pressed" signal to _on_start_button_pressed
	# - SaveMenu's "show_character_creator" and "hide_character_creator" signals to their handlers
	# - DelayTimer's "timeout" signal to _on_timer_timeout
	pass

func _on_start_button_pressed() -> void:
	# Prevent multiple activations
	start_button.disabled = true

	# Animate camera movement and play the audio
	var target_position: Vector2 = main_camera.position + CAMERA_MOVE_OFFSET
	var tween = create_tween()
	tween.tween_property(main_camera, "position", target_position, CAMERA_TWEEN_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	audio_player.play()
	tween.finished.connect(Callable(self, "_on_tween_completed"))

func _on_tween_completed() -> void:
	# Start the pre-configured Timer node (DelayTimer)
	delay_timer.start()

func _on_timer_timeout() -> void:
	save_menu.animate_header(false)

func _on_show_character_creator(slot_index: int) -> void:
	# Display the Character Creator
	# Play the fade animation on MenuFade
	menu_fade_anim.play("fade")
	await get_tree().create_timer(0.5).timeout
	character_creator.visible = true
	save_menu.visible = false
	# Wait for 0.5 seconds (even though the full animation is 1 second)
	await get_tree().create_timer(0.5).timeout
	
	# Now call animate_header after 0.5 seconds into the fade animation
	character_creator.animate_header(false)
	
	# Hide the Save Menu


func _on_hide_character_creator() -> void:
	# Hide the Character Creator and show the Save Menu
	character_creator.visible = false
	save_menu.visible = true
