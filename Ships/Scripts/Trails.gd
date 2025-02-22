extends Line2D

@export var MAX_LENGTH: int = 10
@export var sub_viewport: SubViewport
@export var parent: Node2D
@export var distanceAtLargestWidth: float = 16.0 * 6.0
@export var smallestTipWidth: float
@export var largestTipWidth: float

var length: float = 0.0
var queue: Array = []
var offset: Vector2 = Vector2.ZERO

func _ready():
	offset = sub_viewport.size / 2

func _process(delta):
	length = 0.0
	var pos = parent.global_position + offset
	queue.append(pos)
	if queue.size() > MAX_LENGTH and queue.size() > 2:
		queue.pop_front()
	
	clear_points()
	
	for i in range(queue.size() - 1):
		length += queue[i].distance_to(queue[i + 1])
		add_point(parent.to_local(queue[i]))
	if queue.size() > 0:
		add_point(parent.to_local(queue[queue.size() - 1]))
	
	# Calculate the ratio (clamped between 0 and 1)
	var t = clamp(length / distanceAtLargestWidth, 0, 1)
	var width_value = lerp(smallestTipWidth, largestTipWidth, t)
	width_curve.set_point_value(0, width_value)

func reset_line():
	clear_points()
	queue.clear()
