extends Control

signal crate_selected
signal setlist_selected
signal venue_selected(venue_data)

@onready var crate_button = $GoToCrateDig
@onready var setlist_button = $GoToSetlist

var venue_buttons: Array = []
var venue_lights: Array = []
var venue_data: Array = []
var flash_time := 0.0

const GENRE_COLORS = {
	"euro": Color(0.45, 0.82, 1.0, 1.0),
	"rnb": Color(0.13, 0.24, 0.82, 1.0),
	"pop": Color(1.0, 0.35, 0.73, 1.0),
	"hiphop": Color(1.0, 0.2, 0.2, 1.0),
	"edm": Color(0.35, 0.9, 0.45, 1.0)
}

func _ready() -> void:
	venue_buttons = [
		$GoToV1,
		$GoToV2,
		$GoToV3
	]
	venue_lights = [
		[
			$GenreLights1/GenreLightA,
			$GenreLights1/GenreLightB
		],
		[
			$GenreLights2/GenreLightA,
			$GenreLights2/GenreLightB
		],
		[
			$GenreLights3/GenreLightA,
			$GenreLights3/GenreLightB
		]
	]
	crate_button.pressed.connect(_on_crate_pressed)
	setlist_button.pressed.connect(func(): setlist_selected.emit())
	for i in range(venue_buttons.size()):
		venue_buttons[i].pressed.connect(_on_venue_pressed.bind(i))

func setup_world(options: Array, crowd_state: Dictionary, can_perform: bool = false):
	venue_data = options
	#crowd_label.text = "Crowd State  E:%d  T:%d  P:%d" % [crowd_state.energy, crowd_state.trust, crowd_state.patience]
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
		button.tooltip_text = "Pick a venue after building your 5-song setlist!" if not can_perform else "Start the show"
		_update_light_pair(i, genres)

func _on_crate_pressed() -> void:
	crate_selected.emit()

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
	var normalized = genre.to_lower().replace(" ", "")
	var base: Color = GENRE_COLORS.get(normalized, Color.WHITE)
	return Color(base.r, base.g, base.b, alpha)
