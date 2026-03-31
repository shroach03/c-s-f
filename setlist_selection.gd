extends Control

@onready var grid = $Shell/VBoxContainer/Split/CollectionPanel/CollectionVBox/ScrollContainer/GridContainer
@onready var selected_grid = $Shell/VBoxContainer/Split/SelectedPanel/SelectedVBox/SelectedScroll/SelectedGrid
@onready var start_button = $Shell/VBoxContainer/TopBar/StartShow
@onready var back_button = $Shell/VBoxContainer/TopBar/BackToWorld
@onready var count_label = $Shell/VBoxContainer/TopBar/CountLabel

var selected_songs: Array = []
const SONG_CARD_SCENE = preload("res://scenes/song_card.tscn")
const TARGET_CARD_WIDTH := 176.0

func _ready():
	if not start_button.pressed.is_connected(_on_start_show_button_pressed):
		start_button.pressed.connect(_on_start_show_button_pressed)
	if back_button and not back_button.pressed.is_connected(_on_back_to_world_pressed):
		back_button.pressed.connect(_on_back_to_world_pressed)
	if not resized.is_connected(_update_grid_columns):
		resized.connect(_update_grid_columns)
	start_button.disabled = true
	count_label.text = "Select 5 Songs (0/5)"
	selected_songs.clear()
	_clear_grid(grid)
	_clear_grid(selected_grid)
	_update_grid_columns()
	_populate_collection()

func _clear_grid(target: GridContainer) -> void:
	for child in target.get_children():
		child.queue_free()

func _populate_collection():
	if GameManager == null:
		return
	for song_data in GameManager.player_collection:
		var card = SONG_CARD_SCENE.instantiate()
		grid.add_child(card)
		card.setup_card(song_data, {"context": "selection"})
		if not card.song_selected.is_connected(_on_card_clicked):
			card.song_selected.connect(_on_card_clicked)

func _update_grid_columns() -> void:
	var available_width = max(size.x * 0.45 - 50.0, TARGET_CARD_WIDTH)
	var columns = max(1, int(floor(available_width / TARGET_CARD_WIDTH)))
	grid.columns = columns
	selected_grid.columns = columns

func _on_card_clicked(card_instance, song_data):
	if selected_songs.has(song_data):
		selected_songs.erase(song_data)
		card_instance.modulate = Color.WHITE
	elif selected_songs.size() < 5:
		selected_songs.append(song_data)
		card_instance.modulate = Color(0.5, 0.95, 1.0)
	_refresh_selected_grid()
	count_label.text = "Select 5 Songs (%d/5)" % selected_songs.size()
	start_button.disabled = (selected_songs.size() != 5)

func _refresh_selected_grid() -> void:
	_clear_grid(selected_grid)
	for song_data in selected_songs:
		var card = SONG_CARD_SCENE.instantiate()
		selected_grid.add_child(card)
		card.setup_card(song_data, {"context": "collection", "show_button": false})

func _on_start_show_button_pressed():
	GameManager.finalize_setlist(selected_songs)

func _on_back_to_world_pressed() -> void:
	if GameManager != null:
		GameManager.return_to_world()
