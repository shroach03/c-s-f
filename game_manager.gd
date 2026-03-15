extends Node

var current_crowd_state = { "energy": 50, "trust": 50, "patience": 50 }
var current_score: int = 0
var last_played_energy: int = -1
var current_song_inventory: Array = []
var current_venue_genre: String = ""
var current_venue_genres: Array = []
var set_history: Array = []
var player_collection: Array = []
var current_setlist: Array = []
var available_genres: Array = []

signal score_updated(new_score)
signal crowd_state_updated(new_state)

const SONGS_IN_SET = 5
const WORLD_SCENE = preload("res://scenes/world.tscn")
const CRATE_SCENE = preload("res://scenes/crate_dig.tscn")
const PERFORMANCE_SCENE = preload("res://scenes/song_deck_manager.tscn")
const SELECTION_SCENE = preload("res://scenes/setlist_selection.tscn")

var active_deck_manager = null
var active_world = null

func _ready():
	if get_path() != NodePath("/root/GameManager"):
		return
	_initialize_available_genres()
	start_world_phase()

func _initialize_available_genres():
	if SongDatabase and SongDatabase.SONGS:
		for song in SongDatabase.SONGS:
			var g = song.get("genre", "Unknown")
			if not available_genres.has(g):
				available_genres.append(g)

func _handle_song_played(_card_instance, selected_song_data):
	if not is_instance_valid(self) or selected_song_data == null:
		print("ERROR: null song data")
		return
	var song_title = selected_song_data.get("title", "Unknown")
	print("GameManager received: %s" % song_title)

	var score_results = calculate_score_from_song(selected_song_data)
	var impact = calculate_impact(score_results)
	
	set_history.append(selected_song_data)
	last_played_energy = selected_song_data.get("energy", 0)
	current_score += score_results.points

	update_crowd_state(impact)
	score_updated.emit(current_score)

	if is_instance_valid(active_deck_manager):
		var played_count = set_history.size()
		active_deck_manager.feedback_label.text = "Played %s (+%d). (%d/%d played)" % [selected_song_data.get("title", "Unknown"), score_results.points, played_count, SONGS_IN_SET]
		active_deck_manager.update_venue_ui()

	if check_fail_condition():
		return

	if set_history.size() >= SONGS_IN_SET:
		check_win_condition()
	else:
		if is_instance_valid(active_deck_manager):
			active_deck_manager.draw_next_hand()

func start_world_phase():
	_cleanup_phase_nodes()
	active_world = WORLD_SCENE.instantiate()
	add_child(active_world)
	if active_world.has_signal("crate_selected"):
		active_world.crate_selected.connect(start_crate_digging_phase)
	if active_world.has_signal("venue_selected"):
		active_world.venue_selected.connect(_on_world_venue_selected)
	if active_world.has_method("setup_world"):
		active_world.setup_world(_build_venue_options(), current_crowd_state)

func _build_venue_options() -> Array:
	var options: Array = []
	for index in range(3):
		if available_genres.is_empty():
			options.append({"name": "Venue %d" % (index + 1), "genres": ["Unknown"]})
			continue
		var first = available_genres.pick_random()
		var second = first
		if available_genres.size() > 1 and randi() % 100 > 60:
			while second == first:
				second = available_genres.pick_random()
		var genres = [first]
		if second != first:
			genres.append(second)
		options.append({"name": "Venue %d" % (index + 1), "genres": genres})
	return options

func _on_world_venue_selected(venue_data: Dictionary):
	current_venue_genres = venue_data.get("genres", ["Unknown"])
	current_venue_genre = current_venue_genres[0]
	print("Crowd wants: %s" % ", ".join(current_venue_genres))
	start_crate_digging_phase()
	
func start_crate_digging_phase():
	_cleanup_phase_nodes()
	var crate_scene = CRATE_SCENE.instantiate()
	add_child(crate_scene)
	crate_scene.digging_finished.connect(on_digging_finished)

func on_digging_finished(new_finds: Array):
	player_collection = new_finds.duplicate(true)

	open_setlist_selection_menu()

func open_setlist_selection_menu():
	var selection_menu = SELECTION_SCENE.instantiate()
	add_child(selection_menu)

