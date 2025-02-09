extends CharacterBody2D

# ---------------------------
# Movement and Animation Variables
# ---------------------------
@export var speed := 100                # Movement speed in pixels per second
var direction := Vector2.RIGHT          # Default facing direction is right
signal auto_move_completed
var fighting: bool = false

# Exported Sprite References for Customization
@export var skin: Sprite2D
@export var hat: Sprite2D
@export var facialhair: Sprite2D
@export var body: Sprite2D
@export var larm: Sprite2D
@export var rarm: Sprite2D
@export var lleg: Sprite2D
@export var rleg: Sprite2D

# Exported Variable for Player Name Input
var name_input = "name"
@export var customization_only: bool = false

# Raw input velocity
var custom_velocity := Vector2.ZERO

# Animation constants
const IDLE_ROW = 0
const WALK_ROW = 2
const FRAMES_PER_ANIMATION = 8

# All sprite parts in a list
var sprite_parts: Array[Sprite2D] = []

# Automatic movement variables
var auto_move: bool = false
var auto_target_position: Vector2 = Vector2.ZERO

# ---------------------------
# Customization Loading Variables
# ---------------------------
const SAVE_FILE_BASE_PATH = "user://saveslot"
var save_slot: int = -1

var mouse_move_active: bool = false
var mouse_target_position: Vector2 = Vector2.ZERO

# ---------------------------
# ANIMATION OVERRIDE VARIABLES
# ---------------------------
var anim_override: bool = false
var anim_override_start_time: int = 0
var anim_override_duration: int = 0
var current_anim: String = "idle"   # "idle", "slash", or "hurt"

# ---------------------------
# _ready and _physics_process
# ---------------------------
func _ready():
	sprite_parts = [ skin, hat, facialhair, body, larm, rarm, lleg, rleg ]
	load_customization()
	
	if customization_only:
		set_physics_process(false)
	else:
		play_idle()
		set_physics_process(true)

func _physics_process(_delta: float) -> void:
	if customization_only:
		return
	handle_player_input()
	update_animation()
	move_character()

# ---------------------------
# Input and Movement Functions
# ---------------------------
func handle_player_input() -> void:
	# Auto-movement takes priority.
	if auto_move:
		var diff = auto_target_position - global_position
		if diff.length() < 1:
			# Snap to the target position and signal completion.
			global_position = auto_target_position
			auto_move = false
			custom_velocity = Vector2.ZERO
			velocity = custom_velocity
			emit_signal("auto_move_completed")
		else:
			custom_velocity = diff.normalized() * speed
			direction = Vector2.LEFT if diff.x < 0 else Vector2.RIGHT
			velocity = custom_velocity
		return

	# If fighting is active, disable normal user movement.
	if fighting:
		custom_velocity = Vector2.ZERO
		velocity = custom_velocity
		return

	# Mouse input deactivation.
	if mouse_move_active and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		mouse_move_active = false

	# Reset velocity each frame.
	custom_velocity = Vector2.ZERO

	if mouse_move_active:
		var diff_mouse = mouse_target_position - global_position
		if diff_mouse.length() != 0:
			custom_velocity = diff_mouse.normalized() * speed
			direction = Vector2.LEFT if diff_mouse.x < 0 else Vector2.RIGHT
	else:
		# Process keyboard input.
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

func auto_move_to_position(target: Vector2) -> void:
	auto_move = true
	auto_target_position = target

func set_facing_direction(is_left: bool) -> void:
	direction = Vector2.LEFT if is_left else Vector2.RIGHT
	for part in sprite_parts:
		part.flip_h = is_left

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		mouse_move_active = event.pressed
		if mouse_move_active:
			mouse_target_position = get_global_mouse_position()
	elif event is InputEventMouseMotion and mouse_move_active:
		mouse_target_position = get_global_mouse_position()

func move_character() -> void:
	move_and_slide()

# ---------------------------
# Animation Functions
# ---------------------------
func animate_walk() -> void:
	var frame = (Time.get_ticks_msec() / 100) % FRAMES_PER_ANIMATION
	var base_frame = WALK_ROW * FRAMES_PER_ANIMATION
	var current_frame = base_frame + frame
	var flip_h = (direction == Vector2.LEFT)
	for part in sprite_parts:
		part.flip_h = flip_h
		part.frame = current_frame

func play_idle() -> void:
	var frame = (Time.get_ticks_msec() / 100) % FRAMES_PER_ANIMATION
	var base_frame = IDLE_ROW * FRAMES_PER_ANIMATION
	var current_frame = base_frame + frame
	var flip_h = (direction == Vector2.LEFT)
	for part in sprite_parts:
		part.flip_h = flip_h
		part.frame = current_frame

