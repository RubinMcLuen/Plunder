extends Node2D

var radius: float = 20.0
var fill_color: Color = Color(1,1,1,0.4)
var outline_color: Color = Color(1,1,1,1)
var outline_width: float = 2.0

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, fill_color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, outline_color, outline_width)
