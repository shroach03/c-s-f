extends Control

signal crate_selected
signal setlist_selected
signal venue_selected(venue_data)

@onready var crate_button = $WorldShell/RecordStore/GoToCrateDig
@onready var crowd_label = $WorldShell/CrowdSummary
@onready var setlist_button = $WorldShell/RecordStore/GoToSetlist

var venue_buttons: Array = []
var venue_lights: Array = []
var venue_data: Array = []
var flash_time := 0.0

const GENRE_COLORS = {
	"Euro": Color(0.1, 0.9, 0.9, 1.0),
	"RnB": Color(0.3, 0.4, 1.0, 1.0),
	"Pop": Color(1.0, 0.5, 0.8, 1.0),
	"Hiphop": Color(1.0, 0.0, 0.0, 1.0),
	"EDM": Color(0.3, 1.0, 0.3, 1.0)
}

func _ready() -> void:
	venue_buttons = [
		$WorldShell/VenueRoadmap/Venue1Panel/GoToV1,
		$WorldShell/VenueRoadmap/Venue2Panel/GoToV2,
		$WorldShell/VenueRoadmap/Venue3Panel/GoToV3
	]
	venue_lights = [
		[
			$WorldShell/VenueRoadmap/Venue1Panel/GenreLights1/GenreLightA,
			$WorldShell/VenueRoadmap/Venue1Panel/GenreLights1/GenreLightB
		],
		[
			$WorldShell/VenueRoadmap/Venue2Panel/GenreLights2/GenreLightA,
			$WorldShell/VenueRoadmap/Venue2Panel/GenreLights2/GenreLightB
		],
		[
			$WorldShell/VenueRoadmap/Venue3Panel/GenreLights3/GenreLightA,
			$WorldShell/VenueRoadmap/Venue3Panel/GenreLights3/GenreLightB
		]
	]
	crate_button.pressed.connect(func(): crate_selected.emit())
	setlist_button.pressed.connect(func(): setlist_selected.emit())
	for i in range(venue_buttons.size()):
		venue_buttons[i].pressed.connect(_on_venue_pressed.bind(i))

func setup_world(options: Array, crowd_state: Dictionary, can_perform: bool = false):
	venue_data = options
	crowd_label.text = "Crowd State  E:%d  T:%d  P:%d" % [crowd_state.energy, crowd_state.trust, crowd_state.patience]
	for i in range(venue_buttons.size()):
		var button = venue_buttons[i]
		if i >= venue_data.size():
			button.hide()
			_update_light_pair(i, [])
			continue
		button.show()
		var v = venue_data[i]
		var genres = v.get("genres", ["Unknown"])
		button.text = "%s\n%s" % [v.get("name", "Venue"), "/".join(genres)]
		button.disabled = not can_perform
		button.tooltip_text = "Pick a venue after building a 5-song setlist." if not can_perform else "Start the show"
		_update_light_pair(i, genres)

func _on_venue_pressed(index: int):
	if index < venue_data.size():
		venue_selected.emit(venue_data[index])

func _process(delta: float) -> void:
	flash_time += delta * 4.0
	for i in range(venue_buttons.size()):
		if i >= venue_data.size():
			continue
		var genres = venue_data[i].get("genres", ["Unknown"])
		_animate_light_pair(i, genres)

func _update_light_pair(index: int, genres: Array) -> void:
	if index >= venue_lights.size():
		return
	for j in range(venue_lights[index].size()):
		var light: ColorRect = venue_lights[index][j]
		if j < genres.size():
			light.visible = true
			light.color = _genre_color(genres[j], 0.45)
		else:
			light.visible = false

func _animate_light_pair(index: int, genres: Array) -> void:
	if index >= venue_lights.size():
		return
	for j in range(venue_lights[index].size()):
		var light: ColorRect = venue_lights[index][j]
		if j >= genres.size():
			continue
		var pulse = 0.45 + 0.55 * (0.5 + 0.5 * sin(flash_time * (1.1 + j * 0.2) + index + j))
		light.color = _genre_color(genres[j], pulse)

func _genre_color(genre: String, alpha: float) -> Color:
	var base: Color = GENRE_COLORS.get(genre, Color.WHITE)
	return Color(base.r, base.g, base.b, alpha)
