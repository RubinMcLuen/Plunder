# PathfindingManager.gd
extends Node2D
class_name PathfindingManager

# Scalable pathfinding system for crew members
# Uses Godot's NavigationAgent2D for future obstacle avoidance

signal path_completed(crew_member: Node)
signal target_reached(crew_member: Node, target: Node2D)

var navigation_region: NavigationRegion2D
var crew_agents: Dictionary = {}  # Node -> NavigationAgent2D
var crew_targets: Dictionary = {}  # Node -> target Node2D
var available_enemies: Array = []
var assigned_enemies: Dictionary = {}  # Node -> Array[Node]

# Pathfinding settings
@export var pathfinding_enabled: bool = true
@export var max_crew_per_enemy: int = 2
@export var target_reassignment_distance: float = 50.0
@export var arrival_threshold: float = 20.0
@export var horizontal_combat_range: float = 35.0  # How close horizontally before combat starts
@export var vertical_combat_tolerance: float = 25.0  # How much vertical difference is allowed
@export var post_combat_wait_time: float = 2.0  # Wait time after defeating an enemy

func _ready() -> void:
	# Create navigation region for the battlefield
	setup_navigation_region()
	set_process(true)

func setup_navigation_region() -> void:
	# Create a navigation region that covers the battlefield
	navigation_region = NavigationRegion2D.new()
	navigation_region.name = "BattlefieldNavigation"
	add_child(navigation_region)
	
	# Create a simple rectangular navigation mesh for now
	# This will be expanded later for obstacles
	var nav_mesh = NavigationPolygon.new()
	
	# Define the battlefield area (adjust these coordinates based on your scene)
	var battlefield_rect = Rect2(-400, -200, 800, 400)
	var points = PackedVector2Array([
		Vector2(battlefield_rect.position.x, battlefield_rect.position.y),
		Vector2(battlefield_rect.position.x + battlefield_rect.size.x, battlefield_rect.position.y),
		Vector2(battlefield_rect.position.x + battlefield_rect.size.x, battlefield_rect.position.y + battlefield_rect.size.y),
		Vector2(battlefield_rect.position.x, battlefield_rect.position.y + battlefield_rect.size.y)
	])
	
	nav_mesh.add_outline(points)
	nav_mesh.make_polygons_from_outlines()
	navigation_region.navigation_polygon = nav_mesh

func register_crew_member(crew: Node) -> void:
	if not pathfinding_enabled:
		return
		
	# Create a NavigationAgent2D for this crew member
	var agent = NavigationAgent2D.new()
	agent.name = "NavAgent_" + crew.npc_name
	
	# Configure the agent - disable avoidance since we don't care about collisions
	agent.path_desired_distance = 10.0
	agent.target_desired_distance = arrival_threshold
	agent.path_max_distance = 500.0
	agent.avoidance_enabled = false  # Disable collision avoidance
	agent.radius = 15.0
	agent.max_speed = crew.speed
	
	# Add agent to crew member and store reference
	crew.add_child(agent)
	crew_agents[crew] = agent
	
	# Connect agent signals
	agent.velocity_computed.connect(_on_agent_velocity_computed.bind(crew))
	agent.target_reached.connect(_on_agent_target_reached.bind(crew))
	
	print("Registered crew member for pathfinding: ", crew.npc_name)

func unregister_crew_member(crew: Node) -> void:
	if crew in crew_agents:
		var agent = crew_agents[crew]
		if is_instance_valid(agent):
			agent.queue_free()
		crew_agents.erase(crew)
		crew_targets.erase(crew)
		
		# Remove from enemy assignments
		for enemy in assigned_enemies:
			assigned_enemies[enemy].erase(crew)

func register_enemy(enemy: Node) -> void:
	if not enemy in available_enemies:
		available_enemies.append(enemy)
		assigned_enemies[enemy] = []
		print("Registered enemy for pathfinding: ", enemy.npc_name)

