extends Control

const SONG_CARD_SCENE := preload("res://scenes/song_card.tscn")
const ALL_GENRES := ["EDM", "POP", "Euro", "RnB", "HipHop"]
const TUTORIAL_DECKS := {
	"EDM": [
		{"title": "Warmup Wave",     "artist": "DJ Pixel",    "genre": "EDM",    "energy": 2, "risk": "Low"},
		{"title": "Synth Surge",     "artist": "Neon Kitten",  "genre": "EDM",    "energy": 3, "risk": "Low"},
		{"title": "Drop Protocol",   "artist": "DJ Pixel",    "genre": "EDM",    "energy": 3, "risk": "Medium"},
		{"title": "Bass Ascension",  "artist": "Neon Kitten",  "genre": "EDM",    "energy": 4, "risk": "Medium"},
		{"title": "Grand Finale EDM","artist": "DJ Pixel",    "genre": "EDM",    "energy": 5, "risk": "High"},
	],
	"POP": [
		{"title": "Easy Listener",   "artist": "Whisker Pop", "genre": "POP",    "energy": 2, "risk": "Low"},
		{"title": "Catchy Hook",     "artist": "Whisker Pop", "genre": "POP",    "energy": 3, "risk": "Low"},
		{"title": "Sing Along",      "artist": "Purrfect Duo","genre": "POP",    "energy": 3, "risk": "Medium"},
		{"title": "Chart Climber",   "artist": "Whisker Pop", "genre": "POP",    "energy": 4, "risk": "Medium"},
		{"title": "Encore Anthem",   "artist": "Purrfect Duo","genre": "POP",    "energy": 5, "risk": "High"},
	],
	"Euro": [
		{"title": "Boardwalk Stroll","artist": "Café Claw",   "genre": "Euro",   "energy": 2, "risk": "Low"},
		{"title": "Riviera Groove",  "artist": "Café Claw",   "genre": "Euro",   "energy": 3, "risk": "Low"},
		{"title": "Midnight Paris",  "artist": "Le Purr",     "genre": "Euro",   "energy": 3, "risk": "Medium"},
		{"title": "Côte d'Azur",     "artist": "Café Claw",   "genre": "Euro",   "energy": 4, "risk": "Medium"},
		{"title": "Gran Finale Euro","artist": "Le Purr",     "genre": "Euro",   "energy": 5, "risk": "High"},
	],
	"RnB": [
		{"title": "Smooth Intro",    "artist": "Velvet Paw",  "genre": "RnB",    "energy": 2, "risk": "Low"},
		{"title": "Slow Burn",       "artist": "Velvet Paw",  "genre": "RnB",    "energy": 3, "risk": "Low"},
		{"title": "Soul Check",      "artist": "Clawdius",    "genre": "RnB",    "energy": 3, "risk": "Medium"},
		{"title": "Late Night Vibe", "artist": "Velvet Paw",  "genre": "RnB",    "energy": 4, "risk": "Medium"},
		{"title": "Full Soul Drop",  "artist": "Clawdius",    "genre": "RnB",    "energy": 5, "risk": "High"},
	],
	"HipHop": [
		{"title": "Low Key Flex",    "artist": "MC Mittens",  "genre": "HipHop", "energy": 2, "risk": "Low"},
		{"title": "Street Pulse",    "artist": "MC Mittens",  "genre": "HipHop", "energy": 3, "risk": "Low"},
		{"title": "Bar for Bar",     "artist": "Tabby T",     "genre": "HipHop", "energy": 3, "risk": "Medium"},
		{"title": "Block Party",     "artist": "MC Mittens",  "genre": "HipHop", "energy": 4, "risk": "Medium"},
		{"title": "Grand Finale Hop","artist": "Tabby T",     "genre": "HipHop", "energy": 5, "risk": "High"},
	],
}

const IDEAL_ORDER := [0, 1, 2, 3, 4]

