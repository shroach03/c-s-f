# CrateDiggingManager.gd
extends Control

signal new_song_unlocked(song_data)
signal digging_finished(inventory: Array)

@onready var dig_button = $Shell/MainSplit/LeftPanel/ButtonRow/CrateButton
@onready var status_label = $Shell/MainSplit/LeftPanel/CrateLabel
@onready var display_area = $Shell/MainSplit/LeftPanel/CardPanel/ScrollContainer/UnlockedCardDisplay
@onready var go_to_world_button = $Shell/MainSplit/LeftPanel/ButtonRow/GoToWorld
@onready var info_title: Label = $Shell/MainSplit/RightPanel/InfoPanel/InfoVBox/NowPlayingTitle
@onready var info_artist: Label = $Shell/MainSplit/RightPanel/InfoPanel/InfoVBox/NowPlayingArtist
@onready var info_risk: Label = $Shell/MainSplit/RightPanel/InfoPanel/InfoVBox/NowPlayingRisk
@onready var info_energy_bars: Array = [
	$Shell/MainSplit/RightPanel/InfoPanel/InfoVBox/EnergyBars/Bar1,
	$Shell/MainSplit/RightPanel/InfoPanel/InfoVBox/EnergyBars/Bar2,
	$Shell/MainSplit/RightPanel/InfoPanel/InfoVBox/EnergyBars/Bar3,
	$Shell/MainSplit/RightPanel/InfoPanel/InfoVBox/EnergyBars/Bar4,
	$Shell/MainSplit/RightPanel/InfoPanel/InfoVBox/EnergyBars/Bar5
]

const MAX_DIGS = 3
const SONG_CARD_SCENE = preload("res://scenes/song_card.tscn")
const TARGET_CARD_WIDTH := 176.0

var digs_remaining: int = MAX_DIGS
var master_database: Array = []
var unlocked_inventory: Array = []

func set_existing_inventory(existing_inventory: Array) -> void:
	unlocked_inventory = existing_inventory.duplicate(true)

func _ready():
	go_to_world_button.show()
	go_to_world_button.pressed.connect(_on_go_to_world_pressed)
	dig_button.pressed.connect(_on_dig_button_pressed)
	if not resized.is_connected(_update_grid_columns):
		resized.connect(_update_grid_columns)
	_update_grid_columns()
	if SongDatabase and SongDatabase.SONGS:
		master_database = SongDatabase.SONGS.duplicate(true)
		if unlocked_inventory.is_empty() and GameManager != null:
			unlocked_inventory = GameManager.player_collection.duplicate(true)
		status_label.text = "Pick Crate! %d picks left | Inventory: %d" % [digs_remaining, unlocked_inventory.size()]
	else:
		status_label.text = "ERROR: database not found"
		dig_button.disabled = true

func _update_grid_columns() -> void:
	var available_width = max(size.x - 120.0, TARGET_CARD_WIDTH)
	display_area.columns = max(2, int(floor(available_width / TARGET_CARD_WIDTH)))

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
		_update_now_playing(song_data)
		new_song_unlocked.emit(song_data)
	elif card_instance.modulate != Color(0.5, 1.0, 0.6):
		card_instance.modulate = Color(0.5, 1.0, 0.6)
		status_label.text = "Already owned. Inventory total: %d" % unlocked_inventory.size()
		
func _update_now_playing(song_data: Dictionary) -> void:
	info_title.text = song_data.get("title", "Unknown")
	info_artist.text = song_data.get("artist", "Unknown")
	match song_data.get("risk", "Low"):
		"High":
			info_risk.text = "HIGH RISK"
		"Medium":
			info_risk.text = "MEDIUM RISK"
		_:
			info_risk.text = "LOW RISK"
	var energy := clampi(song_data.get("energy", 1), 1, 5)
	for i in range(info_energy_bars.size()):
		info_energy_bars[i].visible = i < energy

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
