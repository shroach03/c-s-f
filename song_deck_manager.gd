extends Control

signal song_chosen_for_set(card_instance, song_data)
signal card_moved_to_set(card_instance, song_data)

@onready var card_display_area: HBoxContainer = $Background/ScrollContainer/RecordDisplay
@onready var feedback_label: Label = $Background/LastPlayedInfoLabel
@onready var venue_genre_label: Label = $Background/TitleBlock/VenueGenreLabel
@onready var score_label: Label = $Background/TopBar/ScoreLabel
@onready var timer_label: Label = $Background/TopBar/TimerLabel
@onready var back_button: Button = $Background/TopBar/BackToWorld
@onready var left_button: Button = $Background/LeftButton
@onready var right_button: Button = $Background/RightButton
@onready var scroll_container: ScrollContainer = $Background/ScrollContainer
@onready var left_spacer: Control = $Background/ScrollContainer/RecordDisplay/LeftSpacer
@onready var right_spacer: Control = $Background/ScrollContainer/RecordDisplay/RightSpacer

@onready var genre_lights := [
	$Background/GenreLight1,
	$Background/GenreLight2,
	$Background/GenreLight3,
]

@onready var last_title_label: Label = $Background/Title
@onready var last_artist_label: Label = $Background/Artist
@onready var last_genre_label: Label = $Background/Genre
@onready var last_risk_label: Label = $Background/Risk
@onready var last_energy_label: Label = $Background/Energy

const SONG_CARD_SCENE = preload("res://scenes/song_card.tscn")
const CARDS_SHOWN_PER_TURN = 5
const TARGET_CARD_WIDTH := 176.0
const GENRE_COLORS = {
	"Euro": Color(0.0, 0.8, 0.8, 0.65),
	"RnB": Color(0.0, 0.2, 0.8, 0.65),
	"Pop": Color(1.0, 0.5, 0.8, 0.65),
	"Hiphop": Color(0.9, 0.15, 0.2, 0.65),
	"EDM": Color(0.45, 1.0, 0.2, 0.65)
}

var playable_song_pool: Array = []
var source_song_pool: Array = []
var set_history: Array = []
var cards_on_display: Array = []
var current_turn_count: int = 0
var current_venue_genre: String = "Unknown"
var current_venue_genres: Array = []
var flash_t := 0.0

var current_index := 0
var record_width := 0.0

func _ready() -> void:
	if GameManager and not GameManager.score_updated.is_connected(_on_score_updated):
		GameManager.score_updated.connect(_on_score_updated)
	if GameManager and not GameManager.performance_timer_updated.is_connected(_on_performance_timer_updated):
		GameManager.performance_timer_updated.connect(_on_performance_timer_updated)
	if back_button and not back_button.pressed.is_connected(_on_back_to_world_pressed):
		back_button.pressed.connect(_on_back_to_world_pressed)
	if left_button and not left_button.pressed.is_connected(_on_left_button_pressed):
		left_button.pressed.connect(_on_left_button_pressed)
	if right_button and not right_button.pressed.is_connected(_on_right_button_pressed):
		right_button.pressed.connect(_on_right_button_pressed)
	if not resized.is_connected(_update_carousel_layout):
		resized.connect(_update_carousel_layout)

	_update_carousel_layout()
	_update_nav_buttons()
	update_venue_ui()
	_reset_last_card_panel()

func _process(delta: float) -> void:
	flash_t += delta * 5.0
	if current_venue_genres.is_empty():
		_set_genre_lights(Color(1, 1, 1, 0.25))
		return

	var blend = 0.5 + 0.5 * sin(flash_t)
	var primary = GENRE_COLORS.get(current_venue_genres[0], Color.WHITE)
	var pulse_color = primary
	if current_venue_genres.size() > 1:
		var secondary = GENRE_COLORS.get(current_venue_genres[1], Color.WHITE)
		pulse_color = primary.lerp(secondary, blend)
	else:
		pulse_color = primary.darkened((1.0 - blend) * 0.2)
	_set_genre_lights(pulse_color)

func _set_genre_lights(color: Color) -> void:
	for light in genre_lights:
		light.color = color

func _update_carousel_layout() -> void:
	var center_padding = maxf((scroll_container.size.x - TARGET_CARD_WIDTH) * 0.5, 0.0)
	left_spacer.custom_minimum_size.x = center_padding
	right_spacer.custom_minimum_size.x = center_padding
	record_width = TARGET_CARD_WIDTH + card_display_area.get_theme_constant("separation")
	_scroll_to_current()

func _card_count() -> int:
	return maxi(card_display_area.get_child_count() - 2, 0)

func _on_left_button_pressed() -> void:
	_set_index(current_index - 1)

