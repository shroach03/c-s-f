extends Control

signal song_chosen_for_set(card_instance, song_data)
signal card_moved_to_set(card_instance, song_data)

@onready var card_display_area = $Shell/VBoxContainer/PlayArea/Panel/HandVBox/HandScroll/CardDisplayArea
@onready var feedback_label = $Shell/VBoxContainer/LastPlayedInfoLabel
@onready var venue_genre_label = $Shell/VBoxContainer/TopBar/VenueGenreLabel
@onready var score_label = $Shell/VBoxContainer/TopBar/ScoreLabel
@onready var genre_indicator = $Shell/VBoxContainer/GenreIndicator
@onready var last_title_label = $Shell/VBoxContainer/PlayArea/LastCardPanel/LastCardVBox/Title
@onready var last_artist_label = $Shell/VBoxContainer/PlayArea/LastCardPanel/LastCardVBox/Artist
@onready var last_genre_label = $Shell/VBoxContainer/PlayArea/LastCardPanel/LastCardVBox/Genre
@onready var last_risk_label = $Shell/VBoxContainer/PlayArea/LastCardPanel/LastCardVBox/Risk
@onready var last_energy_label = $Shell/VBoxContainer/PlayArea/LastCardPanel/LastCardVBox/Energy
@onready var last_score_label = $Shell/VBoxContainer/PlayArea/LastCardPanel/LastCardVBox/ScoreBreakdown

const SONG_CARD_SCENE = preload("res://scenes/song_card.tscn")
const MAX_SONGS_IN_SET = 5
const CARDS_SHOWN_PER_TURN = 5
const TARGET_CARD_WIDTH := 176.0
const GENRE_COLORS = {
	"Euro": Color(0.0, 0.8, 0.8, 0.6),
	"RnB": Color(0.0, 0.0, 0.6, 0.6),
	"Pop": Color(1.0, 0.5, 0.8, 0.6),
	"Hiphop": Color(1.0, 0.0, 0.0, 0.6),
	"EDM": Color(0.5, 1.0, 0.0, 0.6)
}

var playable_song_pool: Array = []
var set_history: Array = []
var cards_on_display: Array = []
var current_turn_count: int = 0
var current_venue_genre: String = "Unknown"
var current_venue_genres: Array = []
var flash_t := 0.0

func _ready():
	if GameManager and not GameManager.score_updated.is_connected(_on_score_updated):
		GameManager.score_updated.connect(_on_score_updated)
	if not resized.is_connected(_update_grid_columns):
		resized.connect(_update_grid_columns)
	_update_grid_columns()
	update_venue_ui()
	_reset_last_card_panel()

func _process(delta: float) -> void:
	flash_t += delta * 6.0
	if current_venue_genres.is_empty():
		return
	var blend = 0.5 + 0.5 * sin(flash_t)
	var base = GENRE_COLORS.get(current_venue_genres[0], Color.WHITE)
	if current_venue_genres.size() > 1:
		var secondary = GENRE_COLORS.get(current_venue_genres[1], Color.WHITE)
		genre_indicator.color = base.lerp(secondary, blend)
	else:
		genre_indicator.color = base.darkened((1.0 - blend) * 0.25)

func _update_grid_columns() -> void:
	var available_width = max(size.x * 0.62 - 80.0, TARGET_CARD_WIDTH)
	card_display_area.columns = max(2, int(floor(available_width / TARGET_CARD_WIDTH)))

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
		new_card.setup_card(song_data, {"context": "performance"})
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
	draw_next_hand()

func _on_song_selected(card_instance, data: Dictionary):
	current_turn_count += 1
	set_history.append(data)
	song_chosen_for_set.emit(card_instance, data)
	cards_on_display.erase(card_instance)
	card_instance.queue_free()
	emit_signal("card_moved_to_set", card_instance, data)

	if current_turn_count >= MAX_SONGS_IN_SET:
		for card in cards_on_display:
			card.queue_free()
		cards_on_display.clear()
	else:
		draw_next_hand()

func update_venue_ui():
	if current_venue_genres.is_empty() and current_venue_genre != "":
		current_venue_genres = [current_venue_genre]
	if venue_genre_label:
		venue_genre_label.text = "Genre Preference: %s" % "/".join(current_venue_genres)

func show_play_result(song_data: Dictionary, score_results: Dictionary, played_count: int, songs_in_set: int):
	feedback_label.text = "Played %s (+%d). (%d/%d played)" % [song_data.get("title", "Unknown"), score_results.points, played_count, songs_in_set]
	_set_last_card_panel(song_data, score_results)
	update_venue_ui()

func _set_last_card_panel(song_data: Dictionary, score_results: Dictionary):
	last_title_label.text = "Title: %s" % song_data.get("title", "Unknown")
	last_artist_label.text = "Artist: %s" % song_data.get("artist", "Unknown")
	last_genre_label.text = "Genre: %s" % song_data.get("genre", "Unknown")
	last_risk_label.text = "Risk: %s" % song_data.get("risk", "Low")
	last_energy_label.text = "Energy: %d/5" % song_data.get("energy", 0)
	last_score_label.text = "Δ %s = E:%+d G:%+d R:%+d F:%+d" % [
		str(score_results.points),
		score_results.energy_score,
		score_results.genre_score,
		score_results.risk_score,
		score_results.flow_bonus
	]

func _reset_last_card_panel():
	last_title_label.text = "Title: —"
	last_artist_label.text = "Artist: —"
	last_genre_label.text = "Genre: —"
	last_risk_label.text = "Risk: —"
	last_energy_label.text = "Energy: —"
	last_score_label.text = "Δ Score: waiting for first play"

func _on_score_updated(new_score: int):
	if score_label:
		score_label.text = "Score: %d" % new_score
