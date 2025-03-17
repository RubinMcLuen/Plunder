extends Node2D

# --------------------- SIGNALS & ENUMS ---------------------
signal log_updated(message: String)
signal player_turn_started()

enum BattleState {
	SETUP,
	PLAYER_TURN,
	ENEMY_TURN,
	TURN_RESOLUTION,
	VICTORY,
	DEFEAT
}

# --------------------- VARIABLES ---------------------
var current_state: int = BattleState.SETUP
var selected_player_move: Move = null
var selected_enemy_move: Move = null

# Dictionary to track temporary effects for both combatants.
var active_effects = {
	"player": {},
	"enemy": {}
}

# Camera and transition variables
var original_cam_position: Vector2
var original_cam_zoom: Vector2
var player_moved: bool = false
var enemy_moved: bool = false
var camera_moved: bool = false
var fight_ended: bool = false

# Reference to the battle camera (this node’s child)
@onready var camera: Camera2D = $Camera2D

# Global references to player and enemy – DO NOT declare these as locals in _ready()
var player: CharacterBody2D
var enemy: CharacterBody2D

# Exported UI node; assign this in the editor so it’s hidden until the transition completes.
@export var battle_ui: Control

# Declare a global vignette variable.
var vignette: ColorRect = null

# --------------------- LIFECYCLE ---------------------
func _ready() -> void:
	camera.make_current()
	player = get_tree().current_scene.get_node("Player") as CharacterBody2D
	enemy = get_parent() as CharacterBody2D

	if player:
		player.connect("auto_move_completed", Callable(self, "_on_player_auto_move_completed"))
		player.connect("end_fight", Callable(self, "_on_end_fight"))
		player.fighting = true
		player.sword.visible = true
	else:
		push_error("Player not found!")

	if enemy:
		enemy.connect("end_fight", Callable(self, "_on_enemy_end_fight"))
		enemy.set_idle_with_sword_mode(true)
		enemy.fighting = false  # Will be enabled at battle start.
		if enemy.fight_side_right:
			enemy.connect("npc_move_completed", Callable(self, "_on_enemy_auto_move_completed"))
	else:
		push_error("Enemy not found!")

	if battle_ui:
		battle_ui.visible = false

	_animate_camera_transition()
	_move_player_to_enemy()
	randomize()

# --------------------- BATTLE SYSTEM ---------------------
func start_battle() -> void:
	# Reset HP and clear temporary effects.
	player.stats.current_hp = player.stats.max_hp
	enemy.stats.current_hp = enemy.stats.max_hp
	active_effects["player"].clear()
	active_effects["enemy"].clear()
	
	current_state = BattleState.PLAYER_TURN
	print_and_log("Battle Setup: Starting Battle!")
	
	enemy.fighting = true
	transition_to_player_turn()

func transition_to_player_turn() -> void:
	current_state = BattleState.PLAYER_TURN
	print_and_log("Player Turn: Choose your move!")
	emit_signal("player_turn_started")

func submit_player_move(move: Move) -> void:
	if current_state != BattleState.PLAYER_TURN:
		return
	if player.stats.stamina < move.stamina_cost:
		print_and_log("Not enough stamina to use %s!" % move.move_name)
		emit_signal("player_turn_started")
		return
	selected_player_move = move
	print_and_log("Player selected move: %s" % move.move_name)
	transition_to_enemy_turn()

func transition_to_enemy_turn() -> void:
	current_state = BattleState.ENEMY_TURN
	print_and_log("Enemy Turn: Enemy is choosing a move!")
	# Immediately choose enemy move.
	if enemy.stats.moves.size() > 0:
		selected_enemy_move = enemy.stats.moves[randi() % enemy.stats.moves.size()]
		print_and_log("Enemy selected move: %s" % selected_enemy_move.move_name)
	else:
		print_and_log("No moves available for enemy!")
	transition_to_turn_resolution()

