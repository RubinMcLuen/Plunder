extends Node2D

# Global UI nodes
@export var name_input: LineEdit
@export var finish_button: TextureButton
@export var header_node: Node2D

# The customization categories (must match keys in your options JSON)
var categories = ["skin", "top", "bottom", "hat", "misc", "hair"]
var page_size  = 6

var current_category: String = "skin"
var current_page: int = 0
var options: Dictionary = {}

# Main display now uses the Player node.
var player: Node
# We'll assume the Player node has a child AnimatedSprite2D named Appearance.
# Also, the Player node holds its customization resource.
var customization_resource: CharacterCustomizationResource

# No individual sprite nodes now; the composite texture is generated in the resource.
var is_flashing: bool = false

# (Optional) Remove hook logic entirely—now misc has three independent toggles.
# Character data for saving (if still used)
var character_data: Dictionary = {
	"name": "",
	"skin": "",
	"top": "",
	"bottom": "",
	"hat": "",
	"misc": {},   # Will store a dictionary for misc toggles.
	"hair": ""
}

#
# ──────────────────────────────────────────────────────────────────────────────
#  GODOT LIFECYCLE METHODS
# ──────────────────────────────────────────────────────────────────────────────
#
func _ready():
	_initialize_player_node()
	_load_all_options()
	_connect_ui_signals()
	
	# Initialize slider for the default category.
	update_slider_for_category(current_category)
	populate_item_buttons(current_category, current_page)
	
	if finish_button:
		finish_button.connect("pressed", self._on_finish_button_pressed)

#
# ──────────────────────────────────────────────────────────────────────────────
#  INITIALIZATION & SETUP
# ──────────────────────────────────────────────────────────────────────────────
#
func _initialize_player_node():
	# Get the main display node; now it's called "Player"
	player = get_node("Player")
	# We assume the Player node has a child AnimatedSprite2D named "Appearance"
	# and that it uses a ShaderMaterial with a uniform "map_texture".
	customization_resource = ResourceLoader.load("res://Character/Player/PlayerCustomization.tres") as CharacterCustomizationResource
	var appearance = player.get_node("Appearance") as AnimatedSprite2D
	if customization_resource and appearance and appearance.material:
		# Duplicate the material to have a unique instance.
		appearance.material = appearance.material.duplicate()
		# Compile and assign the composite texture.
		var composite_tex: Texture2D = customization_resource.generate_lookup_texture()
		appearance.material.set_shader_parameter("map_texture", composite_tex)
		print("Initialized composite texture with RID: ", composite_tex.get_rid())
	else:
		push_error("Failed to initialize player customization resource or Appearance node.")

func animate_header(reverse: bool = false) -> Tween:
	# If reverse is false, move down by 29 pixels; if true, move up by 29 pixels.
	var offset: int = -17 if not reverse else 17
	var tween = create_tween()
	tween.tween_property(header_node, "global_position:y", header_node.global_position.y + offset, 0.3) \
		.set_trans(Tween.TRANS_LINEAR) \
		.set_ease(Tween.EASE_IN_OUT)
	return tween
#
# ──────────────────────────────────────────────────────────────────────────────
#  LOAD ASSET INDEX JSON
# ──────────────────────────────────────────────────────────────────────────────
#
func _load_all_options():
	var file = FileAccess.open("res://CharacterCreation/asset_index.json", FileAccess.READ)
	if file:
		var text = file.get_as_text()
		var data = JSON.parse_string(text)
		if typeof(data) == TYPE_DICTIONARY:
			for category in categories:
				if data.has(category):
					options[category] = data[category]
				else:
					options[category] = []
		else:
			print("JSON parse error or data not a Dictionary. Got type: ", typeof(data))
	else:
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
	# Simply pass the options to the item buttons.
	item_buttons.populate_buttons(category, options, page)

func update_slider_for_category(category: String) -> void:
	var total_items = options[category].size()
	var required_pages = int(ceil(total_items / float(page_size)))
	required_pages = min(required_pages, 5)
	var slider_node = get_node("Window/Slider")
	slider_node.set_page_count(required_pages)
	slider_node.reset_to_first_page()

