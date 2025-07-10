extends Node

var screenshot_count := 0

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_1:
		await RenderingServer.frame_post_draw
		var img = get_viewport().get_texture().get_image()
		img.save_png("user://screenshot_%d.png" % screenshot_count)
		print("📸 Screenshot saved to user://screenshot_%d.png" % screenshot_count)
		screenshot_count += 1
