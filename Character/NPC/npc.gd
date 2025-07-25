# NPC.gd ─ Full script
extends CharacterBody2D
class_name NPC

# ─────────────────────────────────────────────
# Metadata & Exports
# ─────────────────────────────────────────────
@export var npc_name: String
const NPC_DATA_PATH := "res://NPCs.json"

@export var fight_side_right : bool = false
@export var stats            : CharacterStats
@export var customization_only: bool = false
@export var fightable        : bool = false
@export var dialogue_resource: DialogueResource
@export var npc_texture_index: int  = 0
@export var health           : int  = 3
@export var speed            : float= 100.0

# Crew-hiring
@export var hirable: bool = false
var hired: bool = false
signal npc_hired(npc: NPC)

# ─────────────────────────────────────────────
# State vars
# ─────────────────────────────────────────────
var fighting: bool = false
var idle_with_sword: bool = false
var direction: Vector2 = Vector2.RIGHT

const FRAMES_PER_ANIMATION = 8
var idle_offset    : int = 0
var idle_start_time: int = 0

signal end_fight
signal npc_move_completed

# Animation override (slash / lunge / hurt)
var anim_override           : bool = false
var anim_override_start_time: int  = 0
var anim_override_duration  : int  = 0
var current_anim            : String = "idle"

# Sound effects
const STEP_SOUNDS = [
		preload("res://SFX/stepwood_1.wav"),
		preload("res://SFX/stepwood_2.wav")
]
const SWORD_SOUNDS = [
				preload("res://SFX/sword_clash.1.ogg"),
				preload("res://SFX/sword_clash.2.ogg"),
				preload("res://SFX/sword_clash.3.ogg"),
				preload("res://SFX/sword_clash.4.ogg"),
				preload("res://SFX/sword_clash.5.ogg"),
				preload("res://SFX/sword_clash.6.ogg"),
				preload("res://SFX/sword_clash.7.ogg"),
				preload("res://SFX/sword_clash.8.ogg"),
				preload("res://SFX/sword_clash.9.ogg"),
				preload("res://SFX/sword_clash.10.ogg")
]
const GRUNT_SOUNDS = [
				preload("res://SFX/Grunt1.wav"),
				preload("res://SFX/Grunt2.wav"),
				preload("res://SFX/Grunt3.wav")
]
var _step_index: int = 0

# Cool-down timer (for subclasses)
var cooldown_lock: float = 0.0

# ─────────────────────────────────────────────
# Movement helpers
# ─────────────────────────────────────────────
var auto_move            : bool   = false
var auto_target_position : Vector2 = Vector2.ZERO
var disable_user_input   : bool   = false
var custom_velocity      : Vector2 = Vector2.ZERO  # the velocity you decide each frame

# ─────────────────────────────────────────────
# Child nodes
# ─────────────────────────────────────────────
@onready var appearance : AnimatedSprite2D = $Appearance
@onready var sword      : AnimatedSprite2D = $Appearance.get_node_or_null("Sword")
@onready var area2d     : Area2D           = $Area2D

var body_mat: ShaderMaterial
var hurt_tmr: Timer

# ─────────────────────────────────────────────
# _ready()
# ─────────────────────────────────────────────
func _ready() -> void:
		randomize()
		add_to_group("npc")
		_init_palette()
		_init_hurt_timer()
		appearance.frame_changed.connect(_on_frame_changed)

		idle_offset     = randi() % FRAMES_PER_ANIMATION
		idle_start_time = Time.get_ticks_msec()

		appearance.play("IdleStand")
		appearance.frame = randi() % appearance.sprite_frames.get_frame_count("IdleStand")

		if sword:
			sword.play("IdleSword")
			sword.frame = appearance.frame % sword.sprite_frames.get_frame_count("IdleSword")
			sword.visible = idle_with_sword

		area2d.connect("input_event", Callable(self, "_on_area_input_event"))

