extends NPC
class_name CrewMemberNPC

const BOARD_SPEED       : float = 50.0
const DRAG_SPEED        : float = 200.0
const ATTACK_COOLDOWN   : float = 0.8
const CREW_ATTACK_ANIMS : Array[String] = ["AttackSlash", "AttackLunge"]

var battle_manager: Node
var board_target  : Vector2
var dragging      : bool  = false
var is_boarding   : bool  = false
var has_boarded   : bool  = false
var cooldown      : float = 0.0
var targets       : Array = []  # removed type hint to avoid parsing errors

# New variables for auto-boarding
var auto_boarding: bool = false
var plank_start_target: Vector2
var walking_to_plank: bool = false

# Pathfinding system variables
var pathfinding_mode: bool = false
var pathfinding_target: Node2D = null
var pathfinding_velocity: Vector2 = Vector2.ZERO
var pathfinding_manager: PathfindingManager = null
var combat_target: Node2D = null
var post_combat_waiting: bool = false
var in_combat_range: bool = false

# Demo control variables
var can_attack: bool = true
var attack_affects_enemy: bool = true

@onready var melee_area    : Area2D           = $MeleeRange
@onready var click_area    : Area2D           = $Area2D
@onready var select_hitbox : CollisionShape2D = $Area2D/SelectHitbox

var rng := RandomNumberGenerator.new()

func _ready() -> void:
	super._ready()

	# override generic crew palette (you can customize if needed)
	body_mat.set_shader_parameter(
		"map_texture",
		preload("res://Battle/crewskins.png")
	)

	rng.randomize()

	# Check what progress point we're at to determine initial animation
	var battle_scene = get_tree().current_scene
	var progress = 0
	if battle_scene and "progress_point" in battle_scene:
		progress = battle_scene.progress_point

	# For camera transition step (7) and later, always start with sword idle
	if progress >= 7:
		idle_with_sword = true
		if sword:
			sword.visible = true
			sword.play("IdleSword")
		appearance.play("IdleSword")
		print("Crew _ready: Starting with IdleSword for progress ", progress)
	else:
		# Start without sword until boarding or fighting
		if sword:
			sword.visible = false
		print("Crew _ready: Starting without sword for progress ", progress)

	click_area.input_event.connect(_on_click)
	melee_area.body_entered.connect(_on_target_enter)
	melee_area.body_exited.connect(_on_target_exit)
	
	# Configure based on battle progress point
	_configure_for_progress_point()

func _configure_for_progress_point() -> void:
	var battle_scene = get_tree().current_scene
	if not battle_scene:
		return
		
	var progress = 0
	if "progress_point" in battle_scene:
		progress = battle_scene.progress_point
	
	match progress:
		0, 1, 2, 3: # Early stages - no attacking (indices 0-3)
			can_attack = false
			attack_affects_enemy = false
		4: # Add melee ranges - can attack but no effect (index 4)
			can_attack = true
			attack_affects_enemy = false
		5: # Enemy takes damage - can attack and affects enemy (index 5)
			can_attack = true
			attack_affects_enemy = true
		6, 7, 8, 9, 10: # Full functionality including camera transition (index 6+)
			can_attack = true
			attack_affects_enemy = true
		11: # Pathfinding mode (index 11)
			can_attack = true
			attack_affects_enemy = true
			# Pathfinding will be enabled when crew boards

func _on_click(_vp, e: InputEvent, _i) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
		print("Crew clicked!")
		if battle_manager:
			print("Battle manager exists, calling select_unit")
			# Different behavior based on progress point
			var battle_scene = get_tree().current_scene
			var progress = 0
			if battle_scene and "progress_point" in battle_scene:
				progress = battle_scene.progress_point
			
			print("Progress point: ", progress)
			# Auto-boarding crews (progress 10+) don't respond to clicks if pathfinding
			if not auto_boarding and not pathfinding_mode:
				print("Not auto_boarding or pathfinding, selecting unit")
				battle_manager.select_unit(self)
			else:
				print("Auto_boarding or pathfinding is true, ignoring click")
		else:
			print("No battle_manager!")

