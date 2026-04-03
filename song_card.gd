extends Control
signal song_selected(card_instance, card_data_played)

@onready var title_label = $TitleLabel/loadTitle
@onready var artist_label = $ArtistLabel/loadArtist
@onready var risk_label = $SleeveBack/RiskSticker
@onready var card_button = $Button
var current_song_data: Dictionary = {}

func setup_card(song_data: Dictionary, options: Dictionary = {}) -> void:
	current_song_data = song_data
	var context = options.get("context", "collection")
	var show_tag = options.get("show_tag", false)
	var show_button = options.get("show_button", true)
	title_label.text = song_data.get("title", "Unknown")
	artist_label.text = "by " + song_data.get("artist", "Unknown")
	#risk_label.text = "Risk: " + song_data.get("risk", "Low")
	if context == "performance":
		card_button.tooltip_text = "Play this track"
	elif context == "selection":
		card_button.tooltip_text = "Add or remove from setlist"
	else:
		card_button.tooltip_text = "Inspect"

	if not card_button.pressed.is_connected(_on_button_pressed):
		card_button.pressed.connect(_on_button_pressed)
	card_button.disabled = not show_button
	card_button.visible = show_button
	card_button.focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	card_button.mouse_filter = Control.MOUSE_FILTER_STOP
	modulate = Color.WHITE

func _on_button_pressed() -> void:
	if GameManager != null:
		GameManager.play_sfx("place_card")
	emit_signal("song_selected", self, current_song_data)
