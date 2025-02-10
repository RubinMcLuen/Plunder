extends Node2D

# Reference the Camera2D and the health bar TextureRect nodes.
@onready var camera: Camera2D = $Camera2D
@onready var left_health: TextureRect = $CanvasLayer/playerhealth
@onready var right_health: TextureRect = $CanvasLayer/enemyhealth

var player: CharacterBody2D
var enemy: CharacterBody2D

@export var projectile_scene: PackedScene
@export var feint_projectile_scene: PackedScene
@export var config_file: Resource
@export var character_name: String = "CharacterName1"
@export var circle_radius: float = 64.0
@export var feint_chance: float = 0.5

var spawn_timer: Timer
var spawn_data: Array = []
var all_phases: Array = []
var current_phase_index: int = 0
var phase_failed: bool = false
var game_completed: bool = false
var game_started: bool = false
var difficulty_multiplier: float = 1.0
var current_time: float = 0.0
var num_positions: int = 4

var projectiles: Array = []

# --- Constants for Health Bar Animation ---
const SIDE_OFFSET: float = 10.0        # (Used for horizontal offset only)
const SLIDE_DURATION: float = 0.5        # Duration for sliding animation

# Constants for health atlas
const HEALTH_FRAME_SIZE: Vector2 = Vector2(33, 114)
const MAX_HEALTH_FRAME: int = 3  # Frames 0 through 3

# Variables to store current health bar frames.
var player_health_frame: int = MAX_HEALTH_FRAME
var enemy_health_frame: int = MAX_HEALTH_FRAME

# We'll store the desired final positions (from the editor) so we preserve the vertical placement.
var left_final_pos: Vector2
var right_final_pos: Vector2

# Helper function: Update the atlas region for a health bar.
func set_health_frame(health_bar: TextureRect, frame: int) -> void:
	frame = clamp(frame, 0, MAX_HEALTH_FRAME)
	if health_bar.texture is AtlasTexture:
		# Duplicate the texture so we don't modify the shared resource.
		var atlas_tex = health_bar.texture.duplicate() as AtlasTexture
		atlas_tex.region = Rect2(frame * HEALTH_FRAME_SIZE.x, 0, HEALTH_FRAME_SIZE.x, HEALTH_FRAME_SIZE.y)
		health_bar.texture = atlas_tex
	else:
		push_error("Health bar texture is not an AtlasTexture!")

func _ready() -> void:
	# Set up the camera and main process.
	camera.make_current()
	set_process(true)

	# Assign enemy (NPC) and player.
	enemy = get_parent() as CharacterBody2D
	player = get_tree().current_scene.get_node("Player") as CharacterBody2D

	if player and enemy:
		player.connect("auto_move_completed", Callable(self, "_on_player_auto_move_completed"))
		# Connect player's end_fight signal to the original end-fight function.
		player.connect("end_fight", Callable(self, "_on_end_fight"))
		# Connect enemy's end_fight signal to a new enemy-specific function.
		enemy.connect("end_fight", Callable(self, "_on_enemy_end_fight"))
		
		player.fighting = true
		enemy.fighting = true

		var offset = 36 if enemy.player_direction else -36
		var target_pos = enemy.global_position + Vector2(offset, 0)
		player.auto_move_to_position(target_pos)
		player.set_facing_direction(enemy.player_direction)
	
	# Create a Timer node for spawning projectiles.
	spawn_timer = Timer.new()
	add_child(spawn_timer)
	spawn_timer.connect("timeout", Callable(self, "_on_spawn_timer_timeout"))
	
	_create_vignette()
	
	# Store the desired final positions as set in the editor.
	# (This preserves the vertical positions you configured.)
	left_final_pos = left_health.position
	right_final_pos = right_health.position
	
	# Start the camera zoom tween.
	var tween = create_tween()
	tween.tween_property(camera, "zoom", Vector2(3, 3), 1.0) \
		.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	# When the camera tween finishes, slide in the health bars.
	tween.tween_callback(Callable(self, "_on_camera_zoom_finished"))
	
	# Move the health bars off-screen horizontally while preserving their y coordinate.
	var viewport_size = get_viewport().get_visible_rect().size
	left_health.position = Vector2(-left_health.size.x, left_final_pos.y)
	right_health.position = Vector2(viewport_size.x, right_final_pos.y)

func _process(delta: float) -> void:
	if not game_started and Input.is_action_just_pressed("ui_accept"):
		game_started = true
		_load_spawn_data()
		if spawn_data.size() > 0:
			_on_spawn_timer_timeout()  # Start spawning immediately

