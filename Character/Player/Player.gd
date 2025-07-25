extends CharacterBody2D

# ---------------------------
# Movement and Animation Variables
# ---------------------------
@export var speed := 100    # Movement speed in pixels per second
var direction := Vector2.RIGHT  # Default facing direction is right
@export var stats: CharacterStats

# Signals
signal auto_move_completed
signal end_fight  # Emitted when player's health reaches 0

var health: int = 3
var fighting: bool = false
var disable_user_input: bool = false:
		set(new_value):
				disable_user_input = new_value
		get:
				return disable_user_input


# Use one AnimatedSprite2D node named "Appearance"
@onready var appearance: AnimatedSprite2D = $Appearance
@onready var sword: AnimatedSprite2D = $Appearance/Sword
var body_mat: ShaderMaterial
var hurt_tmr: Timer

# Player Name / Customization
var name_input = "name"
@export var customization_only: bool = false

# Movement + Animation variables
var custom_velocity := Vector2.ZERO

# Automatic movement
var auto_move: bool = false
var auto_target_position: Vector2 = Vector2.ZERO

# Drag-to-move Variables (removed drag to move feature)

# Animation Override (for slash, hurt, lunge, block)
var anim_override: bool = false
var anim_override_start_time: int = 0
var anim_override_duration: int = 0
# current_anim can be "idle", "slash", "hurt", "lunge", or "block"
var current_anim: String = "idle"

# Sound effects
const STEP_SOUNDS = [
		preload("res://SFX/stepwood_1.wav"),
		preload("res://SFX/stepwood_2.wav")
]
const SWORD_SOUNDS = [
		preload("res://SFX/sword_clash.1.ogg"),
		preload("res://SFX/sword_clash.2.ogg"),
		preload("res://SFX/sword_clash.3.ogg"),
		preload("res://SFX/sword_clash.4.ogg"),
		preload("res://SFX/sword_clash.5.ogg"),
		preload("res://SFX/sword_clash.6.ogg"),
		preload("res://SFX/sword_clash.7.ogg"),
		preload("res://SFX/sword_clash.8.ogg"),
		preload("res://SFX/sword_clash.9.ogg"),
		preload("res://SFX/sword_clash.10.ogg")
]
var _step_index: int = 0

# Save/Load
const SAVE_FILE_BASE_PATH = "user://saveslot"
var save_slot: int = -1

# ---------------------------
# _ready & _physics_process
# ---------------------------
func _ready():
				load_customization_from_save()   # use save-file if present
				body_mat = appearance.material
				_init_hurt_timer()
				randomize()
				appearance.frame_changed.connect(_on_frame_changed)
				if customization_only:
					set_physics_process(false)
				else:
						appearance.play("IdleStand")
						set_physics_process(true)


func _physics_process(_delta: float) -> void:
	if customization_only:
		return
	# Disable collisions while auto-moving.
	$CollisionShape2D.disabled = auto_move
	
	handle_player_input()
	update_animation()
	move_character()

# ---------------------------
# Input and Movement
# ---------------------------
func handle_player_input() -> void:
	if disable_user_input and not auto_move:
		custom_velocity = Vector2.ZERO
		velocity = custom_velocity
		return

	if auto_move:
		var diff = auto_target_position - global_position
		if diff.length() < 1:
			global_position = auto_target_position
			auto_move = false
			custom_velocity = Vector2.ZERO
			velocity = custom_velocity
			# Final facing: always face right when fight starts.
			set_facing_direction(false)
			emit_signal("auto_move_completed")
		else:
			custom_velocity = diff.normalized() * speed
			velocity = custom_velocity
			# While moving, face the direction of travel.
			set_facing_direction(diff.x < 0)
		return

	if fighting:
		custom_velocity = Vector2.ZERO
		velocity = custom_velocity
		return

	custom_velocity = Vector2.ZERO

	if Input.is_action_pressed("ui_up"):
				custom_velocity.y -= 1
	if Input.is_action_pressed("ui_down"):
			custom_velocity.y += 1
	if Input.is_action_pressed("ui_left"):
			custom_velocity.x -= 1
			direction = Vector2.LEFT
	if Input.is_action_pressed("ui_right"):
		custom_velocity.x += 1
		direction = Vector2.RIGHT

	if custom_velocity != Vector2.ZERO:
		custom_velocity = custom_velocity.normalized() * speed

	velocity = custom_velocity

