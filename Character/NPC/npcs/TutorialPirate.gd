# UniqueNPC_A.gd
extends NPC
class_name TutorialPirate

signal pirate_dead

func on_death():
	emit_signal("pirate_dead")
	$Appearance.visible = false
	$DeathAnimation.visible = true
	$DeathAnimation.play()
	await $DeathAnimation.animation_finished
	queue_free()

func _on_area_input_event(_viewport, event, _shape_idx) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and fightable:
		# Hide the Arrow and first tutorial hint.
		get_parent().get_node("Arrow").visible = false
		get_parent().get_node("CanvasLayer/TutorialHint1").visible = false

		# Prevent further triggering.
		fightable = false

		# Make SwordFightTutorial visible and wait until its tutorial_finished signal is emitted.
		var sword_tutorial = get_tree().current_scene.get_node("Player/SwordFightTutorial")
		sword_tutorial.visible = true
		var player = get_tree().current_scene.get_node("Player")
		player.disable_user_input = true
		await sword_tutorial.tutorial_finished
		player.disable_user_input = false
		
		# After the tutorial, start the sword fight.
		var sword_fight_scene = load("res://SwordFight/sword_fight.tscn")
		if sword_fight_scene:
			var sword_fight_instance = sword_fight_scene.instantiate()
			var offset = Vector2(-258.5, -146.5)
			if player_direction:
				offset.x += 36
			sword_fight_instance.position += offset
			self.add_child(sword_fight_instance)
