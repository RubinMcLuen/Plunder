extends Area2D

@onready var trail_sprite: Sprite2D = $Trail/SubViewport/Circle
@onready var cannon_shot_sound: AudioStreamPlayer2D = $CannonShotSound   # Cannon shot sound effect
@onready var splash_sound_fx: AudioStreamPlayer2D = $SplashSound         # Splash sound effect
@onready var hit_sound_fx: AudioStreamPlayer2D = $HitSound               # Hit sound effect

const NUM_FRAMES = 360
const ANGLE_PER_FRAME = 360.0 / NUM_FRAMES
const BASE_CANNONBALL_SPEED = 30
const BASE_CANNONBALL_DISTANCE = 40

const MOUSE_BUTTON_LEFT = 1

@export var rotation_speed = 75.0
@export var damping_factor = 0.99
@export var acceleration_factor = 0.5
@export var max_rotation_speed = 100.0
@export var rotation_acceleration = 100.0
@export var steering_wheel: TextureRect
@export var cooldown = 1.0
@export var cannonball_scene: PackedScene
@export var splash_scene: PackedScene
@export var hit_scene: PackedScene
@export var cannon_smoke_scene: PackedScene
@export var deceleration_factor = 100
@export var swipe_sensitivity: float = 1.0

@export var max_speed: float = 60.0
@export var acceleration_rate: float = 40.0

@export var health: int = 100

# --- Steering simulation variables ---
var steering_angle: float = 0.0
var steering_velocity: float = 0.0
@export var steering_spring_constant: float = 10.0
@export var steering_damping: float = 3.0
@export var steering_to_rotation_factor: float = 1.0
@export var steering_wheel_multiplier: float = 3.0

var swipe_input_active: bool = false

var current_frame = 0
var sprite: Sprite2D
var collision_shape: CollisionShape2D
var velocity = Vector2.ZERO
var target_speed = 60.0
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
const ANGLE_TOLERANCE = 1.0
const DISTANCE_TOLERANCE = 1.0

# Trail variables
var pixel_trail = []
var trail_interval = 0.05
var time_since_last_trail = 0.0

# Variables for controlling sound effects per volley
var shot_splash_played = false
var shot_hit_played = false

signal position_updated(new_position: Vector2)
signal movement_started()
signal player_docked()
signal manual_rotation_started()
signal cannons_fired_left()
signal cannons_fired_right()

# List of input action names that are allowed while tutorial or other
# systems restrict player control. When empty, all controls are allowed.
var allowed_actions: Array[String] = []

func set_allowed_actions(actions: Array[String]) -> void:
	allowed_actions = actions

func _action_allowed(action: String) -> bool:
	return allowed_actions.is_empty() or action in allowed_actions

func _ready():
	sprite = $ShipSprite
	collision_shape = $ShipHitbox
	$ShipCamera.make_current()
	connect("area_entered", Callable(self, "_on_area_entered"))

func _process(delta):
		if sprite:
								handle_input(delta)
								if not is_bot_controlled:
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
		else:
			update_swipe_steering(delta)
		
		time_since_last_trail += delta
		if time_since_last_trail >= trail_interval:
			time_since_last_trail = 0.0

# --- Steering and Movement ---

func update_swipe_steering(delta):
	var manual_input_active = Input.is_action_pressed("ui_right") or Input.is_action_pressed("ui_left") or swipe_input_active
	var old_angle = steering_angle
	var steering_acceleration = -steering_spring_constant * steering_angle - steering_damping * steering_velocity
	steering_velocity += steering_acceleration * delta
	steering_angle += steering_velocity * delta
	
	if not manual_input_active:
		if (old_angle > 0 and steering_angle < 0) or (old_angle < 0 and steering_angle > 0):
			steering_angle = 0
			steering_velocity = 0
	
	swipe_input_active = false
	
	current_frame += steering_angle * steering_to_rotation_factor * delta
	current_frame = fmod(current_frame, NUM_FRAMES)
	if current_frame < 0:
		current_frame += NUM_FRAMES
	update_frame()
	
	if steering_wheel:
		steering_wheel.rotation_degrees = steering_angle * steering_wheel_multiplier

func _input(event):
		if not _action_allowed("mouse_turn"):
				return
		if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				var dx = event.relative.x
				if dx != 0:
						steering_velocity += dx * swipe_sensitivity
						swipe_input_active = true

