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
@onready var cat_audience: Array[AnimatedSprite2D] = [
	$Background/BlackCat,
	$Background/OrangeCat,
	$Background/GreyCat,
	$Background/BlackCat2,
	$Background/OrangeCat2,
	$Background/GreyCat2,
]
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
@onready var base_player: AudioStreamPlayer = $BasePlayer
@onready var layer1_player: AudioStreamPlayer = $Layer1Player
@onready var layer2_player: AudioStreamPlayer = $Layer2Player
 
const SONG_CARD_SCENE = preload("res://scenes/song_card.tscn")
const CARDS_SHOWN_PER_TURN = 5
const TARGET_CARD_WIDTH := 176.0
const GENRE_COLORS = {
	"euro": Color(0.0, 0.8, 0.8, 0.65),
	"rnb": Color(0.0, 0.2, 0.8, 0.65),
	"pop": Color(1.0, 0.5, 0.8, 0.65),
	"hiphop": Color(0.9, 0.15, 0.2, 0.65),
	"edm": Color(0.45, 1.0, 0.2, 0.65)
}
 
var playable_song_pool: Array = []
var source_song_pool: Array = []
var set_history: Array = []
var cards_on_display: Array = []
var current_energy: int = 2
var current_turn_count: int = 0
var current_venue_genre: String = "Unknown"
var current_venue_genres: Array = []
var flash_t := 0.0
var _cats_are_dancing: bool = false
var _current_song_energy: int = 2   # 1–5
 
var current_index := 0
var record_width := 0.0
var _audio_cache: Dictionary = {}
var _current_soundtrack_genre: String = ""
var _current_soundtrack_energy: int = 0
 
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
	cats_set_idle()
	_configure_audio_players()
 
func _process(delta: float) -> void:
	var speed : float = lerp(0.8, 4.0, (current_energy - 1) / 4.0)
	flash_t += delta * speed
	if current_venue_genres.is_empty():
		_set_genre_lights([Color(1, 1, 1, 0.25)])
		return
 
	var num_genres := current_venue_genres.size()
 
	if num_genres == 1:
		# single genre: pulse alpha only, no switching
		var base := _genre_color(current_venue_genres[0], Color.WHITE)
		var alpha := 0.35 + 0.45 * (0.5 + 0.5 * sin(flash_t))
		var c := Color(base.r, base.g, base.b, alpha)
		_set_genre_lights([c, c.darkened(0.15), c.darkened(0.3)])
	else:
		var color_a := _genre_color(current_venue_genres[0], Color.WHITE)
		var color_b := _genre_color(current_venue_genres[1], Color.WHITE)

		var light_colors: Array[Color] = []
		for i in range(genre_lights.size()):
			var offset := (i / float(genre_lights.size())) * TAU
			var local_blend := 0.5 + 0.5 * sin(flash_t + offset)
			var mixed := color_a.lerp(color_b, local_blend)
			var local_alpha := 0.35 + 0.4 * (0.5 + 0.5 * sin(flash_t + offset))
			light_colors.append(Color(mixed.r, mixed.g, mixed.b, local_alpha))
		_set_genre_lights(light_colors)
func cats_set_idle() -> void:
	_cats_are_dancing = false
	for cat in cat_audience:
		if not is_instance_valid(cat):
			continue
		cat.play("bored")
		cat.speed_scale = 1.0
 
func cats_start_dancing(energy_level: int) -> void:
	_cats_are_dancing = true
	_current_song_energy = clamp(energy_level, 1, 5)
	var speed := _energy_to_animation_speed(_current_song_energy)
	for i in cat_audience.size():
		var cat: AnimatedSprite2D = cat_audience[i]
		if not is_instance_valid(cat):
			continue
		cat.play("hind_legs")
		# Stagger starting frame so cats don't all bob in perfect unison
		cat.frame = (i * 2) % cat.sprite_frames.get_frame_count("hind_legs")
		cat.speed_scale = speed
 
func cats_react_to_score(_score: int) -> void:
	# Score ticking does not affect cat animation — cats dance for the full
	# intermission period and go idle in draw_next_hand when it's time to pick again.
	pass
 
