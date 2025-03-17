extends AnimatedSprite2D

func _ready():
	randomize()
	var anim_names = sprite_frames.get_animation_names()
	play(anim_names[randi() % anim_names.size()])

func _on_animation_finished():
	queue_free()
