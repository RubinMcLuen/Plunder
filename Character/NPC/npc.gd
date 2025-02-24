extends CharacterBody2D
class_name NPC

@export var npc_name: String  # Used to look up the NPC's data in the JSON file
const NPC_DATA_PATH := "res://npcs.json"  # Adjust as needed
@export var player_direction: bool = true

# When customization_only is true, no animations will be updated.
@export var customization_only: bool = false
# When fightable is true, the fight scene will be initiated after dialogue.
@export var fightable: bool = false

var dialogue_resource

# ---------------------------
# Animation and Fighting Variables
# ---------------------------
var fighting: bool = false
var direction: Vector2 = Vector2.RIGHT
const FRAMES_PER_ANIMATION = 8
var sprite_parts: Array[Sprite2D] = []

# Idle animation randomization variables
var idle_offset: int = 0
var idle_start_time: int = 0

# ---------------------------
# Health Mechanics
# ---------------------------
signal end_fight   # Signal emitted when NPC health reaches 0
@export var health: int = 3

# ---------------------------
# Animation Override Variables
# ---------------------------
var anim_override: bool = false
var anim_override_start_time: int = 0
var anim_override_duration: int = 0
var current_anim: String = "idle"   # "idle", "slash", or "hurt"

# Flag to continuously play sword idle animation
var idle_with_sword: bool = false

func set_idle_with_sword_mode(enabled: bool) -> void:
	idle_with_sword = enabled

# ---------------------------
# Movement and Auto-Move Variables
# ---------------------------
@export var speed: float = 100
var auto_move: bool = false
var auto_target_position: Vector2 = Vector2.ZERO

# Unique signal for when auto-movement finishes
signal npc_move_completed

# Matching player's input variables
var disable_user_input: bool = false
var custom_velocity: Vector2 = Vector2.ZERO

# ---------------------------
# Helper Functions
# ---------------------------
func safe_load(path: String) -> Resource:
	if path.strip_edges() == "":
		return null
	return load(path)

