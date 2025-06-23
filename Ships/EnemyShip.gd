extends Area2D
##
##  ENEMY SHIP – volley cannons, death-boarding
##

# ───────── CONSTANTS ─────────
const NUM_FRAMES               := 360
const ANGLE_PER_FRAME          := 360.0 / NUM_FRAMES
const BASE_CANNONBALL_DISTANCE := 40

const DEATH_TARGET_DEG         := 0.0                      # face east
const DEATH_TARGET_FRAME       := int(round(DEATH_TARGET_DEG / ANGLE_PER_FRAME)) % NUM_FRAMES
const MOUSE_BUTTON_LEFT        := 1                        # click button
const STOP_THRESHOLD           := 2.0                     # px/s → snap speed

# ───────── DEBUG: spawn wreck in dead state ─────────
@export var start_dead_for_testing : bool = false
# If true, a dock arrow is spawned automatically when this ship is destroyed.
# The ocean tutorial handles arrows manually, so it disables this behaviour.
@export var spawn_dock_arrow_on_death : bool = true

# ───────── EXPORTED / NODES ─────────
@export var player                   : Node2D
@export var approach_distance        : float = 150.0
@export var align_distance           : float = 100.0
@export var full_speed               : float = 40.0
@export var slow_speed               : float = 20.0
@export var min_speed                : float = 10.0
@export var acceleration_factor      : float = 0.5
@export var damping_factor           : float = 0.99
@export var max_eased_turn_speed     : float = 80.0
@export var turn_acceleration        : float = 80.0
@export var turn_deceleration        : float = 120.0
@export var angle_tolerance          : float = 4.0
@export var circle_turn_speed        : float = 16.0
@export var circle_move_speed        : float = 30.0

@export var cannonball_scene         : PackedScene
@export var splash_scene             : PackedScene
@export var hit_scene                : PackedScene
@export var cannon_smoke_scene       : PackedScene
@onready var cannon_shot_sound       : AudioStreamPlayer2D = $CannonShotSound
@onready var splash_sound_fx         : AudioStreamPlayer2D = $SplashSound
@onready var hit_sound_fx            : AudioStreamPlayer2D = $HitSound
@onready var trail_sprite            : Sprite2D            = $Trail/SubViewport/Circle
@export var health                   : int = 80

# ───────── STATE VARIABLES ─────────
enum EnemyState { APPROACH, ALIGN, CIRCLE, DEAD }
var current_state            : EnemyState = EnemyState.APPROACH
var post_fire_cycles         : int        = 0
var circle_direction         : int        = 1
var side_offset_degs         : float      = -90.0
var distance_to_player       : float      = 999.0

var current_frame            : float      = 0.0
var sprite                   : Sprite2D
var collision_shape          : CollisionShape2D
var current_speed            : float      = 0.0
var current_rotation_speed   : float      = 0.0
var velocity                 : Vector2    = Vector2.ZERO
var can_shoot                : bool       = true

# death / boarding helpers
var death_initial_speed : float = 0.0
var death_aligned       : bool  = false
signal ready_for_boarding_changed(ready : bool)

# private backing value for the property
var _ready_for_boarding_internal: bool = false

@export var ready_for_boarding: bool = false:
	set(value):
		if _ready_for_boarding_internal == value:
			return
		_ready_for_boarding_internal = value
		emit_signal("ready_for_boarding_changed", value)
	get:
		return _ready_for_boarding_internal

var dock_arrow         : Node2D = null
const ARROW_SCRIPT     = preload("res://KelptownInn/BobbingArrow.gd")
const ARROW_TEXTURE    = preload("res://KelptownInn/assets/arrow.png")
const BROKEN_TEXTURE   = preload("res://Ships/enemybroken.png")



# ───────── READY ─────────
func _ready() -> void:
	sprite          = $Boat
	collision_shape = $CollisionShape2D
	current_speed   = full_speed

	connect("area_entered", Callable(self, "_on_area_entered"))
	$DecideTimer.start()

	# clickable only once wrecked
	input_pickable         = false
	ready_for_boarding     = false

	# DEBUG: immediately spawn as wreck
	if start_dead_for_testing:
		_die()
		death_aligned          = true
		current_frame          = DEATH_TARGET_FRAME
		current_rotation_speed = 0.0
		_update_frame()
		current_speed          = 0.0
		ready_for_boarding     = true
		input_pickable         = true

		if sprite:
			sprite.texture = BROKEN_TEXTURE
			sprite.hframes = 1
			sprite.frame   = 0

		if spawn_dock_arrow_on_death:
			_spawn_dock_arrow()



# ───────── PROCESS ─────────
func _process(delta : float) -> void:
		_update_distance_and_angle()

		match current_state:
			EnemyState.APPROACH: _behave_approach(delta)
			EnemyState.ALIGN   : _behave_align(delta)
			EnemyState.CIRCLE  : _behave_circle(delta)
			EnemyState.DEAD    : _behave_dead(delta)

		_update_movement(delta)
		var new_pos = position + velocity * delta
		if not is_colliding_with_land(new_pos):
				position = new_pos



