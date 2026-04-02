## venue.gd  (script for world.tscn)
## Handles the world hub. Emits signals upward; GameManager does all transitions.
extends Control
 
signal crate_selected
signal setlist_selected
signal venue_selected(venue_data: Dictionary)
 
# ── Node refs ────────────────────────────────────────────────────────────────
@onready var crate_button   : Button = $WorldShell/RecordStore/ButtonColumn/GoToCrateDig
@onready var setlist_button : Button = $WorldShell/BuildSetBuilding/GoToSetlist
@onready var crowd_label    : Label  = $WorldShell/CrowdSummary
 
var venue_buttons  : Array = []
var venue_lights   : Array = []
var venue_taglines : Array = []
var _venue_data    : Array = []   # local copy set by setup_world()
var flash_time     := 0.0
 
const GENRE_COLORS := {
	"Euro":   Color(0.1,  0.9,  0.9,  1.0),
	"RnB":    Color(0.3,  0.4,  1.0,  1.0),
	"Pop":    Color(1.0,  0.5,  0.8,  1.0),
	"Hiphop": Color(1.0,  0.0,  0.0,  1.0),
	"EDM":    Color(0.3,  1.0,  0.3,  1.0)
}
 
# ════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	venue_buttons = [
		$WorldShell/VenueRoadmap/Venue1Panel/GoToV1,
		$WorldShell/VenueRoadmap/Venue2Panel/GoToV2,
		$WorldShell/VenueRoadmap/Venue3Panel/GoToV3,
	]
	venue_taglines = [
		$WorldShell/VenueRoadmap/Venue1Panel/VenueCopy1,
		$WorldShell/VenueRoadmap/Venue2Panel/VenueCopy2,
		$WorldShell/VenueRoadmap/Venue3Panel/VenueCopy3,
	]
	venue_lights = [
		[$WorldShell/VenueRoadmap/Venue1Panel/GenreLights1/GenreLightA,
		 $WorldShell/VenueRoadmap/Venue1Panel/GenreLights1/GenreLightB],
		[$WorldShell/VenueRoadmap/Venue2Panel/GenreLights2/GenreLightA,
		 $WorldShell/VenueRoadmap/Venue2Panel/GenreLights2/GenreLightB],
		[$WorldShell/VenueRoadmap/Venue3Panel/GenreLights3/GenreLightA,
		 $WorldShell/VenueRoadmap/Venue3Panel/GenreLights3/GenreLightB],
	]
 
	crate_button.pressed.connect(_on_crate_pressed)
	setlist_button.pressed.connect(_on_setlist_pressed)
	for i in range(venue_buttons.size()):
		venue_buttons[i].pressed.connect(_on_venue_pressed.bind(i))
 
	_apply_button_styles()
 
## Called by GameManager immediately after instantiating the world scene.
func setup_world(options: Array, crowd_state: Dictionary, can_perform: bool) -> void:
	_venue_data = options
 
	crowd_label.text = "Crowd Readiness  E:%d  T:%d  P:%d" % [
		crowd_state.get("energy",   50),
		crowd_state.get("trust",    50),
		crowd_state.get("patience", 50)
	]
 
	for i in range(venue_buttons.size()):
		if i >= _venue_data.size():
			venue_buttons[i].hide()
			venue_taglines[i].hide()
			_update_light_pair(i, [])
			continue
 
		var v       : Dictionary = _venue_data[i]
		var genres  : Array      = v.get("genres", ["Unknown"])
		venue_buttons[i].show()
		venue_buttons[i].text     = "%s\n%s" % [v.get("name", "Venue"), "/".join(genres)]
		venue_buttons[i].disabled = not can_perform
		venue_buttons[i].tooltip_text = (
			"Build a 5-song setlist first!" if not can_perform
			else v.get("attribute", "Start the show")
		)
		venue_taglines[i].show()
		venue_taglines[i].text = "%s\n%s" % [v.get("tagline", ""), v.get("attribute", "")]
		_update_light_pair(i, genres)
 
# ════════════════════════════════════════════════════════════════════════════
# Button handlers
# ════════════════════════════════════════════════════════════════════════════
 
func _on_crate_pressed() -> void:
	GameManager.play_sfx("click_button")
	crate_selected.emit()
 
func _on_setlist_pressed() -> void:
	GameManager.play_sfx("click_button")
	setlist_selected.emit()
 
func _on_venue_pressed(index: int) -> void:
	if index < _venue_data.size():
		venue_selected.emit(_venue_data[index])
 
# ════════════════════════════════════════════════════════════════════════════
# Lights / animation
# ════════════════════════════════════════════════════════════════════════════
 
func _process(delta: float) -> void:
	flash_time += delta * 4.0
	for i in range(venue_buttons.size()):
		if i >= _venue_data.size():
			continue
		_animate_light_pair(i, _venue_data[i].get("genres", []))
 
func _update_light_pair(index: int, genres: Array) -> void:
	if index >= venue_lights.size():
		return
	for j in range(venue_lights[index].size()):
		var light : ColorRect = venue_lights[index][j]
		if j < genres.size():
			light.visible = true
			light.color   = _genre_color(genres[j], 0.45)
		else:
			light.visible = false
 
func _animate_light_pair(index: int, genres: Array) -> void:
	if index >= venue_lights.size():
		return
	for j in range(venue_lights[index].size()):
		var light : ColorRect = venue_lights[index][j]
		if j >= genres.size():
			continue
		var pulse := 0.45 + 0.55 * (0.5 + 0.5 * sin(flash_time * (1.1 + j * 0.2) + index + j))
		light.color = _genre_color(genres[j], pulse)
 
func _genre_color(genre: String, alpha: float) -> Color:
	var base : Color = GENRE_COLORS.get(genre, Color.WHITE)
	return Color(base.r, base.g, base.b, alpha)
 
func _apply_button_styles() -> void:
	for btn in [crate_button, setlist_button]:
		if btn == null:
			continue
		btn.custom_minimum_size       = Vector2(150, 46)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for btn in venue_buttons:
		if btn == null:
			continue
		btn.custom_minimum_size       = Vector2(170, 54)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
