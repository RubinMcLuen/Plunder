extends Sprite2D

@export var target: Node2D
@export var y_offset: float = -40.0
@export var bob_amplitude: float = 3.0
@export var bob_speed: float = 2.0

var _time := 0.0

func _process(delta: float) -> void:
    if not target:
        return
    _time += delta
    var bob_y = sin(_time * TAU * bob_speed) * bob_amplitude
    global_position = target.global_position + Vector2(0.0, y_offset + bob_y)
