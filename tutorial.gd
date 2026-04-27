extends "res://scripts/song_deck_manager.gd"

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
	{
		"good": "Good opener. Match the room and keep it easy first.",
		"bad": "Too messy. Start lower and stay in genre.",
	},
	{
		"good": "Nice. That step up works.",
		"bad": "Bit rough. Do not jump energy too fast.",
	},
	{
		"good": "Solid middle. Keep it steady.",
		"bad": "That breaks the flow. Smooth it out.",
	},
	{
		"good": "Nice push. Now you can go bigger.",
		"bad": "Too soon for that jump.",
	},
	{
		"good": "Strong finish. That is the idea.",
		"bad": "Close, but the closer missed.",
	},
]

var tutorial_score: int = 0
var tutorial_last_energy: int = -1
var tutorial_picks: int = 0
var tutorial_complete: bool = false

@onready var venue_name_label: Label = $Background/TitleBlock/VenueNameLabel
@onready var venue_attribute_label: Label = $Background/TitleBlock/VenueAttributeLabel

func _ready() -> void:
	super._ready()
	_hide_tutorial_cats()
	_setup_tutorial_scene()
	_build_tutorial_run()

func _setup_tutorial_scene() -> void:
	back_button.text = "Exit Tutorial"
	timer_label.visible = false
	venue_name_label.text = "Tutorial Set"
	venue_attribute_label.text = "Match the room. Build energy. Save the big one for last."
	score_label.text = "Score: 0"
	feedback_label.text = "Pick a track."
	_reset_last_card_panel()

func _build_tutorial_run() -> void:
	tutorial_score = 0
	tutorial_last_energy = -1
	tutorial_picks = 0
	tutorial_complete = false
	current_energy = 2
	current_venue_genre = _pick_tutorial_genre()
	current_venue_genres = [current_venue_genre]
	update_venue_ui()
	initialize_deck_from_inventory(_build_tutorial_deck(current_venue_genre))
	feedback_label.text = "Pick a track."

func _pick_tutorial_genre() -> String:
	var genres := TUTORIAL_TRACKS_BY_GENRE.keys()
	return genres[randi() % genres.size()]

func _build_tutorial_deck(genre: String) -> Array:
	var deck: Array = []
	var wanted_titles: Array = TUTORIAL_TRACKS_BY_GENRE.get(genre, [])
	for song_title in wanted_titles:
		var song_data := _find_song_by_title(song_title)
		if not song_data.is_empty():
			deck.append(song_data)
	if deck.size() >= GameManager.SONGS_IN_SET:
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
	matches.sort_custom(func(a: Dictionary, b: Dictionary): return a.get("energy", 0) < b.get("energy", 0))
	return matches.slice(0, min(GameManager.SONGS_IN_SET, matches.size()))

func _hide_tutorial_cats() -> void:
	for cat in cat_audience:
		if is_instance_valid(cat):
			cat.visible = false
	var dj_cat := get_node_or_null("Background/DJCat")
	if dj_cat:
		dj_cat.visible = false

func _on_song_selected(card_instance, data: Dictionary) -> void:
	if tutorial_complete:
		return

	current_turn_count += 1
	tutorial_picks += 1
	set_history.append(data)
	song_chosen_for_set.emit(card_instance, data)
	cards_on_display.erase(card_instance)
	if is_instance_valid(card_instance):
		card_instance.queue_free()
	card_moved_to_set.emit(card_instance, data)

	var results := _score_tutorial_song(data)
	tutorial_score += results.points
	tutorial_last_energy = data.get("energy", 0)
	current_energy = data.get("energy", 2)
	score_label.text = "Score: %d" % tutorial_score
	_set_last_card_panel(data, {
		"genre_match": results.genre_match,
		"energy_correct": results.energy_ok,
	})
	_show_tutorial_feedback(data, results)
	play_song_audio(data.get("genre", ""), data.get("energy", 2))

	_set_index(clampi(current_index, 0, maxi(_card_count() - 1, 0)))

	if tutorial_picks >= GameManager.SONGS_IN_SET:
		_finish_tutorial()

func _score_tutorial_song(song_data: Dictionary) -> Dictionary:
	var song_genre :String= song_data.get("genre", "")
	var energy :int= song_data.get("energy", 0)
	var risk :String= song_data.get("risk", "Low")
	var genre_match := song_genre.to_lower() == current_venue_genre.to_lower()
	var energy_ok :int= tutorial_last_energy < 0 or abs(energy - tutorial_last_energy) <= 1
	var energy_score := 1 if energy_ok else -1
	var genre_score := 1 if genre_match else -1
	var points := int(round((energy_score * 10.0 + genre_score * 15.0) * _tutorial_risk_multiplier(risk)))
	return {
		"points": points,
		"genre_match": genre_match,
		"energy_ok": energy_ok,
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
	var good_pick :int= results.genre_match and results.energy_ok
	var coaching_set: Dictionary = TUTORIAL_COACHING[coaching_index]
	var sign := "+" if results.points >= 0 else ""
	feedback_label.text = "%s %s%d pts with %s." % [
		coaching_set.get("good" if good_pick else "bad", ""),
		sign,
		results.points,
		song_data.get("title", "that song")
	]
	feedback_label.add_theme_color_override(
		"font_color",
		Color(0.3, 1.0, 0.45) if results.points >= 0 else Color(1.0, 0.4, 0.4)
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
