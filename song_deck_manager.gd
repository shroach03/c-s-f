extends Control

signal song_chosen_for_set(card_instance, song_data)
signal card_moved_to_set(card_instance, song_data)

@onready var backdrop_color: ColorRect = $BackdropColor
@onready var venue_name_label: Label = $Shell/RootSplit/LeftPane/VenueNameLabel
@onready var venue_genre_label: Label = $Shell/RootSplit/LeftPane/VenueGenreLabel
@onready var venue_attribute_label: Label = $Shell/RootSplit/LeftPane/VenueAttributeLabel
@onready var card_display_area: GridContainer = $Shell/RootSplit/RightPane/HandPanel/HandVBox/HandScroll/CardDisplayArea
@onready var feedback_label: Label = $Shell/RootSplit/LeftPane/LastPlayedInfoLabel
@onready var score_label: Label = $Shell/RootSplit/LeftPane/ScoreLabel
@onready var timer_label: Label = $Shell/RootSplit/LeftPane/TimerLabel
@onready var back_button: Button = $Shell/RootSplit/LeftPane/BackButton
@onready var last_title_label: Label = $Shell/RootSplit/LeftPane/LastCardPanel/LastCardVBox/Title
@onready var last_artist_label: Label = $Shell/RootSplit/LeftPane/LastCardPanel/LastCardVBox/Artist
@onready var last_genre_label: Label = $Shell/RootSplit/LeftPane/LastCardPanel/LastCardVBox/Genre
@onready var last_risk_label: Label = $Shell/RootSplit/LeftPane/LastCardPanel/LastCardVBox/Risk
@onready var last_energy_label: Label = $Shell/RootSplit/LeftPane/LastCardPanel/LastCardVBox/Energy
@onready var last_score_label: Label = $Shell/RootSplit/LeftPane/LastCardPanel/LastCardVBox/ScoreBreakdown

const SONG_CARD_SCENE = preload("res://scenes/song_card.tscn")
const CAT_TEXTURE = preload("res://assets/sprites/nyan_alley_cat.png")
const MAX_SONGS_IN_SET := 5
const CARDS_SHOWN_PER_TURN := 5
const TARGET_CARD_WIDTH := 176.0

var playable_song_pool: Array = []
var set_history: Array = []
var cards_on_display: Array = []
var current_turn_count: int = 0
var current_venue_genre: String = "Unknown"
var current_venue_genres: Array = []
var current_venue_data: Dictionary = {}

func _ready() -> void:
	if GameManager and not GameManager.score_updated.is_connected(_on_score_updated):
		GameManager.score_updated.connect(_on_score_updated)
	if back_button and not back_button.pressed.is_connected(_on_back_to_world_pressed):
		back_button.pressed.connect(_on_back_to_world_pressed)
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)
	_on_resized()
	update_venue_ui()
	_reset_last_card_panel()

func _on_resized() -> void:
	var available_width = max(size.x * 0.45 - 50.0, TARGET_CARD_WIDTH)
	card_display_area.columns = max(2, int(floor(available_width / TARGET_CARD_WIDTH)))

func draw_next_hand() -> void:
	for child in card_display_area.get_children():
		if not child in cards_on_display:
			child.queue_free()
	if playable_song_pool.is_empty():
		return
	while cards_on_display.size() < CARDS_SHOWN_PER_TURN and not playable_song_pool.is_empty():
		var song_data = playable_song_pool.pop_front()
		var new_card = SONG_CARD_SCENE.instantiate()
		card_display_area.add_child(new_card)
		new_card.setup_card(song_data, {"context": "performance"})
		new_card.song_selected.connect(_on_song_selected)
		cards_on_display.append(new_card)
	feedback_label.text = "Choose your next track (%d/%d played)." % [current_turn_count, MAX_SONGS_IN_SET]

func initialize_deck_from_inventory(inventory: Array) -> void:
	playable_song_pool = inventory.duplicate(true)
	playable_song_pool.shuffle()
	set_history.clear()
	current_turn_count = 0
	cards_on_display.clear()
	draw_next_hand()

func _on_song_selected(card_instance, data: Dictionary) -> void:
	current_turn_count += 1
	set_history.append(data)
	song_chosen_for_set.emit(card_instance, data)
	cards_on_display.erase(card_instance)
	card_instance.queue_free()
	card_moved_to_set.emit(card_instance, data)

	if current_turn_count < MAX_SONGS_IN_SET:
		draw_next_hand()

func update_venue_ui() -> void:
	if current_venue_genres.is_empty() and current_venue_genre != "":
		current_venue_genres = [current_venue_genre]
	venue_name_label.text = current_venue_data.get("name", "Tonight's Venue")
	venue_genre_label.text = "Genres: %s" % "/".join(current_venue_genres)
	venue_attribute_label.text = current_venue_data.get("attribute", "Build momentum before the room cools.")
	backdrop_color.color = current_venue_data.get("backdrop_color", Color(0.03, 0.03, 0.06, 1.0))
func show_play_result(song_data: Dictionary, score_results: Dictionary, played_count: int, songs_in_set: int) -> void:
	feedback_label.text = "Played %s (+%d). (%d/%d played)" % [song_data.get("title", "Unknown"), score_results.points, played_count, songs_in_set]
	_set_last_card_panel(song_data, score_results)

func _set_last_card_panel(song_data: Dictionary, score_results: Dictionary) -> void:
	last_title_label.text = song_data.get("title", "Unknown")
	last_artist_label.text = song_data.get("artist", "Unknown")
	last_genre_label.text = "Genre: %s" % song_data.get("genre", "Unknown")
	last_risk_label.text = _risk_label(song_data.get("risk", "Low"))
	last_energy_label.text = "Energy: %d/5" % song_data.get("energy", 0)
	last_score_label.text = "Energy:%+d Genre:%+d Risk:%+d Flow:%+d" % [score_results.energy_score, score_results.genre_score, score_results.risk_score, score_results.flow_bonus]

func _reset_last_card_panel() -> void:
	last_title_label.text = "—"
	last_artist_label.text = "—"
	last_genre_label.text = "Genre: —"
	last_risk_label.text = "LOW RISK"
	last_energy_label.text = "Energy: —"
	last_score_label.text = "Score: waiting for first play"

func _risk_label(risk: String) -> String:
	match risk:
		"High":
			return "HIGH RISK"
		"Medium":
			return "MEDIUM RISK"
		_:
			return "LOW RISK"

func _on_score_updated(new_score: int) -> void:
	score_label.text = "Score: %d" % new_score

func update_timer_display(seconds_left: int) -> void:
	timer_label.text = "Time Left: %d" % max(0, seconds_left)

func _on_back_to_world_pressed() -> void:
	if GameManager != null:
		GameManager.return_to_world()
