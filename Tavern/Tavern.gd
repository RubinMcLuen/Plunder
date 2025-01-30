extends Node2D

# Path to save slots
const SAVE_FILE_BASE_PATH = "user://saveslot"
@export var character: Node2D  # Character node to load data into
var skin_node
var hat_node
var facial_hair_node
var left_arm_node
var right_arm_node
var body_node
var left_leg_node
var right_leg_node
var save_slot: int = -1
@export var name_input: LineEdit


func _ready():
	# Ensure the character node is valid
	if not character:
		print("Error: Character node not assigned.")
		return

	# Get all relevant nodes for character customization
	skin_node = character.get_node("Appearance/skin")
	hat_node = character.get_node("Appearance/hat")
	facial_hair_node = character.get_node("Appearance/facialhair")
	left_arm_node = character.get_node("Appearance/Top/leftarm")
	right_arm_node = character.get_node("Appearance/Top/rightarm")
	body_node = character.get_node("Appearance/Top/body")
	left_leg_node = character.get_node("Appearance/Bottom/leftleg")
	right_leg_node = character.get_node("Appearance/Bottom/rightleg")

	# Fetch the save slot number from Global.gd
	save_slot = Global.active_save_slot

	# Validate save slot before loading
	if save_slot >= 0:
		load_character_from_slot(save_slot)
	else:
		print("Invalid save slot number. No data to load.")

func load_character_from_slot(slot_num: int = 0):
	# Build the file path for the save slot
	var save_file_path = "%s%d.json" % [SAVE_FILE_BASE_PATH, slot_num]

	# Check if the save file exists
	if FileAccess.file_exists(save_file_path):
		var file = FileAccess.open(save_file_path, FileAccess.READ)
		if file:
			var json = JSON.new()
			var parse_result = json.parse(file.get_as_text())
			if parse_result == OK:
				var save_data = json.data
				if save_data.has("character"):
					# Apply character data
					apply_character_data(save_data["character"])
				else:
					print("No 'character' key found in save file.")
			else:
				print("Failed to parse save file. Error:", json.error_message())
			file.close()
		else:
			print("Failed to open save file.")
	else:
		print("Save slot does not exist:", slot_num)

func apply_character_data(data: Dictionary):
	if "name" in data and name_input:
		name_input.text = data["name"]

	# Skin
	if data.has("skin") and skin_node:
		var skin_path = data["skin"]
		if skin_path == "":
			skin_node.texture = null
		else:
			skin_node.texture = load(skin_path)

	# Hair
	if data.has("facialhair") and facial_hair_node:
		var facial_hair_path = data["facialhair"]
		if facial_hair_path == "":
			facial_hair_node.texture = null
		else:
			facial_hair_node.texture = load(facial_hair_path)

	# Hat
	if data.has("hat") and hat_node:
		var hat_path = data["hat"]
		if hat_path == "":
			hat_node.texture = null
		else:
			hat_node.texture = load(hat_path)

	# Top (body, left arm, right arm)
	if data.has("top"):
		# Body
		if "body" in data["top"] and body_node:
			var body_path = data["top"]["body"]
			if body_path == "":
				body_node.texture = null
			else:
				body_node.texture = load(body_path)
		# Left Arm
		if "leftarm" in data["top"] and left_arm_node:
			var left_arm_path = data["top"]["leftarm"]
			if left_arm_path == "":
				left_arm_node.texture = null
			else:
				left_arm_node.texture = load(left_arm_path)
		# Right Arm
		if "rightarm" in data["top"] and right_arm_node:
			var right_arm_path = data["top"]["rightarm"]
			if right_arm_path == "":
				right_arm_node.texture = null
			else:
				right_arm_node.texture = load(right_arm_path)

	# Bottom (left leg, right leg)
	if data.has("bottom"):
		# Left Leg
		if "leftleg" in data["bottom"] and left_leg_node:
			var left_leg_path = data["bottom"]["leftleg"]
			if left_leg_path == "":
				left_leg_node.texture = null
			else:
				left_leg_node.texture = load(left_leg_path)
		# Right Leg
		if "rightleg" in data["bottom"] and right_leg_node:
			var right_leg_path = data["bottom"]["rightleg"]
			if right_leg_path == "":
				right_leg_node.texture = null
			else:
				right_leg_node.texture = load(right_leg_path)

	# Misc
	if data.has("misc") and right_arm_node:
		var misc_path = data["misc"]
		if misc_path == "":
			right_arm_node.texture = null
		else:
			right_arm_node.texture = load(misc_path)
