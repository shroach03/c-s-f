## setlist_selection.gd
## Setlist builder. Emits signals upward; does NOT call GameManager directly.
extends Control
 
signal setlist_confirmed(selected_songs: Array)
signal go_to_world_pressed
 
# ── Node refs ────────────────────────────────────────────────────────────────
@onready var collection_grid : GridContainer = $Shell/VBoxContainer/Split/CollectionPanel/CollectionVBox/ScrollContainer/GridContainer
@onready var selected_grid   : GridContainer = $Shell/VBoxContainer/Split/SelectedPanel/SelectedVBox/SelectedScroll/SelectedGrid
@onready var start_button    : Button        = $Shell/VBoxContainer/TopBar/StartShow
@onready var back_button     : Button        = $Shell/VBoxContainer/TopBar/BackToWorld
@onready var count_label     : Label         = $Shell/VBoxContainer/TopBar/CountLabel
 
const SONG_CARD_SCENE   = preload("res://scenes/song_card.tscn")
const TARGET_CARD_WIDTH := 176.0
const SET_SIZE          := 5
 
var selected_songs : Array = []
 
# ════════════════════════════════════════════════════════════════════════════
 
func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	back_button.pressed.connect(_on_back_pressed)
	resized.connect(_update_grid_columns)
 
	start_button.disabled = true
	count_label.text = "Select %d Songs (0/%d)" % [SET_SIZE, SET_SIZE]
	selected_songs.clear()
 
	_update_grid_columns()
	_populate_collection()
 
# ════════════════════════════════════════════════════════════════════════════
 
func _populate_collection() -> void:
	_clear_grid(collection_grid)
	if GameManager == null:
		return
	for song_data in GameManager.player_collection:
		var card = SONG_CARD_SCENE.instantiate()
		collection_grid.add_child(card)
		card.setup_card(song_data, {"context": "selection"})
		card.song_selected.connect(_on_collection_card_clicked)
 
func _on_collection_card_clicked(card_instance, song_data: Dictionary) -> void:
	if selected_songs.has(song_data):
		selected_songs.erase(song_data)
		card_instance.modulate = Color.WHITE
	elif selected_songs.size() < SET_SIZE:
		selected_songs.append(song_data)
		card_instance.modulate = Color(0.5, 0.95, 1.0)
 
	_refresh_selected_grid()
	count_label.text = "Select %d Songs (%d/%d)" % [SET_SIZE, selected_songs.size(), SET_SIZE]
	start_button.disabled = (selected_songs.size() != SET_SIZE)
 
func _refresh_selected_grid() -> void:
	_clear_grid(selected_grid)
	for song_data in selected_songs:
		var card = SONG_CARD_SCENE.instantiate()
		selected_grid.add_child(card)
		card.setup_card(song_data, {"context": "collection", "show_button": false})
 
func _on_start_pressed() -> void:
	setlist_confirmed.emit(selected_songs.duplicate(true))
 
func _on_back_pressed() -> void:
	go_to_world_pressed.emit()
 
func _update_grid_columns() -> void:
	var w : int = max(size.x * 0.45 - 50.0, TARGET_CARD_WIDTH)
	var columns : int = max(1, int(floor(w / TARGET_CARD_WIDTH)))
	collection_grid.columns = columns
	selected_grid.columns   = columns
 
func _clear_grid(target: GridContainer) -> void:
	for child in target.get_children():
		child.queue_free()
