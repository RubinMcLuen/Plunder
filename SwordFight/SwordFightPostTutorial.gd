extends CanvasLayer

signal tutorial_finished

@onready var next_button = $Node2D/NextButton
@onready var back_button = $Node2D/BackButton
@onready var done_button = $Node2D/DoneButton
@onready var pages = [
$Node2D/Page1,
$Node2D/Page2,
$Node2D/Page3
]

var current_page_index := 0

func _ready():
	update_pages_visibility()
	next_button.pressed.connect(_on_next_button_pressed)
	back_button.pressed.connect(_on_back_button_pressed)
	done_button.pressed.connect(_on_done_button_pressed)

func _on_next_button_pressed():
	if current_page_index < pages.size() - 1:
		current_page_index += 1
		update_pages_visibility()

func _on_back_button_pressed():
	if current_page_index > 0:
		current_page_index -= 1
		update_pages_visibility()

func _on_done_button_pressed():
	emit_signal("tutorial_finished")
	queue_free()

func update_pages_visibility():
	# Show only the current page
	for i in pages.size():
		pages[i].visible = (i == current_page_index)
	
	# Update buttons based on the current page
	if current_page_index == 0:
		next_button.visible = true
		back_button.visible = false
		done_button.visible = false
	elif current_page_index == pages.size() - 1:
		next_button.visible = false
		back_button.visible = true
		done_button.visible = true
	else:
		next_button.visible = true
		back_button.visible = true
		done_button.visible = false
