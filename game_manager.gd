extends Node
 
# ---------------------------------------------------------------------------
# GameManager – autoload singleton
# Owns all phase transitions. Every scene is added as a child of this node
# and removed when transitioning away.
# ---------------------------------------------------------------------------
 
# ── Signals ─────────────────────────────────────────────────────────────────
signal score_updated(new_score)
signal crowd_state_updated(new_state)
signal performance_time_updated(seconds_left)
 
# ── Constants ────────────────────────────────────────────────────────────────
const SONGS_IN_SET             := 5
const NIGHT_PASS_SCORE_THRESHOLD := 20
const DEFAULT_CROWD_STATE      := {"energy": 50, "trust": 50, "patience": 50}
 
const WORLD_SCENE       = preload("res://scenes/world.tscn")
const CRATE_SCENE       = preload("res://scenes/crate_dig.tscn")
const SELECTION_SCENE   = preload("res://scenes/setlist_selection.tscn")
const PERFORMANCE_SCENE = preload("res://scenes/song_deck_manager.tscn")
const RESULT_SCENE      = preload("res://scenes/result.tscn")
 
const SFX_FILES := {
	"place_card":         "place_card.wav",
	"record_store_open":  "record_store_open.wav",
	"venue_open":         "venue_open.wav",
	"click_button":       "click_button.wav"
}
 
const PERMANENT_VENUES := [
	{
		"name":            "Nyan Alley",
		"genres":          ["Pop", "EDM"],
		"tagline":         "Neon lane",
		"attribute":       "Build momentum before the room cools.",
		"background_type": "nyan_alley",
		"backdrop_color":  Color(0.101961, 0.0588235, 0.184314, 1.0)
	},
	{
		"name":            "Burmese Beach",
		"genres":          ["Euro"],
		"tagline":         "Beach stage",
		"attribute":       "Keep it melodic – the crowd is laid-back.",
		"background_type": "beach_glow",
		"backdrop_color":  Color(0.0392157, 0.164706, 0.243137, 1.0)
	},
	{
		"name":            "Biggie's Lounge",
		"genres":          ["Hiphop", "RnB"],
		"tagline":         "Lounge crowd",
		"attribute":       "Slow burn crowd – earn their trust early.",
		"background_type": "brick_pulse",
		"backdrop_color":  Color(0.117647, 0.054902, 0.0666667, 1.0)
	}
]
 
# ── State ────────────────────────────────────────────────────────────────────
var current_crowd_state    := DEFAULT_CROWD_STATE.duplicate(true)
var current_score          := 0
var last_played_energy     := -1
var player_collection      : Array = []   # everything the player owns
var current_setlist        : Array = []   # the 5-song set for tonight
var current_song_inventory : Array = []
var current_venue_data     := {}
var current_venue_genres   : Array = []
var current_venue_genre    := ""
var set_history            : Array = []
var momentum               := 0.0
var performance_time_left  := 90
var seconds_since_last_pick := 0
 
# ── Active scene references ──────────────────────────────────────────────────
var _active_scene : Node = null   # only one phase scene lives at a time
 
# ── Internal ─────────────────────────────────────────────────────────────────
var sfx_player  : AudioStreamPlayer = null
var sfx_streams := {}
var performance_timer : Timer = null
 
# ════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ════════════════════════════════════════════════════════════════════════════
 
func _ready() -> void:
	_initialize_sfx()
	_prepare_next_night(false)
	start_world_phase()
 
# ════════════════════════════════════════════════════════════════════════════
# Phase transitions  (the only public entry-points)
# ════════════════════════════════════════════════════════════════════════════
 
func start_world_phase() -> void:
	_swap_scene(WORLD_SCENE.instantiate())
	var world := _active_scene
	world.crate_selected.connect(start_crate_digging_phase)
	world.setlist_selected.connect(open_setlist_selection)
	world.venue_selected.connect(_on_world_venue_selected)
	world.setup_world(
		PERMANENT_VENUES.duplicate(true),
		current_crowd_state.duplicate(true),
		current_setlist.size() >= SONGS_IN_SET
	)
 
