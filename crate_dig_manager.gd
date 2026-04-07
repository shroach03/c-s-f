# CrateDiggingManager.gd
extends Control

signal new_song_unlocked(song_data)
signal digging_finished(inventory: Array)

@onready var dig_button = $Background/CrateButton
@onready var status_label = $Background/CrateLabel
@onready var display_area = $Background/ScrollContainer/RecordDisplay
@onready var go_to_world_button = $Background/GoToWorld
@onready var scroll_container = $Background/ScrollContainer
@onready var record_shelf = $Background/ScrollContainer/RecordDisplay
@onready var left_spacer = $Background/ScrollContainer/RecordDisplay/LeftSpacer
@onready var right_spacer = $Background/ScrollContainer/RecordDisplay/RightSpacer
@onready var left_button = $Background/LeftButton
@onready var right_button = $Background/RightButton

const MAX_DIGS = 3
const SONG_CARD_SCENE = preload("res://scenes/song_card.tscn")
const TARGET_CARD_WIDTH := 176.0

var digs_remaining: int = MAX_DIGS
var master_database: Array = []
var unlocked_inventory: Array = []
var current_index := 0
var record_width := 0.0

func set_existing_inventory(existing_inventory: Array) -> void:
	unlocked_inventory = existing_inventory.duplicate(true)

func _ready():
	go_to_world_button.show()
	go_to_world_button.pressed.connect(_on_go_to_world_pressed)
	dig_button.pressed.connect(_on_dig_button_pressed)
	left_button.pressed.connect(_on_left_button_pressed)
	right_button.pressed.connect(_on_right_button_pressed)
	if SongDatabase and SongDatabase.SONGS:
		master_database = SongDatabase.SONGS.duplicate(true)
		if unlocked_inventory.is_empty() and GameManager != null:
			unlocked_inventory = GameManager.player_collection.duplicate(true)
		status_label.text = "Pick Crate! %d picks left | Inventory: %d" % [digs_remaining, unlocked_inventory.size()]
	else:
		status_label.text = "ERROR: database not found"
		dig_button.disabled = true
	_update_carousel_layout()
	_update_nav_buttons()


func _update_carousel_layout() -> void:
	var center_padding = maxf((scroll_container.size.x - TARGET_CARD_WIDTH) * 0.5, 0.0)
	left_spacer.custom_minimum_size.x = center_padding
	right_spacer.custom_minimum_size.x = center_padding
	record_width = TARGET_CARD_WIDTH + record_shelf.get_theme_constant("separation")
	_scroll_to_current()

func _card_count() -> int:
	return maxi(record_shelf.get_child_count() - 2, 0)

func _on_left_button_pressed() -> void:
	_set_index(current_index - 1)

func _on_right_button_pressed() -> void:
	_set_index(current_index + 1)

func _set_index(new_index: int) -> void:
	current_index = clampi(new_index, 0, maxi(_card_count() - 1, 0))
	_scroll_to_current()
	_update_nav_buttons()

func _scroll_to_current() -> void:
	var target_x = current_index * record_width
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(scroll_container, "scroll_horizontal", target_x, 0.25)

func _update_nav_buttons() -> void:
	var has_cards = _card_count() > 0
	left_button.disabled = (not has_cards) or current_index <= 0
	right_button.disabled = (not has_cards) or current_index >= _card_count() - 1

func _clear_song_cards() -> void:
	for child in display_area.get_children():
		if child == left_spacer or child == right_spacer:
			continue
		child.queue_free()

func _on_dig_button_pressed() -> void:
	if GameManager != null:
		GameManager.play_sfx("click_button")
	if digs_remaining <= 0:
		return
	digs_remaining -= 1
	dig_button.disabled = true
	_clear_song_cards()
	status_label.text = "Searching Crate..."
	await get_tree().create_timer(0.5).timeout
	_reveal_crate_contents(5)
	status_label.text = "Digging... (%d left)| Inventory: %d" % [digs_remaining, unlocked_inventory.size()]

	if digs_remaining > 0:
		dig_button.disabled = false
		status_label.text = "Choose your songs, then pick the crate again! (%d picks left) | Inventory: %d" % [digs_remaining, unlocked_inventory.size()]
	else:
		dig_button.disabled = true
		status_label.text = "Go back to World whenever you're ready! Inventory: %d" % unlocked_inventory.size()

func _reveal_crate_contents(amount: int) -> void:
	var pool = master_database.duplicate(true)
	pool.shuffle()

	for i in range(min(amount, pool.size())):
		var song_data = pool[i]
		var card_visual = SONG_CARD_SCENE.instantiate()
		display_area.add_child(card_visual)
		display_area.move_child(card_visual, right_spacer.get_index())
		card_visual.setup_card(song_data, {"context": "selection"})
		card_visual.song_selected.connect(_on_card_selected_for_inventory)
		_set_index(0)

func _on_card_selected_for_inventory(card_instance, song_data):
	if not unlocked_inventory.has(song_data):
		unlocked_inventory.append(song_data)
		card_instance.modulate = Color(0.5, 1.0, 0.6)
		var song_title = song_data.get("title", "Unknown Song")
		status_label.text = "Added %s to inventory. Total: %d" % [song_title, unlocked_inventory.size()]
		new_song_unlocked.emit(song_data)
	elif card_instance.modulate != Color(0.5, 1.0, 0.6):
		card_instance.modulate = Color(0.5, 1.0, 0.6)
		status_label.text = "Already owned. Inventory total: %d" % unlocked_inventory.size()

func _on_go_to_world_pressed() -> void:
	if GameManager != null:
		GameManager.play_sfx("click_button")
	finish_digging_phase()

func _on_go_to_world_phase():
	if unlocked_inventory.size() < 5:
		status_label.text = "You need at least 5 songs to perform!"
		return
	finish_digging_phase()

func finish_digging_phase() -> void:
	digging_finished.emit(unlocked_inventory.duplicate(true))
	print("Signal 'digging_finished' emitted with ", unlocked_inventory.size(), " songs.")