const COACHING := [
	# Pick 1
	{
		true:  " Nice opener! Starting at energy 2 is the sweet spot — it warms the crowd without overwhelming them. Genre match means the audience is already nodding along. Keep building!",
		false: "  Risky first pick! The crowd needs to warm up. Try to open with a low-energy track that fits the venue's genre. A mismatch early drains Patience fast.",
	},
	# Pick 2
	{
		true:  " Solid progression! Moving from energy 2 → 3 is a smooth step — the crowd feels the build. Staying in genre keeps their Trust climbing. You're reading the room!",
		false: "  The crowd's enthusiasm dipped. Big energy jumps or genre mismatches hit Trust and Patience. Try to increase energy by only 1 step, and stay in the venue's preferred genre.",
	},
	# Pick 3
	{
		true:  " Holding energy at 3 gives the room a breath — this is called a 'groove pocket'. Sustaining genre match here pads your score before the big climb. Great instinct!",
		false: "  Careful — an unsteady middle set is hard to recover from. Keep energy stable or nudge it up by 1. Genre mismatches are especially costly when Patience is already low.",
	},
	# Pick 4
	{
		true:  " Energy 4 — the crowd is rising! You've earned this escalation by building slowly. High-risk cards pay off better when Trust is already high. Almost there!",
		false: "  The jump was too steep or the genre landed wrong. Remember: High-risk songs multiply both gains AND losses. Save them for when the crowd is primed.",
	},
	# Pick 5
	{
		true:  " Perfect closer! Energy 5 with a genre match is a crowd-pleaser finish. High risk on the last song is smart — if everything went well, the multiplier cements a big score. Night complete!",
		false: "⚠  The finale didn't land as hoped. A genre mismatch or a big energy gap on the last song can collapse Patience right at the end. Sequence matters — build, don't spike!",
	},
]

var _crowd := {"energy": 50, "trust": 50, "patience": 50}
var _score: int = 0
var _last_energy: int = -1
var _picks_made: int = 0
var _venue_genre: String = ""

var _card_area:      HBoxContainer
var _scroll:         ScrollContainer
var _left_btn:       Button
var _right_btn:      Button
var _venue_label:    Label
var _score_label:    Label
var _crowd_label:    Label
var _feedback_label: Label
var _coaching_panel: PanelContainer
var _coaching_text:  RichTextLabel
var _coaching_ok:    Button
var _exit_btn:       Button
var _left_spacer:    Control
var _right_spacer:   Control

var _cards_on_display: Array = []
var _current_index: int = 0
const _TARGET_CARD_WIDTH := 176.0
var _record_width: float = 0.0
var _deck: Array = []


func _ready() -> void:
	_pick_venue_genre()
	_build_ui()
	_deal_cards()
	_update_ui()
	_update_nav()


func _pick_venue_genre() -> void:
	_venue_genre = ALL_GENRES[randi() % ALL_GENRES.size()]


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.843, 0.659, 0.812, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.name = "Background"
	add_child(bg)
	var top_bar := HBoxContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.add_theme_constant_override("separation", 12)
	top_bar.custom_minimum_size = Vector2(0, 52)
	bg.add_child(top_bar)

	_exit_btn = Button.new()
	_exit_btn.text = "Exit Tutorial"
	_exit_btn.custom_minimum_size = Vector2(160, 44)
	_exit_btn.pressed.connect(_on_exit_pressed)
	top_bar.add_child(_exit_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)

	_score_label = Label.new()
	_score_label.text = "Score: 0"
	_score_label.custom_minimum_size = Vector2(140, 44)
	_score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_bar.add_child(_score_label)

	var vbox := VBoxContainer.new()
	vbox.set_position(Vector2(30, 60))
	vbox.custom_minimum_size = Vector2(420, 80)
	bg.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = "🎓  TUTORIAL — Tonight's Venue"
	title_lbl.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title_lbl)

	_venue_label = Label.new()
	_venue_label.text = "Preferred Genre: %s" % _venue_genre
	vbox.add_child(_venue_label)

	var hint := Label.new()
	hint.text = "Play all 5 songs. Watch the coaching tips after each pick!"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(hint)

	_crowd_label = Label.new()
	_crowd_label.set_position(Vector2(30, 155))
	_crowd_label.text = _crowd_text()
	bg.add_child(_crowd_label)

	# ── Feedback label ────────────────────────────────────────────────────────
	_feedback_label = Label.new()
	_feedback_label.set_position(Vector2(30, 180))
	_feedback_label.custom_minimum_size = Vector2(480, 36)
	_feedback_label.text = "Pick your opening track!"
	_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bg.add_child(_feedback_label)

	# ── Card carousel ─────────────────────────────────────────────────────────
	_scroll = ScrollContainer.new()
	_scroll.set_position(Vector2(54, 230))
	_scroll.custom_minimum_size = Vector2(420, 210)
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bg.add_child(_scroll)

	_card_area = HBoxContainer.new()
	_card_area.add_theme_constant_override("separation", 12)
	_scroll.add_child(_card_area)

	_left_spacer = Control.new()
	_left_spacer.custom_minimum_size = Vector2(100, 100)
	_card_area.add_child(_left_spacer)

	_right_spacer = Control.new()
	_right_spacer.custom_minimum_size = Vector2(100, 100)
	_card_area.add_child(_right_spacer)

	_left_btn = Button.new()
	_left_btn.text = "<"
	_left_btn.custom_minimum_size = Vector2(44, 44)
	_left_btn.set_position(Vector2(39, 453))
	_left_btn.pressed.connect(func(): _set_index(_current_index - 1))
	bg.add_child(_left_btn)

	_right_btn = Button.new()
	_right_btn.text = ">"
	_right_btn.custom_minimum_size = Vector2(44, 44)
	_right_btn.set_position(Vector2(423, 453))
	_right_btn.pressed.connect(func(): _set_index(_current_index + 1))
	bg.add_child(_right_btn)

	# ── Coaching overlay panel ────────────────────────────────────────────────
	_coaching_panel = PanelContainer.new()
	_coaching_panel.set_anchors_preset(Control.PRESET_CENTER)
	_coaching_panel.custom_minimum_size = Vector2(520, 240)
	_coaching_panel.visible = false
	# Position it centred (approximate; layout resolves after first frame)
	_coaching_panel.set_position(Vector2(200, 160))
	add_child(_coaching_panel)  # child of root so it layers above everything

	var panel_vbox := VBoxContainer.new()
	panel_vbox.add_theme_constant_override("separation", 14)
	_coaching_panel.add_child(panel_vbox)

	var panel_title := Label.new()
	panel_title.text = "🎧  Coach's Note"
	panel_title.add_theme_font_size_override("font_size", 20)
	panel_vbox.add_child(panel_title)

	_coaching_text = RichTextLabel.new()
	_coaching_text.bbcode_enabled = true
	_coaching_text.fit_content = true
	_coaching_text.custom_minimum_size = Vector2(490, 120)
	_coaching_text.scroll_active = false
	panel_vbox.add_child(_coaching_text)

	_coaching_ok = Button.new()
	_coaching_ok.text = "Got it — next pick!"
	_coaching_ok.pressed.connect(_on_coaching_ok_pressed)
	panel_vbox.add_child(_coaching_ok)
	await get_tree().process_frame
	_refresh_carousel_layout()