# ───────── STATE TIMER ─────────
func _on_decide_timer_timeout() -> void:
	if current_state == EnemyState.DEAD or player == null:
		return

	_update_distance_and_angle()

	if current_state == EnemyState.CIRCLE:
		post_fire_cycles -= 1
		if post_fire_cycles <= 0:
			current_state = EnemyState.APPROACH
	else:
		current_state = EnemyState.APPROACH if distance_to_player > approach_distance else EnemyState.ALIGN
		if current_state == EnemyState.ALIGN:
			side_offset_degs = -90.0 if randf() < 0.5 else 90.0



# ───────── STATE BEHAVIOUR ─────────
func _behave_approach(delta : float) -> void:
	current_speed = lerp(current_speed, full_speed, acceleration_factor * delta)
	_turn_toward_player(delta)


func _behave_align(delta : float) -> void:
	var tgt_spd = max(slow_speed, min_speed) if distance_to_player < align_distance else full_speed
	current_speed = lerp(current_speed, tgt_spd, acceleration_factor * delta)

	var diff = _turn_side_toward_player(delta, side_offset_degs)
	if abs(diff) < 5.0:
		_fire_broadside(side_offset_degs)
		post_fire_cycles = 3
		circle_direction = -1 if randf() < 0.5 else 1
		current_state    = EnemyState.CIRCLE


func _behave_circle(delta : float) -> void:
	current_speed = lerp(current_speed, circle_move_speed, acceleration_factor * delta)
	_apply_constant_turn(delta, circle_turn_speed * circle_direction)


func _behave_dead(delta : float) -> void:
	# Phase 1 – rotate to east
	if not death_aligned:
		current_speed = death_initial_speed
		var diff = _turn_to_angle(delta, DEATH_TARGET_DEG)
		if abs(diff) <= 0.5:
			current_frame          = DEATH_TARGET_FRAME
			current_rotation_speed = 0.0
			_update_frame()
			death_aligned = true
		return

	# Phase 2 – smooth decel via lerp, then snap
	current_speed = lerp(current_speed, 0.0, acceleration_factor * 4.0 * delta)
	if current_speed < STOP_THRESHOLD:
		current_speed          = 0.0
		current_rotation_speed = 0.0

		if sprite and sprite.texture != BROKEN_TEXTURE:
			sprite.texture = BROKEN_TEXTURE
			sprite.hframes = 1
			sprite.frame   = 0

		if not ready_for_boarding:
			ready_for_boarding = true
			input_pickable     = true  # now clickable!
			if spawn_dock_arrow_on_death:
				_spawn_dock_arrow()



# ───────── CLICK-TO-BOARD ─────────
func _input_event(_viewport : Object, event : InputEvent, _shape_idx : int) -> void:
	if ready_for_boarding \
	and event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		print("[Enemy] clicked for boarding:", name)
		# Emit the enemy node itself (Ocean expects a Node2D)
		get_tree().current_scene.emit_signal("board_enemy_request", self)



# ───────── UTILITIES ─────────
func _update_distance_and_angle() -> void:
	if player == null:
		distance_to_player = 999.0
		return
	distance_to_player = (player.global_position - global_position).length()


func _turn_toward_player(delta : float) -> void:
	if player == null:
		return
	var tgt = rad_to_deg((player.global_position - global_position).angle())
	_turn_to_angle(delta, tgt)


func _turn_side_toward_player(delta : float, side : float) -> float:
	if player == null:
		return 0.0
	var base = rad_to_deg((player.global_position - global_position).angle()) + side
	return _turn_to_angle(delta, base)


func _turn_to_angle(delta : float, tgt_deg : float) -> float:
	var cur  = wrapf(current_frame * ANGLE_PER_FRAME, 0.0, 360.0)
	var diff = wrapf(tgt_deg - cur, -180.0, 180.0)
	var tgt_speed = sign(diff) * max_eased_turn_speed if abs(diff) > angle_tolerance else 0.0
	_apply_rot_easing(delta, tgt_speed)
	return diff


func _apply_rot_easing(delta : float, tgt_speed : float) -> void:
	var d    = tgt_speed - current_rotation_speed
	var step = (turn_acceleration if d > 0.0 else turn_deceleration) * delta
	current_rotation_speed += clamp(d, -step, step)
	current_frame = wrapf(current_frame + current_rotation_speed * delta / ANGLE_PER_FRAME, 0.0, NUM_FRAMES)
	_update_frame()


func _apply_constant_turn(delta : float, deg_per_sec : float) -> void:
	current_rotation_speed = deg_per_sec
	current_frame = wrapf(current_frame + deg_per_sec * delta / ANGLE_PER_FRAME, 0.0, NUM_FRAMES)
	_update_frame()


