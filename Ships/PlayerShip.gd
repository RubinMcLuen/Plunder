extends Area2D

@onready var trail_sprite: Sprite2D = $Trail/SubViewport/Circle

const NUM_FRAMES = 360
const ANGLE_PER_FRAME = 360.0 / NUM_FRAMES
const MAX_CHARGE_TIME = 2.0
const BASE_CANNONBALL_SPEED = 30
const BASE_CANNONBALL_DISTANCE = 80

# Define MOUSE_BUTTON_LEFT if not already defined.
const MOUSE_BUTTON_LEFT = 1

@export var rotation_speed = 75.0
@export var damping_factor = 0.99
@export var acceleration_factor = 0.5
@export var max_rotation_speed = 100.0
@export var rotation_acceleration = 100.0
@export var steering_wheel: Sprite2D
@export var cooldown = 1.0
@export var cannonball_scene: PackedScene
@export var splash_scene: PackedScene
@export var hit_scene: PackedScene
@export var deceleration_factor = 100
@export var charge_time_left = 1.0
@export var charge_time_right = 1.0

# NEW: Swipe sensitivity – higher values mean a small swipe rotates the ship more.
@export var swipe_sensitivity: float = 0.2

var current_frame = 0
var sprite: Sprite2D = null
var collision_shape: CollisionShape2D = null
var velocity = Vector2.ZERO
var target_speed = 40.0
var current_speed = 0.0
var moving_forward = false
var current_rotation_speed = 0.0
var rotating_right = false
var rotating_left = false
var can_shoot = true
var target_position: Vector2 = Vector2.ZERO
var is_bot_controlled = false
var target_angle = -1.0
var bot_input = {
	"rotate_right": false,
	"rotate_left": false,
	"move_forward": false,
	"shoot_left": false,
	"shoot_right": false
}
const ANGLE_TOLERANCE = 1.0  # Degrees
const DISTANCE_TOLERANCE = 1.0  # Distance units

# Preload the Pixel scene

# Store references to pixel instances
var pixel_trail = []

# Time interval for dropping pixels
var trail_interval = 0.05
var time_since_last_trail = 0.0

signal position_updated(new_position: Vector2)
signal movement_started()
signal player_docked()
signal manual_rotation_started()

func _ready():
	start()
	sprite = $ShipSprite
	collision_shape = $ShipHitbox

	$ShipCamera.make_current()

func _process(delta):
	if sprite:
		handle_input(delta)
		update_movement(delta)

		var new_position = global_position + velocity * delta

		if not is_colliding_with_land(new_position):
			global_position = new_position
			emit_signal("position_updated", global_position)

		if is_bot_controlled:
			if target_angle >= 0:
				rotate_to_target_angle(delta)
			else:
				move_to_target(delta)

		if not rotating_right and not rotating_left:
			apply_rotation_deceleration(delta)

		if rotating_right:
			rotate_right(delta)
		elif rotating_left:
			rotate_left(delta)

		if steering_wheel:
			steering_wheel.rotation_degrees = current_frame * ANGLE_PER_FRAME * 3

		# Update the time since the last trail pixel was created
		time_since_last_trail += delta

		# Check if it's time to create a new trail pixel
		if time_since_last_trail >= trail_interval:
			time_since_last_trail = 0.0

func get_collision_shape_corner():
	if collision_shape and collision_shape.shape is RectangleShape2D:
		var rect_shape = collision_shape.shape
		var extents = rect_shape.extents
		# Bottom-left corner example, adjust as needed
		var corner_local_pos = Vector2(extents.x, -extents.y)
		# Calculate the global position based on the player's rotation
		var rotation = global_rotation
		var corner_global_pos = global_position + corner_local_pos.rotated(rotation)
		return corner_global_pos
	return global_position

func update_frame():
	if sprite:
		sprite.frame = (int(current_frame) + int(float(NUM_FRAMES) / 2)) % NUM_FRAMES
	if collision_shape:
		collision_shape.rotation_degrees = current_frame * ANGLE_PER_FRAME
	# Update trail sprite rotation to match boat's facing direction
	if trail_sprite:
		trail_sprite.rotation_degrees = current_frame * ANGLE_PER_FRAME

