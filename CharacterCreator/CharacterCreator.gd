# CharacterCreator.gd — Godot 4.22
extends Node2D
class_name CharacterCreator

# ─────────────────────────────────────────────────────────────────────
#  EXPORTED / ONREADY NODES
# ─────────────────────────────────────────────────────────────────────
@onready var name_input:    LineEdit         = $CharacterNameArea/NameInput
@onready var player:        Node2D           = $Player
@onready var appearance:    AnimatedSprite2D = $Player/Appearance
@onready var finish_button: TextureButton    = $Window/FinishButton
@onready var header:   Node2D           = $Window/Header
@onready var cat_buttons:   Node             = $Window/CategoryButtons
@onready var item_buttons:  Node             = $Window/ItemButtons
@onready var slider:        Node             = $Window/Slider

# ─────────────────────────────────────────────────────────────────────
#  CONSTANTS
# ─────────────────────────────────────────────────────────────────────
const CUSTOM_RES_PATH  := "res://Character/Player/PlayerCustomization.tres"
const OPTIONS_JSON     := "res://CharacterCreator/AssetIndex.json"
const PAGE_SIZE        := 6
const CATEGORIES       := ["skin", "top", "bottom", "hat", "misc", "hair"]
const HEADER_MOVE_Y       := 17.0
const HEADER_TWEEN_TIME   := 0.3

# ─────────────────────────────────────────────────────────────────────
#  STATE
# ─────────────────────────────────────────────────────────────────────
var current_category: String = "skin"
var current_page:     int    = 0
var options:          Dictionary = {}

var customization: CharacterCustomizationResource
var character_data: Dictionary = {
	"name": "",
	"skin": "",
	"top": "",
	"bottom": "",
	"hat": "",
	"hair": "",
	"misc": {
		"eyepatch": false,
		"hook":      false,
		"peg_leg":   false,
	},
}

# ─────────────────────────────────────────────────────────────────────
#  READY
# ─────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_init_customization_resource()
	_load_all_options()
	_connect_ui()
	_refresh_ui()

# ─────────────────────────────────────────────────────────────────────
#  INITIALISATION
# ─────────────────────────────────────────────────────────────────────
func _init_customization_resource() -> void:
	customization = (load(CUSTOM_RES_PATH) as CharacterCustomizationResource).duplicate()
	if not customization or not appearance:
		push_error("Failed to load CharacterCustomizationResource or Appearance node.")
		return

	appearance.material = appearance.material.duplicate()
	_update_player_texture()

func _load_all_options() -> void:
	var json_text: String = FileAccess.get_file_as_string(OPTIONS_JSON)
	var json: JSON = JSON.new()
	var err: int = json.parse(json_text)
	if err != OK:
		push_error("Failed to parse %s at line %d: %s" %
			[OPTIONS_JSON, json.get_error_line(), json.get_error_message()])
		return
	var data_dict: Dictionary = json.get_data() as Dictionary
	for cat in CATEGORIES:
		options[cat] = data_dict.get(cat, [])



# ─────────────────────────────────────────────────────────────────────
#  UI WIRING
# ─────────────────────────────────────────────────────────────────────
func _connect_ui() -> void:
	cat_buttons.category_selected.connect(_on_category_selected)
	item_buttons.item_selected.connect(_on_item_selected)
	slider.page_changed.connect(_on_page_changed)
	finish_button.pressed.connect(_on_finish)

# ─────────────────────────────────────────────────────────────────────
#  UI REFRESH
# ─────────────────────────────────────────────────────────────────────
func _refresh_ui() -> void:
	_update_slider()
	_populate_items()

func _populate_items() -> void:
	item_buttons.populate_buttons(current_category, options, current_page)

func _update_slider() -> void:
	var total: int = options[current_category].size()
	var pages: int = clampi((total + PAGE_SIZE - 1) / PAGE_SIZE, 1, 5)  # ceiling-divide
	slider.set_page_count(pages)
	slider.reset_to_first_page()


# ─────────────────────────────────────────────────────────────────────
#  SIGNAL CALLBACKS
# ─────────────────────────────────────────────────────────────────────
func _on_category_selected(cat: String) -> void:
	current_category = cat
	current_page = 0
	_refresh_ui()

func _on_page_changed(page: int) -> void:
	current_page = page
	_populate_items()

func _on_item_selected(cat: String, item) -> void:
	match cat:
		"skin":   customization.skin_option   = item
		"top":    customization.top_option    = item
		"bottom": customization.bottom_option = item
		"hat":    customization.hat_option    = item
		"hair":   customization.hair_option   = item
		"misc":   _toggle_misc(int(item))
	_update_player_texture()

func _toggle_misc(idx: int) -> void:
	match idx:
		0: customization.misc_eyepatch = !customization.misc_eyepatch
		1: customization.misc_hook     = !customization.misc_hook
		2: customization.misc_peg_leg  = !customization.misc_peg_leg

# ─────────────────────────────────────────────────────────────────────
#  TEXTURE REBUILD
# ─────────────────────────────────────────────────────────────────────
func _update_player_texture() -> void:
	var tex := customization.generate_lookup_texture()
	if tex:
		appearance.material.set_shader_parameter("map_texture", tex)

# ─────────────────────────────────────────────────────────────────────
#  HEADER ANIMATION  (called from TitleScreen)
# ─────────────────────────────────────────────────────────────────────
func animate_header(down: bool) -> Tween:
	var delta := HEADER_MOVE_Y * (1 if down else -1)
	var tw := create_tween()
	tw.tween_property(header, "global_position:y",
		header.global_position.y + delta, HEADER_TWEEN_TIME
	)
	return tw


# ─────────────────────────────────────────────────────────────────────
#  FINISH / SAVE
# ─────────────────────────────────────────────────────────────────────
func _on_finish() -> void:
	_build_character_data()
	_save_data()
	SceneSwitcher.switch_scene(
		"res://KelptownInn/KelptownInn.tscn",
		Vector2(381, 23),
		"fade"
	)

func _build_character_data() -> void:
	character_data["name"]   = name_input.text.strip_edges()
	character_data["skin"]   = str(customization.skin_option)
	character_data["top"]    = str(customization.top_option)
	character_data["bottom"] = str(customization.bottom_option)
	character_data["hat"]    = str(customization.hat_option)
	character_data["hair"]   = str(customization.hair_option)
	character_data["misc"] = {
		"eyepatch": customization.misc_eyepatch,
		"hook":     customization.misc_hook,
		"peg_leg":  customization.misc_peg_leg,
	}

func _save_data() -> void:
	var slot := Global.active_save_slot
	var path := "user://saveslot%d.json" % slot

	# start with an empty dict
	var full_data: Dictionary = {}

	# if there’s already a file, try to load it as a Dictionary
	if FileAccess.file_exists(path):
		var text := FileAccess.get_file_as_string(path)
		var parsed = JSON.parse_string(text)     # no inference, parsed is a Variant
		if parsed is Dictionary:
			full_data = parsed

	# overwrite only the character sub-key
	full_data["character"] = character_data

	var fw := FileAccess.open(path, FileAccess.WRITE)
	fw.store_string(JSON.stringify(full_data))
	fw.close()


