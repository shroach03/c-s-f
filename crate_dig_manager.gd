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

const MAX_DIGS = 3
const SONG_CARD_SCENE = preload("res://scenes/song_card.tscn")
const TARGET_CARD_WIDTH := 176.0

var digs_remaining: int = MAX_DIGS
var master_database: Array = []
var unlocked_inventory: Array = []
var current_index = 0
var record_width = 0.0

func set_existing_inventory(existing_inventory: Array) -> void:
	unlocked_inventory = existing_inventory.duplicate(true)

func _ready():
	go_to_world_button.show()
	go_to_world_button.pressed.connect(_on_go_to_world_pressed)
	dig_button.pressed.connect(_on_dig_button_pressed)
	if SongDatabase and SongDatabase.SONGS:
		master_database = SongDatabase.SONGS.duplicate(true)
		if unlocked_inventory.is_empty() and GameManager != null:
			unlocked_inventory = GameManager.player_collection.duplicate(true)
		status_label.text = "Pick Crate! %d picks left | Inventory: %d" % [digs_remaining, unlocked_inventory.size()]
	else:
		status_label.text = "ERROR: database not found"
		dig_button.disabled = true

func _update_carousel_layout() -> void:
	# 1. Calculate how much space we need on the sides to keep the record centered
	# Logic: (Half the container width) - (Half the card width)
	var center_padding = (scroll_container.size.x / 2.0) - (TARGET_CARD_WIDTH / 2.0)
	
	# 2. Set the spacer sizes
	left_spacer.custom_minimum_size.x = center_padding
	right_spacer.custom_minimum_size.x = center_padding
	
	# 3. Calculate the distance for a single "click" or "snap"
	var separation = record_shelf.get_theme_constant("separation")
	record_width = TARGET_CARD_WIDTH + separation
	
	# 4. Snap to the current position
	_animate_scroll()

func _on_left_button_pressed():
	if current_index > 0:
		current_index -= 1
		_animate_scroll()

func _on_right_button_pressed():
	# -3 because of the 2 spacers and the 0-based index
	var total_records = record_shelf.get_child_count() - 2 
	if current_index < total_records - 1:
		current_index += 1
		_animate_scroll()

func _animate_scroll():
	var target_x = current_index * record_width
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	# Directly animate the scroll_horizontal property of the container
	tween.tween_property(scroll_container, "scroll_horizontal", target_x, 0.25)

func _on_dig_button_pressed():
	if GameManager != null:
		GameManager.play_sfx("click_button")
	if digs_remaining <= 0:
		return
	digs_remaining -= 1
	dig_button.disabled = true
	for child in display_area.get_children():
		child.queue_free()
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

func _reveal_crate_contents(amount: int):
	var pool = master_database.duplicate(true)
	pool.shuffle()

	for i in range(min(amount, pool.size())):
		var song_data = pool[i]
		var card_visual = SONG_CARD_SCENE.instantiate()
		display_area.add_child(card_visual)
		card_visual.setup_card(song_data, {"context": "selection"})
		card_visual.song_selected.connect(_on_card_selected_for_inventory)


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

func _perform_dig():
	if master_database.size() > 0:
		var newly_unlocked_song = master_database.pick_random()
		unlocked_inventory.append(newly_unlocked_song)
		status_label.text = "Discovered %s" % newly_unlocked_song.get("title", "Unknown")
	else:
		status_label.text = "Crate is empty"

func _on_go_to_world_pressed() -> void:
	if GameManager != null:
		GameManager.play_sfx("click_button")
	finish_digging_phase()

func _on_go_to_world_phase():
	if unlocked_inventory.size() < 5:
		status_label.text = "You need at least 5 songs to perform!"
		return
	finish_digging_phase()

func finish_digging_phase():
	digging_finished.emit(unlocked_inventory.duplicate(true))
	print("Signal 'digging_finished' emitted with ", unlocked_inventory.size(), " songs.")