func _deal_cards() -> void:
	_deck = TUTORIAL_DECKS.get(_venue_genre, TUTORIAL_DECKS["EDM"]).duplicate(true)
	_deck.shuffle()

	for song_data in _deck:
		var card = SONG_CARD_SCENE.instantiate()
		_card_area.add_child(card)
		_card_area.move_child(card, _right_spacer.get_index())
		card.setup_card(song_data, {"context": "performance"})
		if not card.song_selected.is_connected(_on_card_selected):
			card.song_selected.connect(_on_card_selected)
		_cards_on_display.append(card)

	_record_width = _TARGET_CARD_WIDTH + _card_area.get_theme_constant("separation")


func _on_card_selected(card_instance, song_data: Dictionary) -> void:
	if _coaching_panel.visible:
		return  

	_cards_on_display.erase(card_instance)
	if is_instance_valid(card_instance):
		card_instance.queue_free()

	var results = _evaluate_song(song_data)
	_apply_results(song_data, results)
	_show_coaching(song_data, results)

	_picks_made += 1
	_last_energy = song_data.get("energy", 2)

	_set_index(clampi(_current_index, 0, maxi(_card_count() - 1, 0)))
	_update_ui()
	_update_nav()


func _evaluate_song(song_data: Dictionary) -> Dictionary:
	var genre   := song_data.get("genre", "Unknown") as String
	var energy  := song_data.get("energy", 2)        as int
	var risk    := song_data.get("risk", "Low")      as String

	var genre_match    := genre.to_lower() == _venue_genre.to_lower()
	var energy_ok      :int= _last_energy < 0 or abs(energy - _last_energy) <= 1
	var energy_score   := 1 if energy_ok   else -1
	var genre_score    := 1 if genre_match else -1
	var risk_mult      := _risk_multiplier(risk)
	var points         := int(round((energy_score * 10.0 + genre_score * 15.0) * risk_mult))

	return {
		"points":        points,
		"genre_match":   genre_match,
		"energy_ok":     energy_ok,
		"energy_score":  energy_score,
		"genre_score":   genre_score,
		"risk_mult":     risk_mult,
		"good":          genre_match and energy_ok,
	}

func _apply_results(song_data: Dictionary, results: Dictionary) -> void:
	_score += results.points
	var quality :int= results.energy_score + results.genre_score
	_crowd.energy  = clampi(_crowd.energy  + results.energy_score * 3,  0, 100)
	_crowd.trust   = clampi(_crowd.trust   + quality * 4,               0, 100)
	_crowd.patience = clampi(_crowd.patience + results.genre_score * 4, 0, 100)

