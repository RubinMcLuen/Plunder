extends Node2D

@export var boat: Node2D

func _physics_process(delta):
	position = boat.global_position
