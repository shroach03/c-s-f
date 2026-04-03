extends Control

@onready var grid = $Background/ScrollContainer/RecordDisplay
@onready var start_button = $Background/StartShow
@onready var back_button =$Background/BackToWorld
@onready var count_label = $Background/CountLabel
@onready var scroll_container = $Background/ScrollContainer
@onready var record_shelf =$Background/ScrollContainer/RecordDisplay
@onready var left_spacer = $Background/ScrollContainer/RecordDisplay/LeftSpacer
@onready var right_spacer = $Background/ScrollContainer/RecordDisplay/RightSpacer

var selected_songs: Array = []
var current_index = 0
var record_width = 0.0
const SONG_CARD_SCENE = preload("res://scenes/song_card.tscn")
const TARGET_CARD_WIDTH := 176.0

func _ready():
	if not start_button.pressed.is_connected(_on_start_show_button_pressed):
		start_button.pressed.connect(_on_start_show_button_pressed)
	if back_button and not back_button.pressed.is_connected(_on_back_to_world_pressed):
		back_button.pressed.connect(_on_back_to_world_pressed)
	start_button.disabled = true
	count_label.text = "Select 5 Songs (0/5)"
	selected_songs.clear()
	for child in grid.get_children():
		child.queue_free()

	_update_carousel_layout()
	_populate_collection()

func _populate_collection():
	if GameManager == null:
		print("GM REFERENCE MISSING")
		return
	for song_data in GameManager.player_collection:
		var card = SONG_CARD_SCENE.instantiate()
		grid.add_child(card)
		card.setup_card(song_data, {"context": "selection"})
		if not card.song_selected.is_connected(_on_card_clicked):
			card.song_selected.connect(_on_card_clicked)

func _update_carousel_layout() -> void:
	var center_padding = (scroll_container.size.x / 2.0) - (TARGET_CARD_WIDTH / 2.0)
	left_spacer.custom_minimum_size.x = center_padding
	right_spacer.custom_minimum_size.x = center_padding
	var separation = record_shelf.get_theme_constant("separation")
	record_width = TARGET_CARD_WIDTH + separation
	_animate_scroll()

func _on_left_button_pressed():
	if current_index > 0:
		current_index -= 1
		_animate_scroll()

func _on_right_button_pressed():
	# -3 because of the 2 spacers and the 0-based index
	var total_records = record_shelf.get_child_count() - 2 
	if current_index < total_records - 1:
		current_index += 1
		_animate_scroll()

func _animate_scroll():
	var target_x = current_index * record_width
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	# Directly animate the scroll_horizontal property of the container
	tween.tween_property(scroll_container, "scroll_horizontal", target_x, 0.25)

func _on_card_clicked(card_instance, song_data):
	if selected_songs.has(song_data):
		selected_songs.erase(song_data)
		card_instance.modulate = Color.WHITE
	elif selected_songs.size() < 5:
		selected_songs.append(song_data)
		card_instance.modulate = Color(0.5, 0.95, 1.0)

	count_label.text = "Select 5 Songs (%d/5)" % selected_songs.size()
	start_button.disabled = (selected_songs.size() != 5)

func _on_start_show_button_pressed():
	GameManager.finalize_setlist(selected_songs)

func _on_back_to_world_pressed() -> void:
	if GameManager != null:
		GameManager.return_to_world()
