extends Sprite2D

@export var target: Node2D
@export var y_offset: float = -58.0
@export var margin: float = 10.0
@export var bob_amplitude: float = 2.0
@export var bob_speed: float = 3.0

var camera: Camera2D
var t: float = 0.0

func _ready() -> void:
        camera = get_viewport().get_camera_2d()

func _process(delta: float) -> void:
        if not camera:
                camera = get_viewport().get_camera_2d()
        if not target or not camera:
                return

        t += delta
        var bob = sin(t * bob_speed) * bob_amplitude

        var viewport_size = get_viewport_rect().size
        var half_extents = viewport_size * 0.5 * camera.zoom.x
        var left = camera.global_position.x - half_extents.x
        var right = camera.global_position.x + half_extents.x
        var top = camera.global_position.y - half_extents.y
        var bottom = camera.global_position.y + half_extents.y

        var desired = target.global_position + Vector2(0, y_offset + bob)
        var pos = desired
        var offscreen = false

        if pos.x < left:
                pos.x = left + margin
                offscreen = true
        elif pos.x > right:
                pos.x = right - margin
                offscreen = true

        if pos.y < top:
                pos.y = top + margin
                offscreen = true
        elif pos.y > bottom:
                pos.y = bottom - margin
                offscreen = true

        global_position = pos

        if offscreen:
                rotation = (target.global_position - global_position).angle() - Vector2.DOWN.angle()
        else:
                rotation = 0.0
