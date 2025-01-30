extends CharacterBody2D

# ---------------------------
# Movement and Animation Variables
# ---------------------------
@export var speed := 100                # Movement speed in pixels per second
var direction := Vector2.RIGHT          # Default facing direction is right

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
@export var name_input: LineEdit  # Assign this in the Godot Editor

# We'll store the raw input direction here
var custom_velocity := Vector2.ZERO

# Animation constants
const IDLE_ROW = 0
const WALK_ROW = 2
const FRAMES_PER_ANIMATION = 8

# Keep all sprite parts in a list to simplify setting frames/flip
var sprite_parts: Array[Sprite2D] = []

# ---------------------------
# Customization Loading Variables
# ---------------------------
# Path to save slots
const SAVE_FILE_BASE_PATH = "user://saveslot"

# Save slot number
var save_slot: int = -1

func _ready():
	# Initialize sprite_parts list for easy iteration
	sprite_parts = [skin, hat, facialhair, body, larm, rarm, lleg, rleg]
	
	# Start with idle animation
	play_idle()
	
	# Load player customization
	load_customization()

func _physics_process(_delta: float) -> void:
	handle_player_input()
	update_animation()
	move_character()

# ---------------------------
# Movement and Animation Functions
# ---------------------------

func handle_player_input() -> void:
	# Reset velocity each frame to capture new input
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

	# Normalize velocity to prevent faster diagonal movement, then multiply by speed
	if custom_velocity != Vector2.ZERO:
		custom_velocity = custom_velocity.normalized() * speed

	# Assign to the built-in velocity used by CharacterBody2D
	velocity = custom_velocity

func move_character() -> void:
	# Move the character using Godot's physics
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

# ---------------------------
# Customization Loading Functions
# ---------------------------

func load_customization():
	# Fetch the save slot number from Global.gd
	save_slot = Global.active_save_slot

	# Validate and load the save slot
	if save_slot >= 0:
		load_character_from_slot(save_slot)
	else:
		print("Invalid save slot number. No data to load.")

func load_character_from_slot(slot_num: int = 0):
	# Construct the file path for the save slot
	var save_file_path = "%s%d.json" % [SAVE_FILE_BASE_PATH, slot_num]

	# Check if the save file exists
	if FileAccess.file_exists(save_file_path):
		var file = FileAccess.open(save_file_path, FileAccess.READ)
		if file:
			var json = JSON.new()
			var parse_result = json.parse(file.get_as_text())
			if parse_result == OK:
				var save_data = json.data
				if save_data.has("character"):
					# Apply character data
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
	# Set the player's name if available
	if "name" in data and name_input:
		name_input.text = data["name"]

	# Apply skin customization
	if "skin" in data and skin:
		load_or_clear(skin, data["skin"])

	# Apply facial hair customization
	if "facialhair" in data and facialhair:
		load_or_clear(facialhair, data["facialhair"])

	# Apply hat customization
	if "hat" in data and hat:
		load_or_clear(hat, data["hat"])

	# Apply top (body and arms) customization
	if "top" in data:
		var top_data = data["top"]
		
		if "body" in top_data and body:
			load_or_clear(body, top_data["body"])
		
		if "leftarm" in top_data and larm:
			load_or_clear(larm, top_data["leftarm"])
		
		if "rightarm" in top_data and rarm:
			load_or_clear(rarm, top_data["rightarm"])

	# Apply bottom (legs) customization
	if "bottom" in data:
		var bottom_data = data["bottom"]
		
		if "leftleg" in bottom_data and lleg:
			load_or_clear(lleg, bottom_data["leftleg"])
		
		if "rightleg" in bottom_data and rleg:
			load_or_clear(rleg, bottom_data["rightleg"])

	# Apply miscellaneous customization (e.g., accessories)
	if "misc" in data:
		# Assuming 'misc' is an accessory attached to the right arm
		# Adjust this as needed based on your game design
		load_or_clear(rarm, data["misc"])

func load_or_clear(node: Sprite2D, path: String):
	"""
	Loads a texture from the given path and assigns it to the node.
	If the path is empty, clears the node's texture.
	"""
	if path == "":
		node.texture = null
	else:
		var texture = load(path)
		if texture:
			node.texture = texture
		else:
			print("Failed to load texture at path:", path)
			node.texture = null