# ─────────────────────────────────────────────
# Palette (per-NPC colour map)
# ─────────────────────────────────────────────
func _init_palette() -> void:
	var sheet: Texture2D = preload("res://Character/assets/NPCSprites.png")
	var cell := Vector2i(48,48)
	var rect := Rect2i(Vector2i(npc_texture_index * cell.x, 0), cell)
	var img  : Image = sheet.get_image()
	var sub  : Image = Image.create(cell.x, cell.y, false, img.get_format())
	sub.blit_rect(img, rect, Vector2.ZERO)
	var tex  := ImageTexture.create_from_image(sub)

	body_mat = appearance.material.duplicate()
	body_mat.set_shader_parameter("map_texture", tex)
	body_mat.set_shader_parameter("hurt_mode", false)
	appearance.material = body_mat

# ─────────────────────────────────────────────
# Hurt-flash shader timer
# ─────────────────────────────────────────────
func _init_hurt_timer() -> void:
		hurt_tmr = Timer.new()
		hurt_tmr.one_shot = true
		hurt_tmr.wait_time = 0.25
		add_child(hurt_tmr)
		hurt_tmr.timeout.connect(_on_hurt_timeout)

func _flash_red() -> void:
	body_mat.set_shader_parameter("hurt_mode", true)
	hurt_tmr.start()

func _on_hurt_timeout() -> void:
		body_mat.set_shader_parameter("hurt_mode", false)

func _on_frame_changed() -> void:
		if appearance.animation == "Walk" and (appearance.frame == 0 or appearance.frame == 4):
				_play_step_sound()

func _play_step_sound() -> void:
				var snd = STEP_SOUNDS[_step_index % STEP_SOUNDS.size()]
				_step_index = (_step_index + 1) % STEP_SOUNDS.size()
				var p = AudioStreamPlayer2D.new()
				p.stream = snd
				p.pitch_scale = randf_range(0.9, 1.1)
				add_child(p)
				p.play()
				var t = Timer.new()
				t.one_shot = true
				t.wait_time = snd.get_length()
				p.add_child(t)
				t.timeout.connect(p.queue_free)
				t.start()

func _play_sword_sound() -> void:
				var snd = SWORD_SOUNDS[randi() % SWORD_SOUNDS.size()]
				var p = AudioStreamPlayer2D.new()
				p.stream = snd
				add_child(p)
				p.play()
				var t = Timer.new()
				t.one_shot = true
				t.wait_time = snd.get_length()
				p.add_child(t)
				t.timeout.connect(p.queue_free)
				t.start()

func _play_grunt_sound() -> void:
				var snd = GRUNT_SOUNDS[randi() % GRUNT_SOUNDS.size()]
				var p = AudioStreamPlayer2D.new()
				p.stream = snd
				add_child(p)
				p.play()
				var t = Timer.new()
				t.one_shot = true
				t.wait_time = snd.get_length()
				p.add_child(t)
				t.timeout.connect(p.queue_free)
				t.start()

# ─────────────────────────────────────────────
# Damage + death
# ─────────────────────────────────────────────
func take_damage(amount: int = 1) -> void:
	if health <= 0: return
	health -= amount
	_flash_red()
	if health <= 0:
		emit_signal("end_fight")
		queue_free()

# ─────────────────────────────────────────────
# Crew-hiring
# ─────────────────────────────────────────────
func hire() -> void:
	if hired: return
	hired = true
	Global.add_crew(npc_name)
	emit_signal("npc_hired", self)

# ─────────────────────────────────────────────
# Physics
# ─────────────────────────────────────────────
func _physics_process(_delta: float) -> void:
	handle_npc_input()
	move_and_slide()           # we don't capture the return; we maintain velocity ourselves
	_update_base_anim(false)   # pick an animation AFTER we moved

# ─────────────────────────────────────────────
# Input → velocity
# ─────────────────────────────────────────────
func handle_npc_input() -> void:
	if disable_user_input and not auto_move:
		custom_velocity = Vector2.ZERO
		velocity        = custom_velocity
		return

	if auto_move:
		var diff := auto_target_position - global_position
		if diff.length() < 5.0:
			global_position = auto_target_position
			auto_move       = false
			custom_velocity = Vector2.ZERO
			velocity        = custom_velocity
			set_facing_direction(not fight_side_right)
			emit_signal("npc_move_completed")
		else:
			custom_velocity = diff.normalized() * speed
			velocity        = custom_velocity
			set_facing_direction(diff.x < 0)
		return

	if fighting:
		custom_velocity = Vector2.ZERO
		velocity        = custom_velocity
		return

	custom_velocity = Vector2.ZERO
	velocity        = custom_velocity

