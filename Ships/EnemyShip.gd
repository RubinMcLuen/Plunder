extends Area2D

const NUM_FRAMES = 360
const ANGLE_PER_FRAME = 360.0 / NUM_FRAMES

@export var debug_font: Font
@export var player: Node2D                # Assign the player's node
@export var approach_distance := 150.0
@export var align_distance := 100.0

@export var full_speed := 40.0
@export var slow_speed := 20.0
@export var min_speed := 10.0
@export var acceleration_factor := 0.5
@export var damping_factor := 0.99

@export var max_eased_turn_speed = 80.0
@export var turn_acceleration = 80.0
@export var turn_deceleration = 120.0
@export var angle_tolerance = 4.0

# Circle parameters: lower turn speed gives a much larger turning radius (≈5× larger)
@export var circle_turn_speed := 16.0
@export var circle_move_speed := 30.0

@export var cannonball_scene: PackedScene
@export var splash_scene: PackedScene
@export var hit_scene: PackedScene
@export var cooldown := 1.0
var can_shoot = true

@export var health := 80

# Export a variable to toggle debug info.
@export var show_debug: bool = true

# AI states
enum EnemyState {
	APPROACH,
	ALIGN,
	CIRCLE
}
var current_state = EnemyState.APPROACH

# For post-fire circle duration (3 timer cycles)
var post_fire_cycles = 0
var circle_direction = 1            # +1 for right, -1 for left
var side_offset_degs = -90.0        # Determines whether to align left (-90) or right (90)

var current_action = "Unknown"
var distance_to_player = 999.0
var player_angle_degrees = 0.0

var current_frame = 0
var sprite: Sprite2D
var collision_shape: CollisionShape2D

var current_speed = 0.0
var current_rotation_speed = 0.0
var velocity = Vector2.ZERO

func _ready():
	sprite = $Boat
	collision_shape = $CollisionShape2D
	current_speed = full_speed
	# Connect collision signal using Callable.
	connect("area_entered", Callable(self, "_on_area_entered"))
	print("Enemy initialized. Health =", health)

func _process(delta):
	match current_state:
		EnemyState.APPROACH:
			apply_approach_behavior(delta)
		EnemyState.ALIGN:
			apply_align_and_shoot_behavior(delta)
		EnemyState.CIRCLE:
			apply_circle_behavior(delta)

	update_movement(delta)
	global_position += velocity * delta

	if player:
		update_distance_and_angle()

	#queue_redraw()

##
# TIMER CALLBACK (DecideTimer): runs every 5 seconds.
##
func _on_decide_timer_timeout():
	if not player:
		return
	update_distance_and_angle()
	
	match current_state:
		EnemyState.CIRCLE:
			post_fire_cycles -= 1
			print("Enemy circling; remaining cycles:", post_fire_cycles)
			if post_fire_cycles <= 0:
				current_state = EnemyState.APPROACH
				print("Enemy switching to APPROACH state.")
		_:
			if distance_to_player > approach_distance:
				current_state = EnemyState.APPROACH
				print("Enemy switching to APPROACH state (distance =", distance_to_player, ").")
			else:
				current_state = EnemyState.ALIGN
				if randf() < 0.5:
					side_offset_degs = -90.0
				else:
					side_offset_degs = 90.0
				print("Enemy switching to ALIGN state. Side offset set to", side_offset_degs)

##
# STATE: APPROACH
##
func apply_approach_behavior(delta):
	current_action = "Approaching"
	current_speed = lerp(current_speed, full_speed, acceleration_factor * delta)
	turn_toward_player_eased(delta)

