
# GameManager.gd (Attached to the root node of your main scene)
extends Node
# --- State Variables and References (Ensure these are defined above _ready) ---
var current_crowd_state = { "energy": 50, "trust": 50, "patience": 50 }
var current_score: int= 0
var last_played_energy: int=0
var current_song_inventory: Array =[]
var current_venue_genre: String = ""
var set_history: Array= []
var player_collection: Array=[]
var current_setlist: Array=[]


signal score_updated(new_score)

const SONGS_IN_SET = 5 
const SongDatabase= preload("res://scripts/song_database.gd")
const CRATE_SCENE = preload("res://scenes/crate_dig.tscn")
const PERFORMANCE_SCENE = preload("res://scenes/song_deck_manager.tscn")
const SELECTION_SCENE= preload("res://scenes/setlist_selection.tscn")

# ... add other variables/constants from previous examples ...


var active_deck_manager = null

func _ready():
	var db_instance= SongDatabase.new()
	if db_instance and db_instance.SONGS:
		var all_songs= db_instance.SONGS
		var available_genres= []
		for song in all_songs:
			var g = song.get("genre", "Unknown")
			if not available_genres.has(g):
				available_genres.append(g)
		if available_genres.size()>0:
			current_venue_genre= available_genres.pick_random()
		print("Crowd wants to hear %s tonight" % [current_venue_genre])
	db_instance.queue_free()
	# Initialize all necessary components (like setting up your initial state)
	# For testing, make sure the deck manager knows how to draw the first hand
	start_crate_digging_phase()
	

	
# --- Core Game Loop Handler ---

func _handle_song_played(_card_instance, selected_song_data):
	if not is_instance_valid(self) or selected_song_data == null:
		print("ERROR: null song data")
		return
	var song_title= selected_song_data.get("title", "Unknown")
	print("GameManager received: %s" % song_title)
	
	# 1. Logic and Scoring
	var points_earned = calculate_score_from_song(selected_song_data, current_venue_genre)
	var calculation_results = calculate_impact(selected_song_data)
	
	set_history.append(selected_song_data)
	last_played_energy = selected_song_data.get("energy", 0)
	current_score += points_earned
	
	# 2. Update State
	update_crowd_state(calculation_results)
	score_updated.emit(current_score)
	
	# 3. Update UI Feedback on the active manager
	if is_instance_valid(active_deck_manager):
		var played_count = set_history.size()
		active_deck_manager.feedback_label.text = "Played %s. (%d/%d played)" % [selected_song_data.title, played_count, SONGS_IN_SET]

	# 4. Win/Loss Checks
	if check_fail_condition():
		return 
		
	if set_history.size() >= SONGS_IN_SET:
		check_win_condition()
	else:
		# Draw next hand if game continues
		if is_instance_valid(active_deck_manager):
			active_deck_manager.draw_next_hand()
	
func start_crate_digging_phase():
	if is_instance_valid($SongDeckManager):
		$SongDeckManager.queue_free()
	var crate_scene= CRATE_SCENE.instantiate()
	add_child(crate_scene)
	crate_scene.digging_finished.connect(on_digging_finished)

func on_digging_finished(new_finds: Array):
	player_collection= new_finds.duplicate(true)
	print("Crate digging compelte; Inventory has: %d" % new_finds.size())
	for child in get_children():
		if "Crate" in child.name:
			child.queue_free()
	open_setlist_selection_menu()

func open_setlist_selection_menu():
	var selection_menu= SELECTION_SCENE.instantiate()
	add_child(selection_menu)
	selection_menu.initialize(self)

func start_performance_phase():
	active_deck_manager = PERFORMANCE_SCENE.instantiate()
	add_child(active_deck_manager)
	# Connect the signal (ensure names match your deck manager's signal)
	if active_deck_manager.has_signal("song_chosen_for_set"):
		active_deck_manager.song_chosen_for_set.connect(_handle_song_played)
	active_deck_manager.current_venue_genre = current_venue_genre
	active_deck_manager.update_venue_ui()
	active_deck_manager.initialize_deck_from_inventory(current_setlist)
	# Setup UI
	
	

	# Initial feedback text
	active_deck_manager.feedback_label.text = "The show is starting! Pick your first song."
# --- Placeholder Functions (You need to ensure these exist!) ---
func calculate_impact(song_data):
	# Return dummy results for testing the flow if you haven't built the full logic yet
	return {"energy_change": 10, "trust_change": 5, "patience_change": -2}

func update_crowd_state(impact):
	# Apply changes, clamping values between 0 and 100 (or your max/min)
	current_crowd_state.energy = clamp(current_crowd_state.energy + impact.energy_change, 0, 100)
	print("Crowd Energy Updated to: ", current_crowd_state.energy)

func check_fail_condition():
	# For testing the loop, let's pretend we only fail if energy hits 30
	if current_crowd_state.energy <= 30:
		print("*** GAME OVER: Crowd lost interest! ***")
		return true
	return false
	
	
func check_win_condition():
	print("*** VICTORY! Set Complete! ***")
	# In a full version, this would check your Energy/Trust thresholds
func calculate_score_from_song(song_data: Dictionary, venue_genre: String)-> int:
	var points = 0
	# Use .get() for dictionaries!
	var risk = song_data.get("risk", "Low")
	var genre = song_data.get("genre", "Unknown")
	var energy = song_data.get("energy", 0)

	match risk:
		"Low": points += 1
		"Medium": points += 3
		"High": points += 5
		
	if genre == venue_genre:
		points += 5
		
	var energy_diff = abs(energy - last_played_energy)
	if energy_diff == 1:
		points += 3
	elif energy_diff == 0:
		points += 1

	return points
	