func rotate_right(delta):
	current_rotation_speed = min(current_rotation_speed + rotation_acceleration * delta, max_rotation_speed)
	current_frame += current_rotation_speed * delta / ANGLE_PER_FRAME
	if current_frame >= NUM_FRAMES:
		current_frame -= NUM_FRAMES
	update_frame()

func rotate_left(delta):
	current_rotation_speed = max(current_rotation_speed - rotation_acceleration * delta, -max_rotation_speed)
	current_frame += current_rotation_speed * delta / ANGLE_PER_FRAME
	if current_frame < 0:
		current_frame += NUM_FRAMES
	update_frame()

func apply_rotation_deceleration(delta):
	if current_rotation_speed > 0:
		current_rotation_speed = max(current_rotation_speed - deceleration_factor * delta, 0)
		if current_rotation_speed > 0:
			current_frame += current_rotation_speed * delta / ANGLE_PER_FRAME
			if current_frame >= NUM_FRAMES:
				current_frame -= NUM_FRAMES
			update_frame()
	elif current_rotation_speed < 0:
		current_rotation_speed = min(current_rotation_speed + deceleration_factor * delta, 0)
		if current_rotation_speed < 0:
			current_frame += current_rotation_speed * delta / ANGLE_PER_FRAME
			if current_frame < 0:
				current_frame += NUM_FRAMES
			update_frame()

func toggle_forward_movement():
	moving_forward = not moving_forward
	if moving_forward:
		emit_signal("movement_started")

func update_movement(delta):
	if moving_forward:
		current_speed = lerp(current_speed, target_speed, acceleration_factor * delta)
	else:
		current_speed *= damping_factor

	var direction = calculate_direction()
	velocity = direction * current_speed

func calculate_direction():
	var angle = deg_to_rad(current_frame * ANGLE_PER_FRAME)
	return Vector2(cos(angle), sin(angle))

func shoot_left():
	if not can_shoot:
		return
	can_shoot = false
	$GunCooldown.start()
	var ship_direction = calculate_direction()
	var left_direction = Vector2(ship_direction.y, -ship_direction.x)

	var distance_factor = charge_time_left / MAX_CHARGE_TIME
	var cannonball_distance = (BASE_CANNONBALL_DISTANCE * distance_factor) + 50

	for i in range(5):
		var c = cannonball_scene.instantiate()
		c.splash_scene = splash_scene
		c.hit_scene = hit_scene
		get_tree().current_scene.add_child(c)
		var offset = ship_direction.normalized() * (i * 3 - 6)
		var start_position = position + offset + left_direction * 8
		c.start(start_position, left_direction, cannonball_distance, self)

func shoot_right():
	if not can_shoot:
		return
	can_shoot = false
	$GunCooldown.start()
	var ship_direction = calculate_direction()
	var right_direction = Vector2(-ship_direction.y, ship_direction.x)

	var distance_factor = charge_time_right / MAX_CHARGE_TIME
	var cannonball_distance = (BASE_CANNONBALL_DISTANCE * distance_factor) + 50

	for i in range(5):
		var c = cannonball_scene.instantiate()
		c.splash_scene = splash_scene
		c.hit_scene = hit_scene
		get_tree().current_scene.add_child(c)
		var offset = ship_direction.normalized() * (i * 3 - 6)
		var start_position = position + offset + right_direction * 8
		c.start(start_position, right_direction, cannonball_distance, self)

func start():
	if cooldown <= 0:
		cooldown = 1.0
	$GunCooldown.wait_time = cooldown

func _on_gun_cooldown_timeout():
	can_shoot = true

func is_colliding_with_land(new_position):
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = new_position
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var result = space_state.intersect_point(query)
	for collision in result:
		if collision.collider is StaticBody2D:
			return true
	return false


