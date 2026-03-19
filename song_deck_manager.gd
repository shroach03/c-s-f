extends Control

signal song_chosen_for_set(card_instance, song_data)
signal card_moved_to_set(card_instance, song_data)

@onready var venue_backdrop: Control = $VenueBackdrop
@onready var backdrop_color: ColorRect = $VenueBackdrop/BackdropColor
@onready var backdrop_accents: Control = $VenueBackdrop/BackdropAccents
@onready var venue_name_label: Label = $Shell/VBoxContainer/TopBar/TitleBlock/VenueNameLabel
@onready var venue_genre_label: Label = $Shell/VBoxContainer/TopBar/TitleBlock/VenueGenreLabel
@onready var venue_attribute_label: Label = $Shell/VBoxContainer/TopBar/TitleBlock/VenueAttributeLabel
@onready var card_display_area: GridContainer = $Shell/VBoxContainer/PlayArea/Panel/HandVBox/HandScroll/CardDisplayArea
@onready var feedback_label: Label = $Shell/VBoxContainer/LastPlayedInfoLabel
@onready var score_label: Label = $Shell/VBoxContainer/TopBar/ScoreLabel
@onready var back_button: Button = get_node_or_null("Shell/VBoxContainer/TopBar/BackButton") as Button
@onready var genre_indicator: ColorRect = $Shell/VBoxContainer/GenreIndicator
@onready var last_title_label: Label = $Shell/VBoxContainer/PlayArea/LastCardPanel/LastCardVBox/Title
@onready var last_artist_label: Label = $Shell/VBoxContainer/PlayArea/LastCardPanel/LastCardVBox/Artist
@onready var last_genre_label: Label = $Shell/VBoxContainer/PlayArea/LastCardPanel/LastCardVBox/Genre
@onready var last_risk_label: Label = $Shell/VBoxContainer/PlayArea/LastCardPanel/LastCardVBox/Risk
@onready var last_energy_label: Label = $Shell/VBoxContainer/PlayArea/LastCardPanel/LastCardVBox/Energy
@onready var last_score_label: Label = $Shell/VBoxContainer/PlayArea/LastCardPanel/LastCardVBox/ScoreBreakdown

const SONG_CARD_SCENE = preload("res://scenes/song_card.tscn")
const CAT_TEXTURE = preload("res://assets/sprites/nyan_alley_cat.png")
const MAX_SONGS_IN_SET := 5
const CARDS_SHOWN_PER_TURN := 5
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
var current_venue_data: Dictionary = {}
var flash_t := 0.0
var backdrop_t := 0.0
var backdrop_style := "default"
var nyan_sprites: Array = []
var backdrop_dirty := true

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
	_update_grid_columns()
	backdrop_dirty = true

func _process(delta: float) -> void:
	flash_t += delta * 6.0
	backdrop_t += delta
	_update_genre_indicator()
	_animate_backdrop()

func _update_genre_indicator() -> void:
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

func draw_next_hand() -> void:
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

func initialize_deck_from_inventory(inventory: Array) -> void:
	playable_song_pool.clear()
	set_history.clear()
	current_turn_count = 0
	cards_on_display.clear()
	playable_song_pool = inventory.duplicate(true)
	playable_song_pool.shuffle()
	draw_next_hand()

func _on_song_selected(card_instance, data: Dictionary) -> void:
	current_turn_count += 1
	set_history.append(data)
	song_chosen_for_set.emit(card_instance, data)
	cards_on_display.erase(card_instance)
	card_instance.queue_free()
	card_moved_to_set.emit(card_instance, data)

	if current_turn_count >= MAX_SONGS_IN_SET:
		for card in cards_on_display:
			card.queue_free()
		cards_on_display.clear()
	else:
		draw_next_hand()

func update_venue_ui() -> void:
	if current_venue_genres.is_empty() and current_venue_genre != "":
		current_venue_genres = [current_venue_genre]
	venue_name_label.text = current_venue_data.get("name", "Tonight's Venue")
	venue_genre_label.text = "Genres: %s" % "/".join(current_venue_genres)
	venue_attribute_label.text = current_venue_data.get("attribute", "Read the room and sequence the best five-track run.")
	_configure_backdrop()

func _configure_backdrop() -> void:
	backdrop_style = current_venue_data.get("background_type", "default")
	backdrop_color.color = current_venue_data.get("backdrop_color", Color(0.0156863, 0.0235294, 0.0509804, 1.0))
	for child in backdrop_accents.get_children():
		child.queue_free()
	nyan_sprites.clear()
	if backdrop_style == "nyan_alley":
		_spawn_nyan_backdrop()
	elif backdrop_style == "beach_glow":
		_spawn_color_bands([
			Color(0.992157, 0.611765, 0.447059, 0.14),
			Color(0.376471, 0.909804, 0.996078, 0.1),
			Color(1.0, 0.921569, 0.658824, 0.08)
		])
	elif backdrop_style == "brick_pulse":
		_spawn_color_bands([
			Color(0.956863, 0.286275, 0.4, 0.12),
			Color(0.517647, 0.141176, 0.184314, 0.14),
			Color(0.145098, 0.0470588, 0.0666667, 0.12)
		])
	backdrop_dirty = true

