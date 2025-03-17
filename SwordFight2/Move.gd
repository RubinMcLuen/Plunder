# Move.gd
extends Resource
class_name Move

@export var move_name: String = "Unnamed Move"
@export var move_type: String = "Aggressive"  # Options: "Aggressive", "Defensive", "Trickster"
@export var base_power: int = 0
@export var accuracy: float = 1.0  # Range: 0.0 (0%) to 1.0 (100%)
@export var stamina_cost: int = 0
@export var special_effect: String = ""  # e.g., "stun", "blind", "bonus_damage", etc.