func start_crate_digging_phase() -> void:
	play_sfx("record_store_open")
	_swap_scene(CRATE_SCENE.instantiate())
	var crate := _active_scene
	crate.set_existing_inventory(player_collection)
	crate.digging_finished.connect(_on_digging_finished)
	crate.go_to_world_pressed.connect(return_to_world)
 
func open_setlist_selection() -> void:
	_swap_scene(SELECTION_SCENE.instantiate())
	var sel := _active_scene
	sel.setlist_confirmed.connect(_on_setlist_confirmed)
	sel.go_to_world_pressed.connect(return_to_world)
 
func start_performance_phase() -> void:
	play_sfx("venue_open")
	_cleanup_timer()
	_swap_scene(PERFORMANCE_SCENE.instantiate())
	var dm := _active_scene
 
	# Reset per-night state
	current_score = 0
	score_updated.emit(current_score)
	current_crowd_state = DEFAULT_CROWD_STATE.duplicate(true)
	crowd_state_updated.emit(current_crowd_state.duplicate(true))
	set_history.clear()
	last_played_energy     = -1
	performance_time_left  = 90
	seconds_since_last_pick = 0
	momentum = 0.0
 
	# Wire signals
	dm.song_chosen_for_set.connect(_handle_song_played)
	dm.go_to_world_pressed.connect(return_to_world)
 
	# Push venue data before initialising deck
	dm.current_venue_data   = current_venue_data.duplicate(true)
	dm.current_venue_genres = current_venue_genres.duplicate()
	dm.current_venue_genre  = current_venue_genre
	dm.update_venue_ui()
	dm.initialize_deck_from_inventory(current_setlist)
	dm.update_timer_display(performance_time_left)
 
	_start_performance_timer()
 
func return_to_world() -> void:
	_cleanup_timer()
	start_world_phase()
 
# ════════════════════════════════════════════════════════════════════════════
# Internal callbacks
# ════════════════════════════════════════════════════════════════════════════
 
func _on_world_venue_selected(venue_data: Dictionary) -> void:
	if current_setlist.size() < SONGS_IN_SET:
		# World scene should already prevent this, but guard anyway
		push_warning("GameManager: tried to enter venue without a full setlist.")
		return
	current_venue_data    = venue_data.duplicate(true)
	current_venue_genres  = current_venue_data.get("genres", ["Unknown"]).duplicate()
	current_venue_genre   = current_venue_genres[0]
	start_performance_phase()
 
func _on_digging_finished(new_inventory: Array) -> void:
	player_collection      = new_inventory.duplicate(true)
	current_song_inventory = player_collection.duplicate(true)
	start_world_phase()
 
func _on_setlist_confirmed(selected_songs: Array) -> void:
	current_setlist = selected_songs.duplicate(true)
	start_world_phase()
 
func _handle_song_played(_card_instance, selected_song_data: Dictionary) -> void:
	var score_results := calculate_score_from_song(selected_song_data)
	var impact        := calculate_impact(score_results)
 
	set_history.append(selected_song_data)
	last_played_energy       = selected_song_data.get("energy", 0)
	current_score           += score_results.points
	seconds_since_last_pick  = 0
	momentum = clamp(float(score_results.points) * 0.65, -4.0, 8.0)
 
	update_crowd_state(impact)
	score_updated.emit(current_score)
 
	if is_instance_valid(_active_scene):
		_active_scene.show_play_result(
			selected_song_data, score_results,
			set_history.size(), SONGS_IN_SET
		)
 
	if check_fail_condition():
		return
 
	if set_history.size() >= SONGS_IN_SET:
		_cleanup_timer()
		check_win_condition()
	elif is_instance_valid(_active_scene):
		_active_scene.draw_next_hand()
 
