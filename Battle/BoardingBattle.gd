extends Node2D

const FADE_DURATION := 2.0

@onready var containers := [
	$PlankContainer,
	$CrewContainer,
	$EnemyContainer,
]

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