func transition_to_turn_resolution() -> void:
	current_state = BattleState.TURN_RESOLUTION
	print_and_log("Resolving Turn!")
	
	# If player is faster (or equal), resolve player's move instantly...
	if player.stats.speed >= enemy.stats.speed:
		resolve_move(selected_player_move, player.stats, enemy.stats)
		if enemy.stats.current_hp <= 0:
			transition_to_victory()
			return
		# ...then wait one second...
		await get_tree().create_timer(1.0).timeout
		# ...then resolve enemy's move instantly.
		resolve_move(selected_enemy_move, enemy.stats, player.stats)
		if player.stats.current_hp <= 0:
			transition_to_defeat()
			return
	else:
		# If enemy is faster, resolve enemy's move instantly...
		resolve_move(selected_enemy_move, enemy.stats, player.stats)
		if player.stats.current_hp <= 0:
			transition_to_defeat()
			return
		await get_tree().create_timer(1.0).timeout
		# ...then resolve player's move instantly.
		resolve_move(selected_player_move, player.stats, enemy.stats)
		if enemy.stats.current_hp <= 0:
			transition_to_victory()
			return

	clear_turn_effects()
	selected_player_move = null
	selected_enemy_move = null
	transition_to_player_turn()

func resolve_move(move: Move, attacker: Object, defender: Object) -> void:
	if move == null:
		return
	var attacker_key = "player" if attacker == player.stats else "enemy"
	var defender_key = "enemy" if attacker == player.stats else "player"
	
	# Deduct stamina cost.
	attacker.stamina = max(attacker.stamina - move.stamina_cost, 0)
	print_and_log("%s used %s (cost %d stamina)." % [attacker.character_name, move.move_name, move.stamina_cost])
	
	var effective_accuracy: float = move.accuracy
	if active_effects[defender_key].has("blind") and active_effects[defender_key]["blind"] > 0:
		effective_accuracy += 0.2
	if active_effects[defender_key].has("parry_active") and active_effects[defender_key]["parry_active"]:
		effective_accuracy -= 0.3
	
	# Sidestep logic.
	if move.special_effect == "sidestep":
		if attacker.speed > defender.speed:
			print_and_log("%s successfully sidesteps the incoming attack!" % attacker.character_name)
			_play_attack_animation_for(attacker_key, move)
			return
		else:
			print_and_log("%s fails to sidestep!" % attacker.character_name)
	
	# Accuracy check.
	if randf() > effective_accuracy:
		print_and_log("%s's %s misses!" % [attacker.character_name, move.move_name])
		if move.special_effect == "stun":
			print_and_log("%s gets a free counterattack!" % defender.character_name)
			var counter_damage = max(5 + defender.strength - attacker.defense, 0)
			attacker.current_hp -= counter_damage
			print_and_log("%s counterattacks dealing %d damage!" % [defender.character_name, counter_damage])
		_play_attack_animation_for(attacker_key, move)
		return
	
	var effective_defense: float = defender.defense
	if move.special_effect == "lunge":
		effective_defense = defender.defense / 2
	var base_damage: int = move.base_power + attacker.strength - effective_defense
	var damage: int = max(base_damage, 0)
	
	match move.special_effect:
		"feint":
			damage = 5
			active_effects[attacker_key]["feint_bonus"] = true
			print_and_log("%s uses Feint! Next attack will deal extra damage." % attacker.character_name)
		_:
			if active_effects[attacker_key].get("feint_bonus", false):
				damage = int(damage * 1.5)
				print_and_log("Feint bonus! Damage increased to %d." % damage)
				active_effects[attacker_key]["feint_bonus"] = false
	
	if move.special_effect == "recoil":
		active_effects[attacker_key]["recoil"] = true
		print_and_log("%s's Reckless Attack lowers their defense next turn!" % attacker.character_name)
	
	defender.current_hp -= damage
	print_and_log("%s uses %s and deals %d damage!" % [attacker.character_name, move.move_name, damage])
	
	if move.special_effect == "stun":
		if randf() < 0.5:
			active_effects[defender_key]["stunned"] = 1
			print_and_log("%s is stunned!" % defender.character_name)
	if move.special_effect == "blind":
		active_effects[defender_key]["blind"] = 2
		print_and_log("%s is blinded for 2 turns!" % defender.character_name)
	if move.special_effect == "riposte":
		active_effects[attacker_key]["riposte_active"] = true
		print_and_log("%s prepares a riposte!" % attacker.character_name)
	if move.special_effect == "parry":
		active_effects[attacker_key]["parry_active"] = true
		print_and_log("%s braces with a Parry for the next attack!" % attacker.character_name)
	if move.special_effect == "mock":
		active_effects[defender_key]["mocked"] = true
		print_and_log("%s is mocked and may act predictably next turn!" % defender.character_name)
	
	if active_effects[defender_key].get("riposte_active", false):
		var riposte_damage = max((move.base_power + defender.strength - attacker.defense) * 2, 0)
		attacker.current_hp -= riposte_damage
		print_and_log("%s's riposte counters, dealing %d damage!" % [defender.character_name, riposte_damage])
		active_effects[defender_key]["riposte_active"] = false
	
	print_and_log("%s's HP is now %d" % [defender.character_name, defender.current_hp])
	_play_attack_animation_for(attacker_key, move)

