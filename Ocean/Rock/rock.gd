extends Area2D

# Constants
const MAX_HITS = 15
const HITS_PER_FRAME = 5

# Variables
var hits_left = MAX_HITS
var is_exploding = false

# Nodes
@onready var rock_sprite = $Sprite2D
@onready var explosion_sprite = $AnimatedSprite2D

func _ready():
	# Set the initial frame
	rock_sprite.frame = 0
	explosion_sprite.visible = false
	explosion_sprite.connect("animation_finished", Callable(self, "_on_explosion_finished"))
	# Connect the area_entered signal to the _on_area_entered function
	connect("area_entered", Callable(self, "_on_area_entered"))

func take_damage(amount):
	if is_exploding:
		return
	
	hits_left -= 1
	update_sprite_frame()

	if hits_left <= 0:
		explode()

func update_sprite_frame():
	if hits_left > 0:
		var current_frame = float(MAX_HITS - hits_left) / HITS_PER_FRAME
		rock_sprite.frame = current_frame

func explode():
	is_exploding = true
	rock_sprite.visible = false
	explosion_sprite.visible = true
	explosion_sprite.play("explosion")  # Ensure the explosion animation is named "explosion"

func _on_explosion_finished():
	queue_free()

func _on_area_entered(area):
	if area.is_in_group("cannonball2"):
		take_damage(1)
		area.queue_free()  # Optionally remove the cannonball after impact.
	elif area.name == "Player":
		explode()