func _spawn_nyan_backdrop() -> void:
	for row in range(4):
		for column in range(5):
			var sprite := TextureRect.new()
			sprite.texture = CAT_TEXTURE
			sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			sprite.size = Vector2(92, 54)
			sprite.modulate = Color(1, 1, 1, 0.18)
			backdrop_accents.add_child(sprite)
			nyan_sprites.append({
				"node": sprite,
				"row": row,
				"column": column,
				"direction": 1 if row % 2 == 0 else -1,
				"phase": float(column) * 0.35 + float(row) * 0.6,
				"base": Vector2.ZERO
			})

func _spawn_color_bands(colors: Array) -> void:
	for i in range(colors.size()):
		var band := ColorRect.new()
		band.color = colors[i]
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		band.size = Vector2(venue_backdrop.size.x + 120.0, 120.0)
		band.position = Vector2(-40.0, 70.0 + i * 120.0)
		backdrop_accents.add_child(band)

func _animate_backdrop() -> void:
	if backdrop_dirty:
		_layout_backdrop()
	if backdrop_style == "nyan_alley":
		for item in nyan_sprites:
			var node: TextureRect = item["node"]
			var base: Vector2 = item["base"]
			var direction: float = item["direction"]
			var phase: float = item["phase"]
			var drift = sin(backdrop_t * 1.6 + phase) * 26.0 * direction
			var bounce = sin(backdrop_t * 4.0 + phase * 2.0) * 8.0
			node.position = base + Vector2(drift, bounce)
	else:
		for index in range(backdrop_accents.get_child_count()):
			var band := backdrop_accents.get_child(index)
			if band is ColorRect:
				band.position.x = -40.0 + sin(backdrop_t * 0.9 + index) * 24.0

func _layout_backdrop() -> void:
	backdrop_dirty = false
	if backdrop_style == "nyan_alley":
		var rows := 4.0
		var columns := 5.0
		var margin_x := venue_backdrop.size.x * 0.08
		var margin_y := venue_backdrop.size.y * 0.14
		var x_step := (venue_backdrop.size.x - margin_x * 2.0) / max(1.0, columns - 1.0)
		var y_step := (venue_backdrop.size.y - margin_y * 2.0) / max(1.0, rows - 1.0)
		for item in nyan_sprites:
			var node: TextureRect = item["node"]
			var row: int = item["row"]
			var column: int = item["column"]
			var base_position = Vector2(margin_x + column * x_step - node.size.x * 0.5, margin_y + row * y_step - node.size.y * 0.5)
			item["base"] = base_position
			node.position = base_position
	else:
		for index in range(backdrop_accents.get_child_count()):
			var band := backdrop_accents.get_child(index)
			if band is ColorRect:
				band.size = Vector2(venue_backdrop.size.x + 120.0, 120.0)
				band.position.y = 70.0 + index * 120.0


func show_play_result(song_data: Dictionary, score_results: Dictionary, played_count: int, songs_in_set: int) -> void:
	feedback_label.text = "Played %s (+%d). (%d/%d played)" % [song_data.get("title", "Unknown"), score_results.points, played_count, songs_in_set]
	_set_last_card_panel(song_data, score_results)
	update_venue_ui()

func _set_last_card_panel(song_data: Dictionary, score_results: Dictionary) -> void:
	last_title_label.text = "Title: %s" % song_data.get("title", "Unknown")
	last_artist_label.text = "Artist: %s" % song_data.get("artist", "Unknown")
	last_genre_label.text = "Genre: %s" % song_data.get("genre", "Unknown")
	last_risk_label.text = "Risk: %s" % song_data.get("risk", "Low")
	last_energy_label.text = "Energy: %d/5" % song_data.get("energy", 0)
	last_score_label.text = "Score %s = Energy:%+d Genre:%+d Risk:%+d Flow:%+d" % [
		str(score_results.points),
		score_results.energy_score,
		score_results.genre_score,
		score_results.risk_score,
		score_results.flow_bonus
	]

func _reset_last_card_panel() -> void:
	last_title_label.text = "Title: —"
	last_artist_label.text = "Artist: —"
	last_genre_label.text = "Genre: —"
	last_risk_label.text = "Risk: —"
	last_energy_label.text = "Energy: —"
	last_score_label.text = "Score: waiting for first play"

func _on_score_updated(new_score: int) -> void:
	if score_label:
		score_label.text = "Score: %d" % new_score

func _on_back_to_world_pressed() -> void:
	if GameManager != null:
		GameManager.return_to_world()
