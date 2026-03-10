extends Control
signal song_selected(card_instance, card_data_played)

@onready var title_label = $CardBack/Content/TitleLabel/loadTitle
@onready var artist_label = $CardBack/Content/ArtistLabel/loadArtist
@onready var genre_label = $CardBack/Content/GenreLabel/loadGenre
@onready var risk_label = $CardBack/Content/RiskLabel/loadRisk
@onready var energy_label = $CardBack/Content/EnergyLabel/loadEnergy
@onready var tag_label = $CardBack/Content/TagLabel/loadTag
@onready var card_button=$CardBack/Button
var current_song_data: Dictionary = {}

func setup_card(song_data: Dictionary) -> void:
	self.current_song_data=song_data
	if title_label:
		title_label.text = song_data.get("title", "Unknown")
	
	if artist_label:
		artist_label.text = "by " + song_data.get("artist", "Unknown")
		
	if genre_label:
		genre_label.text = song_data.get("genre", "Unknown")
		
	if risk_label:
		risk_label.text = "Risk: " + song_data.get("risk", "Low")
		
	if energy_label:
		energy_label.text = "Energy: %d / 5" % song_data.get("energy", 0)
		
	if tag_label:
		tag_label.text = song_data.get("tag", "") 

	# Safely connect the button
	if has_node("CardBack/Button"):
		var btn = $CardBack/Button
		if not btn.is_connected("pressed", _on_button_pressed):
			btn.pressed.connect(_on_button_pressed)

	# Reset visual state in case this card was reused
	


#
func _on_button_pressed() -> void:
	# This sends the signal up to your SongDeckManager
	emit_signal("song_selected",self, current_song_data)
	# Optional: Visual feedback
	$CardBack/Button.disabled = true 
	modulate = Color(0.5, 0.5, 0.5) # Darken the card to show it's used
	
