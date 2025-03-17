extends CharacterBody2D
class_name NPC

@export var npc_name: String  # Used to look up the NPC's data in the JSON file
const NPC_DATA_PATH := "res://npcs.json"  # Adjust as needed
@export var fight_side_right: bool = false
@export var stats: CharacterStats

@export var customization_only: bool = false
@export var fightable: bool = false

@export var dialogue_resource: DialogueResource

# ---------------------------
# Animation and Fighting Variables
# ---------------------------
var fighting: bool = false
var direction: Vector2 = Vector2.RIGHT
const FRAMES_PER_ANIMATION = 8

var idle_offset: int = 0
var idle_start_time: int = 0

signal end_fight  # Emitted when NPC health reaches 0
@export var health: int = 3

var anim_override: bool = false
var anim_override_start_time: int = 0
var anim_override_duration: int = 0
# current_anim can be "idle", "slash", "hurt", "lunge", or "block"
var current_anim: String = "idle"

# When fighting, use idle sword.
var idle_with_sword: bool = false
func set_idle_with_sword_mode(enabled: bool) -> void:
	idle_with_sword = enabled
	sword.visible = enabled

@export var npc_texture_index: int = 0  # Column index for the preset NPC map texture.

# ---------------------------
# Movement and Auto-Move Variables
# ---------------------------
@export var speed: float = 100
var auto_move: bool = false
var auto_target_position: Vector2 = Vector2.ZERO
signal npc_move_completed

var disable_user_input: bool = false
var custom_velocity: Vector2 = Vector2.ZERO

# ---------------------------
# Appearance Node
# ---------------------------
@onready var appearance: AnimatedSprite2D = $Appearance
@onready var sword: AnimatedSprite2D = $Appearance/Sword

# ---------------------------
# Helper Functions
# ---------------------------
func safe_load(path: String) -> Resource:
	if path.strip_edges() == "":
		return null
	return load(path)

func load_appearance() -> void:
	var npc_spritesheet: Texture2D = preload("res://Character/assets/NPCSprites.png")
	var cell_size: Vector2i = Vector2i(48, 48)
	var region_pos := Vector2i(npc_texture_index * cell_size.x, 0)
	var region_rect := Rect2i(region_pos, cell_size)
	var full_image := npc_spritesheet.get_image()
	var sub_image := Image.create(cell_size.x, cell_size.y, false, full_image.get_format())
	sub_image.blit_rect(full_image, region_rect, Vector2i(0, 0))
	var sub_tex := ImageTexture.create_from_image(sub_image)
	if appearance.material:
		appearance.material = appearance.material.duplicate()
		appearance.material.set_shader_parameter("map_texture", sub_tex)
	else:
		print("Appearance material is null!")

# ---------------------------
# Animation Functions
# ---------------------------
func update_animation() -> void:
	if customization_only:
		if appearance.animation != "IdleStand":
			appearance.play("IdleStand")
		appearance.frame = 0
		appearance.flip_h = (direction == Vector2.LEFT)
		sword.flip_h = (direction == Vector2.LEFT)
		return

	if anim_override:
		match current_anim:
			"slash":
				if appearance.animation != "AttackSlash":
					appearance.play("AttackSlash")
					sword.play("AttackSlash")
			"hurt":
				if appearance.animation != "Hurt":
					appearance.play("Hurt")
			"lunge":
				if appearance.animation != "AttackLunge":
					appearance.play("AttackLunge")
					sword.play("AttackLunge")
			"block":
				if appearance.animation != "AttackBlock":
					appearance.play("AttackBlock")
					sword.play("AttackBlock")
		appearance.flip_h = (direction == Vector2.LEFT)
		if Time.get_ticks_msec() - anim_override_start_time >= anim_override_duration:
			anim_override = false
			current_anim = "idle"
			idle_offset = randi() % FRAMES_PER_ANIMATION
			idle_start_time = Time.get_ticks_msec()
		return

	if auto_move or custom_velocity != Vector2.ZERO:
		if appearance.animation != "Walk":
			appearance.play("Walk")
	elif fighting and idle_with_sword:
		if appearance.animation != "IdleSword":
			appearance.play("IdleSword")
			sword.play("IdleSword")
	else:
		if appearance.animation != "IdleStand":
			appearance.play("IdleStand")
	appearance.flip_h = (direction == Vector2.LEFT)

func play_slash_animation() -> void:
	anim_override = true
	anim_override_start_time = Time.get_ticks_msec()
	anim_override_duration = 800  # Duration in ms for AttackSlash
	current_anim = "slash"
	appearance.stop()
	sword.stop()
	appearance.play("AttackSlash")
	sword.play("AttackSlash")

func play_lunge_animation() -> void:
	anim_override = true
	anim_override_start_time = Time.get_ticks_msec()
	anim_override_duration = 800  # Duration in ms for AttackLunge
	current_anim = "lunge"
	appearance.stop()
	sword.stop()
	appearance.play("AttackLunge")
	sword.play("AttackLunge")

func play_block_animation() -> void:
	anim_override = true
	anim_override_start_time = Time.get_ticks_msec()
	anim_override_duration = 800  # Duration in ms for AttackBlock
	current_anim = "block"
	appearance.stop()
	sword.stop()
	appearance.play("AttackBlock")
	sword.play("AttackBlock")

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

	if auto_move:
		var diff = auto_target_position - global_position
		if diff.length() < 5.0:
			global_position = auto_target_position
			auto_move = false
			custom_velocity = Vector2.ZERO
			velocity = custom_velocity
			# Final facing: always face left for the enemy.
			set_facing_direction(true)
			print("NPC finished moving. Emitting npc_move_completed")
			emit_signal("npc_move_completed")
		else:
			custom_velocity = diff.normalized() * speed
			velocity = custom_velocity
			set_facing_direction(diff.x < 0)
		return

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
	direction = Vector2.LEFT if is_left else Vector2.RIGHT
	appearance.flip_h = is_left
	sword.flip_h = is_left

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
	idle_offset = randi() % FRAMES_PER_ANIMATION
	idle_start_time = Time.get_ticks_msec()
	appearance.play("IdleStand")

func show_dialogue(dialogue_key: String) -> Node:
	if dialogue_resource == null:
		push_error("Dialogue resource not loaded for NPC " + npc_name)
		return null
	var balloon = DialogueManager.show_dialogue_balloon(dialogue_resource, dialogue_key, [self])
	return balloon