func _physics_process(delta: float) -> void:
	cooldown      = max(cooldown - delta, 0.0)
	cooldown_lock = max(cooldown_lock - delta, 0.0)

	if auto_boarding:
		_handle_auto_boarding(delta)
	elif is_boarding and not has_boarded:
		_walk_plank(delta)
	elif dragging:  # Handle dragging regardless of has_boarded status
		_drag(delta)
	elif post_combat_waiting:  # Waiting after defeating an enemy
		velocity = Vector2.ZERO
		# Just idle, waiting for reassignment
	elif pathfinding_mode:  # Handle pathfinding movement
		_handle_pathfinding(delta)
	elif combat_target and is_instance_valid(combat_target):  # Handle combat positioning and attacking
		_handle_combat(delta)
	elif (fighting or can_attack) and can_attack:  # Allow attacking if either fighting OR can_attack is true
		_auto_attack()
	else:
		velocity = Vector2.ZERO

	_update_base_anim(dragging or walking_to_plank or (pathfinding_mode and velocity.length() > 0.1))
	move_and_slide()

func _handle_auto_boarding(delta: float) -> void:
	if walking_to_plank:
		# Walking to the start of the plank
		var dir = plank_start_target - global_position
		if dir.length() < 4.0:
			# Reached the plank start, now board across it
			walking_to_plank = false
			is_boarding = true
			has_boarded = false
			fighting = false
			idle_with_sword = false
		else:
			velocity = dir.normalized() * speed
			set_facing_direction(dir.x < 0)
	elif is_boarding and not has_boarded:
		# Walking across the plank to the enemy ship
		_walk_plank(delta)

func start_auto_boarding(plank_start: Vector2, board_target: Vector2) -> void:
	auto_boarding = true
	walking_to_plank = true
	plank_start_target = plank_start
	self.board_target = board_target
	fighting = false
	idle_with_sword = false

# Pathfinding system functions
func set_pathfinding_mode(enabled: bool, target: Node2D = null) -> void:
	pathfinding_mode = enabled
	pathfinding_target = target
	
	if enabled:
		fighting = false  # Disable combat while pathfinding
		idle_with_sword = false  # Hide sword while pathfinding
		combat_target = null
		in_combat_range = false
		print("Crew ", npc_name, " entering pathfinding mode to ", target.npc_name if target else "unknown")
	else:
		print("Crew ", npc_name, " exiting pathfinding mode")

func set_combat_target(target: Node2D) -> void:
	if not is_instance_valid(target):
		print("Crew ", npc_name, " received invalid combat target")
		return
		
	combat_target = target
	pathfinding_mode = false
	fighting = true
	idle_with_sword = true
	in_combat_range = true
	
	# Notify pathfinding manager that we're now engaged in combat
	if pathfinding_manager and is_instance_valid(pathfinding_manager):
		pathfinding_manager.mark_crew_as_engaged(self)
	
	print("Crew ", npc_name, " entering combat with ", target.npc_name if target else "unknown", " at distance: ", global_position.distance_to(target.global_position))

func start_post_combat_wait(wait_time: float) -> void:
	post_combat_waiting = true
	combat_target = null
	fighting = false
	idle_with_sword = false
	in_combat_range = false
	
	# Notify pathfinding manager that we're now waiting
	if pathfinding_manager and is_instance_valid(pathfinding_manager):
		pathfinding_manager.mark_crew_as_waiting(self)
	
	print("Crew ", npc_name, " starting post-combat wait")
	
	# Create a timer to end the wait
	var timer = Timer.new()
	timer.wait_time = wait_time
	timer.one_shot = true
	add_child(timer)
	timer.timeout.connect(_end_post_combat_wait.bind(timer))
	timer.start()

func _end_post_combat_wait(timer: Timer) -> void:
	timer.queue_free()
	post_combat_waiting = false
	print("Crew ", npc_name, " ending post-combat wait")

func set_pathfinding_velocity(new_velocity: Vector2) -> void:
	pathfinding_velocity = new_velocity

func _handle_pathfinding(delta: float) -> void:
	if not pathfinding_mode:
		return
	
	# Use the velocity computed by the pathfinding manager
	velocity = pathfinding_velocity
	
	# Update facing direction
	if velocity.length() > 0.1:
		set_facing_direction(velocity.x < 0)
	elif pathfinding_target and is_instance_valid(pathfinding_target):
		var dir_to_target = pathfinding_target.global_position - global_position
		set_facing_direction(dir_to_target.x < 0)

