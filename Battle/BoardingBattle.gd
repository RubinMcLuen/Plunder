@tool
extends Node2D
class_name BoardingBattle

# Progress point selector for YouTube demonstration
@export_enum(
	"Scenery Only",
	"Add One Crewmate", 
	"Add Boards",
	"Add Idle Enemy",
	"Add Melee Ranges",
	"Enemy Takes Damage",
	"Full Enemy AI",
	"Add Camera Transition",
	"Manual Deploy System",
	"Random Spawn Positions",
	"Smart Plank Assignment",
	"Crew Pathfinding AI"
) var progress_point: int = 11

# Preload the ocean scene so it's always included in the export
const OCEAN_TUTORIAL_SCENE: PackedScene = preload("res://Ocean/ocean.tscn")
const FADE_DURATION := 2.0

@onready var containers := [
	$PlankContainer,
	$CrewContainer,
	$EnemyContainer,
]

@onready var cam : Camera2D = $Camera2D
@onready var plank_container = $PlankContainer
@onready var crew_container = $CrewContainer
@onready var enemy_container = $EnemyContainer
@onready var enemy_spawn_area = $EnemySpawnArea

var _orig_cam_y: float = 0.0
var _battle_over: bool = false

# Demo-specific variables
var selected_crew: Node = null
var planks_in_use: Array[bool] = []
var crew_plank_assignments: Dictionary = {}

# Pathfinding system
var pathfinding_manager: PathfindingManager

func _ready() -> void:
	# Only run setup in game, not in editor
	if not Engine.is_editor_hint():
		_orig_cam_y = cam.global_position.y
		_setup_based_on_progress()
		set_process(true)

# Called when properties change in editor
func _validate_property(property: Dictionary) -> void:
	if property.name == "progress_point":
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = "Scenery Only,Add One Crewmate,Add Boards,Add Idle Enemy,Add Melee Ranges,Enemy Takes Damage,Full Enemy AI,Add Camera Transition,Manual Deploy System,Random Spawn Positions,Smart Plank Assignment,Crew Pathfinding AI"

func _setup_based_on_progress() -> void:
	# Start with clean slate
	_clear_all_entities()
	
	print("Setting up progress point: ", progress_point)
	
	match progress_point:
		0: # Scenery Only
			print("- Scenery only setup")
			_setup_scenery_only()
		1: # Add One Crewmate
			print("- Adding one draggable crewmate")
			_setup_one_crewmate()
		2: # Add Boards  
			print("- Adding boards")
			_setup_with_boards()
		3: # Add Idle Enemy
			print("- Adding idle enemy")
			_setup_with_idle_enemy()
		4: # Add Melee Ranges
			print("- Adding melee ranges")
			_setup_with_melee_ranges()
		5: # Enemy Takes Damage
			print("- Enemy takes damage")
			_setup_enemy_takes_damage()
		6: # Full Enemy AI
			print("- Full enemy AI")
			_setup_full_enemy_ai()
		7: # Add Camera Transition
			print("- Adding camera transition")
			_setup_with_camera_transition()
		8: # Manual Deploy System
			print("- Manual deploy system")
			_setup_manual_deploy()
		9: # Random Spawn Positions
			print("- Random spawn positions")
			_setup_random_spawn()
		10: # Smart Plank Assignment
			print("- Smart plank assignment")
			_setup_smart_assignment()
		11: # Crew Pathfinding AI
			print("- Crew pathfinding AI")
			_setup_pathfinding_ai()

func _clear_all_entities() -> void:
	for child in crew_container.get_children():
		child.queue_free()
	for child in enemy_container.get_children():
		child.queue_free()
	
	# Clean up pathfinding manager if it exists
	if pathfinding_manager and is_instance_valid(pathfinding_manager):
		pathfinding_manager.queue_free()
		pathfinding_manager = null
	
	# Hide all planks initially
	for plank in plank_container.get_children():
		plank.visible = false

func _setup_scenery_only() -> void:
	# Just the background ships and camera - no entities, no planks
	_setup_no_transition()

func _setup_one_crewmate() -> void:
	_setup_no_transition()
	_spawn_draggable_crew(Vector2(200, 250))

