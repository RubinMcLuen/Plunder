extends Node

const NPC_SCENE_PATHS := [
"res://Character/NPC/NPCs/Barnaby.tscn"
]

# Spawns or updates crew NPCs depending on hired status
func populate_scene(root: Node) -> void:
	var curr_scene: String = root.scene_file_path
	print("[CrewManager] populate_scene for:", curr_scene)
	
	for scene_path in NPC_SCENE_PATHS:
		var packed = load(scene_path) as PackedScene
		if packed == null:
			print("✗ failed to load PackedScene")
		continue
		print("  loaded file:", scene_path)

		var inst = packed.instantiate()
		if not inst is NPC:
			print("    ✗ instance is not NPC, freeing")
			inst.queue_free()
			continue

		var npc = inst as NPC
		print("    ✓ found NPC scene with npc_name:", npc.npc_name)

		# Determine if this NPC is already hired
		var is_hired = npc.npc_name in Global.crew
		# Choose spawn scene based on hire status
		var want_scene = npc.scene_post_hire if is_hired else npc.scene_pre_hire
		print("      is_hired:", is_hired, "want_scene:", want_scene)

		if want_scene == curr_scene:
			if not root.has_node(NodePath(npc.name)):
				# Position and flags
				var pos = npc.position_post_hire if is_hired else npc.position_pre_hire
				print("      → spawning at", pos)
				npc.global_position = pos
				npc.hirable = not is_hired
				npc.hired = is_hired
				root.add_child(npc)
			else:
				inst.queue_free()
		else:
			print("      ✗ wrong scene (skipping)")
		inst.queue_free()