func clear_turn_effects() -> void:
	for key in active_effects["player"].keys():
		if typeof(active_effects["player"][key]) == TYPE_INT:
			active_effects["player"][key] = max(active_effects["player"][key] - 1, 0)
	for key in active_effects["enemy"].keys():
		if typeof(active_effects["enemy"][key]) == TYPE_INT:
			active_effects["enemy"][key] = max(active_effects["enemy"][key] - 1, 0)
	active_effects["player"].erase("parry_active")
	active_effects["player"].erase("riposte_active")
	active_effects["enemy"].erase("parry_active")
	active_effects["enemy"].erase("riposte_active")
	if active_effects["player"].get("recoil", false):
		print_and_log("%s's defense is lowered this turn due to Reckless Attack." % player.stats.character_name)
		active_effects["player"].erase("recoil")
	if active_effects["enemy"].get("recoil", false):
		print_and_log("%s's defense is lowered this turn due to Reckless Attack." % enemy.stats.character_name)
		active_effects["enemy"].erase("recoil")

func transition_to_victory() -> void:
	current_state = BattleState.VICTORY
	print_and_log("Victory! %s wins the battle." % player.stats.character_name)
	_on_enemy_end_fight()

func transition_to_defeat() -> void:
	current_state = BattleState.DEFEAT
	print_and_log("Defeat! %s loses the battle." % player.stats.character_name)
	_on_end_fight()

func print_and_log(message: String) -> void:
	print(message)
	emit_signal("log_updated", message)

func _play_attack_animation_for(attacker_key: String, move: Move) -> void:
	if attacker_key == "player":
		if move.special_effect == "lunge":
			player.play_lunge_animation()
		elif move.special_effect == "block":
			player.play_block_animation()
		else:
			player.play_slash_animation()
	else:
		if move.special_effect == "lunge":
			enemy.play_lunge_animation()
		elif move.special_effect == "block":
			enemy.play_block_animation()
		else:
			enemy.play_slash_animation()

# --------------------- MOVEMENT & CAMERA ---------------------
func _move_player_to_enemy() -> void:
	var offset := 36
	var enemy_start := enemy.global_position
	if enemy.fight_side_right:
		# Player moves to enemy’s starting position and enemy moves to the right.
		player.auto_move_to_position(enemy_start)
		enemy.auto_move_to_position(enemy_start + Vector2(offset, 0))
	else:
		# Player moves to a position offset to the enemy's left.
		player.auto_move_to_position(enemy_start - Vector2(offset, 0))
		enemy.set_facing_direction(true)

func _on_player_auto_move_completed() -> void:
	player.set_facing_direction(false)
	player_moved = true
	if enemy.fight_side_right:
		if enemy_moved and camera_moved:
			_start_battle()
	else:
		if camera_moved:
			_start_battle()

func _on_enemy_auto_move_completed() -> void:
	enemy.set_facing_direction(true)
	enemy_moved = true
	if player_moved and camera_moved:
		_start_battle()

func _animate_camera_transition() -> void:
	if player and player.has_node("Camera2D"):
		var player_cam: Camera2D = player.get_node("Camera2D")
		original_cam_position = player_cam.global_position
		original_cam_zoom = player_cam.zoom
		camera.global_position = original_cam_position
		camera.zoom = original_cam_zoom
	else:
		original_cam_position = camera.global_position
		original_cam_zoom = camera.zoom
	var target_global_pos = self.to_global(Vector2(240, 135))
	var tween_slide = create_tween()
	tween_slide.tween_property(camera, "global_position", target_global_pos, 0.5) \
		.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween_slide.tween_callback(Callable(self, "_on_slide_complete"))

