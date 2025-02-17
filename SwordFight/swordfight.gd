extends Node2D

# ---------------------- SIGNALS ----------------------
# (Add custom signals here if needed)

# ---------------------- EXPORTS ----------------------
@export var projectile_scene: PackedScene
@export var feint_projectile_scene: PackedScene
@export var config_file: Resource
@export var character_name: String = "CharacterName1"
@export var circle_radius: float = 64.0
@export var feint_chance: float = 0.5

# ---------------------- CONSTANTS ---------------------
const SIDE_OFFSET: float = 10.0             # Horizontal offset for health bars.
const SLIDE_DURATION: float = 0.5           # Health bars slide-in/out duration.
const HEALTH_FRAME_SIZE: Vector2 = Vector2(33, 114)
const MAX_HEALTH_FRAME: int = 3  # Frames 0 to 3 in your AtlasTexture.

# ---------------------- ONREADY NODES -----------------
@onready var camera: Camera2D = $Camera2D
@onready var left_health: TextureRect = $CanvasLayer/PlayerHealthBar
@onready var right_health: TextureRect = $CanvasLayer/EnemyHealthBar

# ---------------------- VARIABLES ----------------------
var player: CharacterBody2D
var enemy: CharacterBody2D

var spawn_timer: Timer
var spawn_data: Array = []
var all_phases: Array = []
var current_phase_index: int = 0
var phase_failed: bool = false
var game_completed: bool = false
var game_started: bool = false
var fight_ended: bool = false
var difficulty_multiplier: float = 1.0
var current_time: float = 0.0
var num_positions: int = 4

var projectiles: Array[Node] = []

# Health bar frames (0 is empty, 3 is full).
var player_health_frame: int = MAX_HEALTH_FRAME
var enemy_health_frame: int = MAX_HEALTH_FRAME

# Final positions for the health bars, computed from the safe area in _ready().
var left_final_pos: Vector2
var right_final_pos: Vector2

# We don’t allow user input (e.g., "ui_accept") until the bars have slid in.
var input_allowed: bool = false

# Stored clipped safe area for this device’s screen.
var clipped_safe_area: Rect2

# Flags to delay battle start.
var player_moved: bool = false
var camera_moved: bool = false

# Variables to store the player's camera settings.
var original_cam_position: Vector2
var original_cam_zoom: Vector2

# ---------------------- LIFECYCLE ----------------------
func _ready() -> void:
	# Make our scene camera current.
	camera.make_current()
	set_process(true)

	# Get Player and Enemy references.
	enemy = get_parent() as CharacterBody2D
	player = get_tree().current_scene.get_node("Player") as CharacterBody2D

	# Connect signals from player/enemy if they exist.
	if player and enemy:
		player.connect("auto_move_completed", Callable(self, "_on_player_auto_move_completed"))
		player.connect("end_fight", Callable(self, "_on_end_fight"))
		enemy.connect("end_fight", Callable(self, "_on_enemy_end_fight"))
		player.fighting = true
		enemy.set_idle_with_sword_mode(true)

		# Automatically move the player toward the enemy before the fight starts.
		_move_player_to_enemy()

	# Create a Timer node for spawning projectiles.
	spawn_timer = Timer.new()
	add_child(spawn_timer)
	spawn_timer.connect("timeout", Callable(self, "_on_spawn_timer_timeout"))

	# Compute the clipped safe area for positioning health bars.
	clipped_safe_area = _compute_clipped_safe_area()

	# Calculate final health bar positions once on screen.
	left_final_pos = Vector2(clipped_safe_area.position.x + SIDE_OFFSET, left_health.position.y)
	right_final_pos = Vector2(
		clipped_safe_area.position.x + clipped_safe_area.size.x - right_health.size.x - SIDE_OFFSET,
		right_health.position.y
	)

	# Force health bars to render above everything else.
	left_health.z_index = 100
	right_health.z_index = 100

	# Move health bars off-screen initially.
	left_health.position = Vector2(-left_health.size.x, left_health.position.y)
	right_health.position = Vector2(
		clipped_safe_area.position.x + clipped_safe_area.size.x,
		right_health.position.y
	)

	# Start the camera transition at startup.
	_animate_camera_transition()


func _process(delta: float) -> void:
	# We no longer wait for a key press; the game will start automatically after a 3-second delay.
	pass

