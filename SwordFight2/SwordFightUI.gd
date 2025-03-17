extends Control

var battle_manager
var player_stats_base_x: float
var enemy_stats_base_x: float

# Nodes from your UI scene:
@onready var move_container: Control = $ActionBar/AttackActions
@onready var extra_commands: Control = $ActionBar/ExtraActions
@onready var flee_button: TextureButton = $ActionBar/ExtraActions/Flee
@onready var crew_button: TextureButton = $ActionBar/ExtraActions/Crew
@onready var item_button: TextureButton = $ActionBar/ExtraActions/Items
@onready var battle_log: RichTextLabel = $BattleLog

# Player status bars (ProgressBar nodes)
@onready var player_health_bar: TextureProgressBar = $HealthBar/PlayerHealth
@onready var enemy_health_bar: TextureProgressBar = $HealthBar/EnemyHealth

# Slide-out panels for detailed stats:
@onready var player_stats_panel: TextureRect = $PlayerStats
@onready var enemy_stats_panel: TextureRect = $EnemyStats

# Toggle buttons (using the given node paths):
@onready var player_stats_toggle: TextureButton = $PlayerStats/TextureButton
@onready var enemy_stats_toggle: TextureButton = $EnemyStats/TextureButton

func _ready() -> void:
	battle_manager = get_parent().get_parent()
	call_deferred("populate_move_buttons")
	
	# Connect extra command buttons.
	flee_button.connect("pressed", Callable(self, "_on_flee_pressed"))
	crew_button.connect("pressed", Callable(self, "_on_crew_pressed"))
	item_button.connect("pressed", Callable(self, "_on_item_pressed"))
	
	# Connect signals from the BattleManager.
	if battle_manager.has_signal("log_updated"):
		battle_manager.connect("log_updated", Callable(self, "_on_log_updated"))
	if battle_manager.has_signal("player_turn_started"):
		battle_manager.connect("player_turn_started", Callable(self, "_on_player_turn_started"))
	
	# Connect toggle signals for sliding panels.
	player_stats_toggle.connect("toggled", Callable(self, "_on_player_stats_toggled"))
	enemy_stats_toggle.connect("toggled", Callable(self, "_on_enemy_stats_toggled"))
	
	# Store initial x positions for sliding back later.
	player_stats_base_x = player_stats_panel.position.x
	enemy_stats_base_x = enemy_stats_panel.position.x
	
	update_status_bars()
	update_status_panels()


func populate_move_buttons() -> void:
	# Ensure battle_manager.player and its stats are valid before proceeding.
	if not (battle_manager and battle_manager.player and battle_manager.player.stats):
		return
	var moves = battle_manager.player.stats.moves
	for i in range(4):
		var button = move_container.get_child(i)
		var label = button.get_child(0)
		if i < moves.size():
			var move = moves[i]
			label.text = move.move_name
			button.connect("pressed", Callable(self, "_on_move_selected").bind(move))
			button.disabled = false
		else:
			label.text = ""
			button.disabled = true


func _on_move_selected(move: Resource) -> void:
	# Clear the battle log when a move is pressed.
	battle_log.clear()
	battle_log.append_text("[center]")
	
	# Log the player's selection.
	battle_log.append_text("[color=yellow]Player selected: %s[/color]\n" % move.move_name)
	_set_move_buttons_enabled(false)
	
	# Submit the move to the BattleManager.
	battle_manager.submit_player_move(move)
	update_status_bars()
	update_status_panels()

func _set_move_buttons_enabled(enabled: bool) -> void:
	for child in move_container.get_children():
		if child is Button:
			child.disabled = not enabled

func _on_flee_pressed() -> void:
	battle_log.append_text("[color=red]Player chose to flee![/color]\n")
	# Flee functionality can be implemented later.

func _on_crew_pressed() -> void:
	battle_log.append_text("[color=cyan]Crew menu opened (not implemented yet).[/color]\n")
	# Toggle or slide out the crew panel here.

func _on_item_pressed() -> void:
	battle_log.append_text("[color=magenta]Item menu opened (not implemented yet).[/color]\n")
	# Show the item usage UI here.

func _on_log_updated(message: String) -> void:
	# Append additional log messages, wrapping them in center tags.
	battle_log.append_text("[center]" + message + "[/center]\n")
	update_status_bars()
	update_status_panels()

func _on_player_turn_started() -> void:
	# Instead of clearing here, we now wait until the player presses a move.
	_set_move_buttons_enabled(true)
	update_status_bars()
	update_status_panels()

func update_status_bars() -> void:
	# Update the player's Health and Stamina bars.
	if battle_manager and battle_manager.player and battle_manager.player.stats:
		player_health_bar.value = battle_manager.player.stats.current_hp
		player_health_bar.max_value = battle_manager.player.stats.max_hp
	# Update the enemy's Health and Stamina bars.
	if battle_manager and battle_manager.enemy and battle_manager.enemy.stats:
		enemy_health_bar.value = battle_manager.enemy.stats.current_hp
		enemy_health_bar.max_value = battle_manager.enemy.stats.max_hp

func update_status_panels() -> void:
	# Update player stats panel.
	if battle_manager and battle_manager.player and battle_manager.player.stats:
		var ps = battle_manager.player.stats
		# Assuming the labels are direct children of a VBoxContainer inside the panel:
		var ps_vbox = player_stats_panel.get_node("VBoxContainer")
		if ps_vbox.has_node("HP"):
			ps_vbox.get_node("HP").text = "HP: %d / %d" % [ps.current_hp, ps.max_hp]
		if ps_vbox.has_node("Stamina"):
			ps_vbox.get_node("Stamina").text = "Stamina: %d / %d" % [ps.stamina, ps.max_stamina]
		if ps_vbox.has_node("Strength"):
			ps_vbox.get_node("Strength").text = "Strength: %d" % ps.strength
		if ps_vbox.has_node("Speed"):
			ps_vbox.get_node("Speed").text = "Speed: %d" % ps.speed
		if ps_vbox.has_node("Defense"):
			ps_vbox.get_node("Defense").text = "Defense: %d" % ps.defense
	# Update enemy stats panel.
	if battle_manager and battle_manager.enemy and battle_manager.enemy.stats:
		var es = battle_manager.enemy.stats
		var es_vbox = enemy_stats_panel.get_node("VBoxContainer")
		if es_vbox.has_node("HP"):
			es_vbox.get_node("HP").text = "HP: %d / %d" % [es.current_hp, es.max_hp]
		if es_vbox.has_node("Stamina"):
			es_vbox.get_node("Stamina").text = "Stamina: %d / %d" % [es.stamina, es.max_stamina]
		if es_vbox.has_node("Strength"):
			es_vbox.get_node("Strength").text = "Strength: %d" % es.strength
		if es_vbox.has_node("Speed"):
			es_vbox.get_node("Speed").text = "Speed: %d" % es.speed
		if es_vbox.has_node("Defense"):
			es_vbox.get_node("Defense").text = "Defense: %d" % es.defense

func _on_player_stats_toggled(pressed: bool) -> void:
	print("hehehe")
	var target_x = player_stats_base_x + (120 if pressed else 0)
	var tween = get_tree().create_tween()
	tween.tween_property(player_stats_panel, "position:x", target_x, 0.2)

func _on_enemy_stats_toggled(pressed: bool) -> void:
	var target_x = enemy_stats_base_x + (-120 if pressed else 0)
	var tween = get_tree().create_tween()
	tween.tween_property(enemy_stats_panel, "position:x", target_x, 0.2)
