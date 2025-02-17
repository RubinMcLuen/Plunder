extends Node2D

@onready var page1: Sprite2D = $Page1
@onready var page2: Sprite2D = $Page2
@onready var page3: Sprite2D = $Page3
@onready var page4: Sprite2D = $Page4
@onready var page5: Sprite2D = $Page5
@onready var down_button: TextureButton = $DownButton  # Reference to the DownButton

signal page_changed(new_page: int)

var current_page_index = 0
var max_pages: int = 5  # Will be updated dynamically.
var pages: Array[Sprite2D]
var icon_on = load("res://CharacterCreation/assets/icon_slider_on.png")
var icon_off = load("res://CharacterCreation/assets/icon_slider_off.png")
var initial_down_button_y: float  # Will store the original Y position.

func _ready():
	pages = [page1, page2, page3, page4, page5]
	initial_down_button_y = down_button.position.y  # This is for 5 pages.
	update_icons()


func set_page_count(count: int):
	max_pages = count
	update_icons()
	# Since the default position (initial_down_button_y) is for 5 pages,
	# raise the down button by 10 pixels for each page missing.
	down_button.position.y = initial_down_button_y - ((5 - count) * 13)

func _on_up_button_pressed():
	if current_page_index > 0:
		current_page_index -= 1
		emit_signal("page_changed", current_page_index)
		update_icons()

func _on_down_button_pressed():
	if current_page_index < max_pages - 1:
		current_page_index += 1
		emit_signal("page_changed", current_page_index)
		update_icons()

func update_icons():
	for i in range(pages.size()):
		# Only show pages that are within the valid range.
		pages[i].visible = i < max_pages  
		pages[i].texture = icon_on if i == current_page_index else icon_off

func reset_to_first_page():
	current_page_index = 0
	update_icons()
	emit_signal("page_changed", current_page_index)