func update_frame():
	if sprite:
		sprite.frame = (int(current_frame) + int(float(NUM_FRAMES) / 2)) % NUM_FRAMES
	if collision_shape:
		collision_shape.rotation_degrees = current_frame * ANGLE_PER_FRAME
	if trail_sprite:
		trail_sprite.rotation_degrees = current_frame * ANGLE_PER_FRAME

func toggle_forward_movement():
		moving_forward = not moving_forward
		if moving_forward:
				emit_signal("movement_started")

func update_movement(delta):
		velocity = calculate_direction() * current_speed


func calculate_direction():
	var angle = deg_to_rad(current_frame * ANGLE_PER_FRAME)
	return Vector2(cos(angle), sin(angle))

func handle_input(delta):
	if is_bot_controlled:
		handle_bot_input(delta)
	else:
		handle_player_input(delta)

func handle_bot_input(delta):
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
																var key_impulse = 0.0
																var prev_speed = current_speed
																if _action_allowed("ui_right") and Input.is_action_pressed("ui_right"):
																			key_impulse += 1.0
																			emit_signal("manual_rotation_started")
																if _action_allowed("ui_left") and Input.is_action_pressed("ui_left"):
																			key_impulse -= 1.0
																			emit_signal("manual_rotation_started")
																if key_impulse != 0:
																				var keyboard_impulse_multiplier = 10.0
																				steering_velocity += key_impulse * keyboard_impulse_multiplier

																if _action_allowed("ui_up") and Input.is_action_pressed("ui_up"):
																				current_speed += acceleration_rate * delta
																if _action_allowed("ui_down") and Input.is_action_pressed("ui_down"):
																			current_speed -= acceleration_rate * delta
																current_speed = clamp(current_speed, 0.0, max_speed)
																if prev_speed <= 0.0 and current_speed > 0.0:
																				emit_signal("movement_started")

																if _action_allowed("ui_select") and Input.is_action_just_pressed("ui_select"):
																				# Interaction placeholder
																				pass

																if _action_allowed("shoot_left") and Input.is_action_just_pressed("shoot_left"):
																								shoot_left()
																if _action_allowed("shoot_right") and Input.is_action_just_pressed("shoot_right"):
																								shoot_right()

func reset_bot_input():
	bot_input["rotate_right"] = false
	bot_input["rotate_left"] = false
	bot_input["move_forward"] = false
	bot_input["shoot_left"] = false
	bot_input["shoot_right"] = false

# --- Firing Logic: Random Delay (0-1s) for Each Cannon, All in Parallel ---
func shoot_left():
	if not can_shoot:
			return
	can_shoot = false

	emit_signal("cannons_fired_left")
	
	# Start GunCooldown immediately when shoot is pressed.
	$GunCooldown.start()
	
	shot_splash_played = false
	shot_hit_played = false
	
	var indices = [4, 3, 2, 1, 0]
	# Schedule each cannon to fire after a random delay between 0 and 1 second
	for i in indices:
		var delay = randf_range(0, 0.8)  # random float in [0,1)
		var timer = Timer.new()
		timer.one_shot = true
		timer.wait_time = delay
		add_child(timer)
		timer.timeout.connect(Callable(self, "_fire_left_cannon").bind(i))
		timer.start()

func _fire_left_cannon(i):
	var ship_direction = calculate_direction()
	var left_direction = Vector2(ship_direction.y, -ship_direction.x)

	# Camera shake for this cannon
	camera_shake(-left_direction)
	_play_shot_sound()
	_play_splash_sound()

	var c = cannonball_scene.instantiate()
	c.splash_scene = splash_scene
	c.hit_scene = hit_scene
	c.shooter = self
	get_tree().current_scene.add_child(c)

	var offset = ship_direction.normalized() * (i * 3 - 6)
	var start_position = position + offset + left_direction * 9

	# Smoke effect
	var smoke = cannon_smoke_scene.instantiate()
	get_tree().current_scene.add_child(smoke)
	smoke.position = start_position
	smoke.rotation = ship_direction.angle() - PI/2

	# Determine the spread direction for slight variation
	var spread_angle = deg_to_rad((i - 2) * 2)
	var spread_direction = left_direction.rotated(spread_angle)
	smoke.flip_v = spread_direction.x < 0

	var cannonball_distance = (((BASE_CANNONBALL_DISTANCE * 1.0) + 50) * randf_range(0.85, 1.15))

	# --- NEW: pass boat's velocity (self.velocity) so the cannonball can inherit the ship’s movement.
	#     Make sure the cannonball script actually accepts and uses that velocity.
	c.start(start_position, spread_direction, cannonball_distance, self, velocity)

	# --- If you also want the smoke to move with boat velocity, pass it similarly
	#     (assuming the smoke script has a method or property to store it).
	smoke.start(velocity)

