# Barnaby_Crew.gd
extends CrewMemberNPC
class_name BarnabyCrew

func _ready() -> void:
	super._ready()

	# ─── Override the crewskins palette with Barnaby’s NPC palette ───
	var sheet: Texture2D = preload("res://Character/assets/NPCSprites.png")
	var cell := Vector2i(48, 48)
	var rect := Rect2i(Vector2i(npc_texture_index * cell.x, 0), cell)
	var img  : Image = sheet.get_image()
	var sub  : Image = Image.create(cell.x, cell.y, false, img.get_format())
	sub.blit_rect(img, rect, Vector2.ZERO)
	var tex := ImageTexture.create_from_image(sub)

	body_mat.set_shader_parameter("map_texture", tex)
	body_mat.set_shader_parameter("hurt_mode", false)
	appearance.material = body_mat