# ---------------------- SIGNAL CALLBACKS ----------------------

func _on_spawn_timer_timeout() -> void:
	if fight_ended:
		return

	if spawn_data.size() > 0:
		var spawn_info: Dictionary = spawn_data.pop_front()
		current_time = spawn_info["time"]
		_spawn_projectile(spawn_info)

		# Schedule next spawn if available.
		if spawn_data.size() > 0:
			var next_time = spawn_data[0]["time"]
			var delay = max(next_time - current_time, 0.0001)
			spawn_timer.start(delay)
		else:
			_check_remaining_projectiles()
	else:
		_check_remaining_projectiles()


func _on_player_auto_move_completed() -> void:
	# Once player finishes auto-moving, face the correct direction.
	player.set_facing_direction(enemy.player_direction)
	# Mark that the player has finished moving.
	player_moved = true
	# If the camera transition is complete, start the battle.
	if camera_moved:
		_start_battle()


func _on_end_fight() -> void:
	fight_ended = true
	if spawn_timer:
		spawn_timer.stop()
	despawn_all_projectiles()
	_slide_out_health_bars(Callable(self, "_fade_and_change_scene"))


func _on_enemy_end_fight() -> void:
	fight_ended = true
	if spawn_timer:
		spawn_timer.stop()
	despawn_all_projectiles()
	var vignette = get_node("Vignette")
	if vignette and vignette.material:
		var tween = create_tween()
		tween.tween_property(vignette.material, "shader_parameter/overlay_strength", 0.0, 1.0)
	_slide_out_health_bars(Callable(self, "_start_camera_zoom_out"))
	

# ---------------------- CAMERA TRANSITION (STARTUP) ----------------------
func _animate_camera_transition() -> void:
	# Get the player's Camera2D (assumed to be a child node named "Camera2D").
	var player_cam: Camera2D = player.get_node("Camera2D")
	# Use the player's camera global_position so we have the correct coordinates.
	original_cam_position = player_cam.global_position
	original_cam_zoom = player_cam.zoom

	# Set this scene's camera to exactly match the player's camera.
	camera.global_position = original_cam_position
	camera.zoom = original_cam_zoom

	# --- STEP 1: Slide the camera to the target position.
	# Since the target (240,135) is relative to this scene,
	# convert it to global coordinates.
	var target_global_pos = self.to_global(Vector2(240, 135))
	var tween_slide = create_tween()
	tween_slide.tween_property(camera, "global_position", target_global_pos, 0.5) \
		.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween_slide.tween_callback(Callable(self, "_on_slide_complete"))


func _on_slide_complete() -> void:
	# --- STEP 2: Zoom the camera to the target zoom.
	var tween_zoom = create_tween()
	tween_zoom.tween_property(camera, "zoom", Vector2(3, 3), 1.0) \
		.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween_zoom.tween_callback(Callable(self, "_on_camera_transition_complete"))


func _on_camera_transition_complete() -> void:
	# Now that the startup camera transition is complete, create the vignette.
	_create_vignette()
	camera_moved = true
	if player_moved:
		_start_battle()

# ---------------------- CAMERA TRANSITION (FIGHT END) ----------------------
func _start_camera_zoom_out() -> void:
	# When the fight is over, first zoom back to the player's camera zoom.
	var tween_zoom_back = create_tween()
	tween_zoom_back.tween_property(camera, "zoom", original_cam_zoom, 1.0) \
		.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween_zoom_back.tween_callback(Callable(self, "_on_zoom_out_complete"))


func _on_zoom_out_complete() -> void:
	# Then slide the camera back to the player's current camera global position.
	var player_cam: Camera2D = player.get_node("Camera2D")
	var target_position: Vector2 = player_cam.global_position
	var tween_slide_back = create_tween()
	tween_slide_back.tween_property(camera, "global_position", target_position, 0.3) \
		.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween_slide_back.tween_callback(Callable(self, "_on_end_fight_complete"))


func _on_end_fight_complete() -> void:
	player.fighting = false
	enemy.fighting = false
	enemy.set_idle_with_sword_mode(false)
	enemy.fightable = true
	enemy.exit_tree()
	queue_free()

# ---------------------- START BATTLE ----------------------
func _start_battle() -> void:
	enemy.fighting = true
	_slide_in_health_bars()

