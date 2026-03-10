# --- Script: song_deck_manager.gd ---
extends Control

# --- Signals ---
# This is the signal that GameManager.gd connects to, passing the chosen song data
signal song_chosen_for_set(song_data, venue_genre)
# New signal to indicate a card has been moved to the set
signal card_moved_to_set(card_instance, song_data)

# --- References ---
@onready var song_database = $SongDatabase           # Reference to the node holding the master list
@onready var card_display_area = $Panel/CardDisplayArea # Where the current cards are parented
@onready var feedback_label = $LastPlayedInfoLabel      # Label for status/instruction messages
@onready var venue_genre_label= $VenueGenreLabel
@onready var score_label= $ScoreLabel
@onready var genre_indicator=$GenreIndicator



# --- Constants & Preloads ---
const SONG_CARD_SCENE = preload("res://scenes/song_card.tscn")
const MAX_SONGS_IN_SET = 5
const CARDS_SHOWN_PER_TURN = 5 # How many choices the user gets
const GENRE_COLORS= {
	"Euro":Color(0.0,0.8,0.8,0.6),
	"RnB": Color(0.0,0.0,0.6,0.6),
	"Pop": Color(1.0,0.5,0.8,0.6),
	"Hiphop":Color(1.0,0.0,0.0,0.6),
	"EDM": Color(0.5,1.0,0.0,0.6)
}

# --- Game State ---
var playable_song_pool: Array = [] # The master pool we draw from for this "Night"
var set_history: Array = []        # Tracks the 5 songs chosen in order (Local tracking)
var cards_on_display: Array = []   # Tracks the card instances currently visible in the hand
var current_turn_count: int = 0
var set_slots: Array = []          # Will track card instances placed in the set
var current_venue_genre: String = "Unknown"
var unlocked_songs: Array=[]
var master_database: Array=[]

func _ready():
	# 1. Initialize the playable deck by copying the master database
	
	if venue_genre_label:
		venue_genre_label.text= "Genre Preference: %s" % current_venue_genre


	else:
		feedback_label.text = "Error: Song Database not found or empty!"
	var game_manager_node= get_parent()
	if not game_manager_node.score_updated.is_connected(_on_score_updated):
		game_manager_node.score_updated.connect(_on_score_updated)
		
	
		
#  Start the loop by drawing the first set of cards
	current_turn_count=0



	
# --- Core Loop Function: Draws options for the user ---
func draw_next_hand():
	# Clear any cards that are no longer in the display area (e.g., if they were moved to set)
	# This ensures we only draw into empty slots in the display area
	
	for child in card_display_area.get_children():
		if not child in cards_on_display: # Only remove if it's not being tracked as on display
			child.queue_free()
	
	
	
	
	if playable_song_pool.is_empty():
		if cards_on_display.is_empty() and current_turn_count < MAX_SONGS_IN_SET:
			feedback_label.text= "Deck empty"
		return
	
		# Draw, setup, and connect cards
	while cards_on_display.size() < CARDS_SHOWN_PER_TURN and not playable_song_pool.is_empty():
			# Take the song data from the pool (and remove it so it's not drawn again)
		var song_data = playable_song_pool.pop_front() 
		var new_card = SONG_CARD_SCENE.instantiate()
		card_display_area.add_child(new_card)
		new_card.setup_card(song_data)
		
			
		
		new_card.song_selected.connect(_on_song_selected)
			
			# Connect THIS specific card instance to our signal handler
			# Make sure the signal name matches in SongCard.gd
		
			
		cards_on_display.append(new_card)
	
	# Update feedback prompt
	feedback_label.text = "Choose your next track (%d/%d played)." % [current_turn_count, MAX_SONGS_IN_SET]

func initialize_deck_from_inventory(inventory: Array):
	playable_song_pool.clear()
	set_history.clear()
	current_turn_count=0
	cards_on_display.clear()
	
	playable_song_pool = inventory.duplicate()
	playable_song_pool.shuffle()
	
	print("Venue initialized with %d songs from your crate." % playable_song_pool.size())
	
	draw_next_hand()
# --- Signal Handler: Triggered when a SongCard is clicked ---
func _on_song_selected(card_instance, data: Dictionary): # Modified to receive the instance itself
	print("Card Selected: ", data["title"])
	current_turn_count+=1
	var current_set_size = current_turn_count
	
	# 1. Record the choice & Update Game Manager
	set_history.append(data)
	song_chosen_for_set.emit(card_instance, data)
	
	feedback_label.text = "Played: %s. Preparing next..." % data.title
	
	# 2. Remove the selected card from the display
	cards_on_display.erase(card_instance)
	card_instance.queue_free() # Remove it visually from the hand

	# 3. Emit signal to move this card to the set (for GameManager or a SetBuilder to handle)
	emit_signal("card_moved_to_set", card_instance, data)
	
	# 4. Check if the set is complete
	
	if current_set_size >= MAX_SONGS_IN_SET:
		feedback_label.text = "Set Complete!"	
		for card in cards_on_display:
			card.queue_free()
		cards_on_display.clear()
		# The GameManager will handle the final score and win/lose
	else:
		feedback_label.text = "Played %d/%d. Choose next track" % [current_turn_count, MAX_SONGS_IN_SET]
	draw_next_hand()
func _initialize_venue_genre():
	var unique_genres=[]
	for song in song_database.SONGS:
		if not song.genre in unique_genres:
			unique_genres.append(song.genre)
	if unique_genres.size()>0:
		current_venue_genre = unique_genres.pick_random()
		print("Current Genre: ", current_venue_genre)
	if genre_indicator:
		var indicator_color= GENRE_COLORS.get(current_venue_genre,Color.WHITE)
		genre_indicator.color=indicator_color
func update_venue_ui():
	if venue_genre_label:
		venue_genre_label.text = "Genre Preference: %s" % current_venue_genre
	
	if genre_indicator:
		var indicator_color = GENRE_COLORS.get(current_venue_genre, Color.WHITE)
		genre_indicator.color = indicator_color	
func _on_button_pressed() -> void:
	
	# This sends the signal up to your SongDeckManager, passing THIS card's instance
	# Pass 'self' (the instance)
	# Optional: Visual feedback
	$CardBack/Button.disabled = true 
	modulate = Color(0.5, 0.5, 0.5)
func _on_score_updated(new_score: int):
	print("Score signal recieved ", new_score)
	if score_label:
		score_label.text= "Score: %d" % new_score
