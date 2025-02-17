# QuestManager.gd
extends Node

# A dictionary to store quests.
# The key is a unique quest identifier (a String),
# and the value is a Boolean indicating if the quest is completed.
var quests: Dictionary = {}

# Adds a new quest.
func add_quest(quest_id: String) -> void:
	if quest_id in quests:
		print("Quest '", quest_id, "' already exists!")
	else:
		quests[quest_id] = false  # false means not completed
		print("Added quest '", quest_id, "'.")

# Marks a quest as completed.
func complete_quest(quest_id: String) -> void:
	if quest_id in quests:
		quests[quest_id] = true
		print("Quest '", quest_id, "' marked as completed.")
	else:
		print("Quest '", quest_id, "' not found.")

# Checks if a quest is finished.
func is_quest_finished(quest_id: String) -> bool:
	if quest_id in quests:
		return quests[quest_id]
	else:
		print("Quest '", quest_id, "' not found.")
		return false

# Optional: Prints all quests and their status (for debugging).
func print_quests() -> void:
	for quest_id in quests.keys():
		var status = "Completed" if quests[quest_id] else "Incomplete"
		print("Quest '", quest_id, "': ", status)
