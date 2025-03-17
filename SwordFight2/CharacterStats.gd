extends Resource
class_name CharacterStats

@export var character_name: String = "Pirate"
@export var level: int = 1
@export var max_hp: int = 100
@export var current_hp: int = 100
@export var strength: int = 10
@export var speed: int = 10
@export var defense: int = 10
@export var max_stamina: int = 10   # New property for maximum stamina
@export var stamina: int = 10    # Current stamina
@export var moves: Array[Move] = []
