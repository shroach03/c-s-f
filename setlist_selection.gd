extends Control

var gm_ref=null

@onready var grid = $ScrollContainer/GridContainer
@onready var start_button = $VBoxContainer/TopBar/StartShow
@onready var count_label = $VBoxContainer/TopBar/CountLabel

var selected_songs: Array = []
const SONG_CARD_SCENE = preload("res://scenes/song_card.tscn")

func _ready():
	# 1. Clear the grid
	for child in grid.get_children():
		child.queue_free()
	
	# 2. Populate from the GameManager's permanent collection
	
		
		# Connect the card's signal to our selection logic
	

func initialize(manager_instance):
	gm_ref=manager_instance
	_populate_collection()
	

func _populate_collection():
	print("C.size: ", gm_ref.player_collection.size())
	if gm_ref==null:
		print("GM REFERENCE MISSING")
		return
	for song_data in gm_ref.player_collection:
		var card= SONG_CARD_SCENE.instantiate()
		grid.add_child(card)
		
		card.setup_card(song_data)
		
		if not card.song_selected.is_connected(_on_card_clicked):
			card.song_selected.connect(_on_card_clicked)
		

func _on_card_clicked(card_instance, song_data):
	# If already selected, remove it (Deselect)
	if selected_songs.has(song_data):
		selected_songs.erase(song_data)
		card_instance.modulate = Color.WHITE # Reset color
	
	# If not selected and we have room, add it
	elif selected_songs.size() < 5:
		selected_songs.append(song_data)
		card_instance.modulate = Color.CYAN # Highlight color
	
	# Update UI
	count_label.text = "Select 5 Songs (%d/5)" % selected_songs.size()
	start_button.disabled = (selected_songs.size() != 5)

func _on_start_show_button_pressed():
	# Pass the final 5 back to the GameManager
	duplicate(true)
	gm_ref.start_performance_phase()
	queue_free() # Close this menu