# ---------------------- HEALTH BARS ----------------------
func _slide_in_health_bars() -> void:
	var tween_left = create_tween()
	tween_left.tween_property(left_health, "position", left_final_pos, SLIDE_DURATION) \
		.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween_left.tween_callback(Callable(self, "_on_health_bars_slid_in"))

	var tween_right = create_tween()
	tween_right.tween_property(right_health, "position", right_final_pos, SLIDE_DURATION) \
		.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)


func _on_health_bars_slid_in() -> void:
	input_allowed = true
	# Instead of waiting for a key press, wait 3 seconds then start the game.
	await get_tree().create_timer(1.0).timeout

	_start_game()


func _start_game() -> void:
	game_started = true
	_load_spawn_data()
	if spawn_data.size() > 0:
		_on_spawn_timer_timeout()  # Start first projectile immediately.


func _slide_out_health_bars(callback: Callable) -> void:
	var left_offscreen = Vector2(clipped_safe_area.position.x - left_health.size.x, left_health.position.y)
	var right_offscreen = Vector2(clipped_safe_area.position.x + clipped_safe_area.size.x, right_health.position.y)

	var tween_left = create_tween()
	tween_left.tween_property(left_health, "position", left_offscreen, SLIDE_DURATION)

	var tween_right = create_tween()
	tween_right.tween_property(right_health, "position", right_offscreen, SLIDE_DURATION)

	var timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = SLIDE_DURATION
	add_child(timer)
	timer.connect("timeout", callback)
	timer.start()

func set_health_frame(health_bar: TextureRect, frame: int) -> void:
	frame = clamp(frame, 0, MAX_HEALTH_FRAME)
	if health_bar.texture is AtlasTexture:
		var atlas_tex = health_bar.texture.duplicate() as AtlasTexture
		atlas_tex.region = Rect2(frame * HEALTH_FRAME_SIZE.x, 0, HEALTH_FRAME_SIZE.x, HEALTH_FRAME_SIZE.y)
		health_bar.texture = atlas_tex

# ---------------------- SPAWNING / PHASES ----------------------
func _load_spawn_data() -> void:
	if config_file and character_name != "":
		var file := FileAccess.open(config_file.resource_path, FileAccess.ModeFlags.READ)
		if file:
			var file_content: String = file.get_as_text()
			var json_data = JSON.parse_string(file_content)
			if json_data is Dictionary and json_data.has(character_name):
				var character_data: Dictionary = json_data[character_name]
				all_phases = character_data.get("phases", [])
				num_positions = character_data.get("positions", 4)

	if all_phases.size() > 0:
		spawn_data = all_phases[0]


func _spawn_projectile(spawn_info: Dictionary) -> void:
	var is_feint = randf() < feint_chance
	var projectile: Node

	if is_feint and feint_projectile_scene:
		projectile = feint_projectile_scene.instantiate()
	else:
		projectile = projectile_scene.instantiate()

	if projectile:
		var position_index: int = int(spawn_info["position"]) - 1
		var angle: float = (position_index + 1) * TAU / float(num_positions) - TAU / 4

		# Spawning center = center of clipped safe area.
		var center: Vector2 = clipped_safe_area.position + clipped_safe_area.size * 0.5
		var pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * circle_radius

		if "speed" in spawn_info:
			projectile.speed = spawn_info["speed"] * difficulty_multiplier

		projectile.position = pos
		projectile.rotation = angle
		projectile.z_index = 11
		add_child(projectile)
		register_projectile(projectile)

		projectile.connect("reached_target", Callable(self, "_on_projectile_reached_target"))
		if is_feint:
			projectile.connect("sliced", Callable(self, "_on_feint_projectile_sliced"))

# ---------------------- PROJECTILE HANDLERS ----------------------
func _on_projectile_reached_target(projectile: Area2D) -> void:
	if not (projectile is FeintProjectile):
		phase_failed = true
		if player:
			player.take_damage()
			player_health_frame -= 1
			set_health_frame(left_health, player_health_frame)
		if enemy:
			enemy.play_slash_animation()

	if is_instance_valid(projectile):
		projectile.queue_free()


func _on_feint_projectile_sliced(projectile: Area2D) -> void:
	phase_failed = true
	if player:
		player.take_damage()
		player_health_frame -= 1
		set_health_frame(left_health, player_health_frame)
	if enemy:
		enemy.play_slash_animation()

	if is_instance_valid(projectile):
		projectile.queue_free()


