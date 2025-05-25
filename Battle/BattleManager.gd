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

func spawn_crews() -> void:
	var scene := preload("res://Character/NPC/CrewMember/CrewMember.tscn")
	for plank in plank_container.get_children():
		var c : CrewMemberNPC = scene.instantiate()
		c.global_position = plank.global_position + CREW_SPAWN_OFFSET
		c.board_target    = plank.global_position + BOARD_TARGET_OFFSET
		c.battle_manager  = self
		crew_container.add_child(c)

func spawn_enemies() -> void:
	var scene := preload("res://Character/NPC/Enemy/Enemy.tscn")
	var cs : CollisionShape2D   = enemy_spawn_area.get_node("CollisionShape2D")
	var rect := cs.shape as RectangleShape2D
	var center : Vector2 = cs.global_position
	var ext    : Vector2 = rect.extents

	for i in range(10):
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