func handle_input(delta):
	if is_bot_controlled:
		handle_bot_input(delta)
	else:
		handle_player_input(delta)

func handle_bot_input(_delta):
	if bot_input["rotate_right"]:
		rotating_right = true
		rotating_left = false
	elif bot_input["rotate_left"]:
		rotating_right = false
		rotating_left = true
	else:
		rotating_right = false
		rotating_left = false

	if bot_input["move_forward"]:
		toggle_forward_movement()
	if bot_input["shoot_left"]:
		shoot_left()
	if bot_input["shoot_right"]:
		shoot_right()

func handle_player_input(delta):
	if Input.is_action_pressed("ui_right"):
		emit_signal("manual_rotation_started")
		rotating_right = true
		rotating_left = false
	elif Input.is_action_pressed("ui_left"):
		emit_signal("manual_rotation_started")
		rotating_right = false
		rotating_left = true
	else:
		rotating_right = false
		rotating_left = false

	if Input.is_action_just_pressed("ui_select"):
		toggle_forward_movement()

	if Input.is_action_pressed("shoot_left"):
		charge_time_left = min(charge_time_left + delta, MAX_CHARGE_TIME)
	elif Input.is_action_just_released("shoot_left"):
		shoot_left()
		charge_time_left = 0.0

	if Input.is_action_pressed("shoot_right"):
		charge_time_right = min(charge_time_right + delta, MAX_CHARGE_TIME)
	elif Input.is_action_just_released("shoot_right"):
		shoot_right()
		charge_time_right = 0.0

func reset_bot_input():
	bot_input["rotate_right"] = false
	bot_input["rotate_left"] = false
	bot_input["move_forward"] = false
	bot_input["shoot_left"] = false
	bot_input["shoot_right"] = false

func drive_to_target_position(target_pos):
	is_bot_controlled = true
	target_position = target_pos
	moving_forward = false
	reset_bot_input()

var stuck_timer = 0.0
var last_distance = INF

const STUCK_TIME_LIMIT = 2.0  # seconds
const SNAP_DISTANCE = 10.0    # how close it must be before we allow a forced snap

func move_to_target(delta):
	var direction_to_target = (target_position - global_position).normalized()
	var angle_to_target = direction_to_target.angle()

	# Make sure we use the same angle logic as calculate_direction()
	var current_angle = deg_to_rad(current_frame * ANGLE_PER_FRAME)
	var angle_diff = wrapf(angle_to_target - current_angle, -PI, PI)
	var angle_diff_degrees = abs(rad_to_deg(angle_diff))

	# --- ROTATION LOGIC (same as your existing approach) ---
	if angle_diff_degrees > ANGLE_TOLERANCE:
		var rotation_speed_adjusted = rotation_speed * delta
		if angle_diff_degrees < ANGLE_TOLERANCE * 5:
			rotation_speed_adjusted *= 0.5  # optional slow-down near final angle

		if angle_diff > 0:
			current_frame += rotation_speed_adjusted
		else:
			current_frame -= rotation_speed_adjusted

		current_frame = fmod(current_frame, NUM_FRAMES)
		if current_frame < 0:
			current_frame += NUM_FRAMES

		update_frame()

	# --- TRANSLATION LOGIC ---
	var distance_to_target = global_position.distance_to(target_position)
	
	# Check if we're still too far
	if distance_to_target > DISTANCE_TOLERANCE:
		# Increase stuck timer if not making progress
		if distance_to_target > last_distance - 0.01:
			stuck_timer += delta
		else:
			stuck_timer = 0.0  # We got closer, so reset stuck timer

		# Accelerate up to some speed
		if current_speed < target_speed * 0.5:
			current_speed = target_speed * 0.5
		else:
			current_speed = lerp(current_speed, target_speed, acceleration_factor * delta)

		var direction = calculate_direction()
		velocity = direction * current_speed
		global_position += velocity * delta

		# If we're close enough AND stuck too long, forcibly snap
		if distance_to_target < SNAP_DISTANCE and stuck_timer > STUCK_TIME_LIMIT:
			_force_snap_to_target()
	else:
		# Normal successful snap
		_force_snap_to_target()

	# Update last_distance for next frame
	last_distance = distance_to_target