func _handle_combat(delta: float) -> void:
	# ------------------------------------------------------------------
	# 1)  Abort combat if the target vanished
	# ------------------------------------------------------------------
	if combat_target == null or not is_instance_valid(combat_target):
		print("Crew ", npc_name, " combat target invalid, exiting combat")
		fighting        = false
		in_combat_range = false
		combat_target   = null
		if pathfinding_manager and is_instance_valid(pathfinding_manager):
			pathfinding_manager.mark_crew_as_waiting(self)
		return

	# ------------------------------------------------------------------
	# 2)  Face the opponent
	# ------------------------------------------------------------------
	var dir_to_target := combat_target.global_position - global_position
	set_facing_direction(dir_to_target.x < 0)

	# ------------------------------------------------------------------
	# 3)  Hold the exact ±side_distance slot while fighting
	# ------------------------------------------------------------------
	var side_dist : float = 20.0                # default in case manager is null
	if pathfinding_manager and is_instance_valid(pathfinding_manager):
		side_dist = pathfinding_manager.side_distance

	var target_pos        : Vector2 = combat_target.global_position
	var current_pos       : Vector2 = global_position
	var should_be_on_left : bool    = current_pos.x < target_pos.x

	var ideal_position = Vector2(
		target_pos.x + ( side_dist  if not should_be_on_left else -side_dist ),
		target_pos.y
	)

	var distance_to_ideal := current_pos.distance_to(ideal_position)

	if distance_to_ideal > 1.0:              # More than 1 px off → shuffle into place
		var direction := (ideal_position - current_pos).normalized()
		velocity      = direction * 30.0     # slow, precise nudge
	else:                                     # In the slot → stop & attack
		velocity = Vector2.ZERO
		_auto_attack()                       # uses your existing cooldown logic


# Override the _exit_tree to clean up pathfinding manager references
func _exit_tree() -> void:
	if pathfinding_manager and is_instance_valid(pathfinding_manager):
		pathfinding_manager.unregister_crew_member(self)

func update_animation() -> void:
	# 1) Animation override (slash/lunge/block/hurt)
	if anim_override:
		if sword:
			sword.visible = true

		match current_anim:
			"slash":
				if appearance.animation != "AttackSlash" or not appearance.is_playing():
					appearance.play("AttackSlash")
				if sword and (sword.animation != "AttackSlash" or not sword.is_playing()):
					sword.play("AttackSlash")
			"lunge":
				if appearance.animation != "AttackLunge" or not appearance.is_playing():
					appearance.play("AttackLunge")
				if sword and (sword.animation != "AttackLunge" or not sword.is_playing()):
					sword.play("AttackLunge")
			"block":
				if appearance.animation != "AttackBlock" or not appearance.is_playing():
					appearance.play("AttackBlock")
				if sword and (sword.animation != "AttackBlock" or not sword.is_playing()):
					sword.play("AttackBlock")
			"hurt":
				if appearance.animation != "Hurt" or not appearance.is_playing():
					appearance.play("Hurt")
				if sword and (sword.animation != "Hurt" or not sword.is_playing()):
					sword.play("Hurt")

		# Sync flipping and speed
		appearance.flip_h = (direction == Vector2.LEFT)
		if sword:
			sword.flip_h      = appearance.flip_h
			sword.speed_scale = appearance.speed_scale
			sword.frame       = appearance.frame

		# End the override after its duration
		if Time.get_ticks_msec() - anim_override_start_time >= anim_override_duration:
			anim_override = false

		return

	# 2) Moving (walking to plank, dragging, or boarding) → Walk, sword hidden
	if walking_to_plank or dragging or (is_boarding and not has_boarded):
		if appearance.animation != "Walk":
			appearance.play("Walk")
		if sword:
			sword.visible = false
		appearance.flip_h = (direction == Vector2.LEFT)
		return
	
	# 3) Pathfinding movement - walk with NO sword visible
	if pathfinding_mode and velocity.length() > 0.1:
		if appearance.animation != "Walk":
			appearance.play("Walk")
		if sword:
			sword.visible = false  # Hide sword while pathfinding
		appearance.flip_h = (direction == Vector2.LEFT)
		return
	
	# 4) Post-combat waiting - idle without sword
	if post_combat_waiting:
		if appearance.animation != "IdleStand":
			appearance.play("IdleStand")
		if sword:
			sword.visible = false
		appearance.flip_h = (direction == Vector2.LEFT)
		return

	# 5) Any other movement → Walk, sword hidden
	if velocity.length() > 0.1:
		if appearance.animation != "Walk":
			appearance.play("Walk")
		if sword:
			sword.visible = false
		appearance.flip_h = (direction == Vector2.LEFT)
		return

	# 6) Idle-with-sword (combat stance) - ALWAYS use this if idle_with_sword is true
	if idle_with_sword:
		if appearance.animation != "IdleSword":
			appearance.play("IdleSword")
		if sword:
			sword.visible = true
			if sword.animation != "IdleSword":
				sword.play("IdleSword")
			# **Sync frames here**
			sword.speed_scale = appearance.speed_scale
			sword.frame       = appearance.frame
			sword.flip_h      = appearance.flip_h
		appearance.flip_h = (direction == Vector2.LEFT)
		return

	# 7) Rest → IdleStand, sword hidden
	if appearance.animation != "IdleStand":
		appearance.play("IdleStand")
	if sword:
		sword.visible = false
	appearance.flip_h = (direction == Vector2.LEFT)

