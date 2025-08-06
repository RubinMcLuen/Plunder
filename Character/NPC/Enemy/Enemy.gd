# EnemyNPC.gd - Progressive version for YouTube demo
extends NPC
class_name EnemyNPC

const MAX_HP          = 5
const ATTACK_COOLDOWN = 1.0

var cooldown  : float = 0.0
var attacking : bool  = false
var targets   : Array = []   # hold CrewMemberNPC instances
var ai_enabled: bool = true  # New variable for demo control

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

func set_ai_enabled(enabled: bool) -> void:
	ai_enabled = enabled
	if not enabled:
		attacking = false
		cooldown = 0.0
		targets.clear()

func _physics_process(delta: float) -> void:
	cooldown      = max(cooldown - delta, 0.0)
	cooldown_lock = max(cooldown_lock - delta, 0.0)

	# Check what progress point we're at to determine AI behavior
	var battle_scene = get_tree().current_scene
	var progress = 0
	if battle_scene and "progress_point" in battle_scene:
		progress = battle_scene.progress_point
	
	# AI enabled at progress point 6+ ("Full Enemy AI") AND progress point 11+ ("Crew Pathfinding AI")
	var should_use_ai = (progress >= 6)

	# Only process AI if enabled and should use AI
	if ai_enabled and should_use_ai:
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
	if not ai_enabled:
		return
		
	var tgt = targets[0]
	if not is_instance_valid(tgt):
		targets.pop_front()
		return

	print("Enemy ", npc_name, " attacking ", tgt.npc_name)
	set_facing_direction(tgt.global_position.x < global_position.x)
	play_slash_animation()
	velocity      = Vector2.ZERO
	cooldown      = ATTACK_COOLDOWN
	cooldown_lock = ATTACK_COOLDOWN
	attacking     = true
	var delay = _hit_delay("AttackSlash", 5)
	await get_tree().create_timer(delay).timeout
	if is_instance_valid(tgt) and ai_enabled:
		print("Enemy ", npc_name, " dealing damage to ", tgt.npc_name)
		tgt.take_damage()

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
	# Check progress point to determine if we should add targets
	var battle_scene = get_tree().current_scene
	var progress = 0
	if battle_scene and "progress_point" in battle_scene:
		progress = battle_scene.progress_point
	
	# Add targets at progress point 6+ ("Full Enemy AI") AND progress point 11+ ("Crew Pathfinding AI")
	if progress >= 6 and ai_enabled and n is CrewMemberNPC and not targets.has(n):
		targets.append(n)
		print("Enemy ", npc_name, " detected crew member ", n.npc_name, " - adding to targets")

func _on_exit(n: Node) -> void:
	if n is CrewMemberNPC:
		targets.erase(n)

func play_slash_animation() -> void:
	_play_sword_sound()
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

func _hit_delay(anim_name: String, frame: int) -> float:
	var fps = appearance.sprite_frames.get_animation_speed(anim_name)
	if fps <= 0.001:
		fps = 1.0
	return float(frame - 1) / fps

# Override take_damage to control when enemy can be hurt
func take_damage(amount: int = 1) -> void:
	# For demo purposes, enemy only takes damage in progress points 5 and beyond (index 5)
	var battle_scene = get_tree().current_scene
	var progress = 0
	if battle_scene and "progress_point" in battle_scene:
		progress = battle_scene.progress_point
		
	if progress >= 5:  # Index 5 = "Enemy Takes Damage"
		super.take_damage(amount)
	else:
		# Just flash red but don't actually take damage
		_flash_red()
