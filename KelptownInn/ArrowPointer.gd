extends Sprite2D

@export var target   : Node2D
@export var y_offset : float = -24.0     # tweak for your art

func _ready() -> void:
	# Ensure sprite is drawn around its centre (must also tick “Centered” in Inspector)
	set_centered(true)

func _process(_delta: float) -> void:
	if target:
		global_position = target.global_position + Vector2(0, y_offset)