func _on_right_button_pressed() -> void:
	_set_index(current_index + 1)

func _set_index(new_index: int) -> void:
	current_index = clampi(new_index, 0, maxi(_card_count() - 1, 0))
	_scroll_to_current()
	_update_nav_buttons()

func _scroll_to_current() -> void:
	var target_x = current_index * record_width
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(scroll_container, "scroll_horizontal", target_x, 0.25)

func _update_nav_buttons() -> void:
	var has_cards = _card_count() > 0
	left_button.disabled = (not has_cards) or current_index <= 0
	right_button.disabled = (not has_cards) or current_index >= _card_count() - 1

func draw_next_hand() -> void:
	for card in cards_on_display:
		if not is_instance_valid(card):
			continue
		if card.get_parent() != card_display_area:
			card_display_area.add_child(card)
			card_display_area.move_child(card, right_spacer.get_index())
	if playable_song_pool.is_empty() and not source_song_pool.is_empty():
		playable_song_pool = source_song_pool.duplicate(true)
		playable_song_pool.shuffle()

	while cards_on_display.size() < CARDS_SHOWN_PER_TURN and not playable_song_pool.is_empty():
		var song_data = playable_song_pool.pop_front()
		var new_card = SONG_CARD_SCENE.instantiate()
		card_display_area.add_child(new_card)
		card_display_area.move_child(new_card, right_spacer.get_index())
		new_card.setup_card(song_data, {"context": "performance"})
		if not new_card.song_selected.is_connected(_on_song_selected):
			new_card.song_selected.connect(_on_song_selected)
		cards_on_display.append(new_card)

	if cards_on_display.is_empty() and playable_song_pool.is_empty():
		feedback_label.text = "Deck empty"
	else:
		feedback_label.text = "Choose your next track (%d played)." % [current_turn_count]

	_set_index(clampi(current_index, 0, maxi(_card_count() - 1, 0)))

func initialize_deck_from_inventory(inventory: Array) -> void:
	playable_song_pool.clear()
	source_song_pool.clear()
	set_history.clear()
	current_turn_count = 0
	current_index = 0

	for card in cards_on_display:
		if is_instance_valid(card):
			card.queue_free()
	cards_on_display.clear()

	source_song_pool = inventory.duplicate(true)
	playable_song_pool = source_song_pool.duplicate(true)
	playable_song_pool.shuffle()
	draw_next_hand()

func _on_song_selected(card_instance, data: Dictionary) -> void:
	current_turn_count += 1
	set_history.append(data)
	song_chosen_for_set.emit(card_instance, data)
	cards_on_display.erase(card_instance)
	if is_instance_valid(card_instance):
		card_instance.queue_free()
	card_moved_to_set.emit(card_instance, data)

	draw_next_hand()

	_set_index(clampi(current_index, 0, maxi(_card_count() - 1, 0)))

func update_venue_ui() -> void:
	if current_venue_genres.is_empty() and current_venue_genre != "":
		current_venue_genres = [current_venue_genre]
	venue_genre_label.text = "Genres: %s" % "/".join(current_venue_genres)

func show_play_result(song_data: Dictionary, score_results: Dictionary, played_count: int) -> void:
	feedback_label.text = "Played %s (%+d trend). (%d played)" % [song_data.get("title", "Unknown"), score_results.points, played_count]
	_set_last_card_panel(song_data)
	update_venue_ui()

func _set_last_card_panel(song_data: Dictionary) -> void:
	last_title_label.text = "Title: %s" % song_data.get("title", "Unknown")
	last_artist_label.text = "Artist: %s" % song_data.get("artist", "Unknown")
	last_genre_label.text = "Genre: %s" % song_data.get("genre", "Unknown")
	last_risk_label.text = "Risk: %s" % song_data.get("risk", "Low")
	last_energy_label.text = "Energy: %d/5" % song_data.get("energy", 0)

func _reset_last_card_panel() -> void:
	last_title_label.text = "Title: —"
	last_artist_label.text = "Artist: —"
	last_genre_label.text = "Genre: —"
	last_risk_label.text = "Risk: —"
	last_energy_label.text = "Energy: —"

func _on_score_updated(new_score: int) -> void:
	score_label.text = "Score: %d" % new_score

func _on_performance_timer_updated(time_remaining: float) -> void:
	var whole_seconds = maxi(int(ceil(time_remaining)), 0)
	var minutes = whole_seconds / 60
	var seconds = whole_seconds % 60
	timer_label.text = "Time: %02d:%02d" % [minutes, seconds]

func _on_back_to_world_pressed() -> void:
	if GameManager != null:
		GameManager.return_to_world()