func unregister_enemy(enemy: Node) -> void:
	available_enemies.erase(enemy)
	if enemy in assigned_enemies:
		# Get affected crew but don't reassign immediately - defer it
		var affected_crew = assigned_enemies[enemy].duplicate()
		assigned_enemies.erase(enemy)
		
		# Use call_deferred to safely reassign after everything settles
		for crew in affected_crew:
			if is_instance_valid(crew):
				call_deferred("_safely_reassign_single_crew", crew)

func _safely_reassign_single_crew(crew: Node) -> void:
	# Double-check crew is still valid and not being freed
	if is_instance_valid(crew) and available_enemies.size() > 0:
		assign_target_to_crew(crew)
	elif is_instance_valid(crew):
		print("No enemies available for reassignment of crew ", crew.npc_name)

func assign_target_to_crew(crew: Node) -> void:
	if not pathfinding_enabled or not crew in crew_agents:
		return
	
	var best_enemy = find_best_enemy_for_crew(crew)
	if best_enemy:
		set_crew_target(crew, best_enemy)

func find_best_enemy_for_crew(crew: Node) -> Node:
	var best_enemy: Node = null
	var best_score = INF
	
	for enemy in available_enemies:
		if not is_instance_valid(enemy):
			continue
			
		# Skip if enemy has too many crew assigned
		var assigned_count = assigned_enemies.get(enemy, []).size()
		if assigned_count >= max_crew_per_enemy:
			continue
		
		# Calculate score based on distance and current assignments
		var distance = crew.global_position.distance_to(enemy.global_position)
		var score = distance + (assigned_count * 100)  # Penalty for crowded enemies
		
		if score < best_score:
			best_score = score
			best_enemy = enemy
	
	return best_enemy

func set_crew_target(crew: Node, target: Node) -> void:
	if not crew in crew_agents or not is_instance_valid(target):
		return
	
	# Remove from previous enemy assignment
	if crew in crew_targets:
		var old_target = crew_targets[crew]
		if old_target in assigned_enemies:
			assigned_enemies[old_target].erase(crew)
	
	# Set new target
	crew_targets[crew] = target
	assigned_enemies[target].append(crew)
	
	# Calculate a side position near the enemy
	var side_position = _calculate_side_position(crew, target)
	
	var agent = crew_agents[crew]
	agent.target_position = side_position
	
	# Enable pathfinding mode on the crew member
	if crew.has_method("set_pathfinding_mode"):
		crew.set_pathfinding_mode(true, target)
	
	print("Assigned target ", target.npc_name, " to crew ", crew.npc_name, " at side position ", side_position)

func _calculate_side_position(crew: Node, target: Node) -> Vector2:
	var crew_pos = crew.global_position
	var target_pos = target.global_position
	
	# Determine which side to approach from based on crew's current position
	var to_crew = crew_pos - target_pos
	var is_left_side = to_crew.x < 0
	
	# Use original melee range distance (around 30-35 pixels like the original system)
	var side_distance = 35.0  # Good melee combat distance
	var side_offset = Vector2(side_distance if not is_left_side else -side_distance, 0)
	
	# CRITICAL: Use exactly the same Y position as the target for perfect horizontal alignment
	var target_position = Vector2(target_pos.x + side_offset.x, target_pos.y)
	
	return target_position

func _process(delta: float) -> void:
	if not pathfinding_enabled:
		return
	
	# Update navigation for all crew members
	for crew in crew_agents:
		if not is_instance_valid(crew):
			continue
			
		var agent = crew_agents[crew]
		if not is_instance_valid(agent):
			continue
		
		# Check if we need to reassign targets
		if crew in crew_targets:
			var target = crew_targets[crew]
			if not is_instance_valid(target):
				call_deferred("_safely_reassign_single_crew", crew)
				continue
			
			# Check if crew is at proper melee range and horizontal with target
			var distance_to_target = crew.global_position.distance_to(target.global_position)
			var vertical_distance = abs(crew.global_position.y - target.global_position.y)
			
			# Use melee range distance but require perfect Y alignment
			if distance_to_target <= 40.0 and vertical_distance <= 5.0:
				# Crew is in good melee position with perfect Y alignment - switch to combat mode
				if crew.has_method("set_pathfinding_mode"):
					crew.set_pathfinding_mode(false, target)
					if is_instance_valid(target):
						crew.set_combat_target(target)
				continue
		
		# Update agent movement only if not in combat
		if agent.is_navigation_finished():
			continue
			
		var next_position = agent.get_next_path_position()
		var direction = (next_position - crew.global_position).normalized()
		var desired_velocity = direction * agent.max_speed
		
		# Since avoidance is disabled, we can directly set the velocity
		if crew.has_method("set_pathfinding_velocity"):
			crew.set_pathfinding_velocity(desired_velocity)