func _risk_multiplier(risk: String) -> float:
	match risk:
		"Low":    return 1.0
		"Medium": return 1.8
		"High":   return 2.8
	return 1.0

func _show_coaching(song_data: Dictionary, results: Dictionary) -> void:
	var pick_idx := clampi(_picks_made, 0, COACHING.size() - 1)
	var good     := results.get("good", false) as bool
	var base_msg :String= COACHING[pick_idx][good]

	# Append mechanical breakdown
	var sign := "+" if results.points >= 0 else ""
	var breakdown := "\n\n[color=#aaaaaa]%s — %s | Energy %d | %s risk\nGenre: %s  •  Energy step: %s  •  Points: %s%d[/color]" % [
		song_data.get("title",  "?"),
		song_data.get("artist", "?"),
		song_data.get("energy", 0),
		song_data.get("risk",   "Low"),
		"✓ Match" if results.genre_match else "✗ Mismatch",
		"✓ Smooth" if results.energy_ok  else "✗ Too big a jump",
		sign, results.points,
	]

	_coaching_text.text = base_msg + breakdown

	# Colour the panel border to signal good / bad
	_coaching_ok.text = "Got it — keep going!" if _picks_made < 4 else "Finish night!"
	_coaching_panel.visible = true
	_coaching_panel.set_position(Vector2(
		(size.x - _coaching_panel.size.x) * 0.5,
		(size.y - _coaching_panel.size.y) * 0.5
	))

func _on_coaching_ok_pressed() -> void:
	_coaching_panel.visible = false
	if _picks_made >= 5:
		_finish_tutorial()
	else:
		_update_ui()
		_update_nav()

func _finish_tutorial() -> void:
	var victory :int= _score > 0 and _crowd.trust > 20 and _crowd.patience > 20
	var headline := "Tutorial Complete! 🎉" if victory else "Not bad for a first try!"
	var summary  := "You played a full 5-song set in the tutorial. Head back to the world and give the real venues a go!" if victory \
		else "The crowd was tough — try sequencing low-energy songs first and always match the venue genre."

	_feedback_label.text = "%s  Final score: %d" % [headline, _score]

	_coaching_ok.text = "Back to World"
	_coaching_text.text = "[b]%s[/b]\n%s\n\nFinal Score: [b]%d[/b]\nCrowd — E:%d  T:%d  P:%d" % [
		headline, summary, _score,
		_crowd.energy, _crowd.trust, _crowd.patience,
	]
	_coaching_panel.visible = true
	_coaching_panel.set_position(Vector2(
		(size.x - _coaching_panel.size.x) * 0.5,
		(size.y - _coaching_panel.size.y) * 0.5
	))
	_coaching_ok.pressed.disconnect(_on_coaching_ok_pressed)
	_coaching_ok.pressed.connect(_on_exit_pressed)

func _on_exit_pressed() -> void:
	if GameManager != null:
		GameManager.return_to_world()

func _set_index(new_idx: int) -> void:
	_current_index = clampi(new_idx, 0, maxi(_card_count() - 1, 0))
	_scroll_to_current()
	_update_nav()

func _card_count() -> int:
	return maxi(_card_area.get_child_count() - 2, 0)  # exclude spacers

func _scroll_to_current() -> void:
	_record_width = _TARGET_CARD_WIDTH + _card_area.get_theme_constant("separation")
	var target_x := _current_index * _record_width
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(_scroll, "scroll_horizontal", target_x, 0.25)

func _refresh_carousel_layout() -> void:
	var center_pad := maxf((_scroll.size.x - _TARGET_CARD_WIDTH) * 0.5, 0.0)
	_left_spacer.custom_minimum_size.x  = center_pad
	_right_spacer.custom_minimum_size.x = center_pad
	_record_width = _TARGET_CARD_WIDTH + _card_area.get_theme_constant("separation")
	_scroll_to_current()

func _update_nav() -> void:
	var has_cards := _card_count() > 0
	_left_btn.disabled  = (not has_cards) or _current_index <= 0
	_right_btn.disabled = (not has_cards) or _current_index >= _card_count() - 1


func _update_ui() -> void:
	_score_label.text  = "Score: %d" % _score
	_crowd_label.text  = _crowd_text()
	_venue_label.text  = "Preferred Genre: %s   |   Songs played: %d / 5" % [_venue_genre, _picks_made]
	if not _coaching_panel.visible:
		_feedback_label.text = "Pick your next track! (%d left)" % (5 - _picks_made) if _picks_made < 5 \
			else "Set complete!"

func _crowd_text() -> String:
	return "Crowd  —  Energy: %d   Trust: %d   Patience: %d" % [
		_crowd.energy, _crowd.trust, _crowd.patience
	]