func shoot_right():
	if not can_shoot:
			return
	can_shoot = false

	emit_signal("cannons_fired_right")

	# Start GunCooldown immediately when shoot is pressed.
	$GunCooldown.start()
	
	shot_splash_played = false
	shot_hit_played = false
	
	var indices = [4, 3, 2, 1, 0]
	# Schedule each cannon to fire after a random delay between 0 and 1 second
	for i in indices:
		var delay = randf_range(0, 0.8)  # random float in [0,1)
		var timer = Timer.new()
		timer.one_shot = true
		timer.wait_time = delay
		add_child(timer)
		timer.timeout.connect(Callable(self, "_fire_right_cannon").bind(i))
		timer.start()

func _fire_right_cannon(i):
	var ship_direction = calculate_direction()
	var right_direction = Vector2(-ship_direction.y, ship_direction.x)

	# Camera shake for this cannon
	camera_shake(-right_direction)
	_play_shot_sound()
	_play_splash_sound()

	var c = cannonball_scene.instantiate()
	c.splash_scene = splash_scene
	c.hit_scene = hit_scene
	c.shooter = self
	get_tree().current_scene.add_child(c)

	var offset = ship_direction.normalized() * (i * 3 - 6)
	var start_position = position + offset + right_direction * 9

	# Smoke effect
	var smoke = cannon_smoke_scene.instantiate()
	get_tree().current_scene.add_child(smoke)
	smoke.position = start_position
	smoke.rotation = ship_direction.angle() + PI/2

	# Determine the spread direction for slight variation
	var spread_angle = deg_to_rad((i - 2) * 2)
	var spread_direction = right_direction.rotated(-spread_angle)
	smoke.flip_v = spread_direction.x < 0

	var cannonball_distance = (((BASE_CANNONBALL_DISTANCE * 1.0) + 50) * randf_range(0.85, 1.15))

	# --- NEW: pass boat's velocity (self.velocity) so the cannonball inherits the ship’s movement.
	c.start(start_position, spread_direction, cannonball_distance, self, velocity)

	smoke.start(velocity)   # s

# --- Gun Cooldown & Camera Shake ---
func _on_gun_cooldown_timeout():
	can_shoot = true

