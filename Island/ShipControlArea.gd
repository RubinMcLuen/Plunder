extends Area2D

@export var target_scene: PackedScene          # The scene to switch to
@export var button_path: NodePath = "CanvasLayer/Button"  # Adjust this path to your Button node

func _ready() -> void:
	var btn: Button = get_node(button_path)
	btn.visible = false

	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("body_exited", Callable(self, "_on_body_exited"))

func _on_body_entered(body: Node) -> void:
	var btn: Button = get_node(button_path)
	btn.visible = true
	print("Body entered: ", body.name)

func _on_body_exited(body: Node) -> void:
	var btn: Button = get_node(button_path)
	btn.visible = false
	print("Body exited: ", body.name)

func _on_button_pressed() -> void:
	if target_scene:
		get_tree().change_scene_to_packed(target_scene)
