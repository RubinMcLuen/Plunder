# PaidActor.gd
extends NPC
class_name PaidActor

signal dialogue_requested(dialogue_section: String)

# ──────────────────────────
# Editor-exposed proxies
# ──────────────────────────
@export var editor_npc_name: String = ""
@export var editor_hirability: bool = false
@export var state: String           = "default"

func _ready() -> void:
	# 1) Run NPC._ready() so we get the base setup (including the area2d.connect)
	super._ready()

	# 2) Copy inspector values into the real NPC exports
	npc_name = editor_npc_name
	hirable  = editor_hirability

	# (No need to connect area2d here—done by NPC._ready())

func _on_area_input_event(_viewport, event, _shape_idx) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("dialogue_requested", state)