func _force_snap_to_target():
	global_position = target_position
	moving_forward = false
	velocity = Vector2.ZERO
	current_speed = 0.0
	stuck_timer = 0.0
	last_distance = 0.0
	emit_signal("player_docked")

	# Now handle final rotation if needed
	_choose_final_dock_angle()

# Helper: Returns the signed minimal difference (in degrees) between two angles.
func signed_angle_difference(deg1: float, deg2: float) -> float:
	var diff = deg1 - deg2
	diff = fposmod(diff + 180, 360) - 180
	return diff

# Helper: Normalize an angle to [0, 360)
func normalize_angle(deg: float) -> float:
	var a = fposmod(deg, 360)
	return a

# When docking, choose the final angle based on the ship’s current facing.
func _choose_final_dock_angle():
	# Compute the current ship angle in degrees.
	var current_angle_deg = normalize_angle(current_frame * ANGLE_PER_FRAME)
	print("DEBUG: _choose_final_dock_angle -> current_frame:", current_frame, "=> current_angle_deg:", current_angle_deg)
	
	# Compare differences to candidate angles.
	var diff_east = abs(signed_angle_difference(0, current_angle_deg))
	var diff_west = abs(signed_angle_difference(180, current_angle_deg))
	print("DEBUG: _choose_final_dock_angle -> diff_east (0°):", diff_east, "diff_west (180°):", diff_west)
	
	# Choose the candidate closest to the current facing.
	target_angle = 0 if diff_east < diff_west else 180
	print("DEBUG: _choose_final_dock_angle -> chosen target_angle:", target_angle)
	# (Let _process() drive the gradual rotation.)

# Rotate the ship gradually toward target_angle.
func rotate_to_target_angle(delta):
	var current_angle_deg = normalize_angle(current_frame * ANGLE_PER_FRAME)
	var target_angle_norm = normalize_angle(target_angle)
	
	var diff = signed_angle_difference(target_angle_norm, current_angle_deg)
	print("DEBUG: rotate_to_target_angle -> current_angle_deg:", current_angle_deg, "target_angle_norm:", target_angle_norm, "diff:", diff)
	
	var rotation_step = rotation_speed * delta
	
	# If the difference is smaller than what we’d rotate this frame, snap to target.
	if abs(diff) <= rotation_step:
		current_frame = target_angle_norm / ANGLE_PER_FRAME
		update_frame()
		is_bot_controlled = false
		target_angle = -1.0
		print("DEBUG: rotate_to_target_angle -> snapping to target angle.")
		return

	# Optionally slow rotation when very close.
	if abs(diff) < ANGLE_TOLERANCE * 5:
		rotation_step *= 0.5

	# Rotate in the proper direction.
	if diff > 0:
		current_frame += rotation_step / ANGLE_PER_FRAME
	else:
		current_frame -= rotation_step / ANGLE_PER_FRAME

	current_frame = fmod(current_frame, NUM_FRAMES)
	if current_frame < 0:
		current_frame += NUM_FRAMES
	update_frame()
	
	print("DEBUG: rotate_to_target_angle -> updated current_frame:", current_frame, 
		  "=> new current_angle_deg:", normalize_angle(current_frame * ANGLE_PER_FRAME))

# --- NEW: Mouse swipe input handling ---
func _input(event):
	# Check for mouse motion while the left mouse button is held down.
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		# Use the horizontal motion (event.relative.x) to adjust the rotation.
		var dx = event.relative.x
		if dx != 0:
			# Multiply by swipe_sensitivity so that even small swipes rotate the ship noticeably.
			var rotation_change = dx * swipe_sensitivity
			current_frame += rotation_change / ANGLE_PER_FRAME
			current_frame = fmod(current_frame, NUM_FRAMES)
			if current_frame < 0:
				current_frame += NUM_FRAMES
			update_frame()