func move_character() -> void:
	move_and_slide()

func auto_move_to_position(target: Vector2) -> void:
	auto_move = true
	auto_target_position = target

func set_facing_direction(is_left: bool) -> void:
	direction = Vector2.LEFT if is_left else Vector2.RIGHT
	appearance.flip_h = is_left
	sword.flip_h = is_left

func _unhandled_input(_event: InputEvent) -> void:
	if fighting or auto_move:
			return


# ---------------------------
# Animations
# ---------------------------
func update_animation() -> void:
	if anim_override:
		match current_anim:
			"slash":
				if appearance.animation != "AttackSlash":
					appearance.play("AttackSlash")
					sword.play("AttackSlash")
			"hurt":
				if appearance.animation != "Hurt":
					appearance.play("Hurt")
			"lunge":
				if appearance.animation != "AttackLunge":
					appearance.play("AttackLunge")
					sword.play("AttackLunge")
			"block":
				if appearance.animation != "AttackBlock":
					appearance.play("AttackBlock")
					sword.play("AttackBlock")
		if Time.get_ticks_msec() - anim_override_start_time >= anim_override_duration:
			anim_override = false
			current_anim = "idle"
		return

	# If moving, use Walk animation.
	if auto_move or custom_velocity != Vector2.ZERO:
		if appearance.animation != "Walk":
			appearance.play("Walk")
	# If fighting, always show IdleSword.
	elif fighting:
		if appearance.animation != "IdleSword":
			appearance.play("IdleSword")
			sword.play("IdleSword")
	# Otherwise, show idle stand.
	else:
		if appearance.animation != "IdleStand":
			appearance.play("IdleStand")
			
	appearance.flip_h = (direction == Vector2.LEFT)

func play_slash_animation() -> void:
		_play_sword_sound()
		anim_override = true
		anim_override_start_time = Time.get_ticks_msec()
		anim_override_duration = 800  # Duration in ms for AttackSlash
		current_anim = "slash"
		appearance.stop()
		sword.stop()
		appearance.play("AttackSlash")
		sword.play("AttackSlash")

func play_lunge_animation() -> void:
		_play_sword_sound()
		anim_override = true
		anim_override_start_time = Time.get_ticks_msec()
		anim_override_duration = 800  # Duration in ms for AttackLunge
		current_anim = "lunge"
		appearance.stop()
		sword.stop()
		appearance.play("AttackLunge")
		sword.play("AttackLunge")

func play_block_animation() -> void:
	anim_override = true
	anim_override_start_time = Time.get_ticks_msec()
	anim_override_duration = 800  # Duration in ms for AttackBlock
	current_anim = "block"
	appearance.stop()
	sword.stop()
	appearance.play("AttackBlock")
	sword.play("AttackBlock")

func play_hurt_animation() -> void:
		anim_override = true
		anim_override_start_time = Time.get_ticks_msec()
		anim_override_duration = 300  # Duration in ms for Hurt
		current_anim = "hurt"

func take_damage() -> void:
		play_hurt_animation()
		health -= 1
		_flash_red()
		print("Player health is now: ", health)
		if health <= 0:
				print("Player health reached 0! Emitting end_fight signal.")
				emit_signal("end_fight")

func _init_hurt_timer() -> void:
		hurt_tmr = Timer.new()
		hurt_tmr.one_shot = true
		hurt_tmr.wait_time = 0.25
		add_child(hurt_tmr)
		hurt_tmr.timeout.connect(_on_hurt_timeout)

func _flash_red() -> void:
		body_mat.set_shader_parameter("hurt_mode", true)
		hurt_tmr.start()

