extends Node2D

@export var player: CharacterBody2D
var bartender_talked: bool = false

func _ready():
	$CutsceneManager.play_cutscene("res://Cutscene/cutscenes/KelpTownIntroCutscene.json")
	$Exit.body_entered.connect(_on_exit_body_entered)
	var color_rect = $Player/Camera2D/enter
	color_rect.visible = true
	
	# Wait for 0.5 seconds before starting the tween.
	await get_tree().create_timer(0.5).timeout
	
	# Tween the alpha from 1 to 0 over 1 second.
	var tween = create_tween()
	tween.tween_property(color_rect, "color:a", 0.0, 1.0)

func _on_exit_body_entered(body):
	if bartender_talked:
		if body == player:
			# Wait until the bartender has been talked to.
			# Once the signal is received, proceed with the exit.
			Global.spawn_position = Vector2(-88, -59)  # Save spawn coordinate
			var tween = create_tween()
			tween.tween_property($Player/Camera2D/exit, "color:a", 1.0, 1.0)
			await tween.finished  # Wait until the tween is done
			get_tree().change_scene_to_file("res://Island/island.tscn")

func _on_cutscene_manager_cutscene_finished():
	$Arrow.visible = true
	$CanvasLayer/TutorialHint1.visible = true
	QuestManager.add_quest("")

func _on_pirate_dead():
	$CanvasLayer/TutorialHint2.visible = true

func _on_talked_to_bartender():
	bartender_talked = true
