# CharacterCustomizationResource.gd
extends Resource
class_name CharacterCustomizationResource

@export var sprite_atlas: Texture2D

# Option indices (column index) for each category.
@export var skin_option: int = 0
@export var top_option: int = 0
@export var bottom_option: int = 0
@export var hat_option: int = 0
@export var facial_hair_option: int = 0
@export var hair_option: int = 0

# For misc (row 4): toggle each option on/off.
@export var misc_eyepatch: bool = false
@export var misc_hook: bool = false
@export var misc_peg_leg: bool = false

# The size of one cell (and the final composite image) is 32x32.
@export var lookup_size: Vector2i = Vector2i(48, 48)
const CELL_SIZE: Vector2i = Vector2i(48, 48)

# Helper function: blends a cell from the atlas into final_img.
func _blend_piece(final_img: Image, atlas_img: Image, col: int, row: int) -> void:
	var src_rect = Rect2i(col * CELL_SIZE.x, row * CELL_SIZE.y, CELL_SIZE.x, CELL_SIZE.y)
	# Use blend_rect so that the source image's alpha blends over the destination.
	final_img.blend_rect(atlas_img, src_rect, Vector2i(0, 0))

# Generate the composite lookup image by blending cells from the atlas.
func generate_lookup_image() -> Image:
	if sprite_atlas == null:
		push_error("No sprite_atlas set on CharacterCustomizationResource!")
		return null
	
	# Get the atlas image.
	var atlas_img: Image = sprite_atlas.get_image()
	if atlas_img == null:
		push_error("Atlas image is null. Check your import settings.")
		return null
	
	# Create a blank 32x32 image (RGBA8 format).
	var final_img: Image = Image.create(CELL_SIZE.x, CELL_SIZE.y, false, Image.FORMAT_RGBA8)
	
	# Blend pieces in order (back-to-front). Later calls will be blended on top of previous ones.
	_blend_piece(final_img, atlas_img, skin_option, 0)
	_blend_piece(final_img, atlas_img, hair_option, 6)
	_blend_piece(final_img, atlas_img, facial_hair_option, 5)
	if misc_eyepatch:
		_blend_piece(final_img, atlas_img, 0, 4)
	_blend_piece(final_img, atlas_img, hat_option, 3)
	_blend_piece(final_img, atlas_img, bottom_option, 2)
	_blend_piece(final_img, atlas_img, top_option, 1)
	
	if misc_hook:
		_blend_piece(final_img, atlas_img, 1, 4)
	if misc_peg_leg:
		_blend_piece(final_img, atlas_img, 2, 4)
	
	
	return final_img

# Creates a Texture2D from the composited image.
func generate_lookup_texture() -> Texture2D:
	var final_img = generate_lookup_image()
	if final_img == null:
		return null
	
	var tex: Texture2D = ImageTexture.create_from_image(final_img)
	return tex
