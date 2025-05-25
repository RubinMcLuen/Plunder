extends "res://Character/NPC/NPC.gd"
class_name EnemyNPC

const MAX_HP          = 5
const ATTACK_COOLDOWN = 1.0

var cooldown  = 0.0
var attacking = false
var targets : Array[CrewMemberNPC] = []

@onready var melee_area : Area2D = $MeleeRange

func _ready() -> void:
	super._ready()

	# force all enemies to use the enemyskins.png map
	body_mat.set_shader_parameter(
		"map_texture",
		preload("res://Battle/enemyskins.png")
	)

	health   = MAX_HP
	fighting = true
	melee_area.body_entered.connect(Callable(self, "_on_enter"))
	melee_area.body_exited.connect(Callable(self, "_on_exit"))


func _physics_process(delta : float) -> void:
	cooldown      = max(cooldown - delta, 0.0)
	cooldown_lock = max(cooldown_lock - delta, 0.0)

	if !attacking and cooldown == 0.0 and !targets.is_empty(): _start_slash()
	if attacking and !appearance.is_playing():                 _end_slash()

	_update_base_anim(false)
	move_and_slide()

func _start_slash() -> void:
	var tgt : CrewMemberNPC = targets[0]
	if !is_instance_valid(tgt): targets.pop_front(); return

	set_facing_direction(tgt.global_position.x < global_position.x)
	appearance.play("AttackSlash")
	sword.play("AttackSlash")
	appearance.frame = 0
	sword.frame      = 0
	sword.speed_scale = appearance.speed_scale
	sword.visible     = true

	tgt.take_damage()
	velocity      = Vector2.ZERO
	cooldown      = ATTACK_COOLDOWN
	cooldown_lock = ATTACK_COOLDOWN
	attacking     = true

func _end_slash() -> void:
	appearance.play("IdleSword")
	sword.play("IdleSword")
	appearance.frame = 0
	sword.frame      = 0
	sword.visible    = true
	attacking        = false
	cooldown_lock    = 0.0

func _on_enter(n): if n is CrewMemberNPC and !targets.has(n): targets.append(n)
func _on_exit(n):  if n is CrewMemberNPC: targets.erase(n)
