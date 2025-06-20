# EnemyNPC.gd
extends NPC
class_name EnemyNPC

const MAX_HP          = 5
const ATTACK_COOLDOWN = 1.0

var cooldown  : float = 0.0
var attacking : bool  = false
var targets   : Array = []   # hold CrewMemberNPC instances

@onready var melee_area: Area2D = $MeleeRange

func _ready() -> void:
	super._ready()

	# Override the generic NPC palette with the enemy-specific skin
	body_mat.set_shader_parameter(
		"map_texture",
		preload("res://Battle/enemyskins.png")
	)

	health   = MAX_HP
	fighting = true

	# Start in IdleSword (combat stance)
	idle_with_sword = true
	appearance.play("IdleSword")
	if sword:
		sword.visible = true
		sword.play("IdleSword")
		sword.frame = appearance.frame

	melee_area.body_entered.connect(_on_enter)
	melee_area.body_exited.connect(_on_exit)


func _physics_process(delta: float) -> void:
	cooldown      = max(cooldown - delta, 0.0)
	cooldown_lock = max(cooldown_lock - delta, 0.0)

	if not attacking and cooldown == 0.0 and not targets.is_empty():
		_start_slash()
	elif attacking and not appearance.is_playing():
		_end_slash()

	update_animation()
	move_and_slide()


func update_animation() -> void:
	# 1) Animation override (slash)
	if anim_override:
		if sword:
			sword.visible = true

               if current_anim == "slash":
                       if appearance.animation != "AttackSlash" or not appearance.is_playing():
                               appearance.play("AttackSlash")
                       if sword and (sword.animation != "AttackSlash" or not sword.is_playing()):
                               sword.play("AttackSlash")

		# Sync flip, speed, and frame for slash
		appearance.flip_h = (direction == Vector2.LEFT)
		if sword:
			sword.flip_h      = appearance.flip_h
			sword.speed_scale = appearance.speed_scale
			sword.frame       = appearance.frame

		# End override when done
		if Time.get_ticks_msec() - anim_override_start_time >= anim_override_duration:
			anim_override = false

		return

	# 2) If not attacking, handle walk / idle logic

	# 2a) If moving → Walk, hide sword
	if velocity.length() > 0.1:
		if appearance.animation != "Walk":
			appearance.play("Walk")
		if sword:
			sword.visible = false
		appearance.flip_h = (direction == Vector2.LEFT)
		return

	# 2b) If idle-with-sword (combat stance) → IdleSword, show sword, sync frames
	if fighting and idle_with_sword:
		if appearance.animation != "IdleSword":
			appearance.play("IdleSword")
		if sword:
			sword.visible = true
			if sword.animation != "IdleSword":
				sword.play("IdleSword")
			# **Sync frames here**
			sword.speed_scale = appearance.speed_scale
			sword.frame       = appearance.frame
			sword.flip_h      = appearance.flip_h
		appearance.flip_h = (direction == Vector2.LEFT)
		return

	# 2c) Otherwise → IdleStand, hide sword
	if appearance.animation != "IdleStand":
		appearance.play("IdleStand")
	if sword:
		sword.visible = false
	appearance.flip_h = (direction == Vector2.LEFT)


func _start_slash() -> void:
	var tgt = targets[0]
	if not is_instance_valid(tgt):
		targets.pop_front()
		return

	set_facing_direction(tgt.global_position.x < global_position.x)
	play_slash_animation()

	tgt.take_damage()
	velocity      = Vector2.ZERO
	cooldown      = ATTACK_COOLDOWN
	cooldown_lock = ATTACK_COOLDOWN
	attacking     = true


func _end_slash() -> void:
	appearance.play("IdleSword")
	if sword:
		sword.play("IdleSword")
	appearance.frame = 0
	if sword:
		sword.frame = 0

	attacking     = false
	cooldown_lock = 0.0


func _on_enter(n: Node) -> void:
	if n is CrewMemberNPC and not targets.has(n):
		targets.append(n)


func _on_exit(n: Node) -> void:
	if n is CrewMemberNPC:
		targets.erase(n)


func play_slash_animation() -> void:
	anim_override            = true
	current_anim             = "slash"
	anim_override_start_time = Time.get_ticks_msec()

	# ─── Compute the real length of "AttackSlash" ───
	var anim_name   = "AttackSlash"
	var frame_count = appearance.sprite_frames.get_frame_count(anim_name)
	var fps         = appearance.sprite_frames.get_animation_speed(anim_name)
	if fps <= 0.001:
		fps = 1.0
	anim_override_duration = int((frame_count / fps) * 1000)

	# Keep sword in sync
	if sword:
		sword.speed_scale = appearance.speed_scale