# ════════════════════════════════════════════════════════════════════════════
# Result screen
# ════════════════════════════════════════════════════════════════════════════
 
func _show_result_scene(victory: bool, headline: String, summary: String) -> void:
	_swap_scene(RESULT_SCENE.instantiate())
	var result := _active_scene
	result.continue_pressed.connect(_on_result_continue)
	result.setup_result(
		victory, current_score,
		current_venue_data.duplicate(true),
		current_crowd_state.duplicate(true),
		headline, summary
	)
 
func _on_result_continue() -> void:
	_prepare_next_night(true)
	start_world_phase()
 
# ════════════════════════════════════════════════════════════════════════════
# Night helpers
# ════════════════════════════════════════════════════════════════════════════
 
func _prepare_next_night(reset_score: bool) -> void:
	_cleanup_timer()
	current_crowd_state = DEFAULT_CROWD_STATE.duplicate(true)
	crowd_state_updated.emit(current_crowd_state.duplicate(true))
	if reset_score:
		current_score = 0
		score_updated.emit(current_score)
	last_played_energy      = -1
	current_setlist.clear()
	set_history.clear()
	current_venue_genre     = ""
	current_venue_genres.clear()
	current_venue_data.clear()
	current_song_inventory  = player_collection.duplicate(true)
 
func check_fail_condition() -> bool:
	var cs := current_crowd_state
	if cs["energy"] <= 10 or cs["trust"] <= 10 or cs["patience"] <= 10:
		_cleanup_timer()
		_show_result_scene(false, "Night Over", "The crowd flatlined before the closer.")
		return true
	return false
 
func check_win_condition() -> void:
	if current_score >= NIGHT_PASS_SCORE_THRESHOLD:
		_show_result_scene(true, "Set Complete!", "You landed the room and closed the night strong.")
	else:
		_show_result_scene(false, "Night Over",
			"Your final score was below %d." % NIGHT_PASS_SCORE_THRESHOLD)
 
# ════════════════════════════════════════════════════════════════════════════
# Scene swap – single active scene at a time
# ════════════════════════════════════════════════════════════════════════════
 
func _swap_scene(new_scene: Node) -> void:
	if is_instance_valid(_active_scene):
		_active_scene.queue_free()
		_active_scene = null
	_active_scene = new_scene
	add_child(_active_scene)
 
# ════════════════════════════════════════════════════════════════════════════
# Performance timer
# ════════════════════════════════════════════════════════════════════════════
 
func _start_performance_timer() -> void:
	_cleanup_timer()
	performance_timer = Timer.new()
	performance_timer.wait_time = 1.0
	performance_timer.one_shot  = false
	add_child(performance_timer)
	performance_timer.timeout.connect(_on_performance_timer_tick)
	performance_timer.start()
 
func _cleanup_timer() -> void:
	if is_instance_valid(performance_timer):
		performance_timer.stop()
		performance_timer.queue_free()
		performance_timer = null
 
func _on_performance_timer_tick() -> void:
	performance_time_left       -= 1
	seconds_since_last_pick     += 1
 
	if seconds_since_last_pick <= 4:
		momentum = max(momentum * 0.9, -2.0)
		current_score += int(round(momentum))
	else:
		momentum = max(momentum - 0.6, -3.0)
		current_score += int(floor(momentum))
		update_crowd_state({"energy_change": -1, "trust_change": 0, "patience_change": -1})
 
	current_score = max(current_score, 0)
	score_updated.emit(current_score)
 
	if is_instance_valid(_active_scene) and _active_scene.has_method("update_timer_display"):
		_active_scene.update_timer_display(performance_time_left)
 
	performance_time_updated.emit(performance_time_left)
 
	if check_fail_condition():
		return
 
	if performance_time_left <= 0:
		_cleanup_timer()
		_show_result_scene(false, "Night Over", "Time ran out before the 5-song set was complete.")
 
# ════════════════════════════════════════════════════════════════════════════
# Scoring
# ════════════════════════════════════════════════════════════════════════════
 
