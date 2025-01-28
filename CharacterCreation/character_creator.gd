extends Node2D

#
# ──────────────────────────────────────────────────────────────────────────────
#  GLOBAL VARIABLES & EXPORTS
# ──────────────────────────────────────────────────────────────────────────────
#

@export var name_input: LineEdit
@export var finish_button: TextureButton

var categories = ["skin", "hair", "hat", "top", "bottom", "misc"]
var page_size  = 6

var current_category: String = "skin"
var current_page: int = 0
var options: Dictionary = {}

var character: Node
var skin_node: Sprite2D
var hat_node: Sprite2D
var hair_node: Sprite2D
var left_arm_node: Sprite2D
var right_arm_node: Sprite2D
var body_node: Sprite2D
var left_leg_node: Sprite2D
var right_leg_node: Sprite2D

var is_hook_enabled: bool = false
var active_hook_sprite: String = ""
var original_right_arm_texture: Texture = null
var original_right_arm_texture_path: String = ""

var character_data: Dictionary = {
	"name": "",
	"skin": "",
	"hair": "",
	"hat": "",
	"top": {"body": "", "left_arm": "", "right_arm": ""},
	"bottom": {"left_leg": "", "right_leg": ""},
	"misc": ""
}

#
# ──────────────────────────────────────────────────────────────────────────────
#  GODOT LIFECYCLE METHODS
# ──────────────────────────────────────────────────────────────────────────────
#
func _ready():
	_initialize_character_nodes()
	_load_all_options()
	_connect_ui_signals()
	populate_item_buttons(current_category, current_page)

	if finish_button:
		finish_button.connect("pressed", self._on_finish_button_pressed)

#
# ──────────────────────────────────────────────────────────────────────────────
#  INITIALIZATION & SETUP
# ──────────────────────────────────────────────────────────────────────────────
#
func _initialize_character_nodes():
	character = get_node("Character")
	skin_node = character.get_node("Appearance/Skin")
	hat_node = character.get_node("Appearance/Hat")
	hair_node = character.get_node("Appearance/FacialHair")
	left_arm_node = character.get_node("Appearance/Top/LeftArm")
	right_arm_node = character.get_node("Appearance/Top/RightArm")
	body_node = character.get_node("Appearance/Top/Body")
	left_leg_node = character.get_node("Appearance/Bottom/LeftLeg")
	right_leg_node = character.get_node("Appearance/Bottom/RightLeg")

#
# ──────────────────────────────────────────────────────────────────────────────
#  LOAD ASSET INDEX JSON
# ──────────────────────────────────────────────────────────────────────────────
#
func _load_all_options():
	# Attempt to open the JSON file in read mode
	var file = FileAccess.open("res://CharacterCreation/asset_index.json", FileAccess.READ)
	if file:
		# Read the entire content of the file as text
		var text = file.get_as_text()

		# Parse the JSON text using parse_string(), which returns a Variant
		var data = JSON.parse_string(text)

		# Check if we got a Dictionary back
		if typeof(data) == TYPE_DICTIONARY:
			# data should be the parsed JSON if all went well
			for category in categories:
				if data.has(category):
					options[category] = data[category]
				else:
					options[category] = []
		else:
			# If parse_string() fails or JSON is invalid, it won't be a Dictionary
			print("JSON parse error or data not a Dictionary. Got type: ", typeof(data))
	else:
		# If the file couldn't be opened, print an error
		print("Failed to open asset_index.json")



#
# ──────────────────────────────────────────────────────────────────────────────
#  CONNECT UI SIGNALS
# ──────────────────────────────────────────────────────────────────────────────
#
func _connect_ui_signals():
	var category_buttons = get_node("Window/CategoryButtons")
	category_buttons.connect("category_selected", Callable(self, "_on_category_selected"))

	var item_buttons = get_node("Window/ItemButtons")
	item_buttons.connect("item_selected", Callable(self, "_on_item_selected"))

	var slider_node = get_node("Window/Slider")
	slider_node.connect("page_changed", Callable(self, "_on_page_changed"))

#
# ──────────────────────────────────────────────────────────────────────────────
#  UI & BUTTON POPULATION
# ──────────────────────────────────────────────────────────────────────────────
#
func populate_item_buttons(category: String, page: int):
	var item_buttons = get_node("Window/ItemButtons")
	var main_character_right_arm_texture = right_arm_node.texture if category == "misc" else null
	item_buttons.populate_buttons(category, options, page, main_character_right_arm_texture, is_hook_enabled)

