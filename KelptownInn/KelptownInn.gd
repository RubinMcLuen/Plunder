extends Node2D
class_name KelptownInn

@export var player                       : CharacterBody2D
@export var location_name                : String            = "Kelptown Inn"
@export var bartender_dialogue_resource  : Resource
@export var barnaby_dialogue_resource    : Resource

@onready var bartender : NPC = $Bartender

func _ready() -> void:
	if player == null and has_node("Player"):
				player = get_node("Player") as CharacterBody2D

		# ───────────────────────────────────── 0) Spawn position if loading from a save
	if Global.spawn_position != Vector2.ZERO:
				player.global_position = Global.spawn_position
				Global.spawn_position  = Vector2.ZERO                # ← clear for later scenes

	# 1) Spawn crew for this scene
	CrewManager.populate_scene(self)
	await get_tree().process_frame

	# 2) Hook up the bartender
	bartender.dialogue_requested.connect(_on_bartender_dialogue_requested)

		# 3) Hook up every dynamically-spawned Barnaby
	for b in get_children():
				if b is NPC and b.npc_name == "Barnaby":
						b.dialogue_requested.connect(_on_barnaby_dialogue_requested)
						b.npc_hired.connect(_on_barnaby_hired)

	# 4) UI, camera & exit
	UIManager.show_location_notification(location_name)
	$Player/Camera2D.zoom = Vector2(1.5, 1.5)
	$Exit.body_entered.connect(_on_exit_body_entered)


# ───────────────────────── Bartender
func _on_bartender_dialogue_requested(section: String) -> void:
		player.disable_user_input = true
		var balloon = bartender.show_dialogue(section)
		if balloon:
				balloon.connect("dialogue_finished", Callable(self, "_on_dialogue_finished"))
		else:
				player.disable_user_input = false

func _on_dialogue_finished() -> void:
	player.disable_user_input = false


# ───────────────────────── Barnaby
func _on_barnaby_dialogue_requested(section: String, b: NPC) -> void:
	player.disable_user_input = true
	var balloon = b.show_dialogue(section)
	balloon.connect(
		"dialogue_finished",
		Callable(self, "_on_dialogue_finished_barnaby").bind(b)
	)

func _on_dialogue_finished_barnaby(_b: NPC) -> void:
	player.disable_user_input = false   # no call to b.hire() here


# Walk Barnaby out once hired
func _on_barnaby_hired(b: NPC) -> void:
	var exit_target = $Exit.global_position
	b.auto_move_to_position(exit_target)
	b.npc_move_completed.connect(Callable(b, "queue_free"))


# ───────────────────────── Exit to Island
func _on_exit_body_entered(body: Node) -> void:
	if body == player:
		#            path                               pos         type   old-zoom  pan  new-zoom
		SceneSwitcher.switch_scene(
			"res://Island/Island.tscn",
			Vector2( 64, -42),
			"fade",                           # transition type
			Vector2.ONE,                      # ← only used for "zoom" transitions
			Vector2.ZERO,                     # no camera pan
			Vector2(1.5, 1.5)                 # ← Island’s desired starting zoom
		)
