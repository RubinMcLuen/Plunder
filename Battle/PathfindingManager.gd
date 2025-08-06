# PathfindingManager.gd
extends Node2D
class_name PathfindingManager

# Simplified pathfinding system for crew members with side positioning
signal path_completed(crew_member: Node)
signal target_reached(crew_member: Node, target: Node2D)

var crew_targets: Dictionary = {}  # Node -> target Node2D
var crew_target_positions: Dictionary = {}  # Node -> Vector2 (specific target position)
var crew_assigned_sides: Dictionary = {}  # Node -> "left" or "right"
var crew_engagement_status: Dictionary = {}  # Node -> "pathfinding", "combat", "waiting"
var available_enemies: Array = []
var assigned_enemies: Dictionary = {}  # Node -> Array[Node] (all assigned crew)
var engaged_enemies: Dictionary = {}  # Node -> Array[Node] (only actively fighting crew)

# Side tracking for enemies: enemy -> {"left": crew_node, "right": crew_node}
var enemy_side_assignments: Dictionary = {}

# Pathfinding settings
@export var pathfinding_enabled: bool = true
@export var max_crew_per_enemy: int = 2  # Still 2 total, but now 1 per side
@export var arrival_threshold: float = 15.0  # How close to target position before switching to combat
@export var side_distance: float = 20.0  # How far to the side of enemies to position
@export var vertical_arrival_threshold: float = 4.0  # Vertical alignment tolerance
@export var post_combat_wait_time: float = 2.0

func _ready() -> void:
	set_process(true)
	print("PathfindingManager ready - side positioning enabled, 1 crew per side")

func register_crew_member(crew: Node) -> void:
	if not pathfinding_enabled:
		return
	crew_engagement_status[crew] = "pathfinding"
	print("Registered crew member for pathfinding: ", crew.npc_name)

func unregister_crew_member(crew: Node) -> void:
	# Clean up all references to this crew member
	crew_targets.erase(crew)
	crew_target_positions.erase(crew)
	crew_assigned_sides.erase(crew)
	crew_engagement_status.erase(crew)
	
	# Clean up assignments - this is crucial for side management
	for enemy in assigned_enemies.keys():
		assigned_enemies[enemy].erase(crew)
	for enemy in engaged_enemies.keys():
		engaged_enemies[enemy].erase(crew)
	
	# Clean up side assignments
	for enemy in enemy_side_assignments.keys():
		var sides = enemy_side_assignments[enemy]
		if sides.get("left") == crew:
			sides.erase("left")
		if sides.get("right") == crew:
			sides.erase("right")
	
	print("Unregistered crew member: ", crew.npc_name if crew else "unknown")

func register_enemy(enemy: Node) -> void:
	if not enemy in available_enemies:
		available_enemies.append(enemy)
		assigned_enemies[enemy] = []
		engaged_enemies[enemy] = []
		enemy_side_assignments[enemy] = {}  # Initialize empty side assignments
		print("Registered enemy for pathfinding: ", enemy.npc_name, " at position: ", enemy.global_position)

func unregister_enemy(enemy: Node) -> void:
	available_enemies.erase(enemy)
	if enemy in assigned_enemies:
		# Get affected crew but don't reassign immediately - defer it
		var affected_crew = assigned_enemies[enemy].duplicate()
		assigned_enemies.erase(enemy)
		engaged_enemies.erase(enemy)
		enemy_side_assignments.erase(enemy)
		
		# Use call_deferred to safely reassign after everything settles
		for crew in affected_crew:
			if is_instance_valid(crew):
				crew_engagement_status[crew] = "pathfinding"
				call_deferred("_safely_reassign_single_crew", crew)

func _safely_reassign_single_crew(crew: Node) -> void:
	# Double-check crew is still valid and not being freed
	if is_instance_valid(crew) and available_enemies.size() > 0:
		assign_target_to_crew(crew)
	elif is_instance_valid(crew):
		print("No enemies available for reassignment of crew ", crew.npc_name)

