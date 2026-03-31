extends Control
signal song_selected(card_instance, card_data_played)

@onready var title_label: Label = $CardBack/VBox/loadTitle
@onready var artist_label: Label = $CardBack/VBox/loadArtist
@onready var genre_label: Label = $CardBack/VBox/MetaRow/loadGenre
@onready var risk_label: Label = $CardBack/VBox/MetaRow/loadRisk
@onready var energy_bars: Array = [
	$CardBack/VBox/EnergyBars/Bar1,
	$CardBack/VBox/EnergyBars/Bar2,
	$CardBack/VBox/EnergyBars/Bar3,
	$CardBack/VBox/EnergyBars/Bar4,
	$CardBack/VBox/EnergyBars/Bar5
]
@onready var card_button: Button = $CardBack/Button

var current_song_data: Dictionary = {}

func setup_card(song_data: Dictionary, options: Dictionary = {}) -> void:
	current_song_data = song_data
	var context: String = options.get("context", "collection")
	var show_button: bool = options.get("show_button", true)
	title_label.text = song_data.get("title", "Unknown")
	artist_label.text = song_data.get("artist", "Unknown")
	genre_label.text = song_data.get("genre", "Unknown")
	risk_label.text = _risk_label(song_data.get("risk", "Low"))
	_update_energy_bars(song_data.get("energy", 1))

	if context == "performance":
		card_button.tooltip_text = "Play this track"
	elif context == "selection":
		card_button.tooltip_text = "Add or remove from setlist"
	else:
		card_button.tooltip_text = "Inspect"

	card_button.disabled = not show_button
	card_button.visible = show_button
	modulate = Color.WHITE

func _update_energy_bars(energy: int) -> void:
	var bar_count := clampi(energy, 1, 5)
	for index in range(energy_bars.size()):
		energy_bars[index].visible = index < bar_count

func _risk_label(risk: String) -> String:
	match risk:
		"High":
			return "HIGH RISK"
		"Medium":
			return "MEDIUM RISK"
		_:
			return "LOW RISK"

func _on_button_pressed() -> void:
	if GameManager != null:
		GameManager.play_sfx("place_card")
	emit_signal("song_selected", self, current_song_data)
