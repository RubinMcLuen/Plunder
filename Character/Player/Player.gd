extends CharacterBody2D

@export var speed := 100                # Movement speed in pixels per second
var direction := Vector2.RIGHT          # Default facing direction is right

@export var skin: Sprite2D
@export var hat: Sprite2D
@export var facialhair: Sprite2D
@export var body: Sprite2D
@export var larm: Sprite2D
@export var rarm: Sprite2D
@export var lleg: Sprite2D
@export var rleg: Sprite2D

# We'll store the raw input direction here
var custom_velocity := Vector2.ZERO

# Animation constants
const IDLE_ROW = 0
const WALK_ROW = 2
const FRAMES_PER_ANIMATION = 8

# Keep all sprite parts in a list to simplify setting frames/flip
var sprite_parts: Array[Sprite2D] = []

func _ready():
	# Add all sprite references to a list for easy iteration
	sprite_parts = [skin, hat, facialhair, body, larm, rarm, lleg, rleg]
	play_idle()  # Start with idle animation

func _physics_process(delta: float) -> void:
	handle_player_input()
	update_animation()
	move_character()

func handle_player_input() -> void:
	# Reset each frame to capture new input
	custom_velocity = Vector2.ZERO

	if Input.is_action_pressed("ui_up"):
		custom_velocity.y -= 1
	if Input.is_action_pressed("ui_down"):
		custom_velocity.y += 1
	if Input.is_action_pressed("ui_left"):
		custom_velocity.x -= 1
		direction = Vector2.LEFT
	if Input.is_action_pressed("ui_right"):
		custom_velocity.x += 1
		direction = Vector2.RIGHT

	# Normalize only if there's input, then multiply by speed
	if custom_velocity != Vector2.ZERO:
		custom_velocity = custom_velocity.normalized() * speed

	# Assign to the built-in velocity used by CharacterBody2D
	velocity = custom_velocity

func move_character() -> void:
	# Move the character using Godot's physics
	# (no arguments, since Godot 4 automatically uses 'velocity')
	move_and_slide()

func update_animation() -> void:
	if custom_velocity != Vector2.ZERO:
		animate_walk()
	else:
		play_idle()

func animate_walk() -> void:
	# Determine the current frame based on time
	var frame = int((Time.get_ticks_msec() / 100) % FRAMES_PER_ANIMATION)
	var base_frame = WALK_ROW * FRAMES_PER_ANIMATION
	var current_frame = base_frame + frame
	
	# Flip horizontally if moving left
	var flip_h = (direction == Vector2.LEFT)

	for part in sprite_parts:
		part.flip_h = flip_h
		part.frame = current_frame

func play_idle() -> void:
	# Idle animation: cycle through the idle row frames
	var frame = int((Time.get_ticks_msec() / 100) % FRAMES_PER_ANIMATION)
	var base_frame = IDLE_ROW * FRAMES_PER_ANIMATION
	var current_frame = base_frame + frame

	var flip_h = (direction == Vector2.LEFT)

	for part in sprite_parts:
		part.flip_h = flip_h
		part.frame = current_frame
