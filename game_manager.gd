extends Node

var current_crowd_state = {"energy": 50, "trust": 50, "patience": 50}
var current_score: int = 0
var last_played_energy: int = -1
var current_song_inventory: Array = []
var current_venue_genre: String = ""
var current_venue_genres: Array = []
var set_history: Array = []
var player_collection: Array = []
var current_setlist: Array = []
var available_genres: Array = []
var sfx_streams := {}

signal score_updated(new_score)
signal crowd_state_updated(new_state)

const SONGS_IN_SET = 5
const WORLD_SCENE = preload("res://scenes/world.tscn")
const CRATE_SCENE = preload("res://scenes/crate_dig.tscn")
const PERFORMANCE_SCENE = preload("res://scenes/song_deck_manager.tscn")
const SELECTION_SCENE = preload("res://scenes/setlist_selection.tscn")
const SFX_FILES = {
	"place_card": "place_card.wav",
	"record_store_open": "record_store_open.wav",
	"venue_open": "venue_open.wav"
}

var active_deck_manager = null
var active_world = null
var sfx_player: AudioStreamPlayer = null

func _ready():
	if get_path() != NodePath("/root/GameManager"):
		return
	_initialize_sfx()
	_initialize_available_genres()
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
	if active_world.has_signal("setlist_selected"):
		active_world.setlist_selected.connect(open_setlist_selection_menu)
	if active_world.has_method("setup_world"):
		active_world.setup_world(_build_venue_options(), current_crowd_state, current_setlist.size() >= SONGS_IN_SET)

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
	if current_setlist.size() < SONGS_IN_SET:
		print("Need a full setlist before going to the venue!")
		return
	current_venue_genres = venue_data.get("genres", ["Unknown"])
	current_venue_genre = current_venue_genres[0]
	print("Crowd wants: %s" % ", ".join(current_venue_genres))
	play_sfx("venue_open")
	start_performance_phase()

func start_crate_digging_phase():
	_cleanup_phase_nodes()
	var crate_scene = CRATE_SCENE.instantiate()
	add_child(crate_scene)
	if crate_scene.has_method("set_existing_inventory"):
		crate_scene.set_existing_inventory(player_collection)
	crate_scene.digging_finished.connect(on_digging_finished)
	play_sfx("record_store_open")

func on_digging_finished(new_finds: Array):
	player_collection = new_finds.duplicate(true)
	current_song_inventory = player_collection.duplicate(true)
	start_world_phase()

func open_setlist_selection_menu():
	var selection_menu = SELECTION_SCENE.instantiate()
	add_child(selection_menu)

func finalize_setlist(selected_songs: Array):
	current_setlist = selected_songs.duplicate(true)
	start_world_phase()

func start_performance_phase():
	_cleanup_phase_nodes()
	if is_instance_valid(active_deck_manager):
		active_deck_manager.queue_free()
	active_deck_manager = PERFORMANCE_SCENE.instantiate()
	add_child(active_deck_manager)

	set_history.clear()
	last_played_energy = -1

	if active_deck_manager.has_signal("song_chosen_for_set"):
		active_deck_manager.song_chosen_for_set.connect(_handle_song_played)
	active_deck_manager.current_venue_genres = current_venue_genres.duplicate()
	active_deck_manager.current_venue_genre = current_venue_genre
	active_deck_manager.update_venue_ui()
	active_deck_manager.initialize_deck_from_inventory(current_setlist)
	active_deck_manager.feedback_label.text = "The show is starting! Pick your first song."

func _cleanup_phase_nodes():
	var phase_children: Array = []
	for child in get_children():
		if child.name in ["Crate_dig", "crate_dig", "SongDeckManager", "SetListSelection", "world", "Venue"]:
			phase_children.append(child)
	for child in phase_children:
		if child == active_world:
			active_world = null
		if child == active_deck_manager:
			active_deck_manager = null
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

	if last_played_energy >= 0:
		energy_diff = abs(energy - last_played_energy)
		if energy_diff == 1:
			energy_score += 3
		else:
			energy_correct = false
			penalty_count += 1
			if energy_diff == 0:
				energy_score -= 2
			elif energy_diff == 2:
				energy_score -= 3
			else:
				energy_score -= 5
	else:
		energy_score += 1

	var genre_match = current_venue_genres.has(genre)
	if genre_match:
		genre_score += 5
		if set_history.size() > 0 and set_history.back().get("genre", "") == genre:
			genre_score += 2
	else:
		genre_score -= 5
		penalty_count += 1

	var risk_value = _risk_to_value(risk)
	var off_genre = not genre_match
	var energy_jump = last_played_energy >= 0 and energy_diff >= 2
	var risk_success = (risk_value == 1 and not off_genre) or (risk_value == 2 and (off_genre or energy_jump)) or (risk_value == 3 and off_genre and energy_jump)

	if risk_success:
		risk_score += risk_value * 3
		if risk_value == 3 and off_genre:
			_apply_genre_shift(genre)
	else:
		penalty_count += 1
		risk_score -= max(3, risk_value * 3)

	if set_history.size() >= 2:
		var prev_energy = set_history.back().get("energy", energy)
		var two_back_energy = set_history[set_history.size() - 2].get("energy", prev_energy)
		if energy >= prev_energy and prev_energy >= two_back_energy:
			flow_bonus += 2
		elif energy <= prev_energy and prev_energy <= two_back_energy:
			flow_bonus += 1

	if penalty_count >= 2:
		flow_bonus -= penalty_count

	points = energy_score + genre_score + risk_score + flow_bonus
	return {
		"points": points,
		"energy_score": energy_score,
		"genre_score": genre_score,
		"risk_score": risk_score,
		"flow_bonus": flow_bonus,
		"energy_correct": energy_correct,
		"genre_match": genre_match,
		"risk_success": risk_success,
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

func _apply_genre_shift(new_genre: String):
	if current_venue_genres.has(new_genre):
		return
	if current_venue_genres.size() >= 2:
		current_venue_genres.pop_front()
	current_venue_genres.append(new_genre)
	current_venue_genre = current_venue_genres[0]
	print("Genre shifted. Crowd now accepts: %s" % ", ".join(current_venue_genres))

func calculate_impact(score_results: Dictionary) -> Dictionary:
	var impact = {
		"energy_change": score_results.energy_score + score_results.flow_bonus,
		"trust_change": score_results.genre_score,
		"patience_change": score_results.risk_score
	}
	if not score_results.energy_correct:
		impact.energy_change -= 2
		impact.patience_change -= 1
	if not score_results.genre_match:
		impact.trust_change -= 2
		impact.energy_change -= 1
	if not score_results.risk_success:
		impact.patience_change -= 2
		impact.trust_change -= 1
	return impact

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
			active_deck_manager.feedback_label.text = "Night failed! Crowd state collapsed. Returning to world.."
		_end_night_and_return_world()
		return true
	return false

func check_win_condition():
	print("*** VICTORY! Set Complete! ***")
	if is_instance_valid(active_deck_manager):
		active_deck_manager.feedback_label.text = "Set complete! Final score: %d. Returning to world..." % current_score
	_end_night_and_return_world()

func _end_night_and_return_world():
	current_setlist.clear()
	start_world_phase()