func _check_remaining_projectiles() -> void:
	if game_completed:
		return

	for child in get_children():
		if is_instance_valid(child) and child is Area2D:
			return

	_transition_to_next_phase()


func _transition_to_next_phase() -> void:
	if game_completed:
		return

	if not phase_failed:
		if player:
			player.play_slash_animation()
		if enemy:
			enemy.take_damage()
			enemy_health_frame -= 1
			set_health_frame(right_health, enemy_health_frame)

	phase_failed = false
	current_phase_index += 1

	if current_phase_index < all_phases.size():
		spawn_data = all_phases[current_phase_index]
		current_time = 0.0
		spawn_timer.stop()
		if spawn_data.size() > 0:
			spawn_timer.start(0.001)  # Kick off next wave.
	else:
		game_completed = true
		spawn_data.clear()

# ---------------------- CLEANUP / FADE OUT ----------------------
func _fade_and_change_scene() -> void:
	var vignette: ColorRect = get_node("Vignette") if has_node("Vignette") else null
	if not vignette:
		return

	var tween = create_tween()
	tween.tween_property(vignette.material, "shader_parameter/fade", 1.0, 1.0) \
		 .set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(1.0)
	tween.tween_callback(Callable(self, "_on_fade_complete"))


func _on_fade_complete() -> void:
	get_tree().change_scene_to_file("res://Respawn/respawn.tscn")

# ---------------------- PROJECTILES MANAGEMENT ----------------------
func register_projectile(projectile: Node) -> void:
	if projectile not in projectiles:
		projectiles.append(projectile)


func deregister_projectile(projectile: Node) -> void:
	if projectile in projectiles:
		projectiles.erase(projectile)


func despawn_all_projectiles() -> void:
	for projectile in projectiles:
		if is_instance_valid(projectile):
			projectile.queue_free()
	projectiles.clear()

# ---------------------- VIGNETTE / SAFE AREA ----------------------
func _create_vignette() -> void:
	var vignette = ColorRect.new()
	vignette.name = "Vignette"
	vignette.z_index = 10
	vignette.modulate = Color(1, 1, 1, 1)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	vignette.position = viewport_rect.position
	vignette.size = viewport_rect.size

	var shader = Shader.new()
	shader.code = """
		shader_type canvas_item;

		uniform vec2 vignette_scale = vec2(1.0, 1.0);
		uniform float inner_radius : hint_range(0.0, 1.0) = 0.1;
		uniform float outer_radius : hint_range(0.0, 1.0) = 0.4;
		uniform vec2 center = vec2(0.5, 0.5);
		uniform float overlay_strength : hint_range(0.0, 1.0) = 0.7;
		uniform float fade : hint_range(0.0, 1.0) = 0.0;

		void fragment() {
			vec2 uv = SCREEN_UV;
			float dist = length((uv - center) * vignette_scale);
			float factor = smoothstep(inner_radius, outer_radius, dist);
			float vignette_alpha = factor * overlay_strength;
			float final_alpha = mix(vignette_alpha, 1.0, fade);
			COLOR = vec4(0.0, 0.0, 0.0, final_alpha);
		}
	""".strip_edges()

	var shader_material = ShaderMaterial.new()
	shader_material.shader = shader
	shader_material.set_shader_parameter("overlay_strength", 0.7)
	shader_material.set_shader_parameter("fade", 0.0)

	vignette.material = shader_material
	add_child(vignette)

	var tween = create_tween()
	tween.tween_property(vignette.material, "shader_parameter/overlay_strength", 0.7, 2.0)


func _compute_clipped_safe_area() -> Rect2:
	var safe_area_i: Rect2i = DisplayServer.get_display_safe_area()
	var safe_area: Rect2 = Rect2(safe_area_i.position, safe_area_i.size)
	var visible_rect: Rect2 = get_viewport().get_visible_rect()
	return safe_area.intersection(visible_rect)

# ---------------------- MOVEMENT / SETUP ----------------------
func _move_player_to_enemy() -> void:
	var offset := 36 if enemy.player_direction else -36
	var target_pos = enemy.global_position + Vector2(offset, 0)
	player.auto_move_to_position(target_pos)
	player.set_facing_direction(enemy.player_direction)
