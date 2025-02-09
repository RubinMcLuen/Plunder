extends CharacterBody2D

@export var npc_name: String  # Used to look up the NPC's data in the JSON file
const NPC_DATA_PATH := "res://npcs.json"  # Adjust as needed
@export var player_direction: bool = true

var dialogue_resource

# Animation and Fighting Variables
var fighting: bool = false
var direction: Vector2 = Vector2.RIGHT
const FRAMES_PER_ANIMATION = 8
var sprite_parts: Array[Sprite2D] = []

# ---------------------------
# OVERRIDE ANIMATION VARIABLES
# ---------------------------
var anim_override: bool = false
var anim_override_start_time: int = 0
var anim_override_duration: int = 0
var current_anim: String = "idle"   # "idle", "slash", or "hurt"

# ---------------------------
# Helper Functions
# ---------------------------
func safe_load(path: String) -> Resource:
	if path.strip_edges() == "":
		return null
	return load(path)

func load_appearance() -> void:
	var file := FileAccess.open(NPC_DATA_PATH, FileAccess.READ)
	if file:
		var json_text := file.get_as_text()
		file.close()
		var json := JSON.new()
		var err := json.parse(json_text)
		if err != OK:
			push_error("Failed to parse JSON: " + json.get_error_message())
			return
		var npc_data = json.get_data()
		if npc_data.has(npc_name):
			var data = npc_data[npc_name]
			$Appearance/skin.texture         = safe_load(data.get("skin", ""))
			$Appearance/hat.texture          = safe_load(data.get("hat", ""))
			$Appearance/facialhair.texture   = safe_load(data.get("facialhair", ""))
			$Appearance/Top/leftarm.texture    = safe_load(data.get("leftarm", ""))
			$Appearance/Top/rightarm.texture   = safe_load(data.get("rightarm", ""))
			$Appearance/Top/body.texture       = safe_load(data.get("body", ""))
			$Appearance/Bottom/leftleg.texture    = safe_load(data.get("leftleg", ""))
			$Appearance/Bottom/rightleg.texture   = safe_load(data.get("rightleg", ""))
			
			var dialogue_path = data.get("dialogue_file", "")
			if dialogue_path.strip_edges() != "":
				dialogue_resource = load(dialogue_path)
			else:
				dialogue_resource = null
		else:
			push_error("NPC name '" + npc_name + "' not found in " + NPC_DATA_PATH)
	else:
		push_error("NPC data file not found: " + NPC_DATA_PATH)

# ---------------------------
# Animation Functions
# ---------------------------
func play_idle() -> void:
	var frame = (Time.get_ticks_msec() / 100) % FRAMES_PER_ANIMATION
	var base_frame = 0 * FRAMES_PER_ANIMATION
	var current_frame = base_frame + frame
	var flip_h = (direction == Vector2.LEFT)
	for part in sprite_parts:
		part.flip_h = flip_h
		part.frame = current_frame

func play_idle_with_sword() -> void:
	var frame = (Time.get_ticks_msec() / 100) % FRAMES_PER_ANIMATION
	var base_frame = 5 * FRAMES_PER_ANIMATION
	var current_frame = base_frame + frame
	var flip_h = (direction == Vector2.LEFT)
	for part in sprite_parts:
		part.flip_h = flip_h
		part.frame = current_frame

# ---------------------------
# OVERRIDE ANIMATION FUNCTIONS
# ---------------------------
func play_hurt_animation() -> void:
	# Hurt animation: row 6, 3 frames (300ms total)
	anim_override = true
	anim_override_start_time = Time.get_ticks_msec()
	anim_override_duration = 300
	current_anim = "hurt"

func play_slash_animation() -> void:
	# Slash animation: row 4, 8 frames (800ms total)
	anim_override = true
	anim_override_start_time = Time.get_ticks_msec()
	anim_override_duration = 800
	current_anim = "slash"

func update_animation() -> void:
	if anim_override:
		var elapsed = Time.get_ticks_msec() - anim_override_start_time
		if current_anim == "slash":
			var frame_index = min(int(elapsed / 100), 7)
			var base_frame = 4 * FRAMES_PER_ANIMATION
			var current_frame = base_frame + frame_index
			var flip_h = (direction == Vector2.LEFT)
			for part in sprite_parts:
				part.flip_h = flip_h
				part.frame = current_frame
		elif current_anim == "hurt":
			var frame_index = min(int(elapsed / 100), 2)
			var base_frame = 6 * FRAMES_PER_ANIMATION
			var current_frame = base_frame + frame_index
			var flip_h = (direction == Vector2.LEFT)
			for part in sprite_parts:
				part.flip_h = flip_h
				part.frame = current_frame

		if elapsed >= anim_override_duration:
			anim_override = false
			current_anim = "idle"
	else:
		if fighting:
			play_idle_with_sword()
		else:
			play_idle()

func _physics_process(_delta: float) -> void:
	update_animation()

# ---------------------------
# Node Setup and Input
# ---------------------------
func _ready() -> void:
	load_appearance()
	$Area2D.connect("input_event", Callable(self, "_on_area_input_event"))
	
	
	sprite_parts = [
		$Appearance/skin,
		$Appearance/hat,
		$Appearance/facialhair,
		$Appearance/Top/leftarm,
		$Appearance/Top/rightarm,
		$Appearance/Top/body,
		$Appearance/Bottom/leftleg,
		$Appearance/Bottom/rightleg
	]


func _on_area_input_event(_viewport, event, _shape_idx) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Only allow dialogue if not fighting.
		if not fighting:
			var balloon = DialogueManager.show_dialogue_balloon(dialogue_resource, "introduction", [self])
			balloon.connect("dialogue_finished", Callable(self, "_on_dialogue_finished"))



func _on_dialogue_finished():
	var sword_fight_scene = load("res://SwordFight/sword_fight.tscn")
	if sword_fight_scene:
		var sword_fight_instance = sword_fight_scene.instantiate()
		# Base offset for the sword fight instance.
		var offset = Vector2(-257, -152)
		# If player_direction is false, subtract an extra 64 on the x-axis.
		if player_direction:
			offset.x += 32
		sword_fight_instance.position += offset
		self.add_child(sword_fight_instance)



