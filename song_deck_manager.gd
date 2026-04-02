## song_deck_manager.gd
## Performance phase. Node paths match song_deck_manager.tscn exactly.
extends Control
 
signal song_chosen_for_set(card_instance, song_data)
signal go_to_world_pressed
 
# ── Node refs  (all paths verified against song_deck_manager.tscn) ──────────
@onready var venue_name_label  : Label         = $RootSplit/LeftPane/VenueNameLabel
@onready var venue_genre_label : Label         = $RootSplit/LeftPane/VenueGenreLabel
@onready var score_label       : Label         = $RootSplit/LeftPane/ScoreLabel
@onready var timer_label       : Label         = $RootSplit/LeftPane/TimerLabel
@onready var back_button       : Button        = $RootSplit/LeftPane/BackButton
@onready var feedback_label    : Label         = $RootSplit/LeftPane/FeedbackLabel
@onready var last_title_label  : Label         = $RootSplit/LeftPane/LastCardPanel/LastCardVBox/Title
@onready var last_artist_label : Label         = $RootSplit/LeftPane/LastCardPanel/LastCardVBox/Artist
@onready var last_genre_label  : Label         = $RootSplit/LeftPane/LastCardPanel/LastCardVBox/Genre
@onready var last_risk_label   : Label         = $RootSplit/LeftPane/LastCardPanel/LastCardVBox/Risk
@onready var last_score_label  : Label         = $RootSplit/LeftPane/LastCardPanel/LastCardVBox/ScoreBreakdown
@onready var card_display_area : GridContainer = $RootSplit/RightPane/HandPanel/HandVBox/HandScroll/CardDisplayArea
@onready var audience_row      : HBoxContainer = $RootSplit/RightPane/AudienceRow
 
const SONG_CARD_SCENE   = preload("res://scenes/song_card.tscn")
const MAX_SONGS_IN_SET  := 5
const CARDS_PER_TURN    := 5
const TARGET_CARD_WIDTH := 176.0
 
var playable_song_pool  : Array = []
var set_history         : Array = []
var cards_on_display    : Array = []
var current_turn_count  : int   = 0
 
# Set by GameManager before update_venue_ui() is called
var current_venue_genre  : String     = "Unknown"
var current_venue_genres : Array      = []
var current_venue_data   : Dictionary = {}
 
# ════════════════════════════════════════════════════════════════════════════
 
func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	resized.connect(_on_resized)
	_on_resized()
 
	if GameManager and not GameManager.score_updated.is_connected(_on_score_updated):
		GameManager.score_updated.connect(_on_score_updated)
 
	_reset_last_card_panel()
 
func _on_resized() -> void:
	var w : int = max(size.x * 0.55 - 50.0, TARGET_CARD_WIDTH)
	card_display_area.columns = max(2, int(floor(w / TARGET_CARD_WIDTH)))
 
# ════════════════════════════════════════════════════════════════════════════
# Public API called by GameManager
# ════════════════════════════════════════════════════════════════════════════
 
func update_venue_ui() -> void:
	if current_venue_genres.is_empty() and current_venue_genre != "":
		current_venue_genres = [current_venue_genre]
	venue_name_label.text  = current_venue_data.get("name",  "Tonight's Venue")
	venue_genre_label.text = "Genres: %s" % "/".join(current_venue_genres)
 
func initialize_deck_from_inventory(inventory: Array) -> void:
	playable_song_pool  = inventory.duplicate(true)
	playable_song_pool.shuffle()
	set_history.clear()
	cards_on_display.clear()
	current_turn_count = 0
	draw_next_hand()
 
func draw_next_hand() -> void:
	# Remove cards no longer in the display list (already played)
	for child in card_display_area.get_children():
		if child not in cards_on_display:
			child.queue_free()
 
	if playable_song_pool.is_empty():
		return
 
	while cards_on_display.size() < CARDS_PER_TURN and not playable_song_pool.is_empty():
		var song_data :Dictionary = playable_song_pool.pop_front()
		var card := SONG_CARD_SCENE.instantiate()
		card_display_area.add_child(card)
		card.setup_card(song_data, {"context": "performance"})
		card.song_selected.connect(_on_song_selected)
		cards_on_display.append(card)
 
	feedback_label.text = "Choose your next track (%d/%d played)." % [current_turn_count, MAX_SONGS_IN_SET]
 
func show_play_result(song_data: Dictionary, score_results: Dictionary, played_count: int, songs_in_set: int) -> void:
	feedback_label.text = "Played %s (+%d pts).  (%d/%d)" % [
		song_data.get("title", "Unknown"),
		score_results.get("points", 0),
		played_count, songs_in_set
	]
	_set_last_card_panel(song_data, score_results)
 
func update_timer_display(seconds_left: int) -> void:
	timer_label.text = "Time Left: %d" % max(0, seconds_left)
 
# ════════════════════════════════════════════════════════════════════════════
# Internal
# ════════════════════════════════════════════════════════════════════════════
 
func _on_song_selected(card_instance, data: Dictionary) -> void:
	current_turn_count += 1
	set_history.append(data)
	cards_on_display.erase(card_instance)
	card_instance.queue_free()
	song_chosen_for_set.emit(card_instance, data)
 
func _on_score_updated(new_score: int) -> void:
	score_label.text = "Score: %d" % new_score
 
func _on_back_pressed() -> void:
	go_to_world_pressed.emit()
 
func _set_last_card_panel(song_data: Dictionary, score_results: Dictionary) -> void:
	last_title_label.text  = song_data.get("title",  "Unknown")
	last_artist_label.text = song_data.get("artist", "Unknown")
	last_genre_label.text  = "Genre: %s" % song_data.get("genre", "Unknown")
	last_risk_label.text   = _risk_label(song_data.get("risk", "Low"))
	last_score_label.text  = "Energy:%+d  Genre:%+d  Risk:%+d  Flow:%+d" % [
		score_results.get("energy_score", 0),
		score_results.get("genre_score",  0),
		score_results.get("risk_score",   0),
		score_results.get("flow_bonus",   0)
	]
 
func _reset_last_card_panel() -> void:
	last_title_label.text  = "—"
	last_artist_label.text = "—"
	last_genre_label.text  = "Genre: —"
	last_risk_label.text   = "LOW RISK"
	last_score_label.text  = "Score: waiting for first play"
 
func _risk_label(risk: String) -> String:
	match risk:
		"High":   return "HIGH RISK"
		"Medium": return "MEDIUM RISK"
		_:        return "LOW RISK"
