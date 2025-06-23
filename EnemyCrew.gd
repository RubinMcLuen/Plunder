# EnemyCrew.gd
extends Node2D

# Preload the NPC scene
var NPCScene: PackedScene = preload("res://Character/NPC/NPC.tscn")

# Hard-coded positions for each NPC in a horizontal line.
# Adjust these positions as needed.
var positions = [
	Vector2(50, 100),    # Position for captain
	Vector2(100, 100),  # Position for crew1
	Vector2(150, 100),  # Position for crew2
	Vector2(200, 100),  # Position for crew3
	Vector2(250, 100)   # Position for crew4
]

# Variables to hold references to the spawned NPCs
var captain
var crew1
var crew2
var crew3
var crew4

func _ready() -> void:
	randomize()  # Initialize random number generator

	# Choose a random number of NPCs between 3 and 5.
	var npc_count = randi() % 3 + 3  # Possible values: 3, 4, or 5

	# Spawn the captain first.
	captain = NPCScene.instantiate()
	captain.position = positions[0]
	captain.npc_name = "captain"  # Set the npc_name property to the variable name.
	captain.fightable = true      # Enable fightable.
	add_child(captain)

	if npc_count >= 2:
		crew1 = NPCScene.instantiate()
		crew1.position = positions[1]
		crew1.npc_name = "crew1"
		crew1.fightable = true
		add_child(crew1)
		
	if npc_count >= 3:
		crew2 = NPCScene.instantiate()
		crew2.position = positions[2]
		crew2.npc_name = "crew2"
		crew2.fightable = true
		add_child(crew2)
		
	if npc_count >= 4:
		crew3 = NPCScene.instantiate()
		crew3.position = positions[3]
		crew3.npc_name = "crew3"
		crew3.fightable = true
		add_child(crew3)
		
	if npc_count == 5:
		crew4 = NPCScene.instantiate()
		crew4.position = positions[4]
		crew4.npc_name = "crew4"
		crew4.fightable = true
		add_child(crew4)
