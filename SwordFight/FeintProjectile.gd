extends Projectile
class_name FeintProjectile

signal sliced(projectile: FeintProjectile)

func _on_mouse_entered():
	if is_dragging:
		print("DEBUG: Feint projectile sliced via mouse entered")
		emit_signal("sliced", self)
		queue_free()

func _on_mouse_exited():
	# For FeintProjectiles, exiting without swiping does nothing.
	pass
