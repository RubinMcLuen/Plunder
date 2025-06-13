extends Sprite2D

@export var target: Node2D
@export var x_offset: float = 1.0
@export var y_offset: float = -35.0
@export var bob_amplitude: float = 3.0
@export var bob_speed: float = 1.0

var _time := 0.0

func _process(delta: float) -> void:
    if not is_instance_valid(target):
        return
    _time += delta
    var bob_y = sin(_time * TAU * bob_speed) * bob_amplitude
    global_position = target.global_position + Vector2(x_offset, y_offset + bob_y)