func _setup_with_boards() -> void:
	_setup_no_transition()
	_show_all_planks()
	_spawn_draggable_crew(Vector2(200, 250))

func _setup_with_idle_enemy() -> void:
	_setup_no_transition() 
	_show_all_planks()
	_spawn_draggable_crew(Vector2(200, 250))
	_spawn_idle_enemy()

func _setup_with_melee_ranges() -> void:
	_setup_no_transition()
	_show_all_planks()
	_spawn_attacking_crew(Vector2(200, 250))
	_spawn_idle_enemy()

func _setup_enemy_takes_damage() -> void:
	_setup_no_transition()
	_show_all_planks()
	_spawn_attacking_crew(Vector2(200, 250))
	_spawn_damageable_enemy()

func _setup_full_enemy_ai() -> void:
	_setup_no_transition()
	_show_all_planks()
	_spawn_attacking_crew(Vector2(200, 250))
	_spawn_full_enemy()

func _setup_with_camera_transition() -> void:
	_setup_fade_in()
	_show_all_planks()
	_spawn_draggable_crew(Vector2(200, 250))  # Back to normal crew spawn position
	_spawn_full_enemy()
	
	# Camera transition is now handled by the modified camera script

func _setup_manual_deploy() -> void:
	_setup_fade_in()
	_show_all_planks()
	_spawn_multiple_crew_on_planks()
	_spawn_multiple_enemies()
	
	# Camera transition for manual deploy too
	var tween = create_tween()
	tween.tween_property(cam, "global_position:y", 121, 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

func _setup_random_spawn() -> void:
	_setup_no_transition()  # Remove camera transition
	_show_all_planks()
	_spawn_multiple_crew_random()
	_spawn_multiple_enemies()

func _setup_smart_assignment() -> void:
	_setup_no_transition()
	_show_all_planks()
	_spawn_crew_with_smart_assignment()
	_spawn_multiple_enemies()

func _setup_pathfinding_ai() -> void:
	_setup_no_transition()
	_show_all_planks()
	_setup_pathfinding_manager()
	_spawn_crew_with_pathfinding()
	_spawn_multiple_enemies_for_pathfinding()

func _setup_pathfinding_manager() -> void:
	# Create and configure the pathfinding manager
	pathfinding_manager = PathfindingManager.new()
	pathfinding_manager.name = "PathfindingManager"
	pathfinding_manager.position = Vector2.ZERO
	add_child(pathfinding_manager)
	
	# Configure pathfinding settings
	pathfinding_manager.pathfinding_enabled = true
	pathfinding_manager.max_crew_per_enemy = 2
	pathfinding_manager.arrival_threshold = 25.0
	
	print("Pathfinding manager created and configured")

func _spawn_crew_with_pathfinding() -> void:
	var crew_scene = preload("res://Character/NPC/CrewMember/CrewMember.tscn")
	# Use enemy spawn area as reference but mirror it to the other side
	var cs = enemy_spawn_area.get_node("CollisionShape2D")
	var rect = cs.shape as RectangleShape2D
	var enemy_center = cs.global_position
	var ext = rect.extents
	
	# Mirror the spawn area to the opposite side of the planks
	var crew_center = Vector2(enemy_center.x, enemy_center.y + 200)  # Move down to player ship side
	var planks = plank_container.get_children()
	
	# Initialize plank tracking
	planks_in_use.resize(planks.size())
	planks_in_use.fill(false)
	
	# Spawn 5 crew members instead of 1
	for i in range(5):
		var crew = crew_scene.instantiate()
		var offset = Vector2(randf_range(-ext.x, ext.x), randf_range(-ext.y, ext.y))
		crew.global_position = crew_center + offset
		crew.npc_name = "Crew " + str(i + 1)
		crew.fighting = false  # Will be enabled after pathfinding
		crew.idle_with_sword = false  # Will be enabled when boarding
		crew.battle_manager = self  # Enable dragging for testing
		
		# Assign plank using smart logic
		var assigned_plank_index = _assign_plank_to_crew(crew, planks)
		var plank = planks[assigned_plank_index]
		
		crew.board_target = plank.global_position + Vector2(0, -33)
		crew_plank_assignments[crew] = {
			"plank_index": assigned_plank_index,
			"plank_start": plank.global_position + Vector2(0, 33),
			"board_target": plank.global_position + Vector2(0, -33),
			"walking_speed": randf_range(0.7, 1.0)
		}
		
		crew_container.add_child(crew)
	
	# Start boarding after a short delay
	await get_tree().process_frame
	_start_staggered_boarding()

func _spawn_multiple_enemies_for_pathfinding() -> void:
	var enemy_scene = preload("res://Character/NPC/Enemy/Enemy.tscn")
	var cs = enemy_spawn_area.get_node("CollisionShape2D")
	var rect = cs.shape as RectangleShape2D
	var center = cs.global_position
	var ext = rect.extents
	
	# Spawn 5 enemies instead of 1
	for i in range(5):
		var enemy = enemy_scene.instantiate()
		var offset = Vector2(randf_range(-ext.x, ext.x), randf_range(-ext.y, ext.y))
		enemy.global_position = center + offset
		enemy.npc_name = "Enemy " + str(i + 1)
		enemy_container.add_child(enemy)
		
		# Register enemy with pathfinding manager
		if pathfinding_manager:
			pathfinding_manager.register_enemy(enemy)


# Helper functions for different setups
func _setup_no_transition() -> void:
	# Just fade in without camera movement
	var visuals: Array = []
	for c in containers:
		visuals += _collect_canvas_items(c)

	for item in visuals:
		item.modulate.a = 0.0

	var tw = create_tween().set_parallel(true)
	for item in visuals:
		tw.tween_property(item, "modulate:a", 1.0, FADE_DURATION)

func _setup_fade_in() -> void:
	# Same as no transition - just fade in
	var visuals: Array = []
	for c in containers:
		visuals += _collect_canvas_items(c)

	for item in visuals:
		item.modulate.a = 0.0

	var tw = create_tween().set_parallel(true)
	for item in visuals:
		tw.tween_property(item, "modulate:a", 1.0, FADE_DURATION)

func _show_all_planks() -> void:
	for plank in plank_container.get_children():
		plank.visible = true

func _spawn_draggable_crew(pos: Vector2) -> void:
	print("Spawning draggable crew at: ", pos)
	var crew_scene = preload("res://Character/NPC/CrewMember/CrewMember.tscn")
	var crew = crew_scene.instantiate()
	crew.global_position = pos
	crew.npc_name = "Demo Crew"
	crew.fighting = false
	crew.idle_with_sword = false
	crew.battle_manager = self  # Enable dragging
	print("Crew battle_manager set to: ", crew.battle_manager)
	crew_container.add_child(crew)
	print("Crew added to container")

func _spawn_single_crew(pos: Vector2) -> void:
	var crew_scene = preload("res://Character/NPC/CrewMember/CrewMember.tscn")
	var crew = crew_scene.instantiate()
	crew.global_position = pos
	crew.npc_name = "Demo Crew"
	crew.fighting = false
	crew.idle_with_sword = false
	crew_container.add_child(crew)

func _spawn_attacking_crew(pos: Vector2) -> void:
	var crew_scene = preload("res://Character/NPC/CrewMember/CrewMember.tscn")
	var crew = crew_scene.instantiate()
	crew.global_position = pos
	crew.npc_name = "Demo Crew"
	crew.fighting = true
	crew.idle_with_sword = true
	crew.battle_manager = self  # Enable dragging/interaction
	crew_container.add_child(crew)

func _spawn_idle_enemy() -> void:
	var enemy_scene = preload("res://Character/NPC/Enemy/Enemy.tscn")
	var enemy = enemy_scene.instantiate()
	enemy.global_position = Vector2(300, 100)
	enemy.npc_name = "Demo Enemy"
	
	# Make enemy idle (disable AI)
	enemy.set_ai_enabled(false)
	
	enemy_container.add_child(enemy)

func _spawn_damageable_enemy() -> void:
	var enemy_scene = preload("res://Character/NPC/Enemy/Enemy.tscn")
	var enemy = enemy_scene.instantiate()
	enemy.global_position = Vector2(300, 100)
	enemy.npc_name = "Demo Enemy"
	
	# Enemy can take damage but won't attack back
	enemy.set_ai_enabled(false)
	
	enemy_container.add_child(enemy)

func _spawn_full_enemy() -> void:
	var enemy_scene = preload("res://Character/NPC/Enemy/Enemy.tscn")
	var enemy = enemy_scene.instantiate()
	enemy.global_position = Vector2(300, 100)  # Back to normal enemy position
	enemy.npc_name = "Demo Enemy"
	# Full AI enabled by default
	print("Spawning full enemy at: ", enemy.global_position)
	enemy_container.add_child(enemy)

func _spawn_multiple_crew_on_planks() -> void:
	var crew_scene = preload("res://Character/NPC/CrewMember/CrewMember.tscn")
	var planks = plank_container.get_children()
	
	for i in range(min(5, planks.size())):
		var crew = crew_scene.instantiate()
		var plank = planks[i]
		crew.global_position = plank.global_position + Vector2(0, 33)  # CREW_SPAWN_OFFSET
		crew.board_target = plank.global_position + Vector2(0, -33)    # BOARD_TARGET_OFFSET
		crew.npc_name = "Crew " + str(i + 1)
		crew.fighting = false
		crew.idle_with_sword = true
		
		# Progress point 8 (index 8) should be deployable - they should be clickable
		crew.battle_manager = self  # All crew in manual deploy get battle manager
		
		crew_container.add_child(crew)

func _spawn_multiple_crew_random() -> void:
	var crew_scene = preload("res://Character/NPC/CrewMember/CrewMember.tscn")
	# Use enemy spawn area as reference but mirror it to the other side
	var cs = enemy_spawn_area.get_node("CollisionShape2D")
	var rect = cs.shape as RectangleShape2D
	var enemy_center = cs.global_position
	var ext = rect.extents
	
	# Mirror the spawn area to the opposite side of the planks
	var crew_center = Vector2(enemy_center.x, enemy_center.y + 200)  # Move down to player ship side
	
	for i in range(5):
		var crew = crew_scene.instantiate()
		var offset = Vector2(randf_range(-ext.x, ext.x), randf_range(-ext.y, ext.y))
		crew.global_position = crew_center + offset
		crew.npc_name = "Crew " + str(i + 1)
		crew.fighting = true  # They should be fighting
		crew.idle_with_sword = true
		crew.battle_manager = self
		crew_container.add_child(crew)

func _spawn_crew_with_smart_assignment() -> void:
	var crew_scene = preload("res://Character/NPC/CrewMember/CrewMember.tscn")
	# Use enemy spawn area as reference but mirror it to the other side
	var cs = enemy_spawn_area.get_node("CollisionShape2D")
	var rect = cs.shape as RectangleShape2D
	var enemy_center = cs.global_position
	var ext = rect.extents
	
	# Mirror the spawn area to the opposite side of the planks
	var crew_center = Vector2(enemy_center.x, enemy_center.y + 200)  # Move down to player ship side
	var planks = plank_container.get_children()
	
	# Initialize plank tracking
	planks_in_use.resize(planks.size())
	planks_in_use.fill(false)
	
	for i in range(5):
		var crew = crew_scene.instantiate()
		var offset = Vector2(randf_range(-ext.x, ext.x), randf_range(-ext.y, ext.y))
		crew.global_position = crew_center + offset
		crew.npc_name = "Crew " + str(i + 1)
		crew.fighting = true  # They should be fighting after boarding
		crew.idle_with_sword = true
		crew.battle_manager = self  # Enable dragging for testing
		
		# Assign plank using smart logic
		var assigned_plank_index = _assign_plank_to_crew(crew, planks)
		var plank = planks[assigned_plank_index]
		
		crew.board_target = plank.global_position + Vector2(0, -33)
		crew_plank_assignments[crew] = {
			"plank_index": assigned_plank_index,
			"plank_start": plank.global_position + Vector2(0, 33),
			"board_target": plank.global_position + Vector2(0, -33),
			"walking_speed": randf_range(0.7, 1.0)
		}
		
		crew_container.add_child(crew)
	
	# Start staggered boarding after a short delay
	await get_tree().process_frame
	_start_staggered_boarding()

func _spawn_multiple_enemies() -> void:
	var enemy_scene = preload("res://Character/NPC/Enemy/Enemy.tscn")
	var cs = enemy_spawn_area.get_node("CollisionShape2D")
	var rect = cs.shape as RectangleShape2D
	var center = cs.global_position
	var ext = rect.extents
	
	for i in range(5):
		var enemy = enemy_scene.instantiate()
		var offset = Vector2(randf_range(-ext.x, ext.x), randf_range(-ext.y, ext.y))
		enemy.global_position = center + offset
		enemy.npc_name = "Enemy " + str(i + 1)
		enemy_container.add_child(enemy)

# Smart plank assignment logic
func _assign_plank_to_crew(crew: Node, planks: Array) -> int:
	var best_plank_index = -1
	var shortest_distance = INF
	
	# First, try to find an unused plank that's closest
	for i in range(planks.size()):
		if not planks_in_use[i]:
			var plank = planks[i]
			var distance = crew.global_position.distance_to(plank.global_position)
			if distance < shortest_distance:
				shortest_distance = distance
				best_plank_index = i
	
	# If no unused plank found, find the closest plank (even if used)
	if best_plank_index == -1:
		for i in range(planks.size()):
			var plank = planks[i]
			var distance = crew.global_position.distance_to(plank.global_position)
			if distance < shortest_distance:
				shortest_distance = distance
				best_plank_index = i
	
	# Mark the plank as in use
	planks_in_use[best_plank_index] = true
	return best_plank_index

func _start_staggered_boarding() -> void:
	var crew_members = crew_container.get_children()
	
	for crew in crew_members:
		if crew.has_method("start_auto_boarding"):
			# Random delay between 0.0 and 0.5 seconds
			var delay = randf_range(0.0, 0.5)
			
			var timer = Timer.new()
			timer.wait_time = delay
			timer.one_shot = true
			add_child(timer)
			
			timer.timeout.connect(_start_crew_boarding.bind(crew, timer))
			timer.start()

func _start_crew_boarding(crew: Node, timer: Timer) -> void:
	if not is_instance_valid(crew):
		timer.queue_free()
		return
	
	var assignment = crew_plank_assignments.get(crew)
	if not assignment:
		timer.queue_free()
		return
	
	# Set the crew member's custom speed
	crew.speed = crew.speed * assignment["walking_speed"]
	
	# Start the boarding process
	if crew.has_method("start_auto_boarding"):
		crew.start_auto_boarding(assignment["plank_start"], assignment["board_target"])
	
	timer.queue_free()

# Manual deployment system for different progress points
func select_unit(unit: Node) -> void:
	if selected_crew and is_instance_valid(selected_crew):
		if selected_crew.has_method("stop_drag"):
			selected_crew.stop_drag()
	
	selected_crew = unit
	
	# Different behavior based on progress point
	if progress_point >= 0 and progress_point <= 7:  # Early progress points + camera transition - dragging (0-7)
		if unit.has_method("start_drag"):
			unit.start_drag()
	elif progress_point == 8:  # Manual deploy system - enable boarding if not boarded, dragging if boarded (index 8)
		if unit.has_method("get") and "has_boarded" in unit and unit.has_boarded:
			# If already boarded, allow dragging
			if unit.has_method("start_drag"):
				unit.start_drag()
		else:
			# If not boarded, start boarding
			if unit.has_method("start_board"):
				unit.start_board()
	elif progress_point >= 9 and progress_point <= 10:  # Auto systems - enable dragging for testing (9-10)
		if unit.has_method("start_drag"):
			unit.start_drag()
	elif progress_point >= 11:  # Pathfinding mode - limited interaction (11+)
		# In pathfinding mode, only allow dragging if not currently pathfinding
		if unit.has_method("get") and "pathfinding_mode" in unit and not unit.pathfinding_mode:
			if unit.has_method("start_drag"):
				unit.start_drag()
		else:
			print("Crew is currently pathfinding, interaction disabled")

func _input(event: InputEvent) -> void:
	# Handle different input modes based on progress point
	if progress_point >= 0 and progress_point <= 7:  # Early progress points + camera transition - dragging enabled (0-7)
		if event is InputEventMouseButton \
		and event.button_index == MOUSE_BUTTON_LEFT \
		and !event.pressed \
		and selected_crew \
		and is_instance_valid(selected_crew):
			if selected_crew.has_method("stop_drag"):
				selected_crew.stop_drag()
			selected_crew = null
	elif progress_point >= 8:  # Manual deploy system and beyond - support both boarding and dragging (8+)
		if event is InputEventMouseButton \
		and event.button_index == MOUSE_BUTTON_LEFT \
		and !event.pressed \
		and selected_crew \
		and is_instance_valid(selected_crew):
			if selected_crew.has_method("stop_drag"):
				selected_crew.stop_drag()
			selected_crew = null

# Rest of the original BoardingBattle functionality
func _collect_canvas_items(node: Node) -> Array:
	var out := []
	for child in node.get_children():
		if child is CanvasItem:
			out.append(child)
		out += _collect_canvas_items(child)
	return out

func fade_out_all(t: float = FADE_DURATION) -> Tween:
	var visuals: Array = []
	for c in containers:
		visuals += _collect_canvas_items(c)

	var tw = create_tween().set_parallel(true)
	for item in visuals:
		tw.tween_property(item, "modulate:a", 0.0, t)
	return tw

func _process(_delta: float) -> void:
	# Don't run game logic in editor
	if Engine.is_editor_hint():
		return
		
	# Only check for battle end if we have entities that should be fighting
	if progress_point >= 1 and not _battle_over:  # Only check from "Add One Crewmate" onwards (index 1)
		var crew_alive = $CrewContainer.get_child_count() > 0
		var enemy_alive = $EnemyContainer.get_child_count() > 0
		
		# For progress points with actual combat (5+), check if battle should end
		if progress_point >= 5:  # Index 5 = "Enemy Takes Damage"
			if not crew_alive or not enemy_alive:
				_battle_over = true
				_finish_battle()

func _finish_battle() -> void:
	var tw := fade_out_all(2.0)
	var cam_tw = create_tween()
	cam_tw.tween_property(cam, "global_position:y", _orig_cam_y, 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	await tw.finished
	await cam_tw.finished

	Global.board_zoom_out_next = true
	Global.return_scene_path = ""
	SceneSwitcher.switch_scene(
		OCEAN_TUTORIAL_SCENE,
		Global.spawn_position,
		"none",
		Vector2(),
		Vector2(),
		Vector2(16,16),
		true
	)

func get_battle_state() -> Dictionary:
	var crew_list := []
	for c in $CrewContainer.get_children():
		var crew_data = {
			"name": "Unknown",
			"pos": c.global_position,
			"health": 3,
			"dragging": false,
			"boarded": false,
		}
		
		if c.has_method("get"):
			if "npc_name" in c:
				crew_data["name"] = c.npc_name
			if "health" in c:
				crew_data["health"] = c.health
			if "dragging" in c:
				crew_data["dragging"] = c.dragging
			if "has_boarded" in c:
				crew_data["boarded"] = c.has_boarded
		
		crew_list.append(crew_data)

	var enemy_list := []
	for e in $EnemyContainer.get_children():
		var enemy_data = {
			"name": "Unknown",
			"pos": e.global_position,
			"health": 5,
		}
		
		if e.has_method("get"):
			if "npc_name" in e:
				enemy_data["name"] = e.npc_name
			if "health" in e:
				enemy_data["health"] = e.health
		
		enemy_list.append(enemy_data)

	return {
		"crew": crew_list,
		"enemies": enemy_list,
		"camera": {
			"pos": cam.global_position,
			"zoom": cam.zoom,
		},
	}

func apply_battle_state(state: Dictionary) -> void:
	# Implementation for loading saved states if needed
	pass

func _exit_tree() -> void:
	# Clean up pathfinding manager
	if pathfinding_manager and is_instance_valid(pathfinding_manager):
		pathfinding_manager.queue_free()
	
	if _battle_over:
		Global.battle_state = {}
	else:
		Global.battle_state = get_battle_state()


