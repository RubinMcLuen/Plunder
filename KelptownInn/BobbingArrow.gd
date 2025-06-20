extends Sprite2D

# Slightly adjust the default arrow offsets so the arrow
# points more accurately to the target position.
@export var x_offset: float = 0.0
@export var y_offset: float = -25.0
@export var bob_amplitude: float = 3.0
@export var bob_speed: float = 1.0

var _target: Node2D = null
var _time := 0.0

@export var target: Node2D : set = set_target, get = get_target

func _ready() -> void:
    # Ensure bobbing animation runs even if process mode was disabled in the scene
    set_process(true)

func _process(delta: float) -> void:
    if not is_instance_valid(_target):
        return
    _time += delta
    var bob_y = sin(_time * TAU * bob_speed) * bob_amplitude
    global_position = _target.global_position + Vector2(x_offset, y_offset + bob_y)

func set_target(t: Node2D) -> void:
    _target = t
    _time = 0.0
    if is_instance_valid(_target):
        global_position = _target.global_position + Vector2(x_offset, y_offset)

func get_target() -> Node2D:
    return _target
