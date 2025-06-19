extends NPC
class_name CrewMemberNPC

const BOARD_SPEED       : float = 120.0
const DRAG_SPEED        : float = 200.0
const ATTACK_COOLDOWN   : float = 0.8
const CREW_ATTACK_ANIMS : Array[String] = ["AttackSlash", "AttackLunge"]

var battle_manager: Node
var board_target  : Vector2
var dragging      : bool  = false
var is_boarding   : bool  = false
var has_boarded   : bool  = false
var cooldown      : float = 0.0
var targets       : Array = []  # removed type hint to avoid parsing errors

@onready var melee_area    : Area2D           = $MeleeRange
@onready var click_area    : Area2D           = $Area2D
@onready var select_hitbox : CollisionShape2D = $Area2D/SelectHitbox

var rng := RandomNumberGenerator.new()

func _ready() -> void:
	super._ready()

	# override generic crew palette (you can customize if needed)
	body_mat.set_shader_parameter(
		"map_texture",
		preload("res://Battle/crewskins.png")
	)

	rng.randomize()

	# If we should start with sword drawn, play IdleSword
	if idle_with_sword:
		appearance.play("IdleSword")
		if sword:
			sword.visible = true
			sword.play("IdleSword")
			sword.frame = appearance.frame
	else:
		if sword:
			sword.visible = false

	click_area.input_event.connect(_on_click)
	melee_area.body_entered.connect(_on_target_enter)
	melee_area.body_exited.connect(_on_target_exit)

func _on_click(_vp, e: InputEvent, _i) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed and battle_manager:
		dragging = true
		battle_manager.select_unit(self)

func _physics_process(delta: float) -> void:
	cooldown      = max(cooldown - delta, 0.0)
	cooldown_lock = max(cooldown_lock - delta, 0.0)

	if is_boarding and not has_boarded:
		_walk_plank(delta)
	elif has_boarded and dragging:
		_drag(delta)
	elif has_boarded:
		_auto_attack()
	else:
		velocity = Vector2.ZERO

	_update_base_anim(dragging)
	move_and_slide()

# In CrewMemberNPC.gd:
func update_animation() -> void:
	# 1) Animation override (slash/lunge/block/hurt)
	if anim_override:
		if sword:
			sword.visible = true

		match current_anim:
			"slash":
				if appearance.animation != "AttackSlash":
					appearance.play("AttackSlash")
				if sword.animation != "AttackSlash":
					sword.play("AttackSlash")
			"lunge":
				if appearance.animation != "AttackLunge":
					appearance.play("AttackLunge")
				if sword.animation != "AttackLunge":
					sword.play("AttackLunge")
			"block":
				if appearance.animation != "AttackBlock":
					appearance.play("AttackBlock")
				if sword.animation != "AttackBlock":
					sword.play("AttackBlock")
			"hurt":
				if appearance.animation != "Hurt":
					appearance.play("Hurt")
				if sword.animation != "Hurt":
					sword.play("Hurt")

		# Sync flipping and speed
		appearance.flip_h = (direction == Vector2.LEFT)
		if sword:
			sword.flip_h      = appearance.flip_h
			sword.speed_scale = appearance.speed_scale
			sword.frame       = appearance.frame

		# End the override after its duration
		if Time.get_ticks_msec() - anim_override_start_time >= anim_override_duration:
			anim_override = false

		return

	# 2) Dragging → Walk, sword hidden
	if dragging:
		if appearance.animation != "Walk":
			appearance.play("Walk")
		if sword:
			sword.visible = false
		appearance.flip_h = (direction == Vector2.LEFT)
		return

	# 3) Moving (drag or AI) → Walk, sword hidden
	if velocity.length() > 0.1:
		if appearance.animation != "Walk":
			appearance.play("Walk")
		if sword:
			sword.visible = false
		appearance.flip_h = (direction == Vector2.LEFT)
		return

	# 4) Idle-with-sword (combat stance)
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

	# 5) Rest → IdleStand, sword hidden
	if appearance.animation != "IdleStand":
		appearance.play("IdleStand")
	if sword:
		sword.visible = false
	appearance.flip_h = (direction == Vector2.LEFT)



func _walk_plank(_delta: float) -> void:
		var dir = board_target - global_position
		if dir.length() < 4.0:
				has_boarded       = true
				fighting          = true
				idle_with_sword   = true
				appearance.play("IdleSword")
				if sword:
						sword.visible = true
						sword.play("IdleSword")
						sword.frame = appearance.frame
				velocity = Vector2.ZERO
				dragging     = false
				is_boarding  = false
		else:
				velocity = dir.normalized() * BOARD_SPEED
		set_facing_direction(dir.x < 0)

func _drag(_delta: float) -> void:
	var hit_center = select_hitbox.global_transform.origin
	var dir        = get_global_mouse_position() - hit_center
	velocity = Vector2.ZERO if dir.length() < 4.0 else dir.normalized() * DRAG_SPEED
	if dir.x != 0.0:
		set_facing_direction(dir.x < 0)

func _auto_attack() -> void:
	if targets.is_empty() or cooldown > 0.0:
		return

	var tgt = targets[0]
	if not is_instance_valid(tgt):
		targets.pop_front()
		return

	set_facing_direction(tgt.global_position.x < global_position.x)

	var anim = CREW_ATTACK_ANIMS[rng.randi() % CREW_ATTACK_ANIMS.size()]
	if anim == "AttackSlash":
		play_slash_animation()
	else:
		play_lunge_animation()

	tgt.take_damage()
	velocity      = Vector2.ZERO
	cooldown      = ATTACK_COOLDOWN
	cooldown_lock = ATTACK_COOLDOWN

func _on_target_enter(n: Node) -> void:
	# We can still check “is EnemyNPC” even if not type‐hinted 
	if n is EnemyNPC and not targets.has(n):
		targets.append(n)

func _on_target_exit(n: Node) -> void:
	if n is EnemyNPC:
		targets.erase(n)

func start_board() -> void:
	is_boarding = true

func start_drag() -> void:
	dragging = true

func stop_drag() -> void:
	dragging = false
	velocity = Vector2.ZERO

func play_slash_animation() -> void:
	anim_override            = true
	current_anim             = "slash"
	anim_override_start_time = Time.get_ticks_msec()

	# ─── Compute how long AttackSlash actually is ───
	var anim_name = "AttackSlash"
	var frame_count = appearance.sprite_frames.get_frame_count(anim_name)
	# If someone changed the FPS for this animation in the SpriteFrames resource, use it:
	var fps = appearance.sprite_frames.get_animation_speed(anim_name)
	# Avoid division by zero—default to 1 fps if not set
	if fps <= 0.001:
		fps = 1.0
	# Duration in milliseconds = (frames / fps) * 1000
	anim_override_duration = int((frame_count / fps) * 1000)

	# Make sure the sword sprite (child) matches the same speed:
	if sword:
		sword.speed_scale = appearance.speed_scale

func play_lunge_animation() -> void:
	anim_override            = true
	current_anim             = "lunge"
	anim_override_start_time = Time.get_ticks_msec()

	var anim_name = "AttackLunge"
	var frame_count = appearance.sprite_frames.get_frame_count(anim_name)
	var fps = appearance.sprite_frames.get_animation_speed(anim_name)
	if fps <= 0.001:
		fps = 1.0
	anim_override_duration = int((frame_count / fps) * 1000)

	if sword:
		sword.speed_scale = appearance.speed_scale
