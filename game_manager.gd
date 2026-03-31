extends Node

var current_crowd_state = {"energy": 50, "trust": 50, "patience": 50}
var current_score: int = 0
var last_played_energy: int = -1
var current_song_inventory: Array = []
var current_venue_genre: String = ""
var current_venue_genres: Array = []
var current_venue_data: Dictionary = {}
var venue_preferences: Array = []
var set_history: Array = []
var player_collection: Array = []
var current_setlist: Array = []
var available_genres: Array = []
var sfx_streams := {}

signal score_updated(new_score)
signal crowd_state_updated(new_state)

const SONGS_IN_SET = 5
const NIGHT_PASS_SCORE_THRESHOLD = 20
const DEFAULT_CROWD_STATE = {"energy": 50, "trust": 50, "patience": 50}
const WORLD_SCENE = preload("res://scenes/world.tscn")
const RESULT_SCENE = preload("res://scenes/result.tscn")
const CRATE_SCENE = preload("res://scenes/crate_dig.tscn")
const PERFORMANCE_SCENE = preload("res://scenes/song_deck_manager.tscn")
const SELECTION_SCENE = preload("res://scenes/setlist_selection.tscn")
const SFX_FILES = {
	"place_card": "place_card.wav",
	"record_store_open": "record_store_open.wav",
	"venue_open": "venue_open.wav",
	"click_button": "click_button.wav"
}

const PERMANENT_VENUES = [
	{
		"name": "Nyan Alley",
		"genres": ["Pop", "EDM"],
		"tagline": "",
		"attribute": "",
		"background_type": "nyan_alley",
		"backdrop_color": Color(0.101961, 0.0588235, 0.184314, 1.0)
	},
	{
		"name": "Burmese Beach",
		"genres": ["Euro"],
		"tagline": "",
		"attribute": "",
		"background_type": "beach_glow",
		"backdrop_color": Color(0.0392157, 0.164706, 0.243137, 1.0)
	},
	{
		"name": "Biggie's Lounge.",
		"genres": ["Hiphop", "RnB"],
		"tagline": "",
		"attribute": "",
		"background_type": "brick_pulse",
		"backdrop_color": Color(0.117647, 0.054902, 0.0666667, 1.0)
	}
]

var active_deck_manager = null
var active_world = null
var active_result = null
var sfx_player: AudioStreamPlayer = null

func _ready() -> void:
	if get_path() != NodePath("/root/GameManager"):
		return
	_initialize_sfx()
	_initialize_available_genres()
	_initialize_venue_preferences()
	_prepare_next_night(false)
	start_world_phase()

func _initialize_sfx() -> void:
	sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "SFXPlayer"
	add_child(sfx_player)
	for sfx_name in SFX_FILES.keys():
		var file_name: String = SFX_FILES[sfx_name]
		var resource_path = _find_file_in_res(file_name)
		if resource_path == "":
			print("SFX missing for %s (%s)" % [sfx_name, file_name])
			continue
		var stream := load(resource_path)
		if stream is AudioStream:
			sfx_streams[sfx_name] = stream

func _find_file_in_res(file_name: String, root_path: String = "res://") -> String:
	var dir := DirAccess.open(root_path)
	if dir == null:
		return ""
	dir.list_dir_begin()
	var entry = dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var full_path = root_path.path_join(entry)
		if dir.current_is_dir():
			var nested_path = _find_file_in_res(file_name, full_path)
			if nested_path != "":
				dir.list_dir_end()
				return nested_path
		elif entry.to_lower() == file_name.to_lower():
			dir.list_dir_end()
			return full_path
		entry = dir.get_next()
	dir.list_dir_end()
	return ""

func play_sfx(sfx_name: String) -> void:
	if sfx_player == null:
		return
	var stream: AudioStream = sfx_streams.get(sfx_name)
	if stream == null:
		return
	sfx_player.stop()
	sfx_player.stream = stream
	sfx_player.play()

func _initialize_available_genres() -> void:
	available_genres.clear()
	if SongDatabase and SongDatabase.SONGS:
		for song in SongDatabase.SONGS:
			var genre = song.get("genre", "Unknown")
			if not available_genres.has(genre):
				available_genres.append(genre)

func _initialize_venue_preferences() -> void:
	venue_preferences = PERMANENT_VENUES.duplicate(true)

