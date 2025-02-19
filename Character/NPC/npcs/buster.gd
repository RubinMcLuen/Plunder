# UniqueNPC_A.gd
extends NPC

func _on_area_input_event(_viewport, event, _shape_idx) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and fightable:
		var sword_fight_scene = load("res://SwordFight/sword_fight.tscn")
		if sword_fight_scene:
			var sword_fight_instance = sword_fight_scene.instantiate()
			var offset = Vector2(-258.5, -146.5)
			if player_direction:
				offset.x += 36
			sword_fight_instance.position += offset
			self.add_child(sword_fight_instance)

func on_death():
	$Appearance.visible = false
	$DeathAnimation.visible = true
	$DeathAnimation.play()
	await $DeathAnimation.animation_finished
	queue_free()
