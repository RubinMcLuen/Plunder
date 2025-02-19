extends Node2D

@export var player: CharacterBody2D
@export var bartender: BartenderTutorial    # Reference to the Bartender
@export var pirate: TutorialPirate          # Reference to the pirate
var bartender_talked = false
# Where to get your dialogue resource/scene.
@export var dialogue_resource: Resource
@export var dialogue_scene: PackedScene = preload("res://Dialogue/balloon.tscn")

func _ready() -> void:
	# Connect the bartender’s dialogue_requested signal.
	bartender.dialogue_requested.connect(_on_bartender_dialogue_requested)
	
	# Connect the pirate's dead signal.
	pirate.pirate_dead.connect(_on_pirate_dead)            # For UI changes
	pirate.pirate_dead.connect(bartender._on_pirate_dead)    # Let bartender update its own state

	$CutsceneManager.play_cutscene("res://Cutscene/cutscenes/KelpTownIntroCutscene.json")
	$Exit.body_entered.connect(_on_exit_body_entered)
	var color_rect = $Player/Camera2D/enter
	color_rect.visible = true

	await get_tree().create_timer(0.5).timeout
	var tween = create_tween()
	tween.tween_property(color_rect, "color:a", 0.0, 1.0)

func _on_bartender_dialogue_requested(dialogue_section: String) -> void:
	$CanvasLayer/TutorialHint2.visible = false
	# Disable player input.
	player.disable_user_input = true

	# Create/show the dialogue balloon.
	var balloon = DialogueManager.show_dialogue_balloon(dialogue_resource, dialogue_section, [bartender])
	# Connect the dialogue_finished signal.
	balloon.connect("dialogue_finished", Callable(self, "_on_dialogue_finished"))

func _on_dialogue_finished() -> void:
	# Re-enable user input.
	player.disable_user_input = false
	bartender_talked = true

func _on_exit_body_entered(body):
	if bartender_talked and body == player:
		Global.spawn_position = Vector2(-88, -59)
		var tween = create_tween()
		tween.tween_property($Player/Camera2D/exit, "color:a", 1.0, 1.0)
		await tween.finished
		get_tree().change_scene_to_file("res://Island/island.tscn")

func _on_cutscene_manager_cutscene_finished():
	$Arrow.visible = true
	$CanvasLayer/TutorialHint1.visible = true

func _on_pirate_dead() -> void:
	$CanvasLayer/TutorialHint2.visible = true
