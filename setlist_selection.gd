
extends Control

@onready var grid = $VBoxContainer/ScrollContainer/GridContainer
@onready var start_button = $VBoxContainer/TopBar/StartShow
@onready var count_label = $VBoxContainer/TopBar/CountLabel

var selected_songs: Array = []
const SONG_CARD_SCENE = preload("res://scenes/song_card.tscn")

func _ready():
	if not start_button.pressed.is_connected(_on_start_show_button_pressed):
		start_button.pressed.connect(_on_start_show_button_pressed)
	start_button.disabled = true
	count_label.text = "Select 5 Songs (0/5)"
	
	for child in grid.get_children():
		child.queue_free()


	_populate_collection()
	

func _populate_collection():
	if GameManager == null:
		print("GM REFERENCE MISSING")
		return
	print("C.size: ", GameManager.player_collection.size())
	for song_data in GameManager.player_collection: 
		var card= SONG_CARD_SCENE.instantiate()
		grid.add_child(card)
		card.setup_card(song_data, {"context": "selection"})
		if not card.song_selected.is_connected(_on_card_clicked):
			card.song_selected.connect(_on_card_clicked)
		

func _on_card_clicked(card_instance, song_data):
	if selected_songs.has(song_data):
		selected_songs.erase(song_data)
		card_instance.modulate = Color.WHITE

	elif selected_songs.size() < 5:
		selected_songs.append(song_data)
		card_instance.modulate = Color.CYAN

	count_label.text = "Select 5 Songs (%d/5)" % selected_songs.size()
	start_button.disabled = (selected_songs.size() != 5)

func _on_start_show_button_pressed():
	GameManager.finalize_setlist(selected_songs)
	queue_free()
