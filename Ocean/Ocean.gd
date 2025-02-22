extends Node2D


func _ready():
	var waves = get_node("Waves")
	waves.modulate.a = 0.0
	get_tree().create_tween().tween_property(waves, "modulate:a", 1.0, 1.0)



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
