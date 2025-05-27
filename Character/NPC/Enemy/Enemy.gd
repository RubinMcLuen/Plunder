# EnemyNPC.gd
extends NPC
class_name EnemyNPC

const MAX_HP          = 5
const ATTACK_COOLDOWN = 1.0

var cooldown  : float = 0.0
var attacking : bool  = false
var targets   : Array[CrewMemberNPC] = []

@onready var melee_area: Area2D = $MeleeRange

func _ready() -> void:
	super._ready()

	# set up palette
	body_mat.set_shader_parameter(
		"map_texture",
		preload("res://Battle/enemyskins.png")
	)

	health   = MAX_HP
	fighting = true
	set_idle_with_sword_mode(true)
	if sword:
		sword.visible = true
		sword.play("IdleSword")

	melee_area.body_entered.connect(_on_enter)
	melee_area.body_exited.connect(_on_exit)

func _physics_process(delta: float) -> void:
	cooldown      = max(cooldown - delta, 0.0)
	cooldown_lock = max(cooldown_lock - delta, 0.0)

	if not attacking and cooldown == 0.0 and not targets.is_empty():
		_start_slash()
	elif attacking and not appearance.is_playing():
		_end_slash()

	_update_base_anim(false)
	move_and_slide()

func _start_slash() -> void:
	var tgt := targets[0]
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
	if sword: sword.play("IdleSword")
	appearance.frame = 0
	if sword: sword.frame = 0
	attacking     = false
	cooldown_lock = 0.0

func _on_enter(n):
	if n is CrewMemberNPC and not targets.has(n):
		targets.append(n)

func _on_exit(n):
	if n is CrewMemberNPC:
		targets.erase(n)