func reset_item_buttons_to_main_character():
	var item_buttons = get_node("Window/ItemButtons")
	for i in range(page_size):
		var button = item_buttons.get_node("Button" + str(i + 1))
		var button_character = button.get_node("Character")

		button_character.get_node("Skin").texture     = skin_node.texture
		button_character.get_node("Hat").texture      = hat_node.texture
		button_character.get_node("Hair").texture     = hair_node.texture
		button_character.get_node("LeftArm").texture  = left_arm_node.texture
		button_character.get_node("RightArm").texture = right_arm_node.texture
		button_character.get_node("Body").texture     = body_node.texture
		button_character.get_node("LeftLeg").texture  = left_leg_node.texture
		button_character.get_node("RightLeg").texture = right_leg_node.texture

#
# ──────────────────────────────────────────────────────────────────────────────
#  SIGNAL HANDLERS
# ──────────────────────────────────────────────────────────────────────────────
#
func _on_category_selected(category: String):
	current_category = category
	current_page = 0
	reset_item_buttons_to_main_character()
	populate_item_buttons(current_category, current_page)

func _on_page_changed(new_page: int):
	current_page = new_page
	populate_item_buttons(current_category, current_page)

func _on_item_selected(category: String, item):
	match category:
		"skin":
			_apply_skin(item)
		"hat":
			_apply_hat(item)
		"hair":
			_apply_hair(item)
		"top":
			_apply_top(item)
		"bottom":
			_apply_bottom(item)
		"misc":
			_toggle_hook()

#
# ──────────────────────────────────────────────────────────────────────────────
#  APPLYING INDIVIDUAL CATEGORIES
# ──────────────────────────────────────────────────────────────────────────────
#
func _apply_skin(item):
	if skin_node and item is String:
		skin_node.texture = load(item)

func _apply_hat(item):
	if hat_node and item is String:
		hat_node.texture = load(item)

func _apply_hair(item):
	if hair_node and item is String:
		hair_node.texture = load(item)

func _apply_top(item):
	# Expecting a dictionary like:
	# { "Body": "res://.../body0.png", "LeftArm": "res://.../larm0.png", "RightArm": "res://.../rarm2.png" }
	if typeof(item) == TYPE_DICTIONARY:
		for part in item.keys():
			var node_path = "Appearance/Top/" + part
			var node = character.get_node(node_path)
			
			if node and node is Sprite2D and item[part] is String:
				# Load the new normal texture from the path
				var new_tex_path = item[part]  # e.g. "res://CharacterCreation/customizations/top/RightArm/rarm2.png"
				node.texture = load(new_tex_path)

				# If it's the RightArm, store its path for hooking
				if part == "RightArm":
					original_right_arm_texture_path = new_tex_path

					# If we are already in "hook mode," re-apply the matching hook
					if is_hook_enabled:
						var file_name = new_tex_path.get_file()
						var hook_file_name = file_name.replace("rarm", "hook")
						var hook_path = "res://CharacterCreation/customizations/misc/" + hook_file_name
						node.texture = load(hook_path)
						active_hook_sprite = hook_path

func _apply_bottom(item):
	# Expecting a dictionary like:
	# { "LeftLeg": "res://.../lleg0.png", "RightLeg": "res://.../rleg1.png" }
	if typeof(item) == TYPE_DICTIONARY:
		for part in item.keys():
			var node_path = "Appearance/Bottom/" + part
			var node = character.get_node(node_path)
			if node and node is Sprite2D and item[part] is String:
				node.texture = load(item[part])

#
# ──────────────────────────────────────────────────────────────────────────────
#  HOOK (MISC) TOGGLE LOGIC
# ──────────────────────────────────────────────────────────────────────────────
#
func _toggle_hook():
	var target_node = right_arm_node
	if target_node and target_node is Sprite2D:
		# If we haven't yet stored a RightArm path, store whatever's currently there
		if original_right_arm_texture_path == "":
			original_right_arm_texture_path = target_node.texture.resource_path
		
		if !is_hook_enabled:
			# Turn hook ON
			var file_name = original_right_arm_texture_path.get_file()  # e.g. "rarm2.png"
			var hook_file_name = file_name.replace("rarm", "hook")      # "hook2.png"
			var hook_path = "res://CharacterCreation/customizations/misc/" + hook_file_name
			target_node.texture = load(hook_path)
			
			active_hook_sprite = hook_path
			is_hook_enabled = true
		else:
			# Turn hook OFF (restore normal arm)
			target_node.texture = load(original_right_arm_texture_path)
			
			active_hook_sprite = ""
			is_hook_enabled = false