func calculate_score_from_song(song_data: Dictionary) -> Dictionary:
	var genre    : String = song_data.get("genre", "Unknown")
	var energy   : int    = song_data.get("energy", 0)
	var genre_score  := 0
	var energy_score := 0
	var flow_bonus   := 0
	var penalty_count := 0
	var energy_diff  := 0
	var energy_correct := true
	var energy_trend   := 0
 
	if last_played_energy >= 0:
		energy_diff = abs(energy - last_played_energy)
		if   energy_diff == 0: energy_score += 1
		elif energy_diff == 1: energy_score += 3
		elif energy_diff == 2:
			energy_correct = false
			penalty_count += 1
			energy_score  -= 1
		else:
			energy_correct = false
			penalty_count += 1
			energy_score  -= 3
		energy_trend = sign(energy - last_played_energy)
	else:
		energy_score += 2
 
	var genre_match := current_venue_genres.has(genre)
	if genre_match:
		genre_score += 5
		if set_history.size() > 0 and set_history.back().get("genre", "") == genre:
			genre_score += 1
	else:
		genre_score  -= 3
		penalty_count += 1
 
	if set_history.size() >= 2:
		var prev : int = set_history.back().get("energy", energy)
		var two_back : int = set_history[set_history.size() - 2].get("energy", prev)
		if energy >= prev and prev >= two_back:
			flow_bonus += 2
		elif energy <= prev and prev <= two_back:
			flow_bonus += 1
 
	var risk_details := _calculate_risk_outcome(song_data, genre_match, energy_correct, energy_diff, energy_trend, flow_bonus)
	if not risk_details.success:
		penalty_count += 1
	if risk_details.genre_shift:
		_apply_genre_shift(genre)
	if penalty_count >= 3:
		flow_bonus -= penalty_count - 1
 
	var points :int = energy_score + genre_score + risk_details.score + flow_bonus
	return {
		"points":         points,
		"energy_score":   energy_score,
		"genre_score":    genre_score,
		"risk_score":     risk_details.score,
		"flow_bonus":     flow_bonus,
		"energy_correct": energy_correct,
		"genre_match":    genre_match,
		"risk_success":   risk_details.success,
		"risk_readiness": risk_details.readiness,
		"risk_label":     risk_details.label,
		"penalty_count":  penalty_count
	}
 
func _risk_to_value(risk: String) -> int:
	match risk:
		"Medium": return 2
		"High":   return 3
	return 1
 
func _calculate_risk_outcome(song_data: Dictionary, genre_match: bool, energy_correct: bool, energy_diff: int, energy_trend: int, flow_bonus: int) -> Dictionary:
	var risk_value  := _risk_to_value(song_data.get("risk", "Low"))
	var off_genre   := not genre_match
	var energy_jump := last_played_energy >= 0 and energy_diff >= 2
	var steady      := last_played_energy < 0 or energy_diff <= 1
	var readiness   := 0
	var crowd_heat  := int(round((current_crowd_state["energy"] + current_crowd_state["trust"] + current_crowd_state["patience"]) / 30.0))
 
	if genre_match:             readiness += 2
	else:                       readiness -= 1
	if energy_correct:          readiness += 2
	elif energy_diff == 2:      readiness += 0
	else:                       readiness -= 1
	if flow_bonus > 0:          readiness += 1
	if crowd_heat >= 5:         readiness += 1
	if current_crowd_state["trust"]   >= 55: readiness += 1
	if current_crowd_state["patience"] >= 55: readiness += 1
	if energy_trend != 0:       readiness += 1
	if last_played_energy < 0:  readiness += 1
 
	var score       := 0
	var success     := true
	var genre_shift := false
	var label       := "Landed"
 
	match risk_value:
		1:
			score = 2 + maxi(0, readiness)
			if off_genre and not energy_correct:
				success = false
				score   = -2
				label   = "Too safe for a mismatch"
		2:
			if readiness >= 3:
				score = 3 + readiness
				label = "Crowd bought the twist"
			elif genre_match or steady:
				score = 1
				label = "Playable, but not a spike"
			else:
				success = false
				score   = -2
				label   = "The crowd hesitated"
		3:
			if readiness >= 5:
				score       = 4 + readiness
				genre_shift = off_genre
				label       = "Big swing, big pop"
			elif readiness >= 3:
				score = 2
				label = "Almost there"
			else:
				success = false
				score   = -3
				label   = "Too much too soon"
 
	return {
		"score":       score,
		"success":     success,
		"genre_shift": genre_shift,
		"readiness":   readiness,
		"label":       label,
		"off_genre":   off_genre,
		"energy_jump": energy_jump
	}
 