##
# STATE: ALIGN & SHOOT
##
func apply_align_and_shoot_behavior(delta):
	current_action = "Aligning"
	if distance_to_player < align_distance:
		current_speed = lerp(current_speed, max(slow_speed, min_speed), acceleration_factor * delta)
	else:
		current_speed = lerp(current_speed, full_speed, acceleration_factor * delta)
	var angle_diff = turn_side_toward_player_eased(delta, side_offset_degs)
	if abs(angle_diff) < 5.0:
		print("Enemy aligned for firing. Angle difference =", angle_diff)
		# Revert to original shooting: if side_offset_degs is negative, fire left; else fire right.
		shoot_cannons(side_offset_degs)
		post_fire_cycles = 3
		circle_direction = -1 if randf() < 0.5 else 1
		current_state = EnemyState.CIRCLE
		print("Enemy fired! Switching to CIRCLE state for", post_fire_cycles, "cycles.")

##
# STATE: CIRCLE
##
func apply_circle_behavior(delta):
	current_action = "Circling"
	current_speed = lerp(current_speed, circle_move_speed, acceleration_factor * delta)
	apply_constant_turn(delta, circle_turn_speed * circle_direction)

func apply_constant_turn(delta, deg_per_sec):
	current_rotation_speed = deg_per_sec
	current_frame += current_rotation_speed * delta / ANGLE_PER_FRAME
	if current_frame >= NUM_FRAMES:
		current_frame -= NUM_FRAMES
	elif current_frame < 0:
		current_frame += NUM_FRAMES
	update_frame()

##
# EASING-BASED TURNING
##
func turn_toward_player_eased(delta):
	if not player:
		return
	var angle_to_player = rad_to_deg((player.global_position - global_position).angle())
	var current_deg = wrapf(current_frame * ANGLE_PER_FRAME, 0.0, 360.0)
	var angle_diff = wrapf(angle_to_player - current_deg, -180.0, 180.0)
	var desired_rot_speed = 0.0
	if abs(angle_diff) > angle_tolerance:
		desired_rot_speed = sign(angle_diff) * max_eased_turn_speed
	apply_rotation_easing(delta, desired_rot_speed)

func turn_side_toward_player_eased(delta, side_offset_degs: float) -> float:
	if not player:
		return 0.0
	var angle_to_player = rad_to_deg((player.global_position - global_position).angle())
	var current_deg = wrapf(current_frame * ANGLE_PER_FRAME, 0.0, 360.0)
	var desired_facing = angle_to_player + side_offset_degs
	var angle_diff = wrapf(desired_facing - current_deg, -180.0, 180.0)
	var desired_rot_speed = 0.0
	if abs(angle_diff) > angle_tolerance:
		desired_rot_speed = sign(angle_diff) * max_eased_turn_speed
	apply_rotation_easing(delta, desired_rot_speed)
	return angle_diff

func apply_rotation_easing(delta, target_rot_speed):
	var diff = target_rot_speed - current_rotation_speed
	if diff > 0:
		var accel = turn_acceleration * delta
		if abs(diff) < accel:
			current_rotation_speed = target_rot_speed
		else:
			current_rotation_speed += accel
	elif diff < 0:
		var decel = turn_deceleration * delta
		if abs(diff) < decel:
			current_rotation_speed = target_rot_speed
		else:
			current_rotation_speed -= decel
	current_frame += current_rotation_speed * delta / ANGLE_PER_FRAME
	if current_frame >= NUM_FRAMES:
		current_frame -= NUM_FRAMES
	elif current_frame < 0:
		current_frame += NUM_FRAMES
	update_frame()

func update_frame():
	if sprite:
		sprite.frame = (int(current_frame) + int(NUM_FRAMES / 2)) % NUM_FRAMES
	if collision_shape:
		collision_shape.rotation_degrees = current_frame * ANGLE_PER_FRAME

##
# SHOOTING LOGIC
##
func shoot_cannons(side_degs: float):
	# Invert the firing: if side_degs < 0, fire left; else fire right.
	if side_degs > 0:
		shoot_left()
	else:
		shoot_right()

