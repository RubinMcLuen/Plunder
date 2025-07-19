extends Node

const PLANK_LENGTH        = 66.0
const CREW_SPAWN_OFFSET   = Vector2(0, PLANK_LENGTH * 0.5)
const BOARD_TARGET_OFFSET = Vector2(0, -PLANK_LENGTH * 0.5)

@onready var plank_container  = get_node("../PlankContainer")
@onready var crew_container   = get_node("../CrewContainer")
@onready var enemy_container  = get_node("../EnemyContainer")
@onready var enemy_spawn_area = get_node("../EnemySpawnArea")

var selected : CrewMemberNPC = null

# New variables for staggered boarding
var planks_in_use: Array[bool] = []
var crew_plank_assignments: Dictionary = {}

func _ready() -> void:
	spawn_crews()
	spawn_enemies()
	start_staggered_boarding()

# ─────────────────────────────────────────────
# Replace the old spawn_crews() with this one
# ─────────────────────────────────────────────
const CREW_SCENE_MAP := {
	"Barnaby": preload("res://Character/NPC/NPCs/Barnaby_Crew.tscn")
}
const GENERIC_CREW_SCENE: PackedScene = preload("res://Character/NPC/CrewMember/CrewMember.tscn")

func spawn_crews() -> void:
	var crew_names: Array[String]
	if Global.crew_override.size() > 0:
		crew_names = Global.crew_override.duplicate()
		Global.crew_override.clear()
	else:
		if "Barnaby" not in Global.crew:
			Global.crew.append("Barnaby")
		crew_names = Global.crew.duplicate()
	
	# Get all the planks
	var planks: Array = plank_container.get_children()
	if planks.is_empty():
		push_error("[BattleManager] No planks found – cannot place crew.")
		return
	
	# Initialize plank usage tracking
	planks_in_use.resize(planks.size())
	planks_in_use.fill(false)
	
	# Only spawn as many as both crew and planks allow
	var crew_to_spawn = min(crew_names.size(), planks.size())
	
	   # Mirror enemy spawn area across the planks for crew spawning
	var cs: CollisionShape2D = enemy_spawn_area.get_node("CollisionShape2D")
	var rect := cs.shape as RectangleShape2D
	var enemy_center: Vector2 = cs.global_position
	var ext: Vector2 = rect.extents
	var plank_line_y = plank_container.get_child(0).global_position.y
	var crew_center = Vector2(enemy_center.x, 2.0 * plank_line_y - enemy_center.y)
	
	for i in range(crew_to_spawn):
		var name := crew_names[i]
		var crew_scene: PackedScene = _get_crew_scene(name)
		var c: CrewMemberNPC = crew_scene.instantiate()
		# Spawn in mirrored area relative to enemy spawn
		var spawn_off := Vector2(
		randf_range(-ext.x, ext.x),
		randf_range(-ext.y, ext.y)
		)
		c.global_position = crew_center + spawn_off
		
		# Assign plank using smart assignment logic
		var assigned_plank_index = assign_plank_to_crew(c, planks)
		var plank = planks[assigned_plank_index]
		
		c.board_target = plank.global_position + BOARD_TARGET_OFFSET
		c.battle_manager = self
		c.fighting = false  # Not fighting yet
		c.idle_with_sword = false  # No sword until they board
		
		# Store the plank assignment and walking target
		crew_plank_assignments[c] = {
			"plank_index": assigned_plank_index,
			"plank_start": plank.global_position + CREW_SPAWN_OFFSET,
			"board_target": plank.global_position + BOARD_TARGET_OFFSET,
			"walking_speed": randf_range(0.7, 1.0)  # 70% to 100% speed
		}
		
		crew_container.add_child(c)

func assign_plank_to_crew(crew: CrewMemberNPC, planks: Array) -> int:
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

func start_staggered_boarding() -> void:
	var crew_members = crew_container.get_children()
	
	for crew in crew_members:
		if crew is CrewMemberNPC:
			# Random delay between 0.0 and 0.5 seconds
			var delay = randf_range(0.0, 0.5)
			
			# Create a timer for this crew member
			var timer = Timer.new()
			timer.wait_time = delay
			timer.one_shot = true
			add_child(timer)
			
			# Connect the timer to start boarding for this specific crew member
			timer.timeout.connect(_start_crew_boarding.bind(crew, timer))
			timer.start()

func _start_crew_boarding(crew: CrewMemberNPC, timer: Timer) -> void:
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
	crew.start_auto_boarding(assignment["plank_start"], assignment["board_target"])
	
	# Clean up the timer
	timer.queue_free()

# ─────────────────────────────────────────────
# Helper: choose the right PackedScene for a given crew name
# ─────────────────────────────────────────────
func _get_crew_scene(npc_name: String) -> PackedScene:
	if CREW_SCENE_MAP.has(npc_name):
		return CREW_SCENE_MAP[npc_name]
	print("[BattleManager] No crew scene for", npc_name, " -> using generic")
	return GENERIC_CREW_SCENE

func spawn_enemies() -> void:
	var scene := preload("res://Character/NPC/Enemy/Enemy.tscn")
	var cs : CollisionShape2D   = enemy_spawn_area.get_node("CollisionShape2D")
	var rect := cs.shape as RectangleShape2D
	var center : Vector2 = cs.global_position
	var ext    : Vector2 = rect.extents

	var num = 10
	if Global.enemy_count_override > 0:
		num = Global.enemy_count_override
		Global.enemy_count_override = -1

	for i in range(num):
		var e : EnemyNPC = scene.instantiate()
		var off := Vector2(randf_range(-ext.x, ext.x), randf_range(-ext.y, ext.y))
		e.global_position = center + off
		enemy_container.add_child(e)

# The old selection system is no longer needed, but keeping for compatibility
func select_unit(unit : CrewMemberNPC) -> void:
	# This function is now largely unused since we don't manually deploy crew
	pass

func _input(event: InputEvent) -> void:
	# Remove the old click-to-deploy input handling
	pass

func _on_freed(): 
	selected = null
