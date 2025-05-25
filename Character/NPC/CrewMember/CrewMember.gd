extends "res://Character/NPC/NPC.gd"
class_name CrewMemberNPC

const BOARD_SPEED       : float = 120.0
const DRAG_SPEED        : float = 200.0
const ATTACK_COOLDOWN   : float = 0.8
const CREW_ATTACK_ANIMS : Array[String] = ["AttackSlash", "AttackLunge"]

var battle_manager : Node
var board_target   : Vector2
var dragging       : bool    = false
var is_boarding    : bool    = false
var has_boarded    : bool    = false
var cooldown       : float   = 0.0
var targets        : Array[EnemyNPC] = []

@onready var melee_area     : Area2D           = $MeleeRange
@onready var click_area     : Area2D           = $Area2D
@onready var select_hitbox  : CollisionShape2D = $Area2D/SelectHitbox

var rng := RandomNumberGenerator.new()

func _ready() -> void:
	super._ready()

	# force all crew to use the crewskins.png map
	body_mat.set_shader_parameter(
		"map_texture",
		preload("res://Battle/crewskins.png")
	)

	rng.randomize()
	set_idle_with_sword_mode(true)
	click_area.input_event.connect(Callable(self, "_on_click"))
	melee_area.body_entered.connect(_on_target_enter)
	melee_area.body_exited.connect(_on_target_exit)


func _on_click(_vp, e : InputEvent, _i) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT \
	and e.pressed and battle_manager:
		dragging = true
		battle_manager.select_unit(self)

func _physics_process(delta : float) -> void:
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

func _walk_plank(delta : float) -> void:
	var dir = board_target - global_position
	if dir.length() < 4.0:
		has_boarded = true
		fighting    = true
		velocity    = Vector2.ZERO
	else:
		velocity = dir.normalized() * BOARD_SPEED
	set_facing_direction(dir.x < 0)

func _drag(delta : float) -> void:
	# Prototype logic: base the turn on exact offset from hitbox center
	var hit_center = select_hitbox.global_transform.origin
	var dir        = get_global_mouse_position() - hit_center

	if dir.length() < 4.0:
		velocity = Vector2.ZERO
	else:
		velocity = dir.normalized() * DRAG_SPEED

	# exactly mirror _set_facing(dir.x) from prototype
	if dir.x != 0.0:
		set_facing_direction(dir.x < 0)

func _auto_attack() -> void:
	if targets.is_empty() or cooldown > 0.0:
		return
	var tgt : EnemyNPC = targets[0]
	if not is_instance_valid(tgt):
		targets.pop_front()
		return

	set_facing_direction(tgt.global_position.x < global_position.x)

	var anim = CREW_ATTACK_ANIMS[rng.randi() % CREW_ATTACK_ANIMS.size()]
	appearance.play(anim)
	sword.play(anim)
	appearance.frame = 0
	sword.frame      = 0
	sword.visible    = true

	tgt.take_damage()
	velocity      = Vector2.ZERO
	cooldown      = ATTACK_COOLDOWN
	cooldown_lock = ATTACK_COOLDOWN

func _on_target_enter(n : Node) -> void:
	if n is EnemyNPC and not targets.has(n):
		targets.append(n)
func _on_target_exit(n : Node) -> void:
	if n is EnemyNPC:
		targets.erase(n)

func start_board()   -> void: is_boarding = true
func start_drag()    -> void: dragging    = true
func stop_drag()     -> void:
	dragging = false
	velocity = Vector2.ZERO