func _update_frame() -> void:
	if $Boat:
		if $Boat.hframes > 1:
			$Boat.frame = (int(current_frame) + NUM_FRAMES / 2) % NUM_FRAMES
		else:
			$Boat.frame = 0
	if collision_shape:
		collision_shape.rotation_degrees = current_frame * ANGLE_PER_FRAME
	if trail_sprite:
		trail_sprite.rotation_degrees = collision_shape.rotation_degrees



# ───────── BROADSIDE FIRE ─────────
func _fire_broadside(side_deg : float) -> void:
	if side_deg > 0.0:
		_shoot_side(true)
	else:
		_shoot_side(false)


func _shoot_side(left : bool) -> void:
	if not can_shoot or current_state == EnemyState.DEAD:
		return

	can_shoot = false
	$GunCooldown.start()

	for i in [4, 3, 2, 1, 0]:
		var t := Timer.new()
		t.one_shot  = true
		t.wait_time = randf_range(0.0, 0.8)
		add_child(t)
		t.timeout.connect(Callable(self, "_spawn_cannon").bind(i, left))
		t.start()


func _spawn_cannon(i : int, left : bool) -> void:
	var dir  = _direction()
	var side = Vector2(dir.y, -dir.x) if left else Vector2(-dir.y, dir.x)

	_play_shot()
	_play_splash()

	var start   = position + dir.normalized() * (i * 3.0 - 6.0) + side * 9.0
	var smoke_r = dir.angle() - PI / 2.0 if left else dir.angle() + PI / 2.0
	var spread  = deg_to_rad((i - 2) * 2.0)
	var shotdir = side.rotated(spread if left else -spread)
	var dist    = (BASE_CANNONBALL_DISTANCE + 50.0) * randf_range(0.85, 1.15)

	if cannon_smoke_scene:
		var s = cannon_smoke_scene.instantiate()
		get_tree().current_scene.add_child(s)
		s.position = start
		s.rotation = smoke_r
		s.flip_v   = shotdir.x < 0.0
		s.start(velocity)

	var c = cannonball_scene.instantiate()
	c.splash_scene = splash_scene
	c.hit_scene    = hit_scene
	c.shooter      = self
	get_tree().current_scene.add_child(c)
	c.start(start, shotdir, dist, self, velocity)


func _on_gun_cooldown_timeout() -> void:
	can_shoot = true



# ───────── SFX HELPERS ─────────
func _dup_play(node : AudioStreamPlayer2D) -> void:
	if node == null:
		return
	var s = node.duplicate()
	get_tree().current_scene.add_child(s)
	s.global_position = global_position
	s.play()

	var tm = Timer.new()
	tm.one_shot  = true
	tm.wait_time = s.stream.get_length()
	add_child(tm)
	tm.timeout.connect(Callable(s, "queue_free"))
	tm.start()

func _play_shot()  -> void: _dup_play(cannon_shot_sound)
func _play_splash() -> void: _dup_play(splash_sound_fx)
func _play_hit()   -> void: _dup_play(hit_sound_fx)



# ───────── MOVEMENT & DAMAGE ─────────
func _update_movement(_delta : float) -> void:
		velocity = _direction() * current_speed

func is_colliding_with_land(pos: Vector2) -> bool:
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsPointQueryParameters2D.new()
		query.position = pos
		query.collide_with_bodies = true
		query.collide_with_areas = false
		var result = space_state.intersect_point(query)
		for collision in result:
				if collision.collider is StaticBody2D:
						return true
		return false


func _direction() -> Vector2:
	return Vector2.RIGHT.rotated(deg_to_rad(current_frame * ANGLE_PER_FRAME))


func take_damage(dmg : int) -> void:
	health -= dmg
	if health <= 0 and current_state != EnemyState.DEAD:
		_die()


func _die() -> void:
	current_state       = EnemyState.DEAD
	death_initial_speed = max(current_speed, min_speed)
	death_aligned       = false
	can_shoot           = false
	$DecideTimer.stop()
	print("Enemy destroyed – boarding soon.")



# ───────── DOCK ARROW ─────────
func _spawn_dock_arrow() -> void:
	if dock_arrow and is_instance_valid(dock_arrow):
		return
	if is_queued_for_deletion() or get_tree().current_scene == null:
		return

	dock_arrow = Sprite2D.new()
	dock_arrow.texture = ARROW_TEXTURE
	dock_arrow.z_index = 100
	dock_arrow.set_script(ARROW_SCRIPT)
	if dock_arrow.has_method("set_target"):
		dock_arrow.target = self

	get_tree().current_scene.call_deferred("add_child", dock_arrow)



# ───────── COLLISION CALLBACK ─────────
func _on_area_entered(_area : Area2D) -> void:
	# Implement your collision logic here
	# Example: if area.is_in_group("player_projectiles"): take_damage(area.damage)
	pass