func assign_target_to_crew(crew: Node) -> void:
	if not pathfinding_enabled:
		return
	
	# Don't reassign if crew is already engaged in combat (actively fighting)
	var current_status = crew_engagement_status.get(crew, "pathfinding")
	if current_status == "combat":
		print("Crew ", crew.npc_name, " is already in combat, not reassigning")
		return
	
	var best_enemy_and_side = find_best_enemy_and_side_for_crew(crew)
	if best_enemy_and_side.has("enemy") and best_enemy_and_side.has("side"):
		set_crew_target_and_side(crew, best_enemy_and_side["enemy"], best_enemy_and_side["side"])

func find_best_enemy_and_side_for_crew(crew: Node) -> Dictionary:
	var best_enemy: Node = null
	var best_side: String = ""
	var best_distance = INF
	
	# Clean up invalid enemies first
	_cleanup_invalid_enemies()
	
	for enemy in available_enemies:
		if not is_instance_valid(enemy):
			continue
		
		# Check available sides for this enemy
		var sides = enemy_side_assignments.get(enemy, {})
		var available_sides = []
		
		# Check if left side is available
		var left_crew = sides.get("left", null)
		if not left_crew or not is_instance_valid(left_crew):
			available_sides.append("left")
		
		# Check if right side is available  
		var right_crew = sides.get("right", null)
		if not right_crew or not is_instance_valid(right_crew):
			available_sides.append("right")
		
		# If no sides available, skip this enemy
		if available_sides.is_empty():
			continue
		
		# Calculate distance to enemy - this is the primary factor
		var distance = crew.global_position.distance_to(enemy.global_position)
		
		# Always choose closest enemy first, regardless of other factors
		if distance < best_distance:
			best_distance = distance
			best_enemy = enemy
			
			# Choose the best side based on crew's current position
			var crew_pos = crew.global_position
			var enemy_pos = enemy.global_position
			var preferred_side = "left" if crew_pos.x < enemy_pos.x else "right"
			
			# Use preferred side if available, otherwise use any available side
			best_side = preferred_side if available_sides.has(preferred_side) else available_sides[0]
	
	if best_enemy and best_side != "":
		return {"enemy": best_enemy, "side": best_side}
	else:
		return {}

func _cleanup_invalid_enemies() -> void:
	# Remove invalid enemies from available list and clean up their side assignments
	var valid_enemies = []
	for enemy in available_enemies:
		if is_instance_valid(enemy):
			valid_enemies.append(enemy)
			# Clean up invalid crew from this enemy's side assignments
			_cleanup_enemy_side_assignments(enemy)
		else:
			# Clean up dictionaries for invalid enemies
			assigned_enemies.erase(enemy)
			engaged_enemies.erase(enemy)
			enemy_side_assignments.erase(enemy)
	available_enemies = valid_enemies

func _cleanup_enemy_side_assignments(enemy: Node) -> void:
	if not enemy_side_assignments.has(enemy):
		return
		
	var sides = enemy_side_assignments[enemy]
	
	# Check left side
	var left_crew = sides.get("left", null)
	if left_crew and not is_instance_valid(left_crew):
		sides.erase("left")
		print("Cleaned up invalid left crew from enemy ", enemy.npc_name)
	
	# Check right side
	var right_crew = sides.get("right", null)
	if right_crew and not is_instance_valid(right_crew):
		sides.erase("right")
		print("Cleaned up invalid right crew from enemy ", enemy.npc_name)

func set_crew_target_and_side(crew: Node, target: Node, side: String) -> void:
	if not is_instance_valid(target):
		return
	
	# Remove from previous enemy assignment
	if crew in crew_targets:
		var old_target = crew_targets[crew]
		var old_side = crew_assigned_sides.get(crew, "")
		
		if old_target in assigned_enemies:
			assigned_enemies[old_target].erase(crew)
		if old_target in engaged_enemies:
			engaged_enemies[old_target].erase(crew)
		
		# Remove from old side assignment
		if old_target in enemy_side_assignments and old_side != "":
			var old_sides = enemy_side_assignments[old_target]
			if old_sides.get(old_side) == crew:
				old_sides.erase(old_side)
	
	# Set new target and side
	crew_targets[crew] = target
	crew_assigned_sides[crew] = side
	assigned_enemies[target].append(crew)
	crew_engagement_status[crew] = "pathfinding"
	
	# Assign the side to this crew
	if not enemy_side_assignments.has(target):
		enemy_side_assignments[target] = {}
	enemy_side_assignments[target][side] = crew
	
	# Calculate side position for this crew member
	var target_position = _calculate_side_position(crew, target, side)
	crew_target_positions[crew] = target_position
	
	# Enable pathfinding mode on the crew member
	if crew.has_method("set_pathfinding_mode"):
		crew.set_pathfinding_mode(true, target)
	
	print("Assigned target ", target.npc_name, " (", side, " side) to crew ", crew.npc_name, " at position: ", target_position)

