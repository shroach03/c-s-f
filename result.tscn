extends Control

signal continue_pressed

@onready var title_label: Label = $Backdrop/ColorRect/VictoryFlare/TitleBlock/Title
@onready var subtitle_label: Label = $Backdrop/ColorRect/VictoryFlare/TitleBlock/Subtitle
@onready var score_value_label: Label = $Backdrop/ColorRect/VictoryFlare/ScoreCard/ScoreVBox/ScoreValue
@onready var crowd_value_label: Label = $Backdrop/ColorRect/VictoryFlare/InfoColumn/CrowdValue
@onready var continue_button: Button = $Backdrop/ColorRect/VictoryFlare/ContinueButton
@onready var victory_flare: Control = $Backdrop/ColorRect/VictoryFlare
@onready var fail_flare: Control = $Backdrop/ColorRect/FailFlare
@onready var shell: Control = $Backdrop/ColorRect

var is_victory := false
var anim_time := 0.0

func _ready() -> void:
	continue_button.pressed.connect(_on_continue_pressed)

func setup_result(victory: bool, final_score: int, crowd_state: Dictionary, headline: String, summary: String) -> void:
	is_victory = victory
	title_label.text = headline
	subtitle_label.text = summary
	score_value_label.text = str(final_score)
	crowd_value_label.text = "E:%d  T:%d  P:%d" % [
		crowd_state.get("energy", 0),
		crowd_state.get("trust", 0),
		crowd_state.get("patience", 0)
	]

	var panel_style := shell.get_theme_stylebox("panel").duplicate()
	if panel_style is StyleBoxFlat:
		panel_style.bg_color = Color(0.0862745, 0.113725, 0.188235, 0.95) if victory else Color(0.156863, 0.0588235, 0.0823529, 0.95)
		panel_style.border_color = Color(0.568627, 0.941176, 1.0, 1.0) if victory else Color(1.0, 0.470588, 0.560784, 1.0)
		shell.add_theme_stylebox_override("panel", panel_style)

	victory_flare.visible = victory
	fail_flare.visible = not victory
	continue_button.text = "Book Another Night"

func _process(delta: float) -> void:
	anim_time += delta
	if is_victory:
		victory_flare.modulate.a = 0.32 + 0.18 * (0.5 + 0.5 * sin(anim_time * 3.4))
		victory_flare.rotation = sin(anim_time * 0.7) * 0.03
	else:
		fail_flare.position.x = sin(anim_time * 5.0) * 10.0
		fail_flare.modulate.a = 0.18 + 0.12 * (0.5 + 0.5 * sin(anim_time * 6.0))

func _on_continue_pressed() -> void:
	continue_pressed.emit()
