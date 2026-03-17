extends Control

signal crate_selected
signal venue_selected(venue_data)

@onready var crate_button = $WorldShell/RecordStore/GoToCrateDig
@onready var crowd_label = $WorldShell/CrowdSummary

var venue_buttons: Array = []
var venue_data: Array = []
var flash_time := 0.0

func _ready() -> void:
	venue_buttons = [
		$WorldShell/VenueRoadmap/Venue1Panel/GoToV1,
		$WorldShell/VenueRoadmap/Venue2Panel/GoToV2,
		$WorldShell/VenueRoadmap/Venue3Panel/GoToV3
	]
	crate_button.pressed.connect(func(): crate_selected.emit())
	for i in range(venue_buttons.size()):
		venue_buttons[i].pressed.connect(_on_venue_pressed.bind(i))

func setup_world(options: Array, crowd_state: Dictionary, can_perform: bool = false):
	venue_data = options
	crowd_label.text = "Crowd State  E:%d  T:%d  P:%d" % [crowd_state.energy, crowd_state.trust, crowd_state.patience]
	for i in range(venue_buttons.size()):
		var button = venue_buttons[i]
		if i >= venue_data.size():
			button.hide()
			continue
		button.show()
		var v = venue_data[i]
		var genres = v.get("genres", ["Unknown"])
		button.text = "%s\n%s" % [v.get("name", "Venue"), "/".join(genres)]
		button.disabled = not can_perform
		button.tooltip_text = "Pick a venue after building a 5-song setlist." if not can_perform else "Start the show"

func _on_venue_pressed(index: int):
	if index < venue_data.size():
		venue_selected.emit(venue_data[index])

func _process(delta: float) -> void:
	flash_time += delta * 3.5
	for i in range(venue_buttons.size()):
		if i >= venue_data.size():
			continue
		var button = venue_buttons[i]
		var genres = venue_data[i].get("genres", ["Unknown"])
		var energy = 0.6 + (sin(flash_time + i) + 1.0) * 0.2
		button.modulate = _genre_color(genres[0], energy)

func _genre_color(genre: String, alpha: float) -> Color:
	match genre:
		"Euro":
			return Color(0.1, 0.9, 0.9, alpha)
		"RnB":
			return Color(0.3, 0.4, 1.0, alpha)
		"Pop":
			return Color(1.0, 0.5, 0.8, alpha)
		"Hiphop":
			return Color(1.0, 0.3, 0.3, alpha)
		"EDM":
			return Color(0.5, 1.0, 0.3, alpha)
		_:
			return Color(1.0, 1.0, 1.0, alpha)