func _calculate_side_position(crew: Node, target: Node, side: String) -> Vector2:
	var target_pos = target.global_position
	
	# Position crew to the specified side of the enemy
	var side_offset_x = side_distance if side == "right" else -side_distance
	
	# Use the EXACT same Y position as the target for perfect horizontal alignment
	var target_position = Vector2(target_pos.x + side_offset_x, target_pos.y)
	
	return target_position

func mark_crew_as_engaged(crew: Node) -> void:
	"""Call this when crew starts actively fighting an enemy"""
	if not crew in crew_targets:
		return
		
	var target = crew_targets[crew]
	if not is_instance_valid(target):
		return
		
	crew_engagement_status[crew] = "combat"
	if not engaged_enemies.has(target):
		engaged_enemies[target] = []
	if not engaged_enemies[target].has(crew):
		engaged_enemies[target].append(crew)
		
		var side = crew_assigned_sides.get(crew, "unknown")
		print("Crew ", crew.npc_name, " now engaged in combat with ", target.npc_name, " on ", side, " side")

func mark_crew_as_waiting(crew: Node) -> void:
	"""Call this when crew is waiting after combat"""
	crew_engagement_status[crew] = "waiting"
	
	# Remove from engaged list
	if crew in crew_targets:
		var target = crew_targets[crew]
		if target in engaged_enemies:
			engaged_enemies[target].erase(crew)
		
		# Keep side assignment until reassigned - don't remove from enemy_side_assignments yet
		# This prevents immediate reassignment to the same side
		
		print("Crew ", crew.npc_name, " removed from engaged list for ", target.npc_name if target else "unknown")

func _process(delta: float) -> void:
	if not pathfinding_enabled:
		return
	
	# Clean up invalid crew and enemies periodically
	_cleanup_invalid_crew()
	_cleanup_invalid_enemies()
	
	# Check if any waiting crew should be reassigned
	_check_waiting_crew_for_reassignment()
	
	# Debug: Print current side assignments
	if randf() < 0.01:  # Print occasionally, not every frame
		_debug_print_side_assignments()
	
	# Update pathfinding for all crew members
	for crew in crew_targets.keys():
		if not is_instance_valid(crew):
			crew_targets.erase(crew)
			crew_target_positions.erase(crew)
			crew_assigned_sides.erase(crew)
			crew_engagement_status.erase(crew)
			continue
			
		var target = crew_targets[crew]
		if not is_instance_valid(target):
			call_deferred("_safely_reassign_single_crew", crew)
			continue
		
		var current_status = crew_engagement_status.get(crew, "pathfinding")
		
		# Only process pathfinding if crew is actually pathfinding
		if current_status != "pathfinding":
			continue
		
		# Simple pathfinding: move directly to exact side position
		var side = crew_assigned_sides.get(crew, "right")
		var target_pos = target.global_position
		var exact_target_position = Vector2(
			target_pos.x + (20.0 if side == "right" else -20.0),  # Exactly 20 pixels left/right
			target_pos.y  # Exactly same Y coordinate
		)
		
		# Update target position for this crew
		crew_target_positions[crew] = exact_target_position
		
		# Check if crew has reached their exact target position
		var horizontal_diff = abs(crew.global_position.x - exact_target_position.x)
		var vertical_diff = abs(crew.global_position.y - exact_target_position.y)

		if horizontal_diff <= arrival_threshold and vertical_diff <= vertical_arrival_threshold:
			# Reached exact position - switch to combat mode
			print("Crew ", crew.npc_name, " reached exact ", side, " side position, switching to combat with ", target.npc_name)
			mark_crew_as_engaged(crew)
			if crew.has_method("set_pathfinding_mode"):
				crew.set_pathfinding_mode(false, target)
			if crew.has_method("set_combat_target"):
				crew.set_combat_target(target)
			continue
		
		# Move directly toward the exact target position
		var direction = (exact_target_position - crew.global_position).normalized()
		var desired_velocity = direction * crew.speed * 0.8  # Slightly slower for pathfinding
		
		if crew.has_method("set_pathfinding_velocity"):
			crew.set_pathfinding_velocity(desired_velocity)

