# Island.gd
extends Node2D

@onready var player: CharacterBody2D    = $Player
@onready var monte_coral: CharacterBody2D = $MonteCoral
@onready var first_mate: NPC             = $FirstMate2
@onready var island_sprite_simple: CanvasItem = $islandspritesimple
var skip_fade: bool                      = false

@export var location_name: String        = "Kelptown"
@export var monte_coral_dialogue: Resource
@export var first_mate_dialogue: Resource
@export var dialogue_scene: PackedScene  = preload("res://Dialogue/balloon.tscn")

var scene_state: String = "pre_shiptutorial"

func _set_characters_alpha(a: float) -> void:
	var chars = [player, monte_coral, first_mate]
	for c in chars:
		if c and c is CanvasItem:
			c.modulate.a = a

func _ready() -> void:
		# 1) Spawn crew for this scene
	CrewManager.populate_scene(self)

	_set_characters_alpha(0.0)

	# 2) Immediately apply saved spawn_position (if any)
	if Global.spawn_position != Vector2.ZERO:
		player.global_position = Global.spawn_position
		Global.spawn_position = Vector2.ZERO

	# 3) Connect the exit trigger
	$Exit.body_entered.connect(_on_exit_body_entered)

	# 4) Wait one frame so UIManager has hidden everything
	await get_tree().process_frame

	# 5) Show the location banner
	UIManager.show_location_notification(location_name)

	_fade_in_characters(1.5)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		UIManager.show_location_notification(location_name)


func apply_scene_state() -> void:
	# Determine scene_state based on the ShipTutorial quest
	if QuestManager.quests.has("ShipTutorial"):
		var step = QuestManager.quests["ShipTutorial"]["current_step"]
		if step >= 1:
			scene_state = "shiptutorial_started"
			# Place First Mate by the ship
			first_mate.position = Vector2(-173, 600)
			# Advance his state once tutorial quest is done
			if QuestManager.is_quest_finished("TutorialQuest"):
				first_mate.state = "OnShipReady"
			else:
				first_mate.state = "OnShipNotReady"
		else:
			scene_state = "pre_shiptutorial"
	else:
		scene_state = "pre_shiptutorial"

func _on_exit_body_entered(body: Node) -> void:
	if body == player:
		SceneSwitcher.switch_scene(
			"res://KelptownInn/KelptownInn.tscn",
			Vector2(269, 220),
			"fade",
			Vector2.ONE,
			Vector2.ZERO,
			Vector2(1.5, 1.5)   # ← Kelptown Inn’s zoom
		)



func load_player_position() -> void:
	var slot = Global.active_save_slot
	var save_file_path = "user://saveslot%d.json" % slot
	if FileAccess.file_exists(save_file_path):
		var file = FileAccess.open(save_file_path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var save_data = json.data
			if save_data.has("scene") and save_data["scene"].has("position"):
				var pos = save_data["scene"]["position"]
				player.global_position = Vector2(pos["x"], pos["y"])
				print("Loaded player position:", player.global_position)
		file.close()
	else:
		print("No save file found, using default position.")


func _on_monte_coral_dialogue_requested(dialogue_section: String) -> void:
	player.disable_user_input = true
	var balloon = DialogueManager.show_dialogue_balloon(
		monte_coral_dialogue,
		dialogue_section,
		[monte_coral]
	)
	balloon.connect("dialogue_finished", Callable(self, "_on_dialogue_finished"))
	# Advance tutorial quest if appropriate
	if QuestManager.quests.has("TutorialQuest") and QuestManager.quests["TutorialQuest"]["current_step"] == 4:
		QuestManager.advance_quest_step("TutorialQuest")
		if first_mate.state == "OnShipNotReady":
			first_mate.state = "OnShipReady"


func _on_first_mate_dialogue_requested(dialogue_section: String) -> void:
	player.disable_user_input = true
	var balloon = DialogueManager.show_dialogue_balloon(
		first_mate_dialogue,
		dialogue_section,
		[first_mate]
	)
	balloon.connect("dialogue_finished", Callable(first_mate, "_on_dialogue_finished"))
	balloon.connect("dialogue_finished", Callable(self, "_on_dialogue_finished"))


func _on_first_mate_2_dialogue_requested(dialogue_section: String) -> void:
	# Alternate hook (if used)
	player.disable_user_input = true
	var balloon = DialogueManager.show_dialogue_balloon(
		first_mate_dialogue,
		dialogue_section,
		[first_mate]
	)
	balloon.connect("dialogue_finished", Callable(first_mate, "_on_dialogue_finished"))
	balloon.connect("dialogue_finished", Callable(self, "_on_dialogue_finished"))


func _on_dialogue_finished() -> void:
		player.disable_user_input = false


func _fade_in_characters(t: float = 0.5) -> void:
		var chars = [player, monte_coral, first_mate]
		var tw = create_tween().set_parallel(true)
		for c in chars:
				if c and c is CanvasItem:
						c.modulate.a = 0.0
						tw.tween_property(c, "modulate:a", 1.0, t)

func _fade_out_characters(t: float = 1.0) -> void:
		var chars = [player, monte_coral, first_mate]
		var tw = create_tween().set_parallel(true)
		for c in chars:
				if c and c is CanvasItem:
						tw.tween_property(c, "modulate:a", 0.0, t)

func start_leave_island_transition(t: float = 1.0) -> void:
								_fade_out_characters(t)
								Global.restore_sails_next = true

								if has_node("PlayerShipClose/Sails"):
																var sails := get_node("PlayerShipClose/Sails") as CanvasItem
																sails.visible = true
																sails.modulate.a = 0.0
																create_tween().tween_property(sails, "modulate:a", 1.0, t)

								if island_sprite_simple:
																island_sprite_simple.modulate.a = 0.0
																island_sprite_simple.visible = true
																create_tween().tween_property(island_sprite_simple, "modulate:a", 1.0, t)
