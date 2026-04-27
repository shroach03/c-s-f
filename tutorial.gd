extends Control

signal song_chosen_for_set(card_instance, song_data)

const SONG_CARD_SCENE = preload("res://scenes/song_card.tscn")
const CARDS_SHOWN_PER_TURN = 5
const TARGET_CARD_WIDTH := 176.0
const TUTORIAL_TRACKS_BY_GENRE := {
	"Pop": [
		"Fate of Ophelia",
		"Tit for Tat",
		"Good Luck, Babe!",
		"Stateside",
		"Fame is A Gun",
	],
	"Euro": [
		"Better Off Alone",
		"Stereo Love",
		"Sandstorm",
		"Mr. Saxobeat",
		"We Like to Party!",
	],
	"RnB": [
		"Redbone",
		"Doo Wop (That Thing)",
		"No Scrubs",
		"Party",
		"Work It",
	],
	"Hiphop": [
		"Hypnotize",
		"1,2,3,4 (Sumpin' New)",
		"Still D.R.E",
		"Mama Said Knock You Out",
		"POWER",
	],
	"EDM": [
		"The Days",
		"Latch",
		"Victory Lap",
		"Where You Are",
		"Midnight City",
	],
}
const TUTORIAL_COACHING := [
	{"good": "Good opener. Match the room and keep it easy first.", "bad": "Too messy. Start lower and stay in genre."},
	{"good": "Nice. That step up works.", "bad": "Bit rough. Do not jump energy too fast."},
	{"good": "Solid middle. Keep it steady.", "bad": "That breaks the flow. Smooth it out."},
	{"good": "Nice push. Now you can go bigger.", "bad": "Too soon for that jump."},
	{"good": "Strong finish. That is the idea.", "bad": "Close, but the closer missed."},
]

@onready var card_display_area: HBoxContainer = $Background/ScrollContainer/RecordDisplay
@onready var feedback_label: Label = $Background/LastPlayedInfoLabel
@onready var venue_name_label: Label = $Background/TitleBlock/VenueNameLabel
@onready var venue_genre_label: Label = $Background/TitleBlock/VenueGenreLabel
@onready var venue_attribute_label: Label = $Background/TitleBlock/VenueAttributeLabel
@onready var score_label: Label = $Background/TopBar/ScoreLabel
@onready var timer_label: Label = $Background/TopBar/TimerLabel
@onready var back_button: Button = $Background/TopBar/BackToWorld
@onready var left_button: Button = $Background/LeftButton
@onready var right_button: Button = $Background/RightButton
@onready var scroll_container: ScrollContainer = $Background/ScrollContainer
@onready var left_spacer: Control = $Background/ScrollContainer/RecordDisplay/LeftSpacer
@onready var right_spacer: Control = $Background/ScrollContainer/RecordDisplay/RightSpacer
@onready var dj_cat: AnimatedSprite2D = $Background/DJCat
@onready var last_title_label: Label = $Background/Title
@onready var last_artist_label: Label = $Background/Artist
@onready var last_genre_label: Label = $Background/Genre
@onready var last_risk_label: Label = $Background/Risk
@onready var last_energy_label: Label = $Background/Energy

var playable_song_pool: Array = []
var cards_on_display: Array = []
var current_index := 0
var record_width := 0.0
var tutorial_score: int = 0
var tutorial_last_energy: int = -1
var tutorial_picks: int = 0
var tutorial_complete: bool = false
var tutorial_prompt_visible: bool = true
var current_venue_genre: String = "Pop"
var tutorial_step_index: int = 0