func load_appearance() -> void:
	var file = FileAccess.open(NPC_DATA_PATH, FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		file.close()
		var json := JSON.new()
		var err := json.parse(json_text)
		if err != OK:
			push_error("Failed to parse JSON: " + json.get_error_message())
			return
		var npc_data = json.get_data()
		if npc_data.has(npc_name):
			var data = npc_data[npc_name]
			$Appearance/skin.texture       = safe_load(data.get("skin", ""))
			$Appearance/hat.texture        = safe_load(data.get("hat", ""))
			$Appearance/facialhair.texture = safe_load(data.get("facialhair", ""))
			$Appearance/Top/leftarm.texture  = safe_load(data.get("leftarm", ""))
			$Appearance/Top/rightarm.texture = safe_load(data.get("rightarm", ""))
			$Appearance/Top/body.texture     = safe_load(data.get("body", ""))
			$Appearance/Bottom/leftleg.texture  = safe_load(data.get("leftleg", ""))
			$Appearance/Bottom/rightleg.texture = safe_load(data.get("rightleg", ""))

			var dialogue_path = data.get("dialogue_file", "")
			if dialogue_path.strip_edges() != "":
				dialogue_resource = load(dialogue_path)
			else:
				dialogue_resource = null
		else:
			push_error("NPC name '%s' not found in %s" % [npc_name, NPC_DATA_PATH])
	else:
		push_error("NPC data file not found: %s" % NPC_DATA_PATH)

# ---------------------------
# Animation Functions
# ---------------------------
func play_idle() -> void:
	var elapsed = Time.get_ticks_msec() - idle_start_time
	var frame = int((elapsed / 100) + idle_offset) % FRAMES_PER_ANIMATION
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

func play_hurt_animation() -> void:
	anim_override = true
	anim_override_start_time = Time.get_ticks_msec()
	anim_override_duration = 300  # 3 frames * 100ms each
	current_anim = "hurt"

func play_slash_animation() -> void:
	anim_override = true
	anim_override_start_time = Time.get_ticks_msec()
	anim_override_duration = 800  # 8 frames * 100ms each
	current_anim = "slash"

# New: Walk animation similar to player's script
const WALK_ROW = 2
func animate_walk() -> void:
	var frame = (Time.get_ticks_msec() / 100) % FRAMES_PER_ANIMATION
	var base_frame = WALK_ROW * FRAMES_PER_ANIMATION
	var current_frame = base_frame + frame
	var flip_h = (direction == Vector2.LEFT)
	for part in sprite_parts:
		part.flip_h = flip_h
		part.frame = current_frame

func update_animation() -> void:
	if customization_only:
		# Show the first idle frame if just customizing
		var base_frame = 0
		for part in sprite_parts:
			part.flip_h = (direction == Vector2.LEFT)
			part.frame = base_frame
		return

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
			idle_offset = randi() % FRAMES_PER_ANIMATION
			idle_start_time = Time.get_ticks_msec()
	else:
		# Use walk animation if auto-moving
		if auto_move:
			animate_walk()
		# If fighting and idle_with_sword is enabled, use sword idle
		elif fighting and idle_with_sword:
			play_idle_with_sword()
		else:
			play_idle()

# ---------------------------
# Movement and Input
# ---------------------------
func _physics_process(_delta: float) -> void:
	handle_npc_input()
	update_animation()
	move_and_slide()

func handle_npc_input() -> void:
	# If input is disabled and not auto-moving, zero velocity.
	if disable_user_input and not auto_move:
		custom_velocity = Vector2.ZERO
		velocity = custom_velocity
		return

	# Auto-movement takes priority.
	if auto_move:
		var diff = auto_target_position - global_position
		# Tolerance increased to 5.0 pixels.
		if diff.length() < 5.0:
			global_position = auto_target_position
			auto_move = false
			custom_velocity = Vector2.ZERO
			velocity = custom_velocity
			print("NPC finished moving. Emitting npc_move_completed")
			emit_signal("npc_move_completed")
		else:
			custom_velocity = diff.normalized() * speed
			velocity = custom_velocity
			# Update facing direction based on movement.
			direction = (Vector2.LEFT if diff.x < 0 else Vector2.RIGHT)
		return

	# If fighting is active, no movement.
	if fighting:
		custom_velocity = Vector2.ZERO
		velocity = custom_velocity
		return

	# Default to zero velocity.
	custom_velocity = Vector2.ZERO
	velocity = custom_velocity

# ---------------------------
# Health and Damage
# ---------------------------
func take_damage() -> void:
	print("NPC was hit!")
	play_hurt_animation()
	health -= 1
	print("NPC health is now: ", health)
	
	if health <= 0:
		print("NPC health reached 0! Emitting end_fight signal.")
		emit_signal("end_fight")
		play_hurt_animation()

# ---------------------------
# Node Setup & Dialogue
# ---------------------------
func _ready() -> void:
	add_to_group("npc")
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
	idle_offset = randi() % FRAMES_PER_ANIMATION
	idle_start_time = Time.get_ticks_msec()

func show_dialogue(dialogue_key: String) -> Node:
	if dialogue_resource == null:
		push_error("Dialogue resource not loaded for NPC " + npc_name)
		return null
	var balloon = DialogueManager.show_dialogue_balloon(dialogue_resource, dialogue_key, [self])
	return balloon

func set_facing_direction(is_left: bool) -> void:
	direction = (Vector2.LEFT if is_left else Vector2.RIGHT)
	for part in sprite_parts:
		part.flip_h = is_left

func _on_area_input_event(_viewport, _event, _shape_idx) -> void:
	# Optionally handle input events for the NPC.
	pass

func auto_move_to_position(target: Vector2) -> void:
	auto_move = true
	auto_target_position = target
