extends "res://KelptownIsland/KelptownIsland.gd"

func _on_dock_button_pressed():
    var specific_position = Vector2(-11.875, 40.5)
    var target := "res://Island/islandtutorial.tscn"
    if Global.ocean_tutorial_complete:
        target = "res://Island/island.tscn"
    SceneSwitcher.switch_scene(
        target,
        Vector2(-190, 648),
        "zoom",
        Vector2(16,16),
        specific_position,
        Vector2(1.5, 1.5)
    )

