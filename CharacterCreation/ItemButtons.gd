extends Node2D

@export var page_size: int = 6
var current_category: String = ""
var options: Dictionary = {}
var current_page: int = 0
signal item_selected(category: String, item)

# Preload the spritesheet containing all item cells.
const ITEM_SPRITESHEET: Texture2D = preload("res://Character/assets/PlayerCustomizationSprites.png")
const CELL_SIZE: Vector2i = Vector2i(48, 48)

func _ready():
	for i in range(page_size):
		var button = get_node("Button" + str(i + 1))
		button.connect("pressed", Callable(self, "_on_item_button_pressed").bind(i))

func populate_buttons(category: String, options_dict: Dictionary, page: int = 0):
	if not options_dict.has(category) or typeof(options_dict[category]) != TYPE_ARRAY:
		return

	current_category = category
	current_page = page
	options = options_dict
	for i in range(page_size):
		var button = get_node("Button" + str(i + 1))
		# Each button has a Model node with an Item Sprite2D as a child.
		var item_sprite = button.get_node("Model/Item") as Sprite2D
		var start_idx = page * page_size
		if start_idx + i < options[current_category].size():
			button.visible = true  # Show button if item exists.
			var cell_index = int(options[current_category][start_idx + i])
			item_sprite.texture = get_item_texture(current_category, cell_index)
			item_sprite.visible = true
		else:
			button.visible = false  # Hide the entire button if no item available.

# Helper: Returns an AtlasTexture using the preset spritesheet and correct row for the given category.
func get_item_texture(category: String, cell_index: int) -> Texture2D:
	var row: int = 0
	match category:
		"skin":
			row = 0
		"top":
			row = 1
		"bottom":
			row = 2
		"hat":
			row = 3
		"misc":
			row = 4
		"hair":
			row = 6
		_:
			row = 0
	var atlas_tex = AtlasTexture.new()
	atlas_tex.atlas = ITEM_SPRITESHEET
	atlas_tex.region = Rect2(cell_index * CELL_SIZE.x, row * CELL_SIZE.y, CELL_SIZE.x, CELL_SIZE.y)
	return atlas_tex

func _on_item_button_pressed(button_index: int):
	if not options.has(current_category) or typeof(options[current_category]) != TYPE_ARRAY:
		return

	var start_idx = current_page * page_size
	var item_index = start_idx + button_index

	if item_index >= options[current_category].size():
		return

	var selected_item = options[current_category][item_index]
	emit_signal("item_selected", current_category, selected_item)