func _build_venue_options() -> Array:
	if venue_preferences.is_empty():
		_initialize_venue_preferences()
	return venue_preferences.duplicate(true)

func _handle_song_played(_card_instance, selected_song_data: Dictionary) -> void:
	if not is_instance_valid(self) or selected_song_data == null:
		print("ERROR: null song data")
		return

	var score_results = calculate_score_from_song(selected_song_data)
	var impact = calculate_impact(score_results)
	set_history.append(selected_song_data)
	last_played_energy = selected_song_data.get("energy", 0)
	current_score += score_results.points

	update_crowd_state(impact)
	score_updated.emit(current_score)

	if is_instance_valid(active_deck_manager):
		var played_count = set_history.size()
		active_deck_manager.show_play_result(selected_song_data, score_results, played_count, SONGS_IN_SET)

	if check_fail_condition():
		return

	if set_history.size() >= SONGS_IN_SET:
		check_win_condition()
	elif is_instance_valid(active_deck_manager):
		active_deck_manager.draw_next_hand()

func start_world_phase() -> void:
	_cleanup_phase_nodes()
	active_world = WORLD_SCENE.instantiate()
	add_child(active_world)
	if active_world.has_signal("crate_selected"):
		active_world.crate_selected.connect(start_crate_digging_phase)
	if active_world.has_signal("venue_selected"):
		active_world.venue_selected.connect(_on_world_venue_selected)
	if active_world.has_signal("setlist_selected"):
		active_world.setlist_selected.connect(open_setlist_selection_menu)
	if active_world.has_method("setup_world"):
		active_world.setup_world(_build_venue_options(), current_crowd_state.duplicate(true), current_setlist.size() >= SONGS_IN_SET)

func _on_world_venue_selected(venue_data: Dictionary) -> void:
	if current_setlist.size() < SONGS_IN_SET:
		print("Need a full setlist before going to the venue!")
		return
	current_venue_data = venue_data.duplicate(true)
	current_venue_genres = current_venue_data.get("genres", ["Unknown"]).duplicate()
	current_venue_genre = current_venue_genres[0]
	print("Crowd wants: %s" % ", ".join(current_venue_genres))
	play_sfx("venue_open")
	start_performance_phase()

func start_crate_digging_phase() -> void:
	_cleanup_phase_nodes()
	var crate_scene = CRATE_SCENE.instantiate()
	add_child(crate_scene)
	if crate_scene.has_method("set_existing_inventory"):
		crate_scene.set_existing_inventory(player_collection)
	crate_scene.digging_finished.connect(on_digging_finished)
	play_sfx("record_store_open")

func on_digging_finished(new_finds: Array) -> void: 
	player_collection = new_finds.duplicate(true)
	current_song_inventory = player_collection.duplicate(true)
	start_world_phase()

func open_setlist_selection_menu():
	_cleanup_phase_nodes()
	var selection_menu = SELECTION_SCENE.instantiate()
	add_child(selection_menu)

func finalize_setlist(selected_songs: Array) -> void:
	current_setlist = selected_songs.duplicate(true)
	start_world_phase()

func return_to_world() -> void:
	start_world_phase()
	
func start_performance_phase() -> void:
	_cleanup_phase_nodes()
	current_score = 0
	score_updated.emit(current_score)
	current_crowd_state = DEFAULT_CROWD_STATE.duplicate(true)
	crowd_state_updated.emit(current_crowd_state.duplicate(true))
	
	active_deck_manager = PERFORMANCE_SCENE.instantiate()
	add_child(active_deck_manager)

	set_history.clear()
	last_played_energy = -1

	if active_deck_manager.has_signal("song_chosen_for_set"):
		active_deck_manager.song_chosen_for_set.connect(_handle_song_played)
		active_deck_manager.current_venue_data = current_venue_data.duplicate(true)
	active_deck_manager.current_venue_genres = current_venue_genres.duplicate()
	active_deck_manager.current_venue_genre = current_venue_genre
	active_deck_manager.update_venue_ui()
	active_deck_manager.initialize_deck_from_inventory(current_setlist)
	active_deck_manager.feedback_label.text = "The show is starting! Pick your first song."

func _cleanup_phase_nodes() -> void:
	var phase_children: Array = []
	for child in get_children():
		if child.name in ["Crate_dig", "crate_dig", "SongDeckManager", "SetListSelection", "world", "Venue", "Result"]:
			phase_children.append(child)
	for child in phase_children:
		if child == active_world:
			active_world = null
		if child == active_deck_manager:
			active_deck_manager = null
		if child == active_result:
			active_result = null
		child.queue_free()