const TUTORIAL_STEPS := [
	{
		"title": "Welcome to the tutorial!",
		"body": "You are building a five-song set. Pick tracks that fit the room and build the energy smoothly.",
		"panel_position": Vector2(290, 70),
		"panel_size": Vector2(500, 180),
	},
	{
		"title": "These are the song cards.",
		"body": "The outer border shows genre. The bars at the bottom show energy. The sticker in the corner shows risk.",
		"panel_position": Vector2(60, 70),
		"panel_size": Vector2(430, 180),
		"callout_text": "These are your song cards.",
		"callout_position": Vector2(90, 235),
	},
	{
		"title": "What you are trying to do.",
		"body": "Match the venue genre, avoid big energy jumps, and use high-risk songs when the crowd is ready. Risk multiplies the score swing, good or bad.",
		"panel_position": Vector2(60, 120),
		"panel_size": Vector2(430, 200),
		"callout_text": "Smooth energy steps and genre matches usually score better.",
		"callout_position": Vector2(70, 485),
	},
	{
		"title": "This is the Last Played panel.",
		"body": "It shows your current or last song. Green means a good choice. Red means the genre or energy move was off.",
		"panel_position": Vector2(560, 185),
		"panel_size": Vector2(430, 190),
		"callout_text": "This updates after every pick.",
		"callout_position": Vector2(610, 390),
	},
]

func _ready() -> void:
	if back_button and not back_button.pressed.is_connected(_on_back_to_world_pressed):
		back_button.pressed.connect(_on_back_to_world_pressed)
	if left_button and not left_button.pressed.is_connected(_on_left_button_pressed):
		left_button.pressed.connect(_on_left_button_pressed)
	if right_button and not right_button.pressed.is_connected(_on_right_button_pressed):
		right_button.pressed.connect(_on_right_button_pressed)
	if not resized.is_connected(_update_carousel_layout):
		resized.connect(_update_carousel_layout)

	timer_label.visible = false
	venue_name_label.text = "Tutorial Set"
	venue_attribute_label.text = "Match the room. Build energy. Save the big one for last."
	back_button.text = "Exit Tutorial"
	_reset_last_card_panel()
	_start_tutorial_run()
	_update_carousel_layout()
	_update_nav_buttons()
	_start_dj_cat_animation()
	_show_intro_prompt()

func _start_tutorial_run() -> void:
	tutorial_score = 0
	tutorial_last_energy = -1
	tutorial_picks = 0
	tutorial_complete = false
	score_label.text = "Score: 0"
	current_venue_genre = _pick_tutorial_genre()
	venue_genre_label.text = "Genre: %s" % current_venue_genre
	feedback_label.text = "Pick a track."
	initialize_deck(_build_tutorial_deck(current_venue_genre))

func _pick_tutorial_genre() -> String:
	var genres: Array = TUTORIAL_TRACKS_BY_GENRE.keys()
	return str(genres[randi() % genres.size()])

func _build_tutorial_deck(genre: String) -> Array:
	var deck: Array = []
	for song_title in TUTORIAL_TRACKS_BY_GENRE.get(genre, []):
		var song_data := _find_song_by_title(song_title)
		if not song_data.is_empty():
			deck.append(song_data)
	if deck.size() >= CARDS_SHOWN_PER_TURN:
		return deck
	return _fallback_tutorial_deck(genre)

func _find_song_by_title(song_title: String) -> Dictionary:
	if SongDatabase == null:
		return {}
	for song in SongDatabase.SONGS:
		if song.get("title", "") == song_title:
			return song.duplicate(true)
	return {}

func _fallback_tutorial_deck(genre: String) -> Array:
	var matches: Array = []
	if SongDatabase == null:
		return matches
	for song in SongDatabase.SONGS:
		if song.get("genre", "") == genre:
			matches.append(song.duplicate(true))
	matches.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.get("energy", 0)) < int(b.get("energy", 0)))
	return matches.slice(0, min(CARDS_SHOWN_PER_TURN, matches.size()))

func initialize_deck(inventory: Array) -> void:
	playable_song_pool.clear()
	for card in cards_on_display:
		if is_instance_valid(card):
			card.queue_free()
	cards_on_display.clear()

	playable_song_pool = inventory.duplicate(true)
	draw_next_hand()