func _load_spawn_data():
	if config_file and character_name != "":
		var file = FileAccess.open(config_file.resource_path, FileAccess.ModeFlags.READ)
		if file:
			var file_content = file.get_as_text()
			var json_data = JSON.parse_string(file_content)
			if json_data is Dictionary and json_data.has(character_name):
				var character_data = json_data[character_name]
				all_phases = character_data.get("phases", [])
				num_positions = character_data.get("positions", 4)
	if all_phases.size() > 0:
		spawn_data = all_phases[0]

func _on_spawn_timer_timeout():
	if spawn_data.size() > 0:
		var spawn_info = spawn_data.pop_front()
		current_time = spawn_info["time"]
		_spawn_projectile(spawn_info)
		
		# Schedule the next spawn.
		if spawn_data.size() > 0:
			var next_time = spawn_data[0]["time"]
			var delay = max(next_time - current_time, 0.0001)
			spawn_timer.start(delay)
		else:
			_check_remaining_projectiles()
	else:
		_check_remaining_projectiles()

func _spawn_projectile(spawn_info: Dictionary):
	var is_feint = randf() < feint_chance
	var projectile
	if is_feint and feint_projectile_scene:
		projectile = feint_projectile_scene.instantiate()
	else:
		projectile = projectile_scene.instantiate()
		
	if projectile:
		# Calculate spawn position and rotation.
		var position_index = int(spawn_info["position"]) - 1
		var angle = (position_index + 1) * TAU / num_positions - TAU / 4
		var center = get_viewport().get_visible_rect().size / 2
		var pos = center + Vector2(cos(angle), sin(angle)) * circle_radius
		projectile.z_index = 11
		projectile.position = pos
		projectile.rotation = angle
		projectile.speed = spawn_info["speed"] * difficulty_multiplier
		
		add_child(projectile)
		register_projectile(projectile)
		
		# Connect projectile signals.
		projectile.connect("reached_target", Callable(self, "_on_projectile_reached_target"))
		if is_feint:
			projectile.connect("sliced", Callable(self, "_on_feint_projectile_sliced"))
	
	# Spawn a 1×1 ColorRect at the center.
	var center = get_viewport().get_visible_rect().size / 2
	var color_rect = ColorRect.new()
	color_rect.size = Vector2(1, 1)
	color_rect.position = center - color_rect.size * 0.5
	add_child(color_rect)

func _on_projectile_reached_target(projectile: Area2D):
	if not (projectile is FeintProjectile):
		phase_failed = true
		if player:
			player.take_damage()
			# Update player's health frame.
			player_health_frame -= 1
			set_health_frame(left_health, player_health_frame)
		if enemy:
			enemy.play_slash_animation()
	if is_instance_valid(projectile):
		projectile.queue_free()
		
func _on_feint_projectile_sliced(projectile: FeintProjectile):
	phase_failed = true
	if player:
		player.take_damage()
		# Update player's health frame.
		player_health_frame -= 1
		set_health_frame(left_health, player_health_frame)
	if enemy:
		enemy.play_slash_animation()
	if is_instance_valid(projectile):
		projectile.queue_free()

func _check_remaining_projectiles():
	if game_completed:
		return
	for child in get_children():
		if is_instance_valid(child) and child is Area2D:
			return
	_transition_to_next_phase()

func _transition_to_next_phase():
	if game_completed:
		return
	
	if not phase_failed:
		if player:
			player.play_slash_animation()
		if enemy:
			enemy.take_damage()
			# Update enemy's health frame.
			enemy_health_frame -= 1
			set_health_frame(right_health, enemy_health_frame)
		
	phase_failed = false
	current_phase_index += 1
	
	if current_phase_index < all_phases.size():
		spawn_data = all_phases[current_phase_index]
		current_time = 0.0
		spawn_timer.stop()
		if spawn_data.size() > 0:
			spawn_timer.start(0.001)
	else:
		game_completed = true
		spawn_data.clear()

func _on_player_auto_move_completed() -> void:
	player.set_facing_direction(enemy.player_direction)
	var tween = create_tween()
	tween.tween_property(camera, "zoom", Vector2(3, 3), 1.0) \
		.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	# After zooming in, slide the health bars in.
	tween.tween_callback(Callable(self, "_on_camera_zoom_finished"))

