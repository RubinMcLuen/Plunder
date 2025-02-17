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
	current_page = page  # <--- This line ensures the correct page offset is used.
	options = options_dict
	for i in range(page_size):
		var button = get_node("Button" + str(i + 1))
		var character_node = button.get_node("Character/Appearance")

		if category == "misc":
			if i == 0:
				button.disabled = false
				character_node.visible = true

				# Determine the node name to access
				var arm_node_name = "rightarm"  # Change as needed based on your logic
				var arm_node = get_adjusted_node(character_node, arm_node_name)

				if main_right_arm_texture == null:
					arm_node.texture = null
				else:
					var hook_index = get_hook_index_for_top(main_right_arm_texture)
					if hook_index >= 0 and hook_index < options[category].size():
						var hook_sprite = options[category][hook_index]
						arm_node.texture = load(hook_sprite)
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

# Helper function to get the correctly adjusted node
func get_adjusted_node(character_node: Node, node_name: String) -> Node:
	if node_name == "rightarm" or node_name == "leftarm" or node_name == "body":
		return character_node.get_node("Top/" + node_name)
	elif node_name == "rightleg" or node_name == "leftleg":
		return character_node.get_node("Bottom/" + node_name)
	else:
		return character_node.get_node(node_name)

# Updated apply_item_to_character function
func apply_item_to_character(character: Node2D, item, category: String, is_hook_enabled: bool = false):
	if typeof(item) == TYPE_DICTIONARY:
		for part in item.keys():
			# Use the helper function to get the correct node
			var part_node = get_adjusted_node(character, part)
			if part_node and part_node is Sprite2D:
				# Replace RightArm with the corresponding hook sprite if the hook is enabled
				if is_hook_enabled and part == "rightarm":
					var right_arm_sprite = item[part]
					# Ensure that 'right_arm_sprite' has a valid 'get_file' method
					if right_arm_sprite.has_method("get_file"):
						var file_name = right_arm_sprite.get_file().replace("rarm", "hook")
						var hook_sprite = "res://CharacterCreation/customizations/misc/" + file_name
						var loaded_texture = load(hook_sprite)
						if loaded_texture:
							part_node.texture = loaded_texture
						else:
							push_error("Failed to load hook sprite: " + hook_sprite)
					else:
						push_error("right_arm_sprite does not have a 'get_file' method.")
				else:
					var texture_path = item[part]
					var loaded_texture = load(texture_path)
					if loaded_texture:
						part_node.texture = loaded_texture
					else:
						push_error("Failed to load texture: " + texture_path)
	else:
		# For single-part items, adjust the node path accordingly
		var target_node = get_adjusted_node(character, category)
		if target_node and target_node is Sprite2D:
			var loaded_texture = load(item)
			if loaded_texture:
				target_node.texture = loaded_texture
			else:
				push_error("Failed to load texture: " + item)

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
