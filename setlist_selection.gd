extends Control

@onready var grid = $Background/ScrollContainer/RecordDisplay
@onready var start_button = $Background/StartShow
@onready var back_button = $Background/BackToWorld
@onready var count_label = $Background/CountLabel
@onready var scroll_container = $Background/ScrollContainer
@onready var record_shelf = $Background/ScrollContainer/RecordDisplay
@onready var left_spacer = $Background/ScrollContainer/RecordDisplay/LeftSpacer
@onready var right_spacer = $Background/ScrollContainer/RecordDisplay/RightSpacer
@onready var left_button = $Background/LeftButton
@onready var right_button = $Background/RightButton

var selected_songs: Array = []
var current_index := 0
var record_width := 0.0
const SONG_CARD_SCENE = preload("res://scenes/song_card.tscn")
const TARGET_CARD_WIDTH := 176.0

func _ready() -> void:
	if not start_button.pressed.is_connected(_on_start_show_button_pressed):
		start_button.pressed.connect(_on_start_show_button_pressed)
	if back_button and not back_button.pressed.is_connected(_on_back_to_world_pressed):
		back_button.pressed.connect(_on_back_to_world_pressed)
	left_button.pressed.connect(_on_left_button_pressed)
	right_button.pressed.connect(_on_right_button_pressed)
	start_button.disabled = true
	count_label.text = "Select 5 Songs (0/5)"
	selected_songs.clear()
	_clear_song_cards()
	_update_carousel_layout()
	_populate_collection()
	_update_nav_buttons()

func _populate_collection() -> void:
	if GameManager == null:
		print("GM REFERENCE MISSING")
		return
	for song_data in GameManager.player_collection:
		var card = SONG_CARD_SCENE.instantiate()
		grid.add_child(card)
		grid.move_child(card, right_spacer.get_index())
		card.setup_card(song_data, {"context": "selection"})
		if not card.song_selected.is_connected(_on_card_clicked):
			card.song_selected.connect(_on_card_clicked)
	_set_index(0)

func _clear_song_cards() -> void:
	for child in grid.get_children():
		if child == left_spacer or child == right_spacer:
			continue
		child.queue_free()

func _update_carousel_layout() -> void:
	var center_padding = maxf((scroll_container.size.x - TARGET_CARD_WIDTH) * 0.5, 0.0)
	left_spacer.custom_minimum_size.x = center_padding
	right_spacer.custom_minimum_size.x = center_padding
	record_width = TARGET_CARD_WIDTH + record_shelf.get_theme_constant("separation")
	_scroll_to_current()

func _card_count() -> int:
	return maxi(record_shelf.get_child_count() - 2, 0)

func _on_left_button_pressed() -> void:
	_set_index(current_index - 1)

func _on_right_button_pressed() -> void:
	_set_index(current_index + 1)

func _set_index(new_index: int) -> void:
	current_index = clampi(new_index, 0, maxi(_card_count() - 1, 0))
	_scroll_to_current()
	_update_nav_buttons()

func _scroll_to_current() -> void:
	var target_x = current_index * record_width
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(scroll_container, "scroll_horizontal", target_x, 0.25)

func _update_nav_buttons() -> void:
	var has_cards = _card_count() > 0
	left_button.disabled = (not has_cards) or current_index <= 0
	right_button.disabled = (not has_cards) or current_index >= _card_count() - 1


func _on_card_clicked(card_instance, song_data):
	if selected_songs.has(song_data):
		selected_songs.erase(song_data)
		card_instance.modulate = Color.WHITE
	elif selected_songs.size() < 5:
		selected_songs.append(song_data)
		card_instance.modulate = Color(0.5, 0.95, 1.0)

	count_label.text = "Select 5 Songs (%d/5)" % selected_songs.size()
	start_button.disabled = (selected_songs.size() != 5)

func _on_start_show_button_pressed() -> void:
	GameManager.finalize_setlist(selected_songs)

func _on_back_to_world_pressed() -> void:
	if GameManager != null:
		GameManager.return_to_world()