func draw_next_hand() -> void:
	for card in cards_on_display:
		if not is_instance_valid(card):
			continue
		if card.get_parent() != card_display_area:
			card_display_area.add_child(card)
			card_display_area.move_child(card, right_spacer.get_index())

	while cards_on_display.size() < CARDS_SHOWN_PER_TURN and not playable_song_pool.is_empty():
		var song_data = playable_song_pool.pop_front()
		var new_card = SONG_CARD_SCENE.instantiate()
		card_display_area.add_child(new_card)
		card_display_area.move_child(new_card, right_spacer.get_index())
		new_card.setup_card(song_data, {"context": "performance"})
		if not new_card.song_selected.is_connected(_on_song_selected):
			new_card.song_selected.connect(_on_song_selected)
		cards_on_display.append(new_card)

	_set_index(clampi(current_index, 0, maxi(_card_count() - 1, 0)))

func _on_song_selected(card_instance, data: Dictionary) -> void:
	if tutorial_complete:
		return
	if tutorial_prompt_visible:
		return

	tutorial_picks += 1
	song_chosen_for_set.emit(card_instance, data)
	cards_on_display.erase(card_instance)
	if is_instance_valid(card_instance):
		card_instance.queue_free()

	var results := _score_tutorial_song(data)
	tutorial_score += int(results.get("points", 0))
	tutorial_last_energy = int(data.get("energy", 0))
	score_label.text = "Score: %d" % tutorial_score
	_set_last_card_panel(data, results)
	_show_tutorial_feedback(data, results)
	_set_index(clampi(current_index, 0, maxi(_card_count() - 1, 0)))
	_update_nav_buttons()

	if tutorial_picks >= CARDS_SHOWN_PER_TURN:
		_finish_tutorial()

func _score_tutorial_song(song_data: Dictionary) -> Dictionary:
	var song_genre := str(song_data.get("genre", ""))
	var energy := int(song_data.get("energy", 0))
	var risk := str(song_data.get("risk", "Low"))
	var genre_match := song_genre.to_lower() == current_venue_genre.to_lower()
	var energy_ok := tutorial_last_energy < 0 or abs(energy - tutorial_last_energy) <= 1
	var energy_score := 1 if energy_ok else -1
	var genre_score := 1 if genre_match else -1
	var points := int(round((energy_score * 10.0 + genre_score * 15.0) * _tutorial_risk_multiplier(risk)))
	return {
		"points": points,
		"genre_match": genre_match,
		"energy_correct": energy_ok,
	}

func _tutorial_risk_multiplier(risk: String) -> float:
	match risk:
		"Low":
			return 1.0
		"Medium":
			return 1.8
		"High":
			return 2.8
	return 1.0

func _show_tutorial_feedback(song_data: Dictionary, results: Dictionary) -> void:
	var coaching_index := clampi(tutorial_picks - 1, 0, TUTORIAL_COACHING.size() - 1)
	var good_pick := bool(results.get("genre_match", false)) and bool(results.get("energy_correct", false))
	var coaching_set: Dictionary = TUTORIAL_COACHING[coaching_index]
	var sign := "+" if int(results.get("points", 0)) >= 0 else ""
	feedback_label.text = "%s %s%d pts with %s." % [
		coaching_set.get("good" if good_pick else "bad", ""),
		sign,
		int(results.get("points", 0)),
		song_data.get("title", "that song")
	]
	feedback_label.add_theme_color_override(
		"font_color",
		Color(0.3, 1.0, 0.45) if int(results.get("points", 0)) >= 0 else Color(1.0, 0.4, 0.4)
	)

func _finish_tutorial() -> void:
	tutorial_complete = true
	var success := tutorial_score > 0
	feedback_label.text = "Tutorial done. %s Final score: %d." % [
		"That run works." if success else "Try smoother picks next time.",
		tutorial_score
	]
	feedback_label.add_theme_color_override(
		"font_color",
		Color(0.3, 1.0, 0.45) if success else Color(1.0, 0.4, 0.4)
	)

