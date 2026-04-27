extends Control

signal continue_pressed

@onready var title_label:    Label  = $Backdrop/ColorRect/UILayer/TitleBlock/Title
@onready var subtitle_label: Label  = $Backdrop/ColorRect/UILayer/TitleBlock/Subtitle
@onready var score_value_label: Label = $Backdrop/ColorRect/UILayer/ScoreCard/ScoreVBox/ScoreValue
@onready var crowd_value_label: Label = $Backdrop/ColorRect/UILayer/InfoColumn/CrowdValue
@onready var continue_button:   Button = $Backdrop/ColorRect/UILayer/ContinueButton

@onready var victory_flare: ColorRect = $Backdrop/ColorRect/VictoryFlare
@onready var fail_flare:    ColorRect = $Backdrop/FailFlare
@onready var shell:         ColorRect = $Backdrop/ColorRect

var is_victory := false
var anim_time  := 0.0

func _ready() -> void:
	continue_button.pressed.connect(_on_continue_pressed)

func setup_result(victory: bool, final_score: int, crowd_state: Dictionary,
				  headline: String, summary: String) -> void:
	is_victory = victory
	title_label.text    = headline
	subtitle_label.text = summary
	score_value_label.text = str(final_score)
	crowd_value_label.text = "E:%d  T:%d  P:%d" % [
		crowd_state.get("energy",   0),
		crowd_state.get("trust",    0),
		crowd_state.get("patience", 0)
	]

	shell.color = Color(0.0862745, 0.113725, 0.188235, 0.95) \
		if victory else Color(0.156863, 0.0588235, 0.0823529, 0.95)
	victory_flare.color   = Color(1.0, 0.36, 0.76, 0.28)
	fail_flare.color      = Color(1.0, 0.2,  0.2,  0.24)
	victory_flare.visible = victory
	fail_flare.visible    = not victory
	continue_button.text  = "Book Another Night"

func _process(delta: float) -> void:
	anim_time += delta
	if is_victory:
		victory_flare.color.a = 0.15 + 0.18 * (0.5 + 0.5 * sin(anim_time * 3.4))
	else:
		fail_flare.color.a    = 0.12 + 0.14 * (0.5 + 0.5 * sin(anim_time * 6.0))

func _on_continue_pressed() -> void:
	continue_pressed.emit()