func _on_hurt_timeout() -> void:
				body_mat.set_shader_parameter("hurt_mode", false)

func _on_frame_changed() -> void:
		if appearance.animation == "Walk" and (appearance.frame == 0 or appearance.frame == 4):
				_play_step_sound()

func _play_step_sound() -> void:
				var snd = STEP_SOUNDS[_step_index % STEP_SOUNDS.size()]
				_step_index = (_step_index + 1) % STEP_SOUNDS.size()
				var p = AudioStreamPlayer2D.new()
				p.stream = snd
				p.pitch_scale = randf_range(0.9, 1.1)
				add_child(p)
				p.play()
				var t = Timer.new()
				t.one_shot = true
				t.wait_time = snd.get_length()
				p.add_child(t)
				t.timeout.connect(p.queue_free)
				t.start()

func _play_sword_sound() -> void:
		var snd = SWORD_SOUNDS[randi() % SWORD_SOUNDS.size()]
		var p = AudioStreamPlayer2D.new()
		p.stream = snd
		add_child(p)
		p.play()
		var t = Timer.new()
		t.one_shot = true
		t.wait_time = snd.get_length()
		p.add_child(t)
		t.timeout.connect(p.queue_free)
		t.start()

# ---------------------------
# Customization Loading
# ---------------------------
@export var override_map_texture = false
var custom_map_texture: Texture2D = preload("res://Character/Player/playeryt.png")

func load_customization():
	if override_map_texture:
		appearance.material = appearance.material.duplicate()
		appearance.material.set_shader_parameter("map_texture", custom_map_texture)
		print("Assigned custom texture with RID: ", custom_map_texture.get_rid())
		return

	var char_res = (ResourceLoader.load("res://Character/Player/PlayerCustomization.tres") as CharacterCustomizationResource).duplicate()
	if char_res:
		var composite_tex: Texture2D = char_res.generate_lookup_texture()
		if composite_tex:
			appearance.material = appearance.material.duplicate()
			appearance.material.set_shader_parameter("map_texture", composite_tex)
			print("Assigned composite texture with RID: ", composite_tex.get_rid())
		else:
			push_error("Composite texture is null!")
	else:
		push_error("Failed to load CharacterCustomizationResource.")




func load_customization_from_save():
	# If no slot yet, fall back to default resource.
	if Global.active_save_slot < 0:
		load_customization()
		return

	var path := "user://saveslot%d.json" % Global.active_save_slot
	if not FileAccess.file_exists(path):
		load_customization()
		return

		# read & parse JSON
	var save_dict: Dictionary = {}
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)

	# only use it if it really is a Dictionary
	if parsed is Dictionary:
		save_dict = parsed

	if not save_dict.has("character"):
		load_customization()
		return

	var char: Dictionary = save_dict["character"] as Dictionary

	var res = (ResourceLoader.load("res://Character/Player/PlayerCustomization.tres") as CharacterCustomizationResource).duplicate()
	if not res:
		push_error("Could not load PlayerCustomization.tres")
		return

	# apply the saved selections
	res.skin_option   = int(char.get("skin",   res.skin_option))
	res.top_option    = int(char.get("top",    res.top_option))
	res.bottom_option = int(char.get("bottom", res.bottom_option))
	res.hat_option    = int(char.get("hat",    res.hat_option))
	res.hair_option   = int(char.get("hair",   res.hair_option))

	var misc: Dictionary = char.get("misc", {}) as Dictionary

	res.misc_eyepatch = bool(misc.get("eyepatch", res.misc_eyepatch))
	res.misc_hook     = bool(misc.get("hook",     res.misc_hook))
	res.misc_peg_leg  = bool(misc.get("peg_leg",  res.misc_peg_leg))

	# apply composite texture to the shader
	var tex = res.generate_lookup_texture()
	if tex:
		appearance.material = appearance.material.duplicate()
		appearance.material.set_shader_parameter("map_texture", tex)

	# update player-name variable for UI needs
	name_input = char.get("name", name_input)

