extends "res://Battle/BattleManager.gd"
class_name BattleManagerTutorial

var spawned_enemy : EnemyNPC = null

func _ready() -> void:
	spawn_crews()
	# do not spawn any enemies at start

func spawn_crews() -> void:
        super.spawn_crews()
        # Adjust Barnaby health for tutorial vs normal battles
        var hp = 30 if not Global.ocean_tutorial_complete else 10
        for c in crew_container.get_children():
                if c is BarnabyCrew:
                        c.health = hp

func spawn_single_enemy() -> EnemyNPC:
		var scene := preload("res://Character/NPC/Enemy/Enemy.tscn")
		var cs : CollisionShape2D = enemy_spawn_area.get_node("CollisionShape2D")
		var rect := cs.shape as RectangleShape2D
		var center : Vector2 = cs.global_position
		var ext    : Vector2 = rect.extents
		var e : EnemyNPC = scene.instantiate()
		var off := Vector2(ext.x * 0.8, 0)
		e.global_position = center + off
		e.health = 5
				# Raise the enemy slightly so range indicators draw beneath
		e.z_index += 2
		if e.has_node("MeleeRange"):
				e.get_node("MeleeRange").z_index += 1
		enemy_container.add_child(e)
		spawned_enemy = e
		return e