func _on_agent_velocity_computed(safe_velocity: Vector2, crew: Node) -> void:
	if not is_instance_valid(crew) or not crew in crew_agents:
		return
	
	# Apply the computed safe velocity to the crew member
	if crew.has_method("set_pathfinding_velocity"):
		crew.set_pathfinding_velocity(safe_velocity)

func _on_agent_target_reached(crew: Node) -> void:
	if not is_instance_valid(crew):
		return
	
	print("Crew ", crew.npc_name, " reached target area")
	
	# The crew will handle combat positioning, we just wait for them to engage
	if crew in crew_targets:
		var target = crew_targets[crew]
		if is_instance_valid(target) and crew.has_method("set_combat_target"):
			crew.set_combat_target(target)
		elif not is_instance_valid(target):
			# Target was freed, remove it and try to reassign
			crew_targets.erase(crew)
			call_deferred("_safely_reassign_single_crew", crew)

func on_enemy_defeated(enemy: Node, crew: Node) -> void:
	"""Called when a crew member defeats an enemy"""
	if not is_instance_valid(enemy) or not is_instance_valid(crew):
		return
		
	print("Enemy ", enemy.npc_name, " defeated by ", crew.npc_name)
	
	# Remove the defeated enemy from our system
	unregister_enemy(enemy)
	
	# Start wait timer for the crew member - but don't try to reassign immediately
	if crew.has_method("start_post_combat_wait"):
		crew.start_post_combat_wait(post_combat_wait_time)
	
	# Use call_deferred to safely reassign after everything settles
	call_deferred("_safely_reassign_crew_after_wait", crew)

func _safely_reassign_crew_after_wait(crew: Node) -> void:
	# Wait for the post-combat time, then try to reassign
	var timer = Timer.new()
	timer.wait_time = post_combat_wait_time
	timer.one_shot = true
	add_child(timer)
	timer.timeout.connect(_reassign_crew_after_wait.bind(crew, timer))
	timer.start()

func _reassign_crew_after_wait(crew: Node, timer: Timer) -> void:
	timer.queue_free()
	
	# Only reassign if the crew is still valid and there are enemies available
	if is_instance_valid(crew) and available_enemies.size() > 0:
		print("Reassigning crew ", crew.npc_name, " after combat wait")
		assign_target_to_crew(crew)
	elif is_instance_valid(crew):
		print("No more enemies available for crew ", crew.npc_name)

func get_navigation_region() -> NavigationRegion2D:
	return navigation_region

func is_crew_pathfinding(crew: Node) -> bool:
	return crew in crew_agents and crew in crew_targets

func force_reassign_all_targets() -> void:
	for crew in crew_agents:
		if is_instance_valid(crew):
			assign_target_to_crew(crew)

# Debug visualization
func _draw() -> void:
	if not pathfinding_enabled:
		return
	
	# Draw paths for debugging
	for crew in crew_agents:
		if not is_instance_valid(crew):
			continue
			
		var agent = crew_agents[crew]
		if not is_instance_valid(agent) or agent.is_navigation_finished():
			continue
		
		# Draw path
		var path = agent.get_current_navigation_path()
		if path.size() > 1:
			for i in range(path.size() - 1):
				draw_line(path[i] - global_position, path[i + 1] - global_position, Color.YELLOW, 2.0)
		
		# Draw target
		if crew in crew_targets:
			var target = crew_targets[crew]
			if is_instance_valid(target):
				draw_line(crew.global_position - global_position, target.global_position - global_position, Color.RED, 1.0)
