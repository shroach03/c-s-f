
extends Control

signal song_chosen_for_set(song_data, venue_genre)
signal card_moved_to_set(card_instance, song_data)


	  
@onready var card_display_area = $Panel/CardDisplayArea 
@onready var feedback_label = $LastPlayedInfoLabel    
@onready var venue_genre_label= $VenueGenreLabel
@onready var score_label= $ScoreLabel
@onready var genre_indicator=$GenreIndicator

const SONG_CARD_SCENE = preload("res://scenes/song_card.tscn")
const MAX_SONGS_IN_SET = 5
const CARDS_SHOWN_PER_TURN = 5 
const GENRE_COLORS= {
	"Euro" : Color(0.0, 0.8, 0.8, 0.6),
	"RnB" : Color(0.0, 0.0, 0.6, 0.6),
	"Pop" : Color(1.0, 0.5, 0.8, 0.6),
	"Hiphop" : Color(1.0, 0.0, 0.0, 0.6),
	"EDM" : Color(0.5, 1.0, 0.0, 0.6)
}


var playable_song_pool: Array = [] 
var set_history: Array = []       
var cards_on_display: Array = []   
var current_turn_count: int = 0
var set_slots: Array = []          
var current_venue_genre: String = "Unknown"
var unlocked_songs: Array = []
var master_database: Array = []

func _ready():
	if venue_genre_label:
		venue_genre_label.text= "Genre Preference: %s" % current_venue_genre
	if GameManager and not GameManager.score_updated.is_connected(_on_score_updated):
		GameManager.score_updated.connect(_on_score_updated)
		
	current_turn_count=0

func draw_next_hand():
	for child in card_display_area.get_children():
		if not child in cards_on_display: 
			child.queue_free()
			
	if playable_song_pool.is_empty():
		if cards_on_display.is_empty() and current_turn_count < MAX_SONGS_IN_SET:
			feedback_label.text = "Deck empty"
		return
	
	while cards_on_display.size() < CARDS_SHOWN_PER_TURN and not playable_song_pool.is_empty():
		var song_data = playable_song_pool.pop_front() 
		var new_card = SONG_CARD_SCENE.instantiate()
		card_display_area.add_child(new_card)
		new_card.setup_card(song_data)
		new_card.song_selected.connect(_on_song_selected)
		cards_on_display.append(new_card)
		
	feedback_label.text = "Choose your next track (%d/%d played)." % [current_turn_count, MAX_SONGS_IN_SET]

func initialize_deck_from_inventory(inventory: Array):
	playable_song_pool.clear()
	set_history.clear()
	current_turn_count = 0
	cards_on_display.clear()
	
	playable_song_pool = inventory.duplicate(true)
	playable_song_pool.shuffle()
	
	print("Venue initialized with %d songs from your crate." % playable_song_pool.size())
	draw_next_hand()
func _on_song_selected(card_instance, data: Dictionary): 
	print("Card Selected: ", data["title"])
	current_turn_count += 1
	var current_set_size = current_turn_count
	
	set_history.append(data)
	song_chosen_for_set.emit(card_instance, data)
	feedback_label.text = "Played: %s. Preparing next..." % data.title

	cards_on_display.erase(card_instance)
	card_instance.queue_free() 

	emit_signal("card_moved_to_set", card_instance, data)

	if current_set_size >= MAX_SONGS_IN_SET:
		feedback_label.text = "Set Complete!"
		for card in cards_on_display:
			card.queue_free()
		cards_on_display.clear()

	else:
		feedback_label.text = "Played %d/%d. Choose next track" % [current_turn_count, MAX_SONGS_IN_SET]
		
	draw_next_hand()

func _initialize_venue_genre():
	var unique_genres = []
	if SongDatabase and SongDatabase.SONGS:
		for song in SongDatabase.SONGS:
			if not song.genre in unique_genres:
				unique_genres.append(song.genre)
			unique_genres.append(song.genre)

	if unique_genres.size()>0:
		current_venue_genre = unique_genres.pick_random()
		print("Current Genre: ", current_venue_genre)
		
	if genre_indicator:
		var indicator_color = GENRE_COLORS.get(current_venue_genre,Color.WHITE)
		genre_indicator.color = indicator_color

func update_venue_ui():
	if venue_genre_label:
		venue_genre_label.text = "Genre Preference: %s" % current_venue_genre

	if genre_indicator:
		var indicator_color = GENRE_COLORS.get(current_venue_genre, Color.WHITE)
		genre_indicator.color = indicator_color	

func _on_button_pressed() -> void:
	$CardBack/Button.disabled = true 
	modulate = Color(0.5, 0.5, 0.5)

func _on_score_updated(new_score: int):
	print("Score signal recieved ", new_score)
	if score_label:
		score_label.text = "Score: %d" % new_score