func play_idle_with_sword() -> void:
	var frame = (Time.get_ticks_msec() / 100) % FRAMES_PER_ANIMATION
	var base_frame = 5 * FRAMES_PER_ANIMATION
	var current_frame = base_frame + frame
	var flip_h = (direction == Vector2.LEFT)
	for part in sprite_parts:
		part.flip_h = flip_h
		part.frame = current_frame

# ---------------------------
# OVERRIDE ANIMATION FUNCTIONS
# ---------------------------
func play_slash_animation() -> void:
	# Slash animation: row 4, 8 frames (800ms total)
	anim_override = true
	anim_override_start_time = Time.get_ticks_msec()
	anim_override_duration = 800
	current_anim = "slash"

func play_hurt_animation() -> void:
	# Hurt animation: row 6, 3 frames (300ms total)
	anim_override = true
	anim_override_start_time = Time.get_ticks_msec()
	anim_override_duration = 300
	current_anim = "hurt"

func handle_projectile_hit() -> void:
	print("Player was hit by a projectile!")
	# Additional damage logic here

# ---------------------------
# update_animation
# ---------------------------
func update_animation() -> void:
	if anim_override:
		var elapsed = Time.get_ticks_msec() - anim_override_start_time
		if current_anim == "slash":
			var frame_index = min(int(elapsed / 100), 7)  # 8 frames: indices 0-7
			var base_frame = 4 * FRAMES_PER_ANIMATION
			var current_frame = base_frame + frame_index
			var flip_h = (direction == Vector2.LEFT)
			for part in sprite_parts:
				part.flip_h = flip_h
				part.frame = current_frame
		elif current_anim == "hurt":
			var frame_index = min(int(elapsed / 100), 2)  # 3 frames: indices 0-2
			var base_frame = 6 * FRAMES_PER_ANIMATION
			var current_frame = base_frame + frame_index
			var flip_h = (direction == Vector2.LEFT)
			for part in sprite_parts:
				part.flip_h = flip_h
				part.frame = current_frame

		if elapsed >= anim_override_duration:
			anim_override = false
			current_anim = "idle"
	else:
		# When auto-moving, always show the walking animation even if fighting is enabled.
		if auto_move:
			animate_walk()
		elif fighting:
			play_idle_with_sword()
		elif custom_velocity != Vector2.ZERO:
			animate_walk()
		else:
			play_idle()

# ---------------------------
# Customization Loading Functions
# ---------------------------
func load_customization():
	save_slot = Global.active_save_slot
	if save_slot >= 0:
		load_character_from_slot(save_slot)
	else:
		print("Invalid save slot number. No data to load.")

func load_character_from_slot(slot_num: int = 0):
	var save_file_path = "%s%d.json" % [SAVE_FILE_BASE_PATH, slot_num]
	if FileAccess.file_exists(save_file_path):
		var file = FileAccess.open(save_file_path, FileAccess.READ)
		if file:
			var json = JSON.new()
			var parse_result = json.parse(file.get_as_text())
			if parse_result == OK:
				var save_data = json.data
				if save_data.has("character"):
					apply_character_data(save_data["character"])
				else:
					print("No 'character' key found in save file.")
			else:
				print("Failed to parse save file. Error:", json.error_message())
			file.close()
		else:
			print("Failed to open save file.")
	else:
		print("Save slot does not exist:", slot_num)

func apply_character_data(data: Dictionary):
	if "name" in data and name_input:
		name_input = data["name"]
	if "skin" in data and skin:
		load_or_clear(skin, data["skin"])
	if "facialhair" in data and facialhair:
		load_or_clear(facialhair, data["facialhair"])
	if "hat" in data and hat:
		load_or_clear(hat, data["hat"])
	if "top" in data:
		var top_data = data["top"]
		if "body" in top_data and body:
			load_or_clear(body, top_data["body"])
		if "leftarm" in top_data and larm:
			load_or_clear(larm, top_data["leftarm"])
		if "rightarm" in top_data and rarm:
			load_or_clear(rarm, top_data["rightarm"])
	if "bottom" in data:
		var bottom_data = data["bottom"]
		if "leftleg" in bottom_data and lleg:
			load_or_clear(lleg, bottom_data["leftleg"])
		if "rightleg" in bottom_data and rleg:
			load_or_clear(rleg, bottom_data["rightleg"])
	if "misc" in data:
		# Assuming misc customization is applied to the right arm.
		if data["misc"] != "":
			load_or_clear(rarm, data["misc"])

func load_or_clear(node: Sprite2D, path: String):
	if path == "":
		node.texture = null
	else:
		var texture = load(path)
		if texture:
			node.texture = texture
		else:
			print("Failed to load texture at path:", path)
			node.texture = null
