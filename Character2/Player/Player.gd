extends CharacterBody2D

# ---------------------------
# Movement and Animation Variables
# ---------------------------
@export var speed := 100    # Movement speed in pixels per second
var direction := Vector2.RIGHT  # Default facing direction is right

# Signals
signal auto_move_completed
signal end_fight            # Emitted when player's health reaches 0

var health: int = 3
var fighting: bool = false
var disable_user_input: bool = false

# Use one AnimatedSprite2D node named "Appearance"
@onready var appearance: AnimatedSprite2D = $Appearance

# Player Name / Customization
var name_input = "name"
@export var customization_only: bool = false

# Movement + Animation variables
var custom_velocity := Vector2.ZERO

# Automatic movement
var auto_move: bool = false
var auto_target_position: Vector2 = Vector2.ZERO

# Drag-to-move Variables
var mouse_move_active: bool = false
const MOUSE_STOP_THRESHOLD := 1.0  # Distance below which velocity = 0

# Animation Override (for slash, hurt, etc.)
var anim_override: bool = false
var anim_override_start_time: int = 0
var anim_override_duration: int = 0
var current_anim: String = "idle"  # "idle", "slash", or "hurt"

# Save/Load
const SAVE_FILE_BASE_PATH = "user://saveslot"
var save_slot: int = -1

# ---------------------------
# _ready & _physics_process
# ---------------------------
func _ready():
	load_customization()
	if customization_only:
		set_physics_process(false)
	else:
		# Start with the idle animation.
		appearance.play("IdleStand")
		set_physics_process(true)

func _physics_process(_delta: float) -> void:
	if customization_only:
		return

	# Disable collisions while auto-moving.
	$CollisionShape2D.disabled = auto_move

	handle_player_input()
	update_animation()
	move_character()

# ---------------------------
# Input and Movement
# ---------------------------
func handle_player_input() -> void:
	if disable_user_input and not auto_move:
		custom_velocity = Vector2.ZERO
		velocity = custom_velocity
		return

	if auto_move:
		var diff = auto_target_position - global_position
		if diff.length() < 1:
			global_position = auto_target_position
			auto_move = false
			custom_velocity = Vector2.ZERO
			velocity = custom_velocity
			emit_signal("auto_move_completed")
		else:
			custom_velocity = diff.normalized() * speed
			velocity = custom_velocity
		return

	if fighting:
		custom_velocity = Vector2.ZERO
		velocity = custom_velocity
		return

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		mouse_move_active = true
	else:
		mouse_move_active = false

	custom_velocity = Vector2.ZERO

	if mouse_move_active:
		var diff_mouse = get_global_mouse_position() - global_position
		if diff_mouse.length() > MOUSE_STOP_THRESHOLD:
			custom_velocity = diff_mouse.normalized() * speed
			direction = (Vector2.LEFT if diff_mouse.x < 0 else Vector2.RIGHT)
		else:
			custom_velocity = Vector2.ZERO
	else:
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

		if custom_velocity != Vector2.ZERO:
			custom_velocity = custom_velocity.normalized() * speed

	velocity = custom_velocity

func move_character() -> void:
	move_and_slide()

func auto_move_to_position(target: Vector2) -> void:
	auto_move = true
	auto_target_position = target

func set_facing_direction(is_left: bool) -> void:
	direction = (Vector2.LEFT if is_left else Vector2.RIGHT)
	appearance.flip_h = is_left

func _unhandled_input(_event: InputEvent) -> void:
	if fighting or auto_move:
		return

# ---------------------------
# Animations
# ---------------------------
func update_animation() -> void:
	if anim_override:
		if current_anim == "slash":
			if appearance.animation != "AttackSlash":
				appearance.play("AttackSlash")
		elif current_anim == "hurt":
			if appearance.animation != "Hurt":
				appearance.play("Hurt")
				
		# Ensure flipping is updated
		appearance.flip_h = (direction == Vector2.LEFT)
		
		if Time.get_ticks_msec() - anim_override_start_time >= anim_override_duration:
			anim_override = false
			current_anim = "idle"
		return

	# Otherwise, choose animation based on state.
	if auto_move or custom_velocity != Vector2.ZERO:
		if appearance.animation != "Walk":
			appearance.play("Walk")
	elif fighting:
		if appearance.animation != "IdleSword":
			appearance.play("IdleSword")
	else:
		if appearance.animation != "IdleStand":
			appearance.play("IdleStand")
	
	# Update the flip based on direction.
	appearance.flip_h = (direction == Vector2.LEFT)


func play_slash_animation() -> void:
	anim_override = true
	anim_override_start_time = Time.get_ticks_msec()
	anim_override_duration = 800  # e.g. 800 ms for AttackSlash animation
	current_anim = "slash"

func play_hurt_animation() -> void:
	anim_override = true
	anim_override_start_time = Time.get_ticks_msec()
	anim_override_duration = 300  # e.g. 300 ms for Hurt animation
	current_anim = "hurt"

func take_damage() -> void:
	play_hurt_animation()
	health -= 1
	print("Player health is now: ", health)
	if health <= 0:
		print("Player health reached 0! Emitting end_fight signal.")
		emit_signal("end_fight")

# ---------------------------
# Customization Loading
# ---------------------------
func load_customization():
	# Load the new CharacterCustomizationResource. Adjust the path as needed.
	var char_res = ResourceLoader.load("res://Character2/Player/PlayerCustomization.tres") as CharacterCustomizationResource
	if char_res:
		var composite_tex: Texture2D = char_res.generate_lookup_texture()
		if composite_tex:
			# Duplicate the material to ensure a unique instance for this node.
			appearance.material = appearance.material.duplicate()
			appearance.material.set_shader_parameter("map_texture", composite_tex)
			print("Assigned composite texture with RID: ", composite_tex.get_rid())
		else:
			push_error("Composite texture is null!")
	else:
		push_error("Failed to load CharacterCustomizationResource.")

# ---------------------------
# Save/Load Functions (if needed)
# ---------------------------
func load_customization_from_save():
	# Update these functions if you're still using old save data.
	pass