func _set_genre_lights(colors: Array[Color]) -> void:
	for i in range(genre_lights.size()):
		var color = colors[min(i, colors.size() - 1)] if not colors.is_empty() else Color(1, 1, 1, 0.25)
		genre_lights[i].color = color
 
func _genre_color(genre_value: Variant, fallback_color: Color) -> Color:
	var genre_key = str(genre_value).to_lower().replace(" ", "")
	return GENRE_COLORS.get(genre_key, fallback_color)
 
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
	cats_set_idle()
	feedback_label.remove_theme_color_override("font_color")
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
 
	if cards_on_display.is_empty() and playable_song_pool.is_empty():
		feedback_label.text = "Deck empty"
	else:
		feedback_label.text = "Choose your next track (%d played)." % [current_turn_count]
 
	_set_index(clampi(current_index, 0, maxi(_card_count() - 1, 0)))
 
func _energy_to_animation_speed(energy: int) -> float:
	match energy:
		1: return 0.6
		2: return 1.0
		3: return 1.4
		4: return 1.9
		5: return 2.4
	return 1.0
 
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
	play_song_audio(current_venue_genre, 1)
 
func _on_song_selected(card_instance, data: Dictionary) -> void:
	current_turn_count += 1
	set_history.append(data)
	song_chosen_for_set.emit(card_instance, data)
	cards_on_display.erase(card_instance)
	if is_instance_valid(card_instance):
		card_instance.queue_free()
	card_moved_to_set.emit(card_instance, data)
 
	_set_index(clampi(current_index, 0, maxi(_card_count() - 1, 0)))
 
func update_venue_ui() -> void:
	if current_venue_genres.is_empty() and current_venue_genre != "":
		current_venue_genres = [current_venue_genre]
	venue_genre_label.text = "Genres: %s" % "/".join(current_venue_genres)
 
func play_song_audio(genre: String, energy: int) -> void:
	var genre_key := _normalize_genre_key(genre)
	var clamped_energy := clampi(energy, 1, 5)
	var base_stream := _load_loop_stream("base")
	if base_stream == null:
		return

	var layer1_stream: AudioStream = null
	var layer2_stream: AudioStream = null
	if genre_key != "":
		layer1_stream = _load_loop_stream("%s1" % genre_key)
		layer2_stream = _load_loop_stream("%s2" % genre_key)

	var soundtrack_changed := (
		not base_player.playing
		or base_player.stream != base_stream
		or _current_soundtrack_genre != genre_key
	)

	if soundtrack_changed:
		_restart_soundtrack(base_stream, layer1_stream, layer2_stream, clamped_energy)
	else:
		_update_layer_playback(layer1_player, layer1_stream, clamped_energy >= 2)
		_update_layer_playback(layer2_player, layer2_stream, clamped_energy >= 4)

	_current_soundtrack_genre = genre_key
	_current_soundtrack_energy = clamped_energy

 
func stop_song_audio() -> void:
	base_player.stop()
	layer1_player.stop()
	layer2_player.stop()
	_current_soundtrack_genre = ""
	_current_soundtrack_energy = 0

func _configure_audio_players() -> void:
	for player in [base_player, layer1_player, layer2_player]:
		if not is_instance_valid(player):
			continue
		player.bus = &"Master"

func _restart_soundtrack(base_stream: AudioStream, layer1_stream: AudioStream, layer2_stream: AudioStream, energy: int) -> void:
	base_player.stop()
	layer1_player.stop()
	layer2_player.stop()
	base_player.stream = base_stream
	base_player.play(0.0)
	_update_layer_playback(layer1_player, layer1_stream, energy >= 2, 0.0)
	_update_layer_playback(layer2_player, layer2_stream, energy >= 4, 0.0)

func _update_layer_playback(player: AudioStreamPlayer, stream: AudioStream, should_play: bool, start_position: float = -1.0) -> void:
	if not is_instance_valid(player):
		return
	if stream == null or not should_play:
		player.stop()
		player.stream = null
		return

	var sync_position := start_position
	if sync_position < 0.0 and base_player.playing:
		sync_position = base_player.get_playback_position()
	if sync_position < 0.0:
		sync_position = 0.0

	if player.stream != stream:
		player.stop()
		player.stream = stream
		player.play(sync_position)
	elif not player.playing:
		player.play(sync_position)