func shoot_left():
	if not can_shoot:
		return
	print("Enemy firing left cannons!")
	can_shoot = false
	var ship_direction = calculate_direction()
	var left_direction = Vector2(ship_direction.y, -ship_direction.x)
	var cannonball_distance = 100.0
	for i in range(5):
		var c = cannonball_scene.instantiate()
		c.splash_scene = splash_scene
		c.hit_scene = hit_scene
		get_tree().current_scene.add_child(c)
		var offset = ship_direction.normalized() * (i * 3 - 6)
		var start_position = position + offset + left_direction * 8
		c.start(start_position, left_direction, cannonball_distance, self)
	$GunCooldown.wait_time = cooldown
	$GunCooldown.start()

func shoot_right():
	if not can_shoot:
		return
	print("Enemy firing right cannons!")
	can_shoot = false
	var ship_direction = calculate_direction()
	var right_direction = Vector2(-ship_direction.y, ship_direction.x)
	var cannonball_distance = 100.0
	for i in range(5):
		var c = cannonball_scene.instantiate()
		c.splash_scene = splash_scene
		c.hit_scene = hit_scene
		get_tree().current_scene.add_child(c)
		var offset = ship_direction.normalized() * (i * 3 - 6)
		var start_position = position + offset + right_direction * 8
		c.start(start_position, right_direction, cannonball_distance, self)
	$GunCooldown.wait_time = cooldown
	$GunCooldown.start()

func _on_gun_cooldown_timeout():
	can_shoot = true
	print("Enemy gun cooldown finished. can_shoot =", can_shoot)

func calculate_direction() -> Vector2:
	var angle = deg_to_rad(current_frame * ANGLE_PER_FRAME)
	return Vector2(cos(angle), sin(angle))

##
# MOVEMENT
##
func update_movement(delta):
	if current_speed < min_speed:
		current_speed = min_speed
	var direction = calculate_direction()
	velocity = direction * current_speed

##
# HEALTH / DAMAGE
##
func take_damage(amount: int):
	health -= amount
	print("Enemy took", amount, "damage. Health now:", health)
	if health <= 0:
		print("Enemy has died.")
		queue_free()

##
# DISTANCE & ANGLE
##
func update_distance_and_angle():
	if not player:
		distance_to_player = 999.0
		return
	var dir = player.global_position - global_position
	distance_to_player = dir.length()
	player_angle_degrees = rad_to_deg(dir.angle())
	if player_angle_degrees < 0:
		player_angle_degrees += 360.0

##
# COLLISION HANDLING
##
func _on_area_entered(area: Area2D) -> void:
	# If the colliding area has take_damage(), apply damage.
	if area.has_method("take_damage"):
		area.take_damage(10)
		create_hit_effect()
		queue_free()
		print("Enemy hit! Damage: 10, New Health:", health)

func create_hit_effect():
	if hit_scene:
		var hit = hit_scene.instantiate()
		hit.position = position
		get_tree().current_scene.add_child(hit)

##
# DEBUG DRAWING
##
func _draw():
	if show_debug:
		draw_circle(Vector2.ZERO, approach_distance, Color(0, 0, 1, 0.2))
		draw_circle(Vector2.ZERO, align_distance, Color(1, 0, 0, 0.2))
		var debug_info = [
			"State: %s" % str(current_state),
			"Action: %s" % current_action,
			"DistToPlayer: %.1f" % distance_to_player,
			"CurSpeed: %.1f" % current_speed,
			"RotSpeed: %.1f" % current_rotation_speed,
			"post_fire_cycles: %d" % post_fire_cycles,
			"side_offset_degs: %.1f" % side_offset_degs,
			"Enemy HP: %d" % health,
			"can_shoot? %s" % str(can_shoot)
		]
		var start_pos = Vector2(10, -40)
		var spacing = 14
		for i in range(debug_info.size()):
			draw_string(debug_font, start_pos + Vector2(0, i * spacing), debug_info[i])
