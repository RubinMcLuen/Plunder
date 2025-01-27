extends Node2D

# A dictionary to map part names to their respective nodes
@export var parts: Dictionary = {
	"Skin": null,
	"Hat": null,
	"Hair": null,
	"LeftArm": null,
	"Body": null,
	"RightArm": null,
	"LeftLeg": null,
	"RightLeg": null
}

func _ready():
	# Ensure all part nodes are assigned
	for part_name in parts.keys():
		if not parts[part_name]:
			# Dynamically get the child node
			var node = get_node(part_name)
			if node and node is Sprite2D:
				parts[part_name] = node
			else:
				print("Node not found or not a Sprite2D:", part_name)

func change_clothing(part_name: String, texture_path: String) -> void:
	"""
	Changes the texture of the specified part to a new texture.
	
	:param part_name: The name of the body part to change (e.g., "Hat", "Body").
	:param texture_path: The file path to the new texture.
	"""
	if not parts.has(part_name):
		print("Invalid part name:", part_name)
		return

	var sprite_node: Sprite2D = parts[part_name]
	if sprite_node:
		var new_texture = load(texture_path)
		if new_texture:
			sprite_node.texture = new_texture
		else:
			print("Failed to load texture:", texture_path)
	else:
		print("Part node not found:", part_name)