func camera_shake(shake_direction: Vector2):
	pass
	var amplitude = 5.0
	var duration = 0.1
	var tween = get_tree().create_tween()
	tween.tween_property($ShipCamera, "offset",
		shake_direction.normalized() * amplitude,
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property($ShipCamera, "offset", Vector2.ZERO, duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# --- Collision & Movement Helpers ---
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

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("cannonball"):
		var dmg = 10
		if area.has("damage"):
			dmg = area.damage
		take_damage(dmg)
		area.queue_free()
		print("Player hit! Damage:", dmg, "New Health:", health)

func take_damage(amount: int) -> void:
	health -= amount
	print("Player took", amount, "damage. Health now:", health)
	if health <= 0:
		print("Player has died.")
		queue_free()

# --- Docking & Bot Control ---
func drive_to_target_position(target_pos):
	is_bot_controlled = true
	target_position = target_pos
	moving_forward = false
	reset_bot_input()

var stuck_timer = 0.0
var last_distance = INF

const STUCK_TIME_LIMIT = 10.0
const SNAP_DISTANCE = 1.0

func move_to_target(delta):
	var distance_to_target = global_position.distance_to(target_position)
	if distance_to_target <= DISTANCE_TOLERANCE:
		_force_snap_to_target()
		return

	var direction_to_target = (target_position - global_position).normalized()
	var angle_to_target = direction_to_target.angle()
	var current_angle = deg_to_rad(current_frame * ANGLE_PER_FRAME)
	var angle_diff = wrapf(angle_to_target - current_angle, -PI, PI)
	var angle_diff_degrees = abs(rad_to_deg(angle_diff))

	if angle_diff_degrees > ANGLE_TOLERANCE:
		stuck_timer += delta
		var rotation_speed_adjusted = rotation_speed * delta
		if angle_diff_degrees < ANGLE_TOLERANCE * 5:
			rotation_speed_adjusted *= 0.5
		if angle_diff > 0:
			current_frame += rotation_speed_adjusted
		else:
			current_frame -= rotation_speed_adjusted

		current_frame = fmod(current_frame, NUM_FRAMES)
		if current_frame < 0:
			current_frame += NUM_FRAMES
		update_frame()
	else:
		if distance_to_target < last_distance - 0.01:
			stuck_timer = 0.0
		else:
			stuck_timer += delta

		current_speed = lerp(current_speed, target_speed, acceleration_factor * delta)
		velocity = calculate_direction() * current_speed
		global_position += velocity * delta

	if distance_to_target < SNAP_DISTANCE or stuck_timer >= STUCK_TIME_LIMIT:
		_force_snap_to_target()

	last_distance = distance_to_target

func _force_snap_to_target():
	global_position = target_position
	moving_forward = false
	velocity = Vector2.ZERO
	current_speed = 0.0
	stuck_timer = 0.0
	last_distance = 0.0
	emit_signal("player_docked")
	_choose_final_dock_angle()

func signed_angleDifference(deg1: float, deg2: float) -> float:
	var diff = deg1 - deg2
	diff = fposmod(diff + 180, 360) - 180
	return diff

func normalize_angle(deg: float) -> float:
	return fposmod(deg, 360)

func _choose_final_dock_angle():
	   # Always snap the ship to face east after docking
	target_angle = 0

func rotate_to_target_angle(delta):
	var current_angle_deg = normalize_angle(current_frame * ANGLE_PER_FRAME)
	var target_angle_norm = normalize_angle(target_angle)
	var diff = signed_angleDifference(target_angle_norm, current_angle_deg)
	
	var rotation_step = rotation_speed * delta
	if abs(diff) < ANGLE_TOLERANCE:
		current_frame = int(round(target_angle_norm / ANGLE_PER_FRAME)) % NUM_FRAMES
		update_frame()
		
		steering_angle = 0.0
		steering_velocity = 0.0
		current_rotation_speed = 0.0
		
		is_bot_controlled = false
		target_angle = -1.0
		print("DEBUG: rotate_to_target_angle -> snapped to final dock angle.")
		return

	if abs(diff) < ANGLE_TOLERANCE * 5:
		rotation_step *= 0.5
	if diff > 0:
		current_frame += rotation_step / ANGLE_PER_FRAME
	else:
		current_frame -= rotation_step / ANGLE_PER_FRAME

	current_frame = fmod(current_frame, NUM_FRAMES)
	if current_frame < 0:
		current_frame += NUM_FRAMES
	update_frame()
	print("DEBUG: rotate_to_target_angle -> current_angle_deg:", current_angle_deg,
		" target_angle_norm:", target_angle_norm, " diff:", diff)

func _input_event(viewport, event, shape_idx):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				if not _action_allowed("click_ship"):
						return
				print("Ship clicked!")
				toggle_forward_movement()

# --- Sound-Playing Helpers ---
func request_splash_sound():
	_play_splash_sound()

func request_hit_sound():
	if hit_sound_fx:
		var hit_sound = hit_sound_fx.duplicate()
		get_tree().current_scene.add_child(hit_sound)
		hit_sound.play()
		var sound_length = hit_sound.stream.get_length()
		var free_timer = Timer.new()
		free_timer.one_shot = true
		free_timer.wait_time = sound_length
		add_child(free_timer)
		free_timer.timeout.connect(Callable(hit_sound, "queue_free"))
		free_timer.start()

func _play_shot_sound():
	if cannon_shot_sound:
		var shot_sound = cannon_shot_sound.duplicate()
		get_tree().current_scene.add_child(shot_sound)
		shot_sound.global_position = global_position
		shot_sound.play()
		var sound_length = shot_sound.stream.get_length()
		var free_timer = Timer.new()
		free_timer.one_shot = true
		free_timer.wait_time = sound_length
		add_child(free_timer)
		free_timer.timeout.connect(Callable(shot_sound, "queue_free"))
		free_timer.start()

func _play_splash_sound():
	if splash_sound_fx:
		var splash_sound = splash_sound_fx.duplicate()
		get_tree().current_scene.add_child(splash_sound)
		splash_sound.global_position = global_position
		splash_sound.play()
		var sound_length = splash_sound.stream.get_length()
		var free_timer = Timer.new()
		free_timer.one_shot = true
		free_timer.wait_time = sound_length
		add_child(free_timer)
		free_timer.timeout.connect(Callable(splash_sound, "queue_free"))
		free_timer.start()

func dock_with_enemy(enemy_pos: Vector2):
	var offset = Vector2(0, 15)     # 20 px below felt too far; adjust if needed
	drive_to_target_position(enemy_pos + offset)
	target_angle = -1
