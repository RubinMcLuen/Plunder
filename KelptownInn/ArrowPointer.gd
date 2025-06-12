extends Sprite2D

@export var target: Node2D
@export var y_offset: float = -16.0
@export var margin: float = 10.0

var camera: Camera2D

func _ready() -> void:
    camera = get_viewport().get_camera_2d()
    var anim = get_node_or_null("AnimationPlayer")
    if anim:
        anim.stop()
        anim.queue_free()

func _process(_delta: float) -> void:
    if not target or not camera:
        return
    var viewport_size = get_viewport_rect().size
    var half_extents = viewport_size * 0.5 * camera.zoom.x
    var left = camera.global_position.x - half_extents.x
    var right = camera.global_position.x + half_extents.x
    var top = camera.global_position.y - half_extents.y
    var bottom = camera.global_position.y + half_extents.y
    var desired = target.global_position + Vector2(0, y_offset)
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
