extends Node

const PLANK_LENGTH        = 66.0
const CREW_SPAWN_OFFSET   = Vector2(0, PLANK_LENGTH * 0.5)
const BOARD_TARGET_OFFSET = Vector2(0, -PLANK_LENGTH * 0.5)

@onready var plank_container  = get_node("../PlankContainer")
@onready var crew_container   = get_node("../CrewContainer")
@onready var enemy_container  = get_node("../EnemyContainer")
@onready var enemy_spawn_area = get_node("../EnemySpawnArea")

var selected : CrewMemberNPC = null

func _ready() -> void:
	spawn_crews()
	spawn_enemies()

# ─────────────────────────────────────────────
# Replace the old spawn_crews() with this one
# ─────────────────────────────────────────────
const NPC_FOLDER := "res://Character/NPC/NPCs"
const GENERIC_CREW_SCENE := "res://Character/NPC/CrewMember/CrewMember.tscn"
func spawn_crews() -> void:
	var crew_names: Array[String]
	if Global.crew_override.size() > 0:
			crew_names = Global.crew_override.duplicate()
			Global.crew_override.clear()
	else:
			if "Barnaby" not in Global.crew:
					Global.crew.append("Barnaby")
			crew_names = Global.crew.duplicate()
	# 2) Grab all the planks
	var planks: Array = plank_container.get_children()
	if planks.is_empty():
		push_error("[BattleManager] No planks found – cannot place crew.")
		return

	# 3) Only spawn as many as both crew and planks allow
	var crew_to_spawn = min(crew_names.size(), planks.size())
	for i in range(crew_to_spawn):
		var name  := crew_names[i]
		var plank := planks[i] as Node2D

		var crew_scene: PackedScene = _get_crew_scene(name)
		var c: CrewMemberNPC       = crew_scene.instantiate()

		c.global_position = plank.global_position + CREW_SPAWN_OFFSET
		c.board_target    = plank.global_position + BOARD_TARGET_OFFSET
		c.battle_manager  = self
		c.fighting        = true
		c.idle_with_sword = true   # its own _ready() will play IdleSword

		crew_container.add_child(c)



# ─────────────────────────────────────────────
# Helper: choose the right PackedScene for a given crew name
# ─────────────────────────────────────────────
func _get_crew_scene(npc_name: String) -> PackedScene:
	if npc_name != "":
		var path := "%s/%s_Crew.tscn" % [NPC_FOLDER, npc_name]
		if ResourceLoader.exists(path):
			return load(path)
		print("[BattleManager] No crew scene for", npc_name, "→ using generic")
	return load(GENERIC_CREW_SCENE)




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

func select_unit(unit : CrewMemberNPC) -> void:
	if selected and is_instance_valid(selected):
		selected.stop_drag()
		if selected.tree_exited.is_connected(_on_freed):
			selected.tree_exited.disconnect(_on_freed)
	selected = unit
	if !selected.tree_exited.is_connected(_on_freed):
		selected.tree_exited.connect(_on_freed)
	if !unit.has_boarded:
		unit.start_board()
	else:
		unit.start_drag()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and !event.pressed \
	and selected \
	and is_instance_valid(selected):
		selected.stop_drag()
		selected = null

func _on_freed(): selected = null