func calculate_score_from_song(song_data: Dictionary) -> Dictionary:
	var points = 0
	var genre_score = 0
	var risk_score = 0
	var energy_score = 0
	var flow_bonus = 0
	var penalty_count = 0
	var risk = song_data.get("risk", "Low")
	var genre = song_data.get("genre", "Unknown")
	var energy = song_data.get("energy", 0)
	var energy_diff = 0
	var energy_correct = true
	var energy_trend = 0

	if last_played_energy >= 0:
		energy_diff = abs(energy - last_played_energy)
		if energy_diff == 1:
			energy_score += 3
		elif energy_diff == 0:
			energy_score += 1
		elif energy_diff == 2:
			energy_correct = false
			penalty_count += 1
			energy_score -= 1
		else:
			energy_correct = false
			penalty_count += 1
			energy_score -= 3
		energy_trend = sign(energy - last_played_energy)
	else:
		energy_score += 2

	var genre_match = current_venue_genres.has(genre)
	if genre_match:
		genre_score += 5
		if set_history.size() > 0 and set_history.back().get("genre", "") == genre:
			genre_score +- 1
	else:
		genre_score -= 3
		penalty_count += 1


	if set_history.size() >= 2:
		var prev_energy = set_history.back().get("energy", energy)
		var two_back_energy = set_history[set_history.size() - 2].get("energy", prev_energy)
		if energy >= prev_energy and prev_energy >= two_back_energy:
			flow_bonus += 2
		elif energy <= prev_energy and prev_energy <= two_back_energy:
			flow_bonus += 1

	var risk_details = _calculate_risk_outcome(song_data, genre_match, energy_correct, energy_diff, energy_trend, flow_bonus)
	risk_score = risk_details.score
	if not risk_details.success:
		penalty_count += 1
	if risk_details.genre_shift:
		_apply_genre_shift(genre)

	if penalty_count >= 3:
		flow_bonus -= penalty_count - 1

	points = energy_score + genre_score + risk_score + flow_bonus
	return {
		"points": points,
		"energy_score": energy_score,
		"genre_score": genre_score,
		"risk_score": risk_score,
		"flow_bonus": flow_bonus,
		"energy_correct": energy_correct,
		"genre_match": genre_match,
		"risk_success": risk_details.success,
		"risk_readiness": risk_details.readiness,
		"risk_label": risk_details.label,
		"penalty_count": penalty_count
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

func _calculate_risk_outcome(song_data: Dictionary, genre_match: bool, energy_correct: bool, energy_diff: int, energy_trend: int, flow_bonus: int) -> Dictionary:
	var risk_value = _risk_to_value(song_data.get("risk", "Low"))
	var readiness = 0
	var crowd_heat = int(round((current_crowd_state["energy"] + current_crowd_state["trust"] + current_crowd_state["patience"]) / 30.0))
	var off_genre = not genre_match
	var energy_jump = last_played_energy >= 0 and energy_diff >= 2
	var steady_transition = last_played_energy < 0 or energy_diff <= 1
	var success = true
	var score = 0
	var genre_shift = false
	var label = "Landed"

	if genre_match:
		readiness += 2
	else:
		readiness -= 1

	if energy_correct:
		readiness += 2
	elif energy_diff == 2:
		readiness += 0
	else:
		readiness -= 1

	if flow_bonus > 0:
		readiness += 1
	if crowd_heat >= 5:
		readiness += 1
	if current_crowd_state["trust"] >= 55:
		readiness += 1
	if current_crowd_state["patience"] >= 55:
		readiness += 1
	if energy_trend != 0:
		readiness += 1
	if last_played_energy < 0:
		readiness += 1

	match risk_value:
		1:
			score = 2 + maxi(0, readiness)
			if off_genre and not energy_correct:
				success = false
				score = -2
				label = "Too safe for a mismatch"
		2:
			if readiness >= 3:
				score = 3 + readiness
				label = "Crowd bought the twist"
			elif genre_match or steady_transition:
				score = 1
				label = "Playable, but not a spike"
			else:
				success = false
				score = -2
				label = "The crowd hesitated"
		3:
			if readiness >= 5:
				score = 4 + readiness
				genre_shift = off_genre
				label = "Big swing, big pop"
			elif readiness >= 3:
				score = 2
				label = "Almost there"
			else:
				success = false
				score = -3
				label = "Too much too soon"

	return {
		"score": score,
		"success": success,
		"genre_shift": genre_shift,
		"readiness": readiness,
		"label": label,
		"off_genre": off_genre,
		"energy_jump": energy_jump
	}

func _apply_genre_shift(new_genre: String) -> void:
	if current_venue_genres.has(new_genre):
		return
	if current_venue_genres.size() >= 2:
		current_venue_genres.pop_front()
	current_venue_genres.append(new_genre)
	current_venue_genre = current_venue_genres[0]
	if is_instance_valid(active_deck_manager):
		active_deck_manager.current_venue_genres = current_venue_genres.duplicate()
		active_deck_manager.current_venue_genre = current_venue_genre
		active_deck_manager.update_venue_ui()
	print("Genre shifted. Crowd now accepts: %s" % ", ".join(current_venue_genres))

func calculate_impact(score_results: Dictionary) -> Dictionary:
	var impact = {
		"energy_change": int(round(score_results.energy_score + score_results.flow_bonus * 0.5)),
		"trust_change":  int(round(score_results.genre_score + min(score_results.risk_score, 3) * 0.35)),
		"patience_change":  int(round(score_results.risk_score * 0.7))
	}
	if not score_results.energy_correct:
		impact["energy_change"] -= 1
		impact["patience_change"] -= 1
	if not score_results.genre_match:
		impact["trust_change"] -= 1
		impact["energy_change"] -= 1
	if not score_results.risk_success:
		impact["patience_change"] -= 1
		impact["trust_change"] -= 1
	return impact

func update_crowd_state(impact: Dictionary) -> void: 
	current_crowd_state["energy"] = clamp(current_crowd_state["energy"] + impact["energy_change"], 0, 100)
	current_crowd_state["trust"] = clamp(current_crowd_state["trust"] + impact["trust_change"], 0, 100)
	current_crowd_state["patience"] = clamp(current_crowd_state["patience"] + impact["patience_change"], 0, 100)
	crowd_state_updated.emit(current_crowd_state.duplicate(true))
	print("Crowd -> E:%d T:%d P:%d" % [current_crowd_state["energy"], current_crowd_state["trust"], current_crowd_state["patience"]])

func check_fail_condition() -> bool:
	if current_crowd_state["energy"] <= 10 or current_crowd_state["trust"] <= 10 or current_crowd_state["patience"] <= 10:
		print("*** NIGHT FAILED: the crowd turned on the set. ***")
		_show_result_scene(false, "Night Over", "The crowd flatlined before the closer.")
		return true
	return false

func check_win_condition() -> void:
	if current_score >= NIGHT_PASS_SCORE_THRESHOLD:
		print("*** VICTORY! Set Complete! ***")
		_show_result_scene(true, "Set Complete!", "You landed the room and closed the night strong.")
		return

	print("*** NIGHT FAILED: final score below %d. ***" % NIGHT_PASS_SCORE_THRESHOLD)
	_show_result_scene(false, "Night Over", "Your final score was below %d." % NIGHT_PASS_SCORE_THRESHOLD)

func _show_result_scene(victory: bool, headline: String, summary: String) -> void:
	_cleanup_phase_nodes()
	active_result = RESULT_SCENE.instantiate()
	add_child(active_result)
	if active_result.has_signal("continue_pressed"):
		active_result.continue_pressed.connect(_on_result_continue)
	if active_result.has_method("setup_result"):
		active_result.setup_result(victory, current_score, current_venue_data.duplicate(true), current_crowd_state.duplicate(true), headline, summary)

func _on_result_continue() -> void:
	_prepare_next_night(true)
	start_world_phase()

func _prepare_next_night(reset_score: bool = true) -> void:
	current_crowd_state = DEFAULT_CROWD_STATE.duplicate(true)
	crowd_state_updated.emit(current_crowd_state.duplicate(true))
	if reset_score:
		current_score = 0
		score_updated.emit(current_score)
	last_played_energy = -1
	current_setlist.clear()
	set_history.clear()
	current_venue_genre = ""
	current_venue_genres.clear()
	current_venue_data.clear()
	current_song_inventory = player_collection.duplicate(true)
