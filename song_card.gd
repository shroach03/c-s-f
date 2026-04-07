extends Control
signal song_selected(card_instance, card_data_played)

@onready var title_label = $TitleLabel/loadTitle
@onready var artist_label = $ArtistLabel/loadArtist
@onready var risk_sticker = $SleeveBack/RiskSticker
@onready var card_button = $Button
@onready var energy_bars = [
	$EnergyBars/Bar1,
	$EnergyBars/Bar2,
	$EnergyBars/Bar3,
	$EnergyBars/Bar4,
	$EnergyBars/Bar5,
]

const RISK_COLORS := {
	"low": Color("#56c271"),
	"medium": Color("#f29d38"),
	"high": Color("#d9534f"),
}

const ENERGY_ACTIVE_COLOR := Color("56c271")
const ENERGY_INACTIVE_COLOR := Color(1, 1, 1, 0.2)
var current_song_data: Dictionary = {}

func setup_card(song_data: Dictionary, options: Dictionary = {}) -> void:
	current_song_data = song_data
	var context = options.get("context", "collection")
	var show_button = options.get("show_button", true)
	title_label.text = song_data.get("title", "Unknown")
	artist_label.text = "by " + song_data.get("artist", "Unknown")
	_apply_risk_visual(song_data.get("risk", "Low"))
	_apply_energy_visual(song_data.get("energy", 1))

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

func _apply_risk_visual(risk_value: Variant) -> void:
	var risk_key = str(risk_value).to_lower()
	var sticker_style := risk_sticker.get_theme_stylebox("panel") as StyleBoxFlat
	if sticker_style == null:
		return
	var style_copy = sticker_style.duplicate() as StyleBoxFlat
	style_copy.bg_color = RISK_COLORS.get(risk_key, Color("#56c271"))
	risk_sticker.add_theme_stylebox_override("panel", style_copy)

func _apply_energy_visual(energy_value: Variant) -> void:
	var energy = clampi(int(energy_value), 0, energy_bars.size())
	for index in range(energy_bars.size()):
		var bar = energy_bars[index]
		bar.color = ENERGY_ACTIVE_COLOR if index < energy else ENERGY_INACTIVE_COLOR

func _on_button_pressed() -> void:
	if GameManager != null:
		GameManager.play_sfx("place_card")
	emit_signal("song_selected", self, current_song_data)
