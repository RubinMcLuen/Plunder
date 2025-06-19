extends "res://Island/ShipControlArea.gd"

func _on_button_pressed() -> void:
	SceneSwitcher.switch_scene(
		"res://Ocean/oceantutorial.tscn",
		Vector2(-2, 41),
		"zoom",
		Vector2(0.0625, 0.0625),
		Vector2(-32, 656)
	)

