extends Area2D

@export var target_scene: PackedScene          # The scene to switch to
var allow_menu: bool = true  # Prevent showing the menu on initial scene load

func _ready() -> void:
	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("body_exited", Callable(self, "_on_body_exited"))

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and allow_menu:
		UIManager.show_set_sail_menu()

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		UIManager.hide_set_sail_menu()
		allow_menu = true  # Now the player can reenter to trigger the menu

func _on_button_pressed() -> void:
SceneSwitcher.switch_scene(
preload("res://Ocean/ocean.tscn"),
								Vector2(-2, 39),
								"zoom",
								Vector2(0.0625, 0.0625),
								Vector2(-32, 624)
				)