func _on_category_selected(category: String):
	current_category = category
	current_page = 0
	populate_item_buttons(current_category, current_page)
	update_slider_for_category(current_category)

func _on_page_changed(new_page: int):
	current_page = new_page
	populate_item_buttons(current_category, current_page)

#
# ──────────────────────────────────────────────────────────────────────────────
#  ITEM SELECTION – UPDATE CUSTOMIZATION RESOURCE & RECOMPILE TEXTURE
# ──────────────────────────────────────────────────────────────────────────────
#
func _on_item_selected(category: String, item):
	# Update the customization resource for the chosen category.
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
			_apply_misc(item)
	# After updating a category, recompile the composite texture and update the Player's Appearance.
	_update_player_customization_texture()

# For each category, update the corresponding property in customization_resource.
# We assume the resource now expects a simple integer index for most categories.
func _apply_skin(item):
	customization_resource.skin_option = int(item)

func _apply_hat(item):
	customization_resource.hat_option = int(item)

func _apply_hair(item):
	customization_resource.hair_option = int(item)

func _apply_top(item):
	customization_resource.top_option = int(item)

func _apply_bottom(item):
	customization_resource.bottom_option = int(item)

# For misc, toggle the appropriate boolean based on the selected index.
func _apply_misc(item):
	var idx = int(item)
	match idx:
		0:
			customization_resource.misc_eyepatch = !customization_resource.misc_eyepatch
		1:
			customization_resource.misc_hook = !customization_resource.misc_hook
		2:
			customization_resource.misc_peg_leg = !customization_resource.misc_peg_leg
		_:
			# If somehow an index outside 0-2 is selected, do nothing.
			pass

# Recompile and update the player's composite texture.
func _update_player_customization_texture():
	var composite_tex: Texture2D = customization_resource.generate_lookup_texture()
	if composite_tex:
		var appearance = player.get_node("Appearance") as AnimatedSprite2D
		# Duplicate material to ensure a unique instance.
		appearance.material = appearance.material.duplicate()
		appearance.material.set_shader_parameter("map_texture", composite_tex)
		print("Updated composite texture with RID: ", composite_tex.get_rid())
	else:
		push_error("Failed to generate composite texture.")

#
# ──────────────────────────────────────────────────────────────────────────────
#  FINISH / SAVE / LOAD (unchanged, if needed)
# ──────────────────────────────────────────────────────────────────────────────
#
func _on_finish_button_pressed() -> void:
	update_character_data()
	save_character_data()
	
	print("Finished customization, data saved, and loading next scene.")
	SceneSwitcher.switch_scene("res://KelptownInn/KelptownInnIntroCutscene.tscn", Vector2(381, 23), "fade")

func update_character_data():
	ensure_character_data_integrity()
	
	if name_input:
		character_data["name"] = name_input.text.strip_edges() if name_input.text else ""
	# Update character_data with values from customization_resource.
	character_data["skin"] = str(customization_resource.skin_option)
	character_data["top"] = str(customization_resource.top_option)
	character_data["bottom"] = str(customization_resource.bottom_option)
	character_data["hat"] = str(customization_resource.hat_option)
	character_data["hair"] = str(customization_resource.hair_option)
	# For misc, store a dictionary of booleans.
	character_data["misc"] = {
		"eyepatch": str(customization_resource.misc_eyepatch),
		"hook": str(customization_resource.misc_hook),
		"peg_leg": str(customization_resource.misc_peg_leg)
	}

func save_character_data():
	var slot = Global.active_save_slot
	var save_file_path = "user://saveslot" + str(slot) + ".json"
	var save_data = {"character": character_data}
	print("Saving data to:", save_file_path)
	var file = FileAccess.open(save_file_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(save_data))
	file.close()
	print("Character data saved successfully to slot", slot)

func ensure_character_data_integrity():
	if "top" not in character_data:
		character_data["top"] = ""
	if "bottom" not in character_data:
		character_data["bottom"] = ""
	if "misc" not in character_data:
		character_data["misc"] = {}
	if "hair" not in character_data:
		character_data["hair"] = ""