func _load_loop_stream(loop_name: String) -> AudioStream:
	if _audio_cache.has(loop_name):
		return _audio_cache[loop_name]

	var path := "res://audio/loops/%s.wav" % loop_name
	if not ResourceLoader.exists(path):
		push_warning("SongDeckManager: Missing audio loop: " + path)
		_audio_cache[loop_name] = null
		return null

	var stream := load(path) as AudioStream
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_audio_cache[loop_name] = stream
	return stream

func _normalize_genre_key(genre: String) -> String:
	return genre.strip_edges().to_lower().replace(" ", "")
 
func show_play_result(song_data: Dictionary, score_results: Dictionary, played_count: int) -> void:
	var energy: int = song_data.get("energy", 2)
	var genre: String = song_data.get("genre", "")
	current_energy = energy
	cats_start_dancing(energy)
	var sign_str := "+" if score_results.points >= 0 else ""
	feedback_label.text = "Played %s (%s%d pts). Song %d/%d" % [
		song_data.get("title", "Unknown"),
		sign_str,
		score_results.points,
		played_count,
		GameManager.SONGS_IN_SET
	]
	feedback_label.add_theme_color_override("font_color",
		Color(0.3, 1.0, 0.45) if score_results.points >= 0 else Color(1.0, 0.4, 0.4))
	_set_last_card_panel(song_data, score_results)
	update_venue_ui()
	play_song_audio(genre, energy)
 
func _set_last_card_panel(song_data: Dictionary, score_results: Dictionary = {}) -> void:
	last_title_label.text = "Title: %s" % song_data.get("title", "Unknown")
	last_artist_label.text = "Artist: %s" % song_data.get("artist", "Unknown")
 
	var genre_match: bool = score_results.get("genre_match", true)
	var energy_correct: bool = score_results.get("energy_correct", true)
	var good := Color(0.3, 1.0, 0.45)
	var bad  := Color(1.0, 0.35, 0.35)
	var neutral := Color(1, 1, 1)
 
	last_genre_label.text = "Genre: %s  %s" % [
		song_data.get("genre", "Unknown"),
		"✓" if genre_match else "✗"
	]
	last_genre_label.add_theme_color_override("font_color", good if genre_match else bad)
 
	var energy_val: int = song_data.get("energy", 0)
	last_energy_label.text = "Energy: %d/5  %s" % [
		energy_val,
		"✓" if energy_correct else "✗"
	]
	last_energy_label.add_theme_color_override("font_color", good if energy_correct else bad)
 
	last_risk_label.text = "Risk: %s" % song_data.get("risk", "Low")
	last_risk_label.add_theme_color_override("font_color", neutral)
	last_title_label.add_theme_color_override("font_color", neutral)
	last_artist_label.add_theme_color_override("font_color", neutral)
 
func _reset_last_card_panel() -> void:
	last_title_label.text = "Title: —"
	last_artist_label.text = "Artist: —"
	last_genre_label.text = "Genre: —"
	last_risk_label.text = "Risk: —"
	last_energy_label.text = "Energy: —"
	for lbl in [last_title_label, last_artist_label, last_genre_label, last_risk_label, last_energy_label]:
		lbl.remove_theme_color_override("font_color")
 
func _on_score_updated(new_score: int) -> void:
	score_label.text = "Score: %d" % new_score
	cats_react_to_score(new_score)
func _on_performance_timer_updated(time_remaining: float) -> void:
	var whole_seconds = maxi(int(ceil(time_remaining)), 0)
	var minutes = whole_seconds / 60
	var seconds = whole_seconds % 60
	timer_label.text = "Time: %02d:%02d" % [minutes, seconds]
 
func _on_back_to_world_pressed() -> void:
	stop_song_audio()
	if GameManager != null:
		GameManager.return_to_world()