func _set_last_card_panel(song_data: Dictionary, score_results: Dictionary = {}) -> void:
	last_title_label.text = "Title: %s" % song_data.get("title", "Unknown")
	last_artist_label.text = "Artist: %s" % song_data.get("artist", "Unknown")
	last_genre_label.text = "Genre: %s" % song_data.get("genre", "Unknown")
	last_risk_label.text = "Risk: %s" % song_data.get("risk", "Low")
	last_energy_label.text = "Energy: %d/5" % int(song_data.get("energy", 0))

	var good := Color(0.3, 1.0, 0.45)
	var bad := Color(1.0, 0.35, 0.35)
	last_genre_label.add_theme_color_override("font_color", good if bool(score_results.get("genre_match", true)) else bad)
	last_energy_label.add_theme_color_override("font_color", good if bool(score_results.get("energy_correct", true)) else bad)

func _reset_last_card_panel() -> void:
	last_title_label.text = "Title: -"
	last_artist_label.text = "Artist: -"
	last_genre_label.text = "Genre: -"
	last_risk_label.text = "Risk: -"
	last_energy_label.text = "Energy: -"
	for lbl in [last_title_label, last_artist_label, last_genre_label, last_risk_label, last_energy_label]:
		lbl.remove_theme_color_override("font_color")

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
	left_button.disabled = tutorial_prompt_visible or (not has_cards) or current_index <= 0
	right_button.disabled = tutorial_prompt_visible or (not has_cards) or current_index >= _card_count() - 1

func _on_back_to_world_pressed() -> void:
	if GameManager != null:
		GameManager.return_to_world()

func _start_dj_cat_animation() -> void:
	if is_instance_valid(dj_cat):
		dj_cat.visible = true
		dj_cat.play("tail_wag")

func _show_intro_prompt() -> void:
	tutorial_step_index = 0
	var overlay := ColorRect.new()
	overlay.name = "IntroOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.68)
	add_child(overlay)
	_render_tutorial_step()

func _render_tutorial_step() -> void:
	var overlay := get_node_or_null("IntroOverlay")
	if overlay == null:
		return
	for child in overlay.get_children():
		child.queue_free()

	var step: Dictionary = TUTORIAL_STEPS[tutorial_step_index]

	var panel := PanelContainer.new()
	panel.name = "IntroPanel"
	panel.custom_minimum_size = step.get("panel_size", Vector2(420, 180))
	panel.position = step.get("panel_position", Vector2(280, 90))
	overlay.add_child(panel)

	var panel_vbox := VBoxContainer.new()
	panel_vbox.add_theme_constant_override("separation", 12)
	panel_vbox.offset_left = 16
	panel_vbox.offset_top = 16
	panel_vbox.offset_right = 16
	panel_vbox.offset_bottom = 16
	panel.add_child(panel_vbox)

	var title := Label.new()
	title.text = str(step.get("title", "Tutorial"))
	title.add_theme_font_size_override("font_size", 22)
	panel_vbox.add_child(title)

	var body := Label.new()
	body.text = str(step.get("body", ""))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(360, 90)
	panel_vbox.add_child(body)

	var next_button := Button.new()
	next_button.text = "Next" if tutorial_step_index < TUTORIAL_STEPS.size() - 1 else "Start Tutorial"
	next_button.custom_minimum_size = Vector2(150, 38)
	next_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	next_button.pressed.connect(_advance_tutorial_step)
	panel_vbox.add_child(next_button)

	if step.has("callout_text"):
		var callout := Label.new()
		callout.text = str(step.get("callout_text", ""))
		callout.position = step.get("callout_position", Vector2.ZERO)
		callout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		callout.custom_minimum_size = Vector2(280, 40)
		overlay.add_child(callout)

func _advance_tutorial_step() -> void:
	tutorial_step_index += 1
	if tutorial_step_index >= TUTORIAL_STEPS.size():
		_dismiss_intro_prompt()
		return
	_render_tutorial_step()

func _dismiss_intro_prompt() -> void:
	tutorial_prompt_visible = false
	var overlay := get_node_or_null("IntroOverlay")
	if overlay:
		overlay.queue_free()
	_update_nav_buttons()
