extends CharacterBody2D
class_name NPC

@export var npc_name: String  # Used to look up the NPC's data in the JSON file
const NPC_DATA_PATH := "res://npcs.json"  # Adjust as needed
@export var player_direction: bool = true

# When customization_only is true, no animations will be updated.
@export var customization_only: bool = false
# When fightable is true, the fight scene will be initiated after dialogue.
@export var fightable: bool = false

var dialogue_resource

# ---------------------------
# Animation and Fighting Variables
# ---------------------------
var fighting: bool = false
var direction: Vector2 = Vector2.RIGHT
const FRAMES_PER_ANIMATION = 8

# For randomized idle (if needed)
var idle_offset: int = 0
var idle_start_time: int = 0

signal end_fight   # Emitted when NPC health reaches 0
@export var health: int = 3

# Animation Override Variables
var anim_override: bool = false
var anim_override_start_time: int = 0
var anim_override_duration: int = 0
var current_anim: String = "idle"   # "idle", "slash", or "hurt"

# Flag to continuously play sword idle animation
var idle_with_sword: bool = false
func set_idle_with_sword_mode(enabled: bool) -> void:
	idle_with_sword = enabled

@export var npc_texture_index: int = 0  # Column index for the preset NPC map texture.

# ---------------------------
# Movement and Auto-Move Variables
# ---------------------------
@export var speed: float = 100
var auto_move: bool = false
var auto_target_position: Vector2 = Vector2.ZERO
signal npc_move_completed

# Matching player's input variables
var disable_user_input: bool = false
var custom_velocity: Vector2 = Vector2.ZERO

# ---------------------------
# Appearance Node
# ---------------------------
# We now use one AnimatedSprite2D node named "Appearance".
@onready var appearance: AnimatedSprite2D = $Appearance

# ---------------------------
# Helper Functions (for loading NPC data)
# ---------------------------
func safe_load(path: String) -> Resource:
	if path.strip_edges() == "":
		return null
	return load(path)

# This function loads NPC appearance and dialogue data from a JSON file.
# (In this new system, we assume that the NPC's appearance is represented by a single composite texture
# or a prebuilt AnimatedSprite2D. Adjust this as needed.)
func load_appearance() -> void:
	# Instead of changing the Appearance node's texture, we assign the preset map texture to the shader uniform.
	# Load the preset NPC spritesheet.
	var npc_spritesheet: Texture2D = preload("res://Character2/assets/NPCSprites.png")
	
	# Define the cell size.
	var cell_size: Vector2i = Vector2i(48, 48)
	
	# Create an AtlasTexture that selects the desired cell.
	var atlas_tex := AtlasTexture.new()
	atlas_tex.atlas = npc_spritesheet
	atlas_tex.region = Rect2i(npc_texture_index * cell_size.x, 0, cell_size.x, cell_size.y)
	
	# Duplicate the material on Appearance to ensure a unique instance,
	# then assign the atlas texture to the shader uniform "map_texture".
	appearance.material = appearance.material.duplicate()
	appearance.material.set_shader_parameter("map_texture", atlas_tex)


# ---------------------------
# Animation Functions
# ---------------------------
# These functions use animation names defined in the AnimatedSprite2D's SpriteFrames.

func update_animation() -> void:
	if customization_only:
		# In customization-only mode, always show idle stand.
		if appearance.animation != "IdleStand":
			appearance.play("IdleStand")
		appearance.flip_h = (direction == Vector2.LEFT)
		return

	if anim_override:
		var elapsed = Time.get_ticks_msec() - anim_override_start_time
		if current_anim == "slash":
			if appearance.animation != "AttackSlash":
				appearance.play("AttackSlash")
		elif current_anim == "hurt":
			if appearance.animation != "Hurt":
				appearance.play("Hurt")
		appearance.flip_h = (direction == Vector2.LEFT)
		if elapsed >= anim_override_duration:
			anim_override = false
			current_anim = "idle"
			idle_offset = randi() % FRAMES_PER_ANIMATION
			idle_start_time = Time.get_ticks_msec()
		return

	# Default animation based on movement or fighting state.
	if auto_move or custom_velocity != Vector2.ZERO:
		if appearance.animation != "Walk":
			appearance.play("Walk")
	elif fighting and idle_with_sword:
		if appearance.animation != "IdleSword":
			appearance.play("IdleSword")
	else:
		if appearance.animation != "IdleStand":
			appearance.play("IdleStand")
	appearance.flip_h = (direction == Vector2.LEFT)

func play_slash_animation() -> void:
	anim_override = true
	anim_override_start_time = Time.get_ticks_msec()
	anim_override_duration = 800  # Duration in ms for AttackSlash
	current_anim = "slash"

func play_hurt_animation() -> void:
	anim_override = true
	anim_override_start_time = Time.get_ticks_msec()
	anim_override_duration = 300  # Duration in ms for Hurt
	current_anim = "hurt"

# ---------------------------
# Movement and Input
# ---------------------------
func _physics_process(_delta: float) -> void:
	handle_npc_input()
	update_animation()
	move_and_slide()

func handle_npc_input() -> void:
	if disable_user_input and not auto_move:
		custom_velocity = Vector2.ZERO
		velocity = custom_velocity
		return

	# Auto-movement takes priority.
	if auto_move:
		var diff = auto_target_position - global_position
		if diff.length() < 5.0:
			global_position = auto_target_position
			auto_move = false
			custom_velocity = Vector2.ZERO
			velocity = custom_velocity
			print("NPC finished moving. Emitting npc_move_completed")
			emit_signal("npc_move_completed")
		else:
			custom_velocity = diff.normalized() * speed
			velocity = custom_velocity
			# Update facing direction based on movement.
			direction = (Vector2.LEFT if diff.x < 0 else Vector2.RIGHT)
		return

	# If fighting, no movement.
	if fighting:
		custom_velocity = Vector2.ZERO
		velocity = custom_velocity
		return

	custom_velocity = Vector2.ZERO
	velocity = custom_velocity

func auto_move_to_position(target: Vector2) -> void:
	auto_move = true
	auto_target_position = target

func set_facing_direction(is_left: bool) -> void:
	direction = (Vector2.LEFT if is_left else Vector2.RIGHT)
	appearance.flip_h = is_left

func _on_area_input_event(_viewport, _event, _shape_idx) -> void:
	# Optionally handle input events for the NPC.
	pass

# ---------------------------
# Health and Damage
# ---------------------------
func take_damage() -> void:
	print("NPC was hit!")
	play_hurt_animation()
	health -= 1
	print("NPC health is now: ", health)
	if health <= 0:
		print("NPC health reached 0! Emitting end_fight signal.")
		emit_signal("end_fight")
		play_hurt_animation()

# ---------------------------
# Node Setup & Dialogue
# ---------------------------
func _ready() -> void:
	add_to_group("npc")
	load_appearance()
	$Area2D.connect("input_event", Callable(self, "_on_area_input_event"))
	# Set up initial idle animation and randomization.
	idle_offset = randi() % FRAMES_PER_ANIMATION
	idle_start_time = Time.get_ticks_msec()
	appearance.play("IdleStand")