func _walk_plank(_delta: float) -> void:
	var dir = board_target - global_position
	if dir.length() < 4.0:
		has_boarded       = true
		fighting          = true
		idle_with_sword   = true
		auto_boarding     = false
		walking_to_plank  = false
		is_boarding       = false
		
		# Register with pathfinding manager for progress point 11+
		var battle_scene = get_tree().current_scene
		var progress = 0
		if battle_scene and "progress_point" in battle_scene:
			progress = battle_scene.progress_point
		
		if progress >= 11:
			pathfinding_manager = battle_scene.get_node_or_null("PathfindingManager")
			if pathfinding_manager:
				pathfinding_manager.register_crew_member(self)
				pathfinding_manager.assign_target_to_crew(self)
		
		# For manual deploy and auto systems, make sure they remain draggable after boarding
		if progress >= 8:  # Manual deploy (8) and auto systems (9+)
			# Keep battle_manager reference so they stay draggable
			pass  # battle_manager should already be set
		
		appearance.play("IdleSword")
		if sword:
			sword.visible = true
			sword.play("IdleSword")
			sword.frame = appearance.frame
		velocity = Vector2.ZERO
		dragging = false
	else:
		velocity = dir.normalized() * BOARD_SPEED
	set_facing_direction(dir.x < 0)

func _drag(_delta: float) -> void:
	var hit_center = select_hitbox.global_transform.origin
	var dir        = get_global_mouse_position() - hit_center
	velocity = Vector2.ZERO if dir.length() < 4.0 else dir.normalized() * DRAG_SPEED
	if dir.x != 0.0:
		set_facing_direction(dir.x < 0)

func _auto_attack() -> void:
	# Debug: Always print when _auto_attack is called
	if randf() < 0.1:
		print("AUTO_ATTACK DEBUG - Crew ", npc_name, " _auto_attack() called")
	
	# For combat target system, check if we have a specific combat target
	if combat_target and is_instance_valid(combat_target):
		if randf() < 0.1:
			print("AUTO_ATTACK - Crew ", npc_name, " has combat target: ", combat_target.npc_name, " cooldown: ", cooldown, " can_attack: ", can_attack)
		
		if cooldown > 0.0 or not can_attack:
			if randf() < 0.1:
				print("AUTO_ATTACK - Crew ", npc_name, " blocked: cooldown=", cooldown, " can_attack=", can_attack)
			return
		
		print("AUTO_ATTACK - Crew ", npc_name, " attacking combat target ", combat_target.npc_name)
		# Attack the specific combat target
		_attack_target(combat_target)
		return
	
	# Original auto-attack logic for area-based targeting
	if targets.is_empty() or cooldown > 0.0 or not can_attack:
		if randf() < 0.1:
			print("AUTO_ATTACK - Crew ", npc_name, " no targets or blocked: targets=", targets.size(), " cooldown=", cooldown, " can_attack=", can_attack)
		return

	# Debug output for all progress points
	var battle_scene = get_tree().current_scene
	var progress = 0
	if battle_scene and "progress_point" in battle_scene:
		progress = battle_scene.progress_point
	
	print("Progress ", progress, ": Crew attempting attack, can_attack=", can_attack, ", attack_affects_enemy=", attack_affects_enemy, ", fighting=", fighting)

	var tgt = targets[0]
	if not is_instance_valid(tgt):
		targets.pop_front()
		return

	_attack_target(tgt)

