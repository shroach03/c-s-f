## crate_dig_manager.gd
## Crate-digging phase. Emits signals upward; does NOT call GameManager directly.
extends Control
 
signal new_song_unlocked(song_data)
signal digging_finished(inventory: Array)
signal go_to_world_pressed   # GameManager connects this to return_to_world()
 
# ── Node refs ────────────────────────────────────────────────────────────────
@onready var dig_button     : Button        = $Shell/MainSplit/LeftPanel/ButtonRow/CrateButton
@onready var go_world_btn   : Button        = $Shell/MainSplit/LeftPanel/ButtonRow/GoToWorld
@onready var status_label   : Label         = $Shell/MainSplit/LeftPanel/CrateLabel
@onready var display_area   : GridContainer = $Shell/MainSplit/LeftPanel/CardPanel/ScrollContainer/UnlockedCardDisplay
@onready var info_title     : Label         = $Shell/MainSplit/RightPanel/InfoPanel/InfoVBox/NowPlayingTitle
@onready var info_artist    : Label         = $Shell/MainSplit/RightPanel/InfoPanel/InfoVBox/NowPlayingArtist
@onready var info_risk      : Label         = $Shell/MainSplit/RightPanel/InfoPanel/InfoVBox/NowPlayingRisk
@onready var info_energy_bars : Array = [
	$Shell/MainSplit/RightPanel/InfoPanel/InfoVBox/EnergyBars/Bar1,
	$Shell/MainSplit/RightPanel/InfoPanel/InfoVBox/EnergyBars/Bar2,
	$Shell/MainSplit/RightPanel/InfoPanel/InfoVBox/EnergyBars/Bar3,
	$Shell/MainSplit/RightPanel/InfoPanel/InfoVBox/EnergyBars/Bar4,
	$Shell/MainSplit/RightPanel/InfoPanel/InfoVBox/EnergyBars/Bar5,
]
 
const SONG_CARD_SCENE    = preload("res://scenes/song_card.tscn")
const TARGET_CARD_WIDTH  := 176.0
const MAX_DIGS           := 3
const CARDS_PER_DIG      := 5
 
var digs_remaining      : int   = MAX_DIGS
var master_database     : Array = []
var unlocked_inventory  : Array = []   # grows as player picks cards
 
# ════════════════════════════════════════════════════════════════════════════
 
## Called by GameManager before adding to the tree, so _ready() sees it.
func set_existing_inventory(existing: Array) -> void:
	unlocked_inventory = existing.duplicate(true)
 
func _ready() -> void:
	dig_button.pressed.connect(_on_dig_pressed)
	go_world_btn.pressed.connect(_on_go_to_world_pressed)
	resized.connect(_update_grid_columns)
	_update_grid_columns()
 
	if SongDatabase and SongDatabase.SONGS:
		master_database = SongDatabase.SONGS.duplicate(true)
	else:
		status_label.text = "ERROR: SongDatabase not found"
		dig_button.disabled = true
		return
 
	_refresh_status()
 
# ════════════════════════════════════════════════════════════════════════════
# Dig flow
# ════════════════════════════════════════════════════════════════════════════
 
func _on_dig_pressed() -> void:
	if digs_remaining <= 0:
		return
	GameManager.play_sfx("click_button")
	digs_remaining -= 1
	dig_button.disabled = true
 
	for child in display_area.get_children():
		child.queue_free()
 
	status_label.text = "Searching crate…"
	await get_tree().create_timer(0.5).timeout
	_reveal_crate_contents(CARDS_PER_DIG)
	_refresh_status()
 
	if digs_remaining > 0:
		dig_button.disabled = false
 
func _reveal_crate_contents(amount: int) -> void:
	var pool :Array = master_database.duplicate(true)
	pool.shuffle()
	for i in range(min(amount, pool.size())):
		var card = SONG_CARD_SCENE.instantiate()
		display_area.add_child(card)
		card.setup_card(pool[i], {"context": "selection"})
		card.song_selected.connect(_on_card_selected)
 
func _on_card_selected(card_instance, song_data: Dictionary) -> void:
	if not unlocked_inventory.has(song_data):
		unlocked_inventory.append(song_data)
		card_instance.modulate = Color(0.5, 1.0, 0.6)
		new_song_unlocked.emit(song_data)
		_update_now_playing(song_data)
	else:
		card_instance.modulate = Color(0.5, 1.0, 0.6)
 
	_refresh_status()
 
func _on_go_to_world_pressed() -> void:
	GameManager.play_sfx("click_button")
	digging_finished.emit(unlocked_inventory.duplicate(true))
	go_to_world_pressed.emit()
 
# ════════════════════════════════════════════════════════════════════════════
# UI helpers
# ════════════════════════════════════════════════════════════════════════════
 
func _refresh_status() -> void:
	if digs_remaining > 0:
		status_label.text = "Pick Crate! %d digs left  |  Inventory: %d" % [digs_remaining, unlocked_inventory.size()]
	else:
		status_label.text = "No digs left. Head back when ready!  |  Inventory: %d" % unlocked_inventory.size()
 
func _update_now_playing(song_data: Dictionary) -> void:
	info_title.text  = song_data.get("title",  "Unknown")
	info_artist.text = song_data.get("artist", "Unknown")
	match song_data.get("risk", "Low"):
		"High":   info_risk.text = "HIGH RISK"
		"Medium": info_risk.text = "MEDIUM RISK"
		_:        info_risk.text = "LOW RISK"
	var energy : int = clampi(song_data.get("energy", 1), 1, 5)
	for i in range(info_energy_bars.size()):
		info_energy_bars[i].visible = i < energy
 
func _update_grid_columns() -> void:
	var w : int = max(size.x - 120.0, TARGET_CARD_WIDTH)
	display_area.columns = max(2, int(floor(w / TARGET_CARD_WIDTH)))