func _on_camera_zoom_finished() -> void:
	# Tween the health bars from their off-screen positions back to their stored final positions.
	var tween_left = create_tween()
	tween_left.tween_property(left_health, "position", left_final_pos, SLIDE_DURATION) \
		 .set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
		 
	var tween_right = create_tween()
	tween_right.tween_property(right_health, "position", right_final_pos, SLIDE_DURATION) \
		 .set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)

func slide_out_health_bars(callback: Callable) -> void:
	# Compute off-screen positions based on the viewport size.
	var viewport_size = get_viewport().get_visible_rect().size
	var left_offscreen = Vector2(-left_health.size.x, left_health.position.y)
	var right_offscreen = Vector2(viewport_size.x, right_health.position.y)
	
	var tween = create_tween()
	tween.tween_property(left_health, "position", left_offscreen, SLIDE_DURATION) \
		.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(right_health, "position", right_offscreen, SLIDE_DURATION) \
		.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(callback)

func _on_end_fight() -> void:
	if spawn_timer:
		spawn_timer.stop()
	
	despawn_all_projectiles()
	
	var vignette = get_node("Vignette")
	if not vignette:
		return

	var tween = create_tween()
	tween.tween_property(vignette.material, "shader_parameter/overlay_strength", 0.0, 1.0) \
			.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	# Slide out health bars, then zoom the camera out.
	slide_out_health_bars(Callable(self, "_start_camera_zoom_out"))

func _start_camera_zoom_out() -> void:
	var tween = create_tween()
	tween.tween_property(camera, "global_position", player.global_position, 1.0) \
		.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "zoom", Vector2(1, 1), 1.0) \
		.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(Callable(self, "_on_end_fight_complete"))

func _on_end_fight_complete() -> void:
	player.fighting = false
	enemy.fighting = false
	queue_free()

func _on_enemy_end_fight() -> void:
	if spawn_timer:
		spawn_timer.stop()
	
	despawn_all_projectiles()
	
	var vignette = get_node("Vignette")
	if not vignette:
		return

	var tween = create_tween()
	tween.tween_property(vignette.material, "shader_parameter/overlay_strength", 0.0, 1.0) \
			.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	# Slide out health bars, then zoom the camera out for enemy end-fight.
	slide_out_health_bars(Callable(self, "_start_camera_zoom_out_enemy"))

func _start_camera_zoom_out_enemy() -> void:
	var tween = create_tween()
	tween.tween_property(camera, "global_position", enemy.global_position, 1.0) \
		.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "zoom", Vector2(1, 1), 1.0) \
		.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(Callable(self, "_on_enemy_end_fight_complete"))

func _on_enemy_end_fight_complete() -> void:
	player.fighting = false
	enemy.fighting = false
	queue_free()

func register_projectile(projectile: Node):
	if projectile not in projectiles:
		projectiles.append(projectile)

func deregister_projectile(projectile: Node):
	if projectile in projectiles:
		projectiles.erase(projectile)

func despawn_all_projectiles():
	for projectile in projectiles:
		if is_instance_valid(projectile):
			projectile.queue_free()
	projectiles.clear()

func _create_vignette() -> void:
	var vignette = ColorRect.new()
	vignette.name = "Vignette"
	
	var viewport_rect = get_viewport().get_visible_rect()
	vignette.position = viewport_rect.position
	vignette.size = viewport_rect.size
	
	vignette.z_index = 10
	vignette.modulate = Color(1, 1, 1, 1)
	
	var shader = Shader.new()
	shader.code = """
		shader_type canvas_item;
		
		// Uniforms for adjusting the clear center.
		uniform vec2 vignette_scale = vec2(1.0, 1.0);
		uniform float inner_radius : hint_range(0.0, 1.0) = 0.1;
		uniform float outer_radius : hint_range(0.0, 1.0) = 0.4;
		uniform vec2 center = vec2(0.5, 0.5);
		uniform float overlay_strength : hint_range(0.0, 1.0) = 0.0;
		
		void fragment() {
			vec2 uv = SCREEN_UV;
			float dist = length((uv - center) * vignette_scale);
			float factor = smoothstep(inner_radius, outer_radius, dist);
			float final_alpha = factor * overlay_strength;
			COLOR = vec4(0.0, 0.0, 0.0, final_alpha);
		}
	"""
	
	var shader_material = ShaderMaterial.new()
	shader_material.shader = shader
	shader_material.set_shader_parameter("overlay_strength", 0.0)
	
	vignette.material = shader_material
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	add_child(vignette)
	
	var tween = create_tween()
	tween.tween_property(vignette.material, "shader_parameter/overlay_strength", 0.7, 2.0)
