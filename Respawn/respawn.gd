extends Control

func _ready():
	# Ensure the skull starts fully transparent (alpha = 0)
	var col: Color = $skull.modulate
	col.a = 0.0
	$skull.modulate = col

	# Create a tween (SceneTreeTween is not a node so you don't add it as a child)
	var tween = get_tree().create_tween()
	
	# Fade in: Tween the alpha (modulate.a) from 0 (transparent) to 1 (opaque) over 1 second
	tween.tween_property($skull, "modulate:a", 1.0, 1.0)
	
	# Wait for 2 seconds while the skull is fully opaque
	tween.tween_interval(1.0)
	
	# Fade out: Tween the alpha (modulate.a) back to 0 (transparent) over 1 second
	tween.tween_property($skull, "modulate:a", 0.0, 1.0)
	
	tween.tween_interval(0.2)
	
	# After fading out, change to the new scene
	tween.tween_callback(Callable(self, "_change_scene"))

func _change_scene():
	# Change to the scene "Tavern/tavern.tscn"
	get_tree().change_scene_to_file("res://Tavern/tavern.tscn")
