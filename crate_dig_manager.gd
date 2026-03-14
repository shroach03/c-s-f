extends Control

signal new_song_unlocked(song_data)
signal digging_finished(inventory: Array)

# References (Adjust paths based on your scene tree!)
@onready var dig_button = $CrateButton
@onready var status_label = $CrateLabel
@onready var display_area= $UnlockedCardDisplay
@onready var go_to_venue_button=$GoToVenue
#@onready var genre_icon=  $VenueGenreIcon


const MAX_DIGS = 3
const SONG_CARD_SCENE = preload("res://scenes/song_card.tscn")

var digs_remaining: int = MAX_DIGS
var master_database: Array = []
var unlocked_inventory: Array = []


func _ready():
	# Connect button and initialize state
	go_to_venue_button.hide()
	go_to_venue_button.pressed.connect(finish_digging_phase)
	dig_button.pressed.connect(_on_dig_button_pressed)
	if SongDatabase and SongDatabase.SONGS:
		master_database = SongDatabase.SONGS.duplicate(true)
		status_label.text= "Pick Crate! %d picks left" % digs_remaining
	else:
		status_label.text="ERROR: database not found"
		dig_button.disabled= true

func _on_dig_button_pressed():
	if digs_remaining <= 0:
		return
	digs_remaining -=1
	dig_button.disabled = true
	for child in display_area.get_children():
		child.queue_free()
	status_label.text = "Searching Crate..."
	await get_tree().create_timer(0.5).timeout
	_reveal_crate_contents(5)
	status_label.text = "Digging... (%d left)" % digs_remaining

	if digs_remaining>0:
		dig_button.disabled= false
		status_label.text = "Choose your songs, then pick the crate again! (%d picks left)" % digs_remaining
	else:
		dig_button.disabled = true
		status_label.text = "You've picked your songs! Go to venue."
		await get_tree().create_timer(1.5).timeout
		finish_digging_phase()

func _reveal_crate_contents(amount: int):
	var pool = master_database.duplicate(true)
	pool.shuffle()
	
	for i in range(min(amount, pool.size())):
		var song_data = pool[i]
		var card_visual = SONG_CARD_SCENE.instantiate()
		display_area.add_child(card_visual)
		card_visual.setup_card(song_data)
		card_visual.song_selected.connect(_on_card_selected_for_inventory)		
	go_to_venue_button.show()

func _on_card_selected_for_inventory(card_instance, song_data):
	if not unlocked_inventory.has(song_data):
		unlocked_inventory.append(song_data)
		card_instance.modulate = Color(0.5, 1.2, 0.5)
		var song_title = song_data.get("title", "Unknown Song")
		status_label.text = "Added %s to inventory. Total: %d" % [song_title, unlocked_inventory.size()]

func _perform_dig():
	if master_database.size() > 0:
		var newly_unlocked_song = master_database.pick_random()
		unlocked_inventory.append(newly_unlocked_song)
		status_label.text = "Discovered %s" % newly_unlocked_song.get("title","Unknown")
	else:
		status_label.text = "Crate is empty"

func finish_digging_phase():
	if unlocked_inventory.size() < 5:
		status_label.text = "You need at least 5 songs to perform!"
		return
		
	digging_finished.emit(unlocked_inventory.duplicate(true))
	print("Signal 'digging_finished' emitted with ", unlocked_inventory.size(), " songs.")
