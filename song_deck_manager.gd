
extends Control

signal song_chosen_for_set(card_instance, song_data)
signal card_moved_to_set(card_instance, song_data)


	  
@onready var card_display_area = $VBoxContainer/Panel/CardDisplayArea
@onready var feedback_label = $VBoxContainer/LastPlayedInfoLabel  
@onready var venue_genre_label= $VBoxContainer/TopBar/VenueGenreLabel
@onready var score_label= $VBoxContainer/TopBar/ScoreLabel
@onready var genre_indicator=$VBoxContainer/GenreIndicator

const SONG_CARD_SCENE = preload("res://scenes/song_card.tscn")
const MAX_SONGS_IN_SET = 5
const CARDS_SHOWN_PER_TURN = 5
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
var flash_t:= 0.0

func _ready():
	if GameManager and not GameManager.score_updated.is_connected(_on_score_updated):
		GameManager.score_updated.connect(_on_score_updated)
	update_venue_ui()

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
		feedback_label.text = "Set Complete!"
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

func _on_score_updated(new_score: int):
	if score_label:
		score_label.text = "Score: %d" % new_score
