extends Node2D

# Signal emitted when a category button is pressed
signal category_selected(category: String)

func _ready():
	# Dynamically connect each TextureButton to emit the signal with the corresponding category
	for button in get_children():
		if button is TextureButton:
			var category_name = button.name.replace("Button", "").to_lower()
			button.connect("pressed", Callable(self, "_on_category_button_pressed").bind(category_name))

func _on_category_button_pressed(category: String):
	"""
	Emits the category_selected signal when a category button is pressed.
	"""
	emit_signal("category_selected", category)
