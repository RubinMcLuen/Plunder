extends Node2D

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
        cam_tw.tween_property(cam, "global_position:y", _orig_cam_y, 2.0)
                .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
        await tw.finished
        await cam_tw.finished
        Global.board_zoom_out_next = true
        var scene = Global.return_scene_path if Global.return_scene_path != "" else "res://Ocean/oceantutorial.tscn"
        Global.return_scene_path = ""
        SceneSwitcher.switch_scene(scene, Global.spawn_position, "none", Vector2(), Vector2(), Vector2(16,16), true)
