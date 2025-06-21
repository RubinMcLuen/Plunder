# ─────────────────────────────────────────────
# Barnaby.gd
# ─────────────────────────────────────────────
extends NPC

signal dialogue_requested(dialogue_section: String, caller: NPC)

@export var scene_pre_hire    : String  = "res://KelptownInn/KelptownInn.tscn"
@export var position_pre_hire : Vector2 = Vector2(235,  133)
@export var scene_post_hire   : String  = "res://Island/Island.tscn"
@export var position_post_hire: Vector2 = Vector2( 75, 700)

@export var state: String = "Hirable"

func _on_area_input_event(_viewport, event, _shape_idx) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("dialogue_requested", state, self)

# ─────────────────────────────────────────────
# OVERRIDE: suppress auto-hire on dialogue finish
# ─────────────────────────────────────────────
func show_dialogue(dialogue_key: String) -> Node:
        if dialogue_resource == null:
                push_error("Dialogue resource not loaded for NPC " + npc_name)
                return null
        _play_grunt_sound()
        # Show the dialogue balloon WITHOUT connecting it to NPC._on_dialogue_finished
        var balloon = DialogueManager.show_dialogue_balloon(dialogue_resource, dialogue_key, [self])
        return balloon
