extends Node2D

@onready var camera: Camera2D = $Camera2D

# Remove export variables for player and enemy; define them as regular variables instead.
var player: CharacterBody2D
var enemy: CharacterBody2D

@export var projectile_scene: PackedScene
@export var feint_projectile_scene: PackedScene
@export var config_file: Resource
@export var character_name: String = "CharacterName1"
@export var circle_radius: float = 64.0
@export var feint_chance: float = 0.5

# --- Internal variables for projectile spawning and phase management ---
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

func _ready() -> void:
	camera.make_current()
	set_process(true)
	print("DEBUG: _ready() called in Fight Script")

	# Assign enemy (NPC) and player
	enemy = get_parent() as CharacterBody2D
	player = get_tree().current_scene.get_node("Player") as CharacterBody2D

	if player and enemy:
		player.connect("auto_move_completed", Callable(self, "_on_player_auto_move_completed"))
		player.fighting = true
		enemy.fighting = true

		# Determine offset based on the NPC's side
		var offset = 36 if enemy.player_direction else -36
		var target_pos = enemy.global_position + Vector2(offset, 0)
		player.auto_move_to_position(target_pos)
		player.set_facing_direction(enemy.player_direction)
	else:
		print("DEBUG: Player or Enemy node not found!")

	# Create a Timer node for spawning projectiles, etc.
	spawn_timer = Timer.new()
	add_child(spawn_timer)
	spawn_timer.connect("timeout", Callable(self, "_on_spawn_timer_timeout"))




func _process(delta: float) -> void:
	if not game_started and Input.is_action_just_pressed("ui_accept"):
		game_started = true
		print("DEBUG: Game started!")
		_load_spawn_data()
		if spawn_data.size() > 0:
			_on_spawn_timer_timeout()  # Start spawning immediately

func _load_spawn_data():
	print("DEBUG: Loading spawn data...")
	if config_file and character_name != "":
		var file = FileAccess.open(config_file.resource_path, FileAccess.ModeFlags.READ)
		if file:
			var file_content = file.get_as_text()
			var json_data = JSON.parse_string(file_content)
			if json_data is Dictionary and json_data.has(character_name):
				var character_data = json_data[character_name]
				all_phases = character_data.get("phases", [])
				num_positions = character_data.get("positions", 4)
				print("DEBUG: Loaded phases: ", all_phases)
			else:
				print("DEBUG: Character name '", character_name, "' not found in JSON")
		else:
			print("DEBUG: Failed to open config file")
	if all_phases.size() > 0:
		spawn_data = all_phases[0]
		print("DEBUG: Using spawn_data for phase 0: ", spawn_data)
	else:
		print("DEBUG: No phases found for character:", character_name)

func _on_spawn_timer_timeout():
	print("DEBUG: Spawn timer timeout; spawn_data size =", spawn_data.size(), ", current_time =", current_time)
	if spawn_data.size() > 0:
		var spawn_info = spawn_data.pop_front()
		current_time = spawn_info["time"]
		print("DEBUG: Spawning projectile with info:", spawn_info)
		_spawn_projectile(spawn_info)
		
		# Schedule the next spawn.
		if spawn_data.size() > 0:
			var next_time = spawn_data[0]["time"]
			var delay = max(next_time - current_time, 0.0001)
			print("DEBUG: Scheduling next projectile in", delay, "seconds")
			spawn_timer.start(delay)
		else:
			print("DEBUG: No more spawn info in current phase; checking for remaining projectiles")
			_check_remaining_projectiles()
	else:
		print("DEBUG: spawn_data empty; checking remaining projectiles")
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
		
		projectile.position = pos
		projectile.rotation = angle
		projectile.speed = spawn_info["speed"] * difficulty_multiplier
		
		add_child(projectile)
		register_projectile(projectile)
		
		# Connect projectile signals.
		projectile.connect("reached_target", Callable(self, "_on_projectile_reached_target"))
		if is_feint:
			projectile.connect("sliced", Callable(self, "_on_feint_projectile_sliced"))
		
		print("DEBUG: Projectile spawned; is_feint =", is_feint, ", position =", pos, ", speed =", projectile.speed)
	else:
		print("DEBUG: Failed to instantiate projectile.")

func _on_projectile_reached_target(projectile: Area2D):
	print("DEBUG: Projectile reached target:", projectile, "| Is Feint:", projectile is FeintProjectile)
	# Only mark failure for a normal projectile.
	if not (projectile is FeintProjectile):
		phase_failed = true
		if player:
			player.play_hurt_animation()
			player.handle_projectile_hit()
		if enemy:
			enemy.play_slash_animation()
	if is_instance_valid(projectile):
		projectile.queue_free()
		

func _on_feint_projectile_sliced(projectile: FeintProjectile):
	print("DEBUG: Feint projectile sliced:", projectile)
	phase_failed = true
	if player:
		player.play_hurt_animation()
		player.handle_projectile_hit()
	if enemy:
		enemy.play_slash_animation()
	if is_instance_valid(projectile):
		projectile.queue_free()

func _check_remaining_projectiles():
	print("DEBUG: Checking remaining projectiles; total children =", get_children().size())
	if game_completed:
		print("DEBUG: Game completed; exiting check.")
		return
	for child in get_children():
		if is_instance_valid(child) and child is Area2D:
			print("DEBUG: Found active projectile:", child)
			return
	_transition_to_next_phase()

func _transition_to_next_phase():
	print("DEBUG: Transitioning to next phase. Phase failed =", phase_failed, 
		  "| Current phase index =", current_phase_index, "of", all_phases.size())
	if game_completed:
		return
	
	if not phase_failed:
		# Successful phase => the player hits the enemy
		if player:
			player.play_slash_animation()
		if enemy:
			enemy.play_hurt_animation()
	else:
		print("DEBUG: Phase failed; no success slash executed.")
	
	phase_failed = false
	current_phase_index += 1
	
	if current_phase_index < all_phases.size():
		spawn_data = all_phases[current_phase_index]
		print("DEBUG: Loaded spawn data for phase", current_phase_index, ":", spawn_data)
		current_time = 0.0  # Reset the local time for the new phase
		spawn_timer.stop()
		if spawn_data.size() > 0:
			spawn_timer.start(0.001)  # Immediate spawn for the new phase
	else:
		game_completed = true
		spawn_data.clear()
		print("DEBUG: All phases completed; game over.")

func _on_player_auto_move_completed() -> void:
	print("DEBUG: Player auto move completed.")
	# Set the facing direction based on the enemy's property.
	player.set_facing_direction(enemy.player_direction)
	var tween = create_tween()
	tween.tween_property(camera, "zoom", Vector2(3, 3), 1.0).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)

func register_projectile(projectile: Node):
	if projectile not in projectiles:
		projectiles.append(projectile)
		print("DEBUG: Registered projectile:", projectile)

func deregister_projectile(projectile: Node):
	if projectile in projectiles:
		projectiles.erase(projectile)
		print("DEBUG: Deregistered projectile:", projectile)

func despawn_all_projectiles():
	print("DEBUG: Despawning all projectiles; count =", projectiles.size())
	for projectile in projectiles:
		if is_instance_valid(projectile):
			projectile.queue_free()
	projectiles.clear()
