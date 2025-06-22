extends Node2D
class_name BoardingBattle

const FADE_DURATION := 2.0

@onready var containers := [
		$PlankContainer,
		$CrewContainer,
		$EnemyContainer,
]

@onready var cam : Camera2D = $Camera2D

var _orig_cam_y: float = 0.0
var _battle_over: bool = false

func _ready() -> void:
		# 1) gather every CanvasItem (Sprite2D, Control, etc.) under those containers
	var visuals: Array = []
	for c in containers:
			visuals += _collect_canvas_items(c)

	# 2) force them all fully transparent
	for item in visuals:
		item.modulate.a = 0.0

	# 3) one tween, truly parallel
	var tw = create_tween().set_parallel(true)
	for item in visuals:
			tw.tween_property(item, "modulate:a", 1.0, FADE_DURATION)

	_orig_cam_y = cam.global_position.y
	set_process(true)
	if Global.battle_state and Global.battle_state.size() > 0:
			apply_battle_state(Global.battle_state)
			Global.battle_state = {}


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
		if _battle_over:
				return
		var crew_alive = $CrewContainer.get_child_count() > 0
		var enemy_alive = $EnemyContainer.get_child_count() > 0
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
		var scene = Global.return_scene_path if Global.return_scene_path != "" else "res://Ocean/oceantutorial.tscn"
		Global.return_scene_path = ""
		SceneSwitcher.switch_scene(scene, Global.spawn_position, "none", Vector2(), Vector2(), Vector2(16,16), true)

func get_battle_state() -> Dictionary:
	var crew_list = []
	for c in $CrewContainer.get_children():
		crew_list.append({
			"name": c.npc_name if "npc_name" in c else c.name,
			"pos": c.global_position,
			"health": c.health,
			"dragging": c.dragging if c.has_method("dragging") else false,
			"boarded": c.has_boarded if c.has_method("has_boarded") else false,
		})
	var enemy_list = []
	for e in $EnemyContainer.get_children():
		enemy_list.append({
			"name": e.npc_name if "npc_name" in e else e.name,
			"pos": e.global_position,
			"health": e.health,
		})
        return {
                "crew": crew_list,
                "enemies": enemy_list,
                "camera": {
                        "pos": cam.global_position,
                        "zoom": cam.zoom,
                },
        }

func apply_battle_state(state: Dictionary) -> void:
		var crew_info = state.get("crew", [])
		var crews = $CrewContainer.get_children()
		for i in range(min(crew_info.size(), crews.size())):
				var data = crew_info[i]
				var c = crews[i]
				c.global_position = data.get("pos", c.global_position)
				c.health = int(data.get("health", c.health))
				if "dragging" in data:
						c.dragging = bool(data["dragging"])
				if "boarded" in data:
						c.has_boarded = bool(data["boarded"])
		var enemy_info = state.get("enemies", [])
		var enemies = $EnemyContainer.get_children()
                for i in range(min(enemy_info.size(), enemies.size())):
                                var d = enemy_info[i]
                                var e = enemies[i]
                                e.global_position = d.get("pos", e.global_position)
                                e.health = int(d.get("health", e.health))

                var cam_info = state.get("camera", {})
                var cpos = cam_info.get("pos", cam.global_position)
                if typeof(cpos) == TYPE_DICTIONARY and cpos.has("x") and cpos.has("y"):
                                cam.global_position = Vector2(cpos["x"], cpos["y"]) 
                elif typeof(cpos) == TYPE_VECTOR2:
                                cam.global_position = cpos
                elif typeof(cpos) == TYPE_STRING:
                                var tmp = str_to_var(cpos)
                                if typeof(tmp) == TYPE_VECTOR2:
                                                cam.global_position = tmp

                var cz = cam_info.get("zoom", cam.zoom)
                if typeof(cz) == TYPE_DICTIONARY and cz.has("x") and cz.has("y"):
                                cam.zoom = Vector2(cz["x"], cz["y"])
                elif typeof(cz) == TYPE_VECTOR2:
                                cam.zoom = cz
                elif typeof(cz) == TYPE_STRING:
                                var tmp2 = str_to_var(cz)
                                if typeof(tmp2) == TYPE_VECTOR2:
                                                cam.zoom = tmp2

func _exit_tree() -> void:
		Global.battle_state = get_battle_state()