func _on_slide_complete() -> void:
	_create_vignette()
	var tween_zoom = create_tween()
	tween_zoom.parallel().tween_property(camera, "zoom", Vector2(4, 4), 1.0) \
		.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween_zoom.parallel().tween_property(vignette.material, "shader_parameter/fade", 1.0, 1.0) \
		.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween_zoom.tween_callback(Callable(self, "_on_camera_transition_complete"))

func _on_camera_transition_complete() -> void:
	if battle_ui:
		battle_ui.visible = true
	camera_moved = true
	if player_moved:
		_start_battle()

func _start_battle() -> void:
	enemy.fighting = true
	start_battle()

# --------------------- FIGHT END / TRANSITIONS ---------------------
func _on_end_fight() -> void:
	fight_ended = true
	_fade_and_change_scene()

func _on_enemy_end_fight() -> void:
	fight_ended = true
	_start_camera_zoom_out()

func _start_camera_zoom_out() -> void:
	var tween_zoom_back = create_tween()
	tween_zoom_back.tween_property(camera, "zoom", original_cam_zoom, 1.0) \
		.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween_zoom_back.tween_callback(Callable(self, "_on_zoom_out_complete"))

func _on_zoom_out_complete() -> void:
	var target_position: Vector2 = player.global_position
	var tween_slide_back = create_tween()
	tween_slide_back.tween_property(camera, "global_position", target_position, 0.3) \
		.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween_slide_back.tween_callback(Callable(self, "_on_end_fight_complete"))

func _on_end_fight_complete() -> void:
	player.fighting = false
	player.sword.visible = false
	enemy.fighting = false
	enemy.set_idle_with_sword_mode(false)
	enemy.fightable = true
	enemy.on_death()
	queue_free()

func _fade_and_change_scene() -> void:
	var v: ColorRect = get_node("Vignette") if has_node("Vignette") else null
	if not v:
		return
	var tween = create_tween()
	tween.tween_property(v.material, "shader_parameter/fade", 1.0, 1.0) \
		 .set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(1.0)
	tween.tween_callback(Callable(self, "_on_fade_complete"))

func _on_fade_complete() -> void:
	get_tree().change_scene_to_file("res://Respawn/respawn.tscn")

func _create_vignette() -> void:
	if vignette:
		return
	vignette = ColorRect.new()
	vignette.name = "Vignette"
	vignette.z_index = 10
	vignette.modulate = Color(1, 1, 1, 1)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	vignette.position = viewport_rect.position
	vignette.size = viewport_rect.size
	var shader = Shader.new()
	shader.code = """
		shader_type canvas_item;
		uniform vec2 vignette_scale = vec2(1.0, 1.0);
		uniform float inner_radius : hint_range(0.0, 1.0) = 0.1;
		uniform float outer_radius : hint_range(0.0, 1.0) = 0.4;
		uniform vec2 center = vec2(0.5, 0.5);
		uniform float overlay_strength : hint_range(0.0, 1.0) = 0.7;
		uniform float fade : hint_range(0.0, 1.0) = 0.0;
		void fragment() {
			vec2 uv = SCREEN_UV;
			float dist = length((uv - center) * vignette_scale);
			float factor = smoothstep(inner_radius, outer_radius, dist);
			float vignette_alpha = factor * overlay_strength;
			float final_alpha = mix(0.0, vignette_alpha, fade);
			COLOR = vec4(0.0, 0.0, 0.0, final_alpha);
		}
	""".strip_edges()
	var shader_material = ShaderMaterial.new()
	shader_material.shader = shader
	shader_material.set_shader_parameter("overlay_strength", 0.7)
	shader_material.set_shader_parameter("fade", 0.0)
	vignette.material = shader_material
	add_child(vignette)
	var tween = create_tween()
	tween.tween_property(vignette.material, "shader_parameter/overlay_strength", 0.7, 2.0)
