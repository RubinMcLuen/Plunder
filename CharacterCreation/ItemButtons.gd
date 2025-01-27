extends Node2D

@export var page_size: int = 6
var current_category: String = ""
var options: Dictionary = {}
var current_page: int = 0
signal item_selected(category: String, item)

func _ready():
	for i in range(page_size):
		var button = get_node("Button" + str(i + 1))
		button.connect("pressed", Callable(self, "_on_item_button_pressed").bind(i))

func populate_buttons(category: String, options_dict: Dictionary, page: int = 0, main_right_arm_texture: Texture = null, is_hook_enabled: bool = false):
	if category not in options_dict or typeof(options_dict[category]) != TYPE_ARRAY:
		return

	current_category = category
	options = options_dict

	for i in range(page_size):
		var button = get_node("Button" + str(i + 1))
		var character_node = button.get_node("Character")

		if category == "misc":
			if i == 0:
				button.disabled = false
				character_node.visible = true
				if main_right_arm_texture == null:
					character_node.get_node("RightArm").texture = null
				else:
					var hook_index = get_hook_index_for_top(main_right_arm_texture)
					if hook_index >= 0 and hook_index < options[category].size():
						var hook_sprite = options[category][hook_index]
						character_node.get_node("RightArm").texture = load(hook_sprite)
			else:
				button.disabled = true
				character_node.visible = false
		else:
			var start_idx = page * page_size
			if start_idx + i < options[current_category].size():
				var item = options[current_category][start_idx + i]
				button.disabled = false
				character_node.visible = true

				# Pass hook state to apply_item_to_character
				apply_item_to_character(character_node, item, category, is_hook_enabled)
			else:
				button.disabled = true
				character_node.visible = false


func apply_item_to_character(character: Node2D, item, category: String, is_hook_enabled: bool = false):
	if typeof(item) == TYPE_DICTIONARY:
		for part in item.keys():
			var part_node = character.get_node(part)
			if part_node and part_node is Sprite2D:
				# Replace RightArm with the corresponding hook sprite if the hook is enabled
				if is_hook_enabled and part == "RightArm":
					var right_arm_sprite = item[part]
					# Construct the hook sprite path directly in the "misc" folder
					var file_name = right_arm_sprite.get_file().replace("rarm", "hook")
					var hook_sprite = "res://CharacterCreation/customizations/misc/" + file_name
					part_node.texture = load(hook_sprite)
				else:
					part_node.texture = load(item[part])
	else:
		var target_node = character.get_node(category.capitalize())
		if target_node and target_node is Sprite2D:
			# For single-part items, apply the texture normally
			target_node.texture = load("res://CharacterCreation/customizations/" + category + "/" + item)

func _on_item_button_pressed(button_index: int):
	if current_category not in options or typeof(options[current_category]) != TYPE_ARRAY:
		return

	var start_idx = current_page * page_size
	var item_index = start_idx + button_index

	if item_index >= options[current_category].size():
		return

	var selected_item = options[current_category][item_index]
	emit_signal("item_selected", current_category, selected_item)

func get_hook_index_for_top(right_arm_texture: Texture) -> int:
	if right_arm_texture == null:
		return -1

	var texture_path = right_arm_texture.resource_path
	var base_name = texture_path.get_file().get_basename()
	var regex = RegEx.new()
	regex.compile("\\d+")
	var match = regex.search(base_name)

	if match == null:
		return -1

	var hook_index = match.get_string(0).to_int()
	var hook_file_name = "hook" + str(hook_index) + ".png"

	for i in range(options["misc"].size()):
		if options["misc"][i].ends_with(hook_file_name):
			return i

	return -1

