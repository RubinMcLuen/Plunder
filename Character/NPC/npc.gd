extends CharacterBody2D

@export var npc_texture_index : int = 0
@export var health            : int = 10
@export var speed             : float = 100.0

const HURT_FLASH_TIME : float = 0.20
const ATTACK_ANIMS    : Array[String] = ["AttackSlash", "AttackLunge"]

var fighting        = false
var idle_with_sword = true
var direction       = Vector2.RIGHT
var cooldown_lock   = 0.0

@onready var appearance : AnimatedSprite2D = $Appearance
@onready var sword      : AnimatedSprite2D = $Appearance/Sword
@onready var area2d     : Area2D           = $Area2D

var body_mat : ShaderMaterial
var hurt_tmr : Timer

signal end_fight
signal npc_move_completed

# ───────── READY ─────────
func _ready() -> void:
	_init_palette()
	_init_hurt_timer()
	appearance.play("IdleStand")
	sword.play("IdleSword")
	sword.visible = true
	area2d.input_event.connect(_on_area_input_event)

# palette
func _init_palette() -> void:
	var sheet : Texture2D = preload("res://Character/assets/NPCSprites.png")
	var cell  : Vector2i  = Vector2i(48, 48)
	var rect  : Rect2i    = Rect2i(Vector2i(npc_texture_index * cell.x, 0), cell)

	var img     : Image = sheet.get_image()
	var sub_img : Image = Image.create(cell.x, cell.y, false, img.get_format())
	sub_img.blit_rect(img, rect, Vector2.ZERO)
	var sub_tex : ImageTexture = ImageTexture.create_from_image(sub_img)

	body_mat = appearance.material.duplicate()
	body_mat.set_shader_parameter("map_texture", sub_tex)
	body_mat.set_shader_parameter("hurt_mode", false)
	appearance.material = body_mat

# hurt flash
func _init_hurt_timer() -> void:
	hurt_tmr = Timer.new()
	hurt_tmr.one_shot = true
	add_child(hurt_tmr)
	hurt_tmr.timeout.connect(_end_flash)

func _flash_red() -> void:
	body_mat.set_shader_parameter("hurt_mode", true)
	hurt_tmr.start(HURT_FLASH_TIME)

func _end_flash() -> void:
	body_mat.set_shader_parameter("hurt_mode", false)

func take_damage(amount : int = 1) -> void:
	if health <= 0: return
	health = max(0, health - amount)
	_flash_red()
	if health == 0:
		emit_signal("end_fight")
		queue_free()

# utilities
func set_idle_with_sword_mode(b : bool) -> void:
	idle_with_sword = b
	sword.visible   = b

func set_facing_direction(left : bool) -> void:
	direction        = Vector2.LEFT if left else Vector2.RIGHT
	appearance.flip_h = left
	sword.flip_h      = left

# idle / walk / sync
func _update_base_anim(force_walk : bool) -> void:
	if appearance.animation in ATTACK_ANIMS:
		if sword.animation == appearance.animation:
			sword.frame = appearance.frame
		if appearance.is_playing(): return
	if cooldown_lock > 0.0: return

	var walking := force_walk or velocity.length() > 0.1
	if walking:
		if appearance.animation != "Walk":
			appearance.play("Walk")
		sword.visible = false
	else:
		if fighting and idle_with_sword:
			if appearance.animation != "IdleSword":
				appearance.play("IdleSword"); sword.play("IdleSword")
		else:
			if appearance.animation != "IdleStand":
				appearance.play("IdleStand")
		sword.visible = idle_with_sword
		sword.frame   = appearance.frame

# physics
func _physics_process(delta : float) -> void:
	_update_base_anim(false)
	move_and_slide()
	cooldown_lock = max(0.0, cooldown_lock - delta)

func _on_area_input_event(_vp, _e, _i) -> void: pass