# Helper for scripted moves
func auto_move_to_position(target: Vector2) -> void:
	auto_move            = true
	auto_target_position = target

# Facing (sprite flip)
func set_facing_direction(is_left: bool) -> void:
	direction         = Vector2.LEFT if is_left else Vector2.RIGHT
	appearance.flip_h = is_left
	if sword: sword.flip_h = is_left

# ─────────────────────────────────────────────
# Animation dispatcher
# ─────────────────────────────────────────────
func _update_base_anim(_unused: bool) -> void:
	update_animation()

func update_animation() -> void:
	# 1) Customisation mode: always IdleStand
	if customization_only:
		if appearance.animation != "IdleStand":
			appearance.play("IdleStand")
		appearance.frame = 0
		appearance.flip_h = (direction == Vector2.LEFT)
		return

	# 2) Animation overrides (slash, hurt, block, etc.)
	if anim_override:
		if sword:
			sword.visible = true
		match current_anim:
					"slash":
							if appearance.animation != "AttackSlash" or not appearance.is_playing():
									appearance.play("AttackSlash")
									if sword: sword.play("AttackSlash")
					"lunge":
							if appearance.animation != "AttackLunge" or not appearance.is_playing():
									appearance.play("AttackLunge")
									if sword: sword.play("AttackLunge")
					"block":
							if appearance.animation != "AttackBlock" or not appearance.is_playing():
									appearance.play("AttackBlock")
									if sword: sword.play("AttackBlock")
					"hurt":
							if appearance.animation != "Hurt" or not appearance.is_playing():
									appearance.play("Hurt")
		appearance.flip_h = (direction == Vector2.LEFT)
		if sword: sword.flip_h = (direction == Vector2.LEFT)
		if Time.get_ticks_msec() - anim_override_start_time >= anim_override_duration:
			anim_override = false
		return

	# 3) Movement: walk if auto-moving OR velocity > 0
	var is_moving := auto_move or velocity.length() > 0.1
	if is_moving:
		if appearance.animation != "Walk":
			appearance.play("Walk")
		if sword:
			sword.visible = false
		appearance.flip_h = (direction == Vector2.LEFT)
		return

	# 4) If not moving and NOT fighting → idle (no sword)
	if not fighting:
		if appearance.animation != "IdleStand":
			appearance.play("IdleStand")
		if sword: sword.visible = false
		return

	# 5) Idle with sword drawn
	if idle_with_sword:
		if appearance.animation != "IdleSword":
			appearance.play("IdleSword")
		if sword:
			sword.visible = true
			if sword.animation != "IdleSword":
				sword.play("IdleSword")
			sword.frame       = appearance.frame
			sword.speed_scale = appearance.speed_scale
		appearance.flip_h = (direction == Vector2.LEFT)
		return

	# 6) Fallback idle (fighting but stationary, sword hidden)
	if appearance.animation != "IdleStand":
		appearance.play("IdleStand")
	if sword:
		sword.visible = false
	appearance.flip_h = (direction == Vector2.LEFT)

# ─────────────────────────────────────────────
# Dialogue helpers
# ─────────────────────────────────────────────
func show_dialogue(dialogue_key: String) -> Node:
		if dialogue_resource == null:
				push_error("Dialogue resource not loaded for NPC " + npc_name)
				return null
		_play_grunt_sound()
		var balloon := DialogueManager.show_dialogue_balloon(dialogue_resource, dialogue_key, [self])
		balloon.connect("dialogue_finished", Callable(self, "_on_dialogue_finished"))
		return balloon

func _on_dialogue_finished() -> void:
	if hirable and not hired:
		hire()

# ─────────────────────────────────────────────
# Click area (can be overridden in subclasses)
# ─────────────────────────────────────────────
func _on_area_input_event(_vp, _event, _shape_idx) -> void:
	pass