func _apply_genre_shift(new_genre: String) -> void:
	if current_venue_genres.has(new_genre):
		return
	if current_venue_genres.size() >= 2:
		current_venue_genres.pop_front()
	current_venue_genres.append(new_genre)
	current_venue_genre = current_venue_genres[0]
	if is_instance_valid(_active_scene) and _active_scene.has_method("update_venue_ui"):
		_active_scene.current_venue_genres = current_venue_genres.duplicate()
		_active_scene.current_venue_genre  = current_venue_genre
		_active_scene.update_venue_ui()
 
func calculate_impact(score_results: Dictionary) -> Dictionary:
	var impact := {
		"energy_change":   int(round(score_results.energy_score + score_results.flow_bonus * 0.5)),
		"trust_change":    int(round(score_results.genre_score  + min(score_results.risk_score, 3) * 0.35)),
		"patience_change": int(round(score_results.risk_score   * 0.7))
	}
	if not score_results.energy_correct:
		impact["energy_change"]   -= 1
		impact["patience_change"] -= 1
	if not score_results.genre_match:
		impact["trust_change"]  -= 1
		impact["energy_change"] -= 1
	if not score_results.risk_success:
		impact["patience_change"] -= 1
		impact["trust_change"]    -= 1
	return impact
 
func update_crowd_state(impact: Dictionary) -> void:
	current_crowd_state["energy"]   = clamp(current_crowd_state["energy"]   + impact["energy_change"],   0, 100)
	current_crowd_state["trust"]    = clamp(current_crowd_state["trust"]    + impact["trust_change"],    0, 100)
	current_crowd_state["patience"] = clamp(current_crowd_state["patience"] + impact["patience_change"], 0, 100)
	crowd_state_updated.emit(current_crowd_state.duplicate(true))
 
# ════════════════════════════════════════════════════════════════════════════
# SFX
# ════════════════════════════════════════════════════════════════════════════
 
func _initialize_sfx() -> void:
	sfx_player      = AudioStreamPlayer.new()
	sfx_player.name = "SFXPlayer"
	add_child(sfx_player)
	for sfx_name in SFX_FILES:
		var path := _find_file_in_res(SFX_FILES[sfx_name])
		if path == "":
			push_warning("SFX missing: %s" % sfx_name)
			continue
		var stream := load(path)
		if stream is AudioStream:
			sfx_streams[sfx_name] = stream
 
func play_sfx(sfx_name: String) -> void:
	if sfx_player == null:
		return
	var stream : AudioStream = sfx_streams.get(sfx_name)
	if stream == null:
		return
	sfx_player.stop()
	sfx_player.stream = stream
	sfx_player.play()
 
func _find_file_in_res(file_name: String, root_path: String = "res://") -> String:
	var dir := DirAccess.open(root_path)
	if dir == null:
		return ""
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var full := root_path.path_join(entry)
			if dir.current_is_dir():
				var nested := _find_file_in_res(file_name, full)
				if nested != "":
					dir.list_dir_end()
					return nested
			elif entry.to_lower() == file_name.to_lower():
				dir.list_dir_end()
				return full
		entry = dir.get_next()
	dir.list_dir_end()
	return ""