func start_performance_phase():
	if is_instance_valid(active_deck_manager):
		active_deck_manager.queue_free()
	active_deck_manager = PERFORMANCE_SCENE.instantiate()
	add_child(active_deck_manager)

	if active_deck_manager.has_signal("song_chosen_for_set"):
		active_deck_manager.song_chosen_for_set.connect(_handle_song_played)
	active_deck_manager.current_venue_genres = current_venue_genres.duplicate()
	active_deck_manager.current_venue_genre = current_venue_genre
	active_deck_manager.update_venue_ui()
	active_deck_manager.initialize_deck_from_inventory(current_setlist)
	active_deck_manager.feedback_label.text = "The show is starting! Pick your first song."

func _cleanup_phase_nodes():
	for child in get_children():
		if child.name in ["Crate_dig", "SongDeckManager", "SetListSelection", "Venue"]:
			child.queue_free()



func calculate_score_from_song(song_data: Dictionary) -> Dictionary:
	var points = 0
	var genre_score = 0
	var risk_score = 0
	var energy_score = 0
	var risk = song_data.get("risk", "Low")
	var genre = song_data.get("genre", "Unknown")
	var energy = song_data.get("energy", 0)

	if last_played_energy >= 0:
		var energy_diff = abs(energy - last_played_energy)
		if energy_diff == 1:
			energy_score += 3
		elif energy_diff == 0:
			energy_score += 1
		elif energy_diff == 2:
			energy_score += 2
		elif energy_diff >= 3:
			energy_score -= 2
	else:
		energy_score += 1

	if current_venue_genres.has(genre):
		genre_score += 5
		if set_history.size() > 0 and set_history.back().get("genre", "") == genre:
			genre_score += 2
	else:
		genre_score -= 2

	var risk_value = _risk_to_value(risk)
	var off_genre = not current_venue_genres.has(genre)
	var energy_jump = last_played_energy >= 0 and abs(energy - last_played_energy) >= 2
	var risk_success = (risk_value == 1 and not off_genre) or (risk_value == 2 and (off_genre or energy_jump)) or (risk_value == 3 and off_genre and energy_jump)

	if risk_success:
		risk_score += risk_value * 3
		if risk_value == 3 and off_genre:
			_apply_genre_shift(genre)
	else:
		risk_score -= risk_value * 2

	points = energy_score + genre_score + risk_score
	return {
		"points": points,
		"energy_score": energy_score,
		"genre_score": genre_score,
		"risk_score": risk_score
	}

func _risk_to_value(risk: String) -> int:
	match risk:
		"Low":
			return 1
		"Medium":
			return 2
		"High":
			return 3
	return 1

func _apply_genre_shift(new_genre: String):
	if current_venue_genres.has(new_genre):
		return
	if current_venue_genres.size() >= 2:
		current_venue_genres.pop_front()
	current_venue_genres.append(new_genre)
	current_venue_genre = current_venue_genres[0]
	print("Genre shifted. Crowd now accepts: %s" % ", ".join(current_venue_genres))

func calculate_impact(score_results: Dictionary) -> Dictionary:
	return {
		"energy_change": score_results.energy_score,
		"trust_change": score_results.genre_score,
		"patience_change": score_results.risk_score
	}

func update_crowd_state(impact: Dictionary):
	current_crowd_state.energy = clamp(current_crowd_state.energy + impact.energy_change, 0, 100)
	current_crowd_state.trust = clamp(current_crowd_state.trust + impact.trust_change, 0, 100)
	current_crowd_state.patience = clamp(current_crowd_state.patience + impact.patience_change, 0, 100)
	crowd_state_updated.emit(current_crowd_state.duplicate())
	print("Crowd -> E:%d T:%d P:%d" % [current_crowd_state.energy, current_crowd_state.trust, current_crowd_state.patience])

func check_fail_condition() -> bool:
	if current_crowd_state.energy <= 10 or current_crowd_state.trust <= 10 or current_crowd_state.patience <= 10:
		print("*** NIGHT FAILED: the crowd turned on the set. ***")
		if is_instance_valid(active_deck_manager):
			active_deck_manager.feedback_label.text = "Night failed! Crowd state collapsed."
		return true
	return false

func check_win_condition():
	print("*** VICTORY! Set Complete! ***")
	if is_instance_valid(active_deck_manager):
		active_deck_manager.feedback_label.text = "Set complete! Final score: %d" % current_score

	