func _attack_target(tgt: Node) -> void:
	if not is_instance_valid(tgt):
		return
		
	set_facing_direction(tgt.global_position.x < global_position.x)

	var anim = CREW_ATTACK_ANIMS[rng.randi() % CREW_ATTACK_ANIMS.size()]
	if anim == "AttackSlash":
		play_slash_animation()
	else:
		play_lunge_animation()

	velocity      = Vector2.ZERO
	cooldown      = ATTACK_COOLDOWN
	cooldown_lock = ATTACK_COOLDOWN
	var delay = _hit_delay(anim, 5)
	await get_tree().create_timer(delay).timeout
	
	# Check if target is still valid before damaging
	if not is_instance_valid(tgt):
		return
		
	if attack_affects_enemy:
		var battle_scene = get_tree().current_scene
		var progress = 0
		if battle_scene and "progress_point" in battle_scene:
			progress = battle_scene.progress_point
		print("Actually damaging enemy at progress ", progress)
		
		# Check if this will defeat the enemy
		var enemy_will_die = false
		if tgt.has_method("get") and "health" in tgt:
			enemy_will_die = tgt.health <= 1
		
		tgt.take_damage()
		
		# If enemy was defeated and we have a pathfinding manager, notify it
		# Store the reference before the enemy gets freed
		if enemy_will_die and pathfinding_manager and is_instance_valid(pathfinding_manager):
			# Call this deferred to avoid the freed object issue
			call_deferred("_notify_enemy_defeated", tgt, self)
	else:
		var battle_scene = get_tree().current_scene
		var progress = 0
		if battle_scene and "progress_point" in battle_scene:
			progress = battle_scene.progress_point
		print("Attack animation only, no damage at progress ", progress)

func _notify_enemy_defeated(enemy: Node, crew: Node) -> void:
	if pathfinding_manager and is_instance_valid(pathfinding_manager):
		pathfinding_manager.on_enemy_defeated(enemy, crew)

func _on_target_enter(n: Node) -> void:
	# We can still check "is EnemyNPC" even if not type‐hinted 
	if n is EnemyNPC and not targets.has(n):
		targets.append(n)
		
		# Debug for all progress points
		var battle_scene = get_tree().current_scene
		var progress = 0
		if battle_scene and "progress_point" in battle_scene:
			progress = battle_scene.progress_point
		
		print("Progress ", progress, ": Enemy entered range, targets now: ", targets.size(), ", can_attack: ", can_attack, ", fighting: ", fighting)

func _on_target_exit(n: Node) -> void:
	if n is EnemyNPC:
		targets.erase(n)

func start_board() -> void:
	# Legacy function - still used by old manual boarding system
	is_boarding = true

func start_drag() -> void:
	dragging = true
	# Don't require has_boarded for dragging in demo mode

func stop_drag() -> void:
	dragging = false
	velocity = Vector2.ZERO

func play_slash_animation() -> void:
	_play_sword_sound()
	anim_override            = true
	current_anim             = "slash"
	anim_override_start_time = Time.get_ticks_msec()

	# ─── Compute how long AttackSlash actually is ───
	var anim_name = "AttackSlash"
	var frame_count = appearance.sprite_frames.get_frame_count(anim_name)
	# If someone changed the FPS for this animation in the SpriteFrames resource, use it:
	var fps = appearance.sprite_frames.get_animation_speed(anim_name)
	# Avoid division by zero—default to 1 fps if not set
	if fps <= 0.001:
		fps = 1.0
	# Duration in milliseconds = (frames / fps) * 1000
	anim_override_duration = int((frame_count / fps) * 1000)

	# Make sure the sword sprite (child) matches the same speed:
	if sword:
		sword.speed_scale = appearance.speed_scale

func play_lunge_animation() -> void:
	_play_sword_sound()
	anim_override            = true
	current_anim             = "lunge"
	anim_override_start_time = Time.get_ticks_msec()

	var anim_name = "AttackLunge"
	var frame_count = appearance.sprite_frames.get_frame_count(anim_name)
	var fps = appearance.sprite_frames.get_animation_speed(anim_name)
	if fps <= 0.001:
		fps = 1.0
	anim_override_duration = int((frame_count / fps) * 1000)

	if sword:
		sword.speed_scale = appearance.speed_scale

func _hit_delay(anim_name: String, frame: int) -> float:
	var fps = appearance.sprite_frames.get_animation_speed(anim_name)
	if fps <= 0.001:
		fps = 1.0
	return float(frame - 1) / fps
