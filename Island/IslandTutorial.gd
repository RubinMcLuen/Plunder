extends "res://Island/island.gd"

func _on_exit_body_entered(body: Node) -> void:
	if body == player:
		SceneSwitcher.switch_scene(
			"res://KelptownInn/KelptownInnTutorial.tscn",
			Vector2(269, 220),
			"fade",
			Vector2.ONE,
			Vector2.ZERO,
			Vector2(1.5, 1.5)
		)