func _debug_print_side_assignments() -> void:
	print("=== SIDE ASSIGNMENTS DEBUG ===")
	for enemy in enemy_side_assignments.keys():
		if is_instance_valid(enemy):
			var sides = enemy_side_assignments[enemy]
			var left_crew = sides.get("left", null)
			var right_crew = sides.get("right", null)
			var left_name = left_crew.npc_name if left_crew and is_instance_valid(left_crew) else "empty"
			var right_name = right_crew.npc_name if right_crew and is_instance_valid(right_crew) else "empty"
			print("Enemy ", enemy.npc_name, " - Left: ", left_name, ", Right: ", right_name)

func _cleanup_invalid_crew() -> void:
	# Clean up crew references that are no longer valid
	var keys_to_remove = []
	for crew in crew_targets.keys():
		if not is_instance_valid(crew):
			keys_to_remove.append(crew)
	
	for crew in keys_to_remove:
		unregister_crew_member(crew)

func _check_waiting_crew_for_reassignment() -> void:
	# Check if any waiting crew should be reassigned to available enemy sides
	for crew in crew_engagement_status.keys():
		if crew_engagement_status[crew] == "waiting" and is_instance_valid(crew):
			# Check if there are enemies with available sides
			var has_available_side = false
			for enemy in available_enemies:
				if is_instance_valid(enemy):
					var sides = enemy_side_assignments.get(enemy, {})
					var left_available = not sides.has("left") or not is_instance_valid(sides.get("left"))
					var right_available = not sides.has("right") or not is_instance_valid(sides.get("right"))
					if left_available or right_available:
						has_available_side = true
						break
			
			if has_available_side:
				print("Reassigning waiting crew ", crew.npc_name, " to available enemy side")
				crew_engagement_status[crew] = "pathfinding"
				assign_target_to_crew(crew)

func on_enemy_defeated(enemy: Node, crew: Node) -> void:
	"""Called when a crew member defeats an enemy"""
	if not is_instance_valid(enemy) or not is_instance_valid(crew):
		return
		
	print("Enemy ", enemy.npc_name, " defeated by ", crew.npc_name)
	
	# Remove the defeated enemy from our system
	unregister_enemy(enemy)
	
	# Mark crew as waiting
	mark_crew_as_waiting(crew)
	
	# Start wait timer for the crew member
	if crew.has_method("start_post_combat_wait"):
		crew.start_post_combat_wait(post_combat_wait_time)
	
	# Use call_deferred to safely reassign after everything settles
	call_deferred("_safely_reassign_crew_after_wait", crew)

func _safely_reassign_crew_after_wait(crew: Node) -> void:
	# Wait for the post-combat time, then try to reassign
	var timer = Timer.new()
	timer.wait_time = post_combat_wait_time + 0.5  # Add extra delay
	timer.one_shot = true
	add_child(timer)
	timer.timeout.connect(_reassign_crew_after_wait.bind(crew, timer))
	timer.start()

func _reassign_crew_after_wait(crew: Node, timer: Timer) -> void:
	timer.queue_free()
	
	# Only reassign if the crew is still valid and there are enemies with available sides
	if is_instance_valid(crew) and available_enemies.size() > 0:
		print("Reassigning crew ", crew.npc_name, " after combat wait")
		crew_engagement_status[crew] = "pathfinding"
		assign_target_to_crew(crew)
	elif is_instance_valid(crew):
		print("No more enemies with available sides for crew ", crew.npc_name)

func is_crew_pathfinding(crew: Node) -> bool:
	return crew in crew_targets and crew_engagement_status.get(crew, "pathfinding") == "pathfinding"

func force_reassign_all_targets() -> void:
	for crew in crew_targets.keys():
		if is_instance_valid(crew) and crew_engagement_status.get(crew, "pathfinding") == "pathfinding":
			assign_target_to_crew(crew)
