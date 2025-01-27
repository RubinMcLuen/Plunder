extends Node2D

@export var page1: Sprite2D
@export var page2: Sprite2D
@export var page3: Sprite2D
@export var page4: Sprite2D
@export var page5: Sprite2D

signal page_changed(new_page: int)

var current_page_index = 0
var max_pages: int = 1
var pages: Array[Sprite2D]
var icon_on = load("res://CharacterCreation/assets/icon_slider_on.png")
var icon_off = load("res://CharacterCreation/assets/icon_slider_off.png")

func _ready():
	pages = [page1, page2, page3, page4, page5]
	update_icons()

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
		pages[i].visible = i < max_pages  # Show only valid pages
		pages[i].texture = icon_on if i == current_page_index else icon_off

func reset_to_first_page():
	current_page_index = 0
	update_icons()
	emit_signal("page_changed", current_page_index)