#
# ──────────────────────────────────────────────────────────────────────────────
#  FINISH / SAVE / LOAD
# ──────────────────────────────────────────────────────────────────────────────
#
func _on_finish_button_pressed():
	update_character_data()
	save_character_data()

	print("Finished customization and data saved.")
	get_tree().change_scene_to_file("res://Island/Island.tscn")

func update_character_data():
	ensure_character_data_integrity()

	# Store player name
	if name_input:
		character_data["name"] = name_input.text.strip_edges() if name_input.text else ""

	# Skin
	if skin_node and skin_node.texture and skin_node.texture.resource_path != "":
		character_data["skin"] = skin_node.texture.resource_path
	else:
		character_data["skin"] = ""

	# Hair
	if hair_node and hair_node.texture and hair_node.texture.resource_path != "":
		character_data["hair"] = hair_node.texture.resource_path
	else:
		character_data["hair"] = ""

	# Hat
	if hat_node and hat_node.texture and hat_node.texture.resource_path != "":
		character_data["hat"] = hat_node.texture.resource_path
	else:
		character_data["hat"] = ""

	# Top (Body, LeftArm, RightArm)
	if body_node and body_node.texture and body_node.texture.resource_path != "":
		character_data["top"]["body"] = body_node.texture.resource_path
	else:
		character_data["top"]["body"] = ""

	if left_arm_node and left_arm_node.texture and left_arm_node.texture.resource_path != "":
		character_data["top"]["left_arm"] = left_arm_node.texture.resource_path
	else:
		character_data["top"]["left_arm"] = ""

	if right_arm_node and right_arm_node.texture and right_arm_node.texture.resource_path != "":
		character_data["top"]["right_arm"] = right_arm_node.texture.resource_path
	else:
		character_data["top"]["right_arm"] = ""

	# Bottom (LeftLeg, RightLeg)
	if left_leg_node and left_leg_node.texture and left_leg_node.texture.resource_path != "":
		character_data["bottom"]["left_leg"] = left_leg_node.texture.resource_path
	else:
		character_data["bottom"]["left_leg"] = ""

	if right_leg_node and right_leg_node.texture and right_leg_node.texture.resource_path != "":
		character_data["bottom"]["right_leg"] = right_leg_node.texture.resource_path
	else:
		character_data["bottom"]["right_leg"] = ""

	# Hook / misc
	if is_hook_enabled:
		character_data["misc"] = active_hook_sprite
		print(active_hook_sprite)
	else:
		character_data["misc"] = ""

func save_character_data():
	var slot = Global.active_save_slot
	var save_file_path = "user://saveslot" + str(slot) + ".json"
	var save_data = {"character": character_data}

	print("Saving data to:", save_file_path)
	
	var file = FileAccess.open(save_file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()
		print("Character data saved successfully to slot", slot)
	else:
		print("Failed to save character data.")

func apply_character_data(data: Dictionary):
	if "name" in data and name_input:
		name_input.text = data["name"]

	if "skin" in data and skin_node:
		skin_node.texture = load(data["skin"])

	if "hair" in data and hair_node:
		hair_node.texture = load(data["hair"])

	if "hat" in data and hat_node:
		hat_node.texture = load(data["hat"])

	if "top" in data:
		body_node.texture      = load(data["top"]["body"])
		left_arm_node.texture  = load(data["top"]["left_arm"])
		right_arm_node.texture = load(data["top"]["right_arm"])

	if "bottom" in data:
		left_leg_node.texture  = load(data["bottom"]["left_leg"])
		right_leg_node.texture = load(data["bottom"]["right_leg"])

	if "misc" in data:
		right_arm_node.texture = load(data["misc"])

func ensure_character_data_integrity():
	if "top" not in character_data:
		character_data["top"] = {"body": "", "left_arm": "", "right_arm": ""}
	if "bottom" not in character_data:
		character_data["bottom"] = {"left_leg": "", "right_leg": ""}
	if "misc" not in character_data:
		character_data["misc"] = ""

#
# ──────────────────────────────────────────────────────────────────────────────
#  VISIBILITY METHODS (OPTIONAL)
# ──────────────────────────────────────────────────────────────────────────────
#
func turn_on_visibility():
	visible = true

func turn_off_visibility():
	visible = false




