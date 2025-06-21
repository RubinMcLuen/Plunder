extends CanvasLayer

@export var next_action: StringName = "ui_accept"
@export var skip_action: StringName = "ui_cancel"

@onready var balloon: Control = %Balloon
@onready var character_label: RichTextLabel = %CharacterLabel
@onready var dialogue_label: DialogueLabel = %DialogueLabel
@onready var responses_menu: MarginContainer = %Responses
@onready var next_button: TextureButton = %NextButton
@onready var margin_container: MarginContainer = %MarginContainer

@onready var option_button_1: TextureButton = %Option1Button
@onready var option_button_2: TextureButton = %Option2Button
@onready var option_button_3: TextureButton = %Option3Button
@onready var option_button_4: TextureButton = %Option4Button
@onready var option_label_1: RichTextLabel = %Option1Label
@onready var option_label_2: RichTextLabel = %Option2Label
@onready var option_label_3: RichTextLabel = %Option3Label
@onready var option_label_4: RichTextLabel = %Option4Label
@onready var button_sound: AudioStreamPlayer = $ButtonSound

var resource: DialogueResource
var temporary_game_states: Array = []
var is_waiting_for_input: bool = false
var will_hide_balloon: bool = false
var selected_response_index: int = -1
signal dialogue_finished

var dialogue_line: DialogueLine:
	set(next_dialogue_line):
		is_waiting_for_input = false
		
		if not is_node_ready():
			await ready

		balloon.focus_mode = Control.FOCUS_ALL
		balloon.grab_focus()


		if not next_dialogue_line:
			emit_signal("dialogue_finished")
			queue_free()
			return


		if not is_node_ready():
			await ready

		dialogue_line = next_dialogue_line

		character_label.visible = not dialogue_line.character.is_empty()
		character_label.text = tr("[center]" + dialogue_line.character, "dialogue")

		dialogue_label.hide()
		dialogue_label.dialogue_line = dialogue_line

		responses_menu.hide()
		_update_responses_menu(dialogue_line.responses)

		balloon.show()
		will_hide_balloon = false

		dialogue_label.show()
		if not dialogue_line.text.is_empty():
			dialogue_label.type_out()
			await dialogue_label.finished_typing

		if dialogue_line.responses.size() > 0:
			is_waiting_for_input = true
			return

		if dialogue_line.time != "":
			var time = dialogue_line.text.length() * 0.02 if dialogue_line.time == "auto" else float(dialogue_line.time)
			await get_tree().create_timer(time).timeout
			next(dialogue_line.next_id)
		else:
			is_waiting_for_input = true
			balloon.focus_mode = Control.FOCUS_ALL
			balloon.grab_focus()
	get:
		return dialogue_line

@onready var option_buttons: Array = [
	option_button_1,
	option_button_2,
	option_button_3,
	option_button_4
]

func _ready() -> void:

	balloon.hide()
	for i in range(option_buttons.size()):
		option_buttons[i].connect("pressed", Callable(self, "_on_response_button_pressed").bind(i))

func _unhandled_input(_event: InputEvent) -> void:
	get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_instance_valid(dialogue_label):
		var visible_ratio = dialogue_label.visible_ratio
		self.dialogue_line = await resource.get_next_dialogue_line(dialogue_line.id)
		if visible_ratio < 1:
			dialogue_label.skip_typing()

func start(dialogue_resource: DialogueResource, title: String, extra_game_states: Array = []) -> void:
	temporary_game_states = [self] + extra_game_states
	is_waiting_for_input = false
	resource = dialogue_resource
	self.dialogue_line = await resource.get_next_dialogue_line(title, temporary_game_states)
	# Check if extra_game_states contains a node instead of a texture.
	if extra_game_states.size() > 0 and extra_game_states[0] is Node:
		update_portrait(extra_game_states[0])


func next(next_id: String) -> void:
	self.dialogue_line = await resource.get_next_dialogue_line(next_id, temporary_game_states)

func _on_mutated(_mutation: Dictionary) -> void:
	is_waiting_for_input = false
	will_hide_balloon = true
	get_tree().create_timer(0.1).timeout.connect(func():
		if will_hide_balloon:
			will_hide_balloon = false
			balloon.hide()
	)

func _on_balloon_gui_input(event: InputEvent) -> void:
	if dialogue_label.is_typing:
		var skip_button_was_pressed: bool = event.is_action_pressed(skip_action)
		if skip_button_was_pressed:
			get_viewport().set_input_as_handled()
			dialogue_label.skip_typing()
			return

	if not is_waiting_for_input:
		return
	if dialogue_line.responses.size() > 0:
		return

	if event.is_action_pressed(next_action) and get_viewport().gui_get_focus_owner() == balloon:
		next(dialogue_line.next_id)

func _on_responses_menu_response_selected(response: DialogueResponse) -> void:
	next(response.next_id)

func _on_responses_menu_visibility_changed() -> void:
	if responses_menu.visible:
		margin_container.hide()
	else:
		margin_container.show()

func _update_responses_menu(responses: Array) -> void:
	# Clear any previous selection and make sure Next is enabled by default
	selected_response_index = -1
	next_button.disabled = false

	var labels: Array = [
		option_label_1,
		option_label_2,
		option_label_3,
		option_label_4
	]

	for i in range(option_buttons.size()):
		var btn: TextureButton = option_buttons[i]
		var lbl: RichTextLabel = labels[i]

		# Allow toggle mode and clear any pressed state
		btn.toggle_mode = true
		btn.set_pressed(false)

		if i < responses.size():
			lbl.text = responses[i].text
			lbl.visible = true
			btn.disabled = false
		else:
			lbl.visible = false
			btn.disabled = true


func _on_next_button_pressed() -> void:
	if button_sound:
			button_sound.play()
	# 1. If text is still typing, skip to the end
	if dialogue_label.is_typing:
		dialogue_label.skip_typing()
		return

	# 2. If we're not waiting for player choice, ignore
	if not is_waiting_for_input:
		return

	# 3. If this line has responses and user hasn't selected one yet,
	#    reveal the options and disable Next until selection
	if dialogue_line.responses.size() > 0 and selected_response_index == -1:
		is_waiting_for_input = false
		responses_menu.visible = true
		margin_container.visible = false
		next_button.disabled = true
		return
	# 4. If the user selected an option, follow that branch
	elif selected_response_index != -1:
		is_waiting_for_input = false
		var response = dialogue_line.responses[selected_response_index]
		margin_container.visible = true
		responses_menu.visible = false
		next(response.next_id)
	# 5. Otherwise (no responses at all), just advance
	else:
		next(dialogue_line.next_id)


func _on_response_button_pressed(index: int) -> void:
	if button_sound:
			button_sound.play()
	# Only keep the clicked button toggled on
	for i in range(option_buttons.size()):
		option_buttons[i].set_pressed(i == index)

	# Record which option was chosen and re-enable Next
	selected_response_index = index
	next_button.disabled = false
	is_waiting_for_input = true



func update_portrait(character_node: Node) -> void:
	await ready  # Ensure _ready() has run

	if not character_node:
		print("Error: Given character node is null!")
		return

	# Duplicate the node (using a deep duplicate if needed)
	var new_portrait = character_node.duplicate()
	
		# Set the scale to exactly 2 (Vector2(2, 2))
	new_portrait.scale = Vector2(4, 4)
	new_portrait.customization_only = true
	# Set the position to (16, 16)
	if new_portrait is Node2D:
		new_portrait.position = Vector2(28, 84)

	
	# Add the new portrait instance to a container or to self.
	$Node2D/Balloon/Container.add_child(new_portrait)





