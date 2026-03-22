## game_manager.gd
## ---------------------------------------------------------------------------
## Top-level orchestrator for the maze game.
##
## Responsibilities:
##   1. Tell MazeGenerator to create a new MazeData.
##   2. Tell MazeRenderer to draw it.
##   3. Spawn the Player at the Start cell.
##   4. Listen for the player's `reached_end` signal → show win feedback and
##      regenerate a new maze.
##   5. Spawn collectibles (numbers, letters, or word letters) based on mode.
##   6. Manage the Tag Partner (Chaser) AI lifecycle.
##
## UI, HUD, and TTS are delegated to child components:
##   - GameHUD      → top-bar stopwatch, word display, move counter
##   - WinScreen    → win/gotcha overlay, countdown, mode suggestions
##   - TTSManager   → background-threaded voice hints
## ---------------------------------------------------------------------------
class_name GameManager
extends Node


# ── Child-node references ────────────────────────────────────────────────────

@onready var maze_generator: MazeGenerator = $MazeGenerator
@onready var maze_renderer:  MazeRenderer  = $MazeRenderer
@onready var player:         PlayerController = $Player
@onready var hud:            GameHUD        = $HUD
@onready var win_screen:     WinScreen      = $WinScreen
@onready var tts:            TTSManager     = $TTSManager

const CollectibleScene = preload("res://scenes/collectible.tscn")
const ChaserScene = preload("res://scenes/chaser.tscn")


# ── Chaser State ─────────────────────────────────────────────────────────────

var _chaser: Node2D = null
var _nav_map: AStar2D = null
var _chaser_active: bool = false

# ── Pause State ─────────────────────────────────────────────────────────────

var _is_paused: bool = false
var _pause_dialog: CanvasLayer = null
var _pause_no_button: Button = null


# ── Game State ───────────────────────────────────────────────────────────────

var _current_maze: MazeData = null
var _collectibles: Dictionary = {}  # Vector2i -> Collectible
var _elapsed_time: float = 0.0
var _move_count: int = 0
var _word_next_index: int = 0


# ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	# GameManager remains active to handle pause, but pauses children by default
	process_mode = Node.PROCESS_MODE_ALWAYS
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	maze_generator.process_mode = Node.PROCESS_MODE_PAUSABLE
	maze_renderer.process_mode = Node.PROCESS_MODE_PAUSABLE
	hud.process_mode = Node.PROCESS_MODE_PAUSABLE
	tts.process_mode = Node.PROCESS_MODE_ALWAYS

	# Wire up the player signals.
	player.reached_end.connect(_on_player_reached_end)
	player.moved.connect(_on_player_moved)
	player.bumped.connect(_on_player_bumped)

	# Wire up the win screen signals.
	win_screen.next_round_pressed.connect(_on_next_round_pressed)
	win_screen.harder_pressed.connect(_on_harder_pressed)
	win_screen.home_pressed.connect(_on_home_pressed)
	win_screen.suggestion_pressed.connect(_on_suggestion_pressed)
	win_screen.chaser_toggled_pressed.connect(_on_chaser_toggled_pressed)

	# Tell the maze renderer to leave space for the HUD bar.
	maze_renderer.top_margin = hud.get_height()

	# Generate and display the first maze.
	_start_new_maze()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if not win_screen.is_active():
			if _is_paused:
				_hide_pause_dialog()
			else:
				_show_pause_dialog()


func _process(delta: float) -> void:
	# Stopwatch (only while playing, not during win screen or pause)
	if not win_screen.is_active() and not get_tree().paused:
		_elapsed_time += delta
		hud.update_time(_elapsed_time)


func _unhandled_input(event: InputEvent) -> void:
	# Android TV 'Back' button maps to ui_cancel
	if event.is_action_pressed("ui_cancel"):
		if win_screen.is_active():
			return
		
		if _is_paused:
			_hide_pause_dialog()
		else:
			_show_pause_dialog()
		get_viewport().set_input_as_handled()


# ── Pause Menu ───────────────────────────────────────────────────────────────

func _show_pause_dialog() -> void:
	if not _pause_dialog:
		_create_pause_dialog()
	
	_is_paused = true
	get_tree().paused = true
	_pause_dialog.visible = true
	if _pause_no_button:
		_pause_no_button.grab_focus()


func _hide_pause_dialog() -> void:
	_is_paused = false
	get_tree().paused = false
	if _pause_dialog:
		_pause_dialog.visible = false


func _create_pause_dialog() -> void:
	_pause_dialog = CanvasLayer.new()
	_pause_dialog.layer = 100
	_pause_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause_dialog)
	
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.anchors_preset = Control.PRESET_FULL_RECT
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_dialog.add_child(overlay)
	
	var center := CenterContainer.new()
	center.anchors_preset = Control.PRESET_FULL_RECT
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	
	var panel := PanelContainer.new()
	var style: StyleBoxFlat = UIHelpers.create_rounded_stylebox(
		Color(0.15, 0.17, 0.22), Color("#1188FF"), 20, 4
	)
	style.content_margin_left = 60
	style.content_margin_right = 60
	style.content_margin_top = 40
	style.content_margin_bottom = 40
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 30)
	panel.add_child(vbox)
	
	var lbl := Label.new()
	lbl.text = tr("quit_confirm")
	lbl.add_theme_font_size_override("font_size", 42)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl)
	
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)
	
	var yes_btn: Button = UIHelpers.create_styled_button(tr("yes"), 200, 80, Color("#FFCC00"))
	yes_btn.pressed.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	)
	hbox.add_child(yes_btn)
	
	_pause_no_button = UIHelpers.create_styled_button(tr("no"), 200, 80)
	_pause_no_button.pressed.connect(_hide_pause_dialog)
	hbox.add_child(_pause_no_button)


# ── Game Flow ────────────────────────────────────────────────────────────────

## Generate a fresh maze, render it, and place the player.
func _start_new_maze() -> void:
	win_screen.hide_screen()

	# Clear old collectibles
	for c in _collectibles.values():
		if is_instance_valid(c):
			c.queue_free()
	_collectibles.clear()

	# Reset round state
	_elapsed_time = 0.0
	_move_count = 0
	_word_next_index = 0
	hud.update_moves(_move_count)

	# Thorough Chaser Cleanup
	_chaser_active = false
	if _chaser and is_instance_valid(_chaser):
		_chaser.request_move.disconnect(_on_chaser_request_move)
		_chaser.queue_free()
	_chaser = null

	# Re-enable player
	player.set_process(true)
	player.set_physics_process(true)
	player.set_process_input(true)

	# 1. Generate
	_current_maze = maze_generator.generate()

	# 2. Render
	maze_renderer.draw_maze(_current_maze)

	# 2.2 Navigation for chaser
	_nav_map = maze_renderer.get_navigation_map()

	# 2.5 Spawn collectibles if applicable
	if Config.game_mode > 0:
		if Config.game_mode == 3:
			_spawn_word_collectibles()
		else:
			_spawn_collectibles()

	# Update word display in HUD
	hud.update_word_display(Config.current_word, Config.game_mode)

	# 3. Place player at Start cell
	var start_cell: MazeData.CellData = _current_maze.get_start_cell()
	if start_cell:
		player.reset_movement()
		player.grid_pos      = start_cell.coords
		player.maze_data     = _current_maze
		player.maze_renderer = maze_renderer
		player.position      = maze_renderer.grid_to_pixel(start_cell.coords)

	# Rebuild the player visual (picks up theme sprites if available).
	player._build_visual()

	# Re-enable player input (disabled during win sequence).
	player.set_process(true)


## Called when the player steps onto the End cell.
func _on_player_reached_end() -> void:
	if win_screen.is_active(): return

	# Stop Chaser
	_chaser_active = false
	if _chaser: _chaser.stop()

	# Freeze player
	player.set_process(false)
	player.set_physics_process(false)
	player.set_process_input(false)

	# Full word progress update if word mode
	if Config.game_mode == 3:
		hud.light_up_letter(_word_next_index)

	var elapsed_int: int = int(_elapsed_time)
	var mm: int = elapsed_int / 60
	var ss: int = elapsed_int % 60
	var time_str: String = "%02d:%02d" % [mm, ss]

	win_screen.show_win(time_str, _move_count)
	win_screen.update_suggestions(Config.game_mode)


# ── Win Screen Callbacks ─────────────────────────────────────────────────────

func _on_next_round_pressed() -> void:
	_start_new_maze()

func _on_harder_pressed() -> void:
	# The WinScreen sets button text to "challenge_mm" on Gotcha, "challenge_pp" on Win.
	# We check at the Config level which direction to go.
	if Config.difficulty > 0 and win_screen._harder_button and win_screen._harder_button.text == tr("challenge_mm"):
		Config.difficulty = clampi(Config.difficulty - 1, 0, 4)
	else:
		if Config.difficulty >= 4: return
		Config.difficulty = clampi(Config.difficulty + 1, 0, 4)

	Config.save_settings()
	_start_new_maze()

func _on_home_pressed() -> void:
	win_screen.hide_screen()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_suggestion_pressed(target_mode: int) -> void:
	Config.game_mode = target_mode
	Config.save_settings()
	_start_new_maze()

func _on_chaser_toggled_pressed() -> void:
	Config.chaser_enabled = not Config.chaser_enabled
	Config.save_settings()
	_start_new_maze()


# ── Collectibles ─────────────────────────────────────────────────────────────

## Spawn numbers or letters along the main path based on the game mode.
func _spawn_collectibles() -> void:
	if _current_maze == null or Config.game_mode <= 0:
		return

	var path_coords: Array[Vector2i] = _current_maze.main_path_coords

	# Exclude start and end cells
	var temp_path: Array[MazeData.CellData] = []
	for coord in path_coords:
		var c: MazeData.CellData = _current_maze.get_cell(coord)
		if not c.is_start and not c.is_end:
			temp_path.append(c)

	var L: int = temp_path.size()
	if L == 0:
		return

	var max_items: int = 26 if Config.game_mode == 2 else 50
	var num_items: int = maxi(1, mini(max_items, L / 3))
	var step: float = float(L) / float(num_items)

	for i in range(num_items):
		var idx: int = int(i * step + (step / 2.0))
		idx = mini(idx, L - 1)
		var cell: MazeData.CellData = temp_path[idx]

		var val_str: String = ""
		if Config.game_mode == 1:
			val_str = str(i + 1)
		elif Config.game_mode == 2:
			val_str = String.chr(65 + i)

		var col: Collectible = CollectibleScene.instantiate()
		col.process_mode = Node.PROCESS_MODE_PAUSABLE
		col.grid_pos = cell.coords
		col.value_str = val_str

		add_child(col)
		col.setup(maze_renderer.get_cell_size(), maze_renderer.theme)
		col.position = maze_renderer.grid_to_pixel(cell.coords)
		_collectibles[cell.coords] = col


## Spawn word-letter collectibles along the main path (Words mode).
func _spawn_word_collectibles() -> void:
	if _current_maze == null:
		return

	var lang: String = Config.get_effective_language()
	var word_data: Dictionary = WordList.get_random_word(lang, Config.difficulty)
	if word_data.is_empty():
		push_warning("GameManager: No word found for lang=%s diff=%d" % [lang, Config.difficulty])
		return

	Config.current_word = word_data
	_word_next_index = 0

	var word: String = word_data.get("word", "")
	if word.is_empty():
		return

	var path_coords: Array[Vector2i] = _current_maze.main_path_coords

	var temp_path: Array[MazeData.CellData] = []
	for coord in path_coords:
		var c: MazeData.CellData = _current_maze.get_cell(coord)
		if not c.is_start and not c.is_end:
			temp_path.append(c)

	var L: int = temp_path.size()
	if L == 0:
		return

	var collectible_chars: Array[int] = []
	for i in range(word.length()):
		if word[i] != " ":
			collectible_chars.append(i)

	var num_collectibles: int = collectible_chars.size()
	if num_collectibles == 0: return

	var step: float = float(L) / float(num_collectibles)

	for i in range(num_collectibles):
		var char_idx: int = collectible_chars[i]
		var path_idx: int = int(i * step + (step / 2.0))
		path_idx = mini(path_idx, L - 1)
		var cell: MazeData.CellData = temp_path[path_idx]

		var col: Collectible = CollectibleScene.instantiate()
		col.process_mode = Node.PROCESS_MODE_PAUSABLE
		col.grid_pos = cell.coords
		col.value_str = word[char_idx]
		col.collect_index = char_idx

		add_child(col)
		col.setup(maze_renderer.get_cell_size(), maze_renderer.theme)
		col.position = maze_renderer.grid_to_pixel(cell.coords)
		_collectibles[cell.coords] = col


# ── Player Event Handlers ────────────────────────────────────────────────────

func _on_player_bumped(_dir: Vector2i) -> void:
	# Bumps are NOT moves — do not increment _move_count or trigger chaser spawn.
	pass


func _on_player_moved(new_pos: Vector2i) -> void:
	_move_count += 1
	hud.update_moves(_move_count)
	_check_chaser_trigger()
	_check_chaser_collision()

	if _collectibles.has(new_pos):
		var col: Collectible = _collectibles[new_pos]
		var val: String = col.value_str

		# Words mode: enforce collection order
		if Config.game_mode == 3 and col.collect_index >= 0:
			var word_lang: String = Config.current_word.get("lang", "")

			if col.collect_index == _word_next_index:
				col.collect()
				_collectibles.erase(new_pos)
				hud.light_up_letter(_word_next_index)
				tts.speak(val, 0.85, word_lang)

				_word_next_index += 1

				var word_full: String = Config.current_word.get("word", "")
				var hit_word_boundary: bool = false

				while _word_next_index < word_full.length() and word_full[_word_next_index] == " ":
					hud.light_up_letter(_word_next_index)
					_word_next_index += 1
					hit_word_boundary = true

				if hit_word_boundary or _word_next_index >= word_full.length():
					var phrase_so_far: String = word_full.substr(0, _word_next_index).strip_edges()
					if not phrase_so_far.is_empty():
						get_tree().create_timer(1.2).timeout.connect(func(): tts.speak(phrase_so_far, 0.7, word_lang))
			else:
				_shake_collectible(col)
		else:
			col.collect()
			_collectibles.erase(new_pos)
			tts.speak(val, 0.85)


## Shake a collectible to indicate wrong collection order.
func _shake_collectible(col: Collectible) -> void:
	var base_pos: Vector2 = col.position
	var tw: Tween = col.create_tween()
	tw.tween_property(col, "position", base_pos + Vector2(8, 0), 0.04)
	tw.tween_property(col, "position", base_pos + Vector2(-8, 0), 0.04)
	tw.tween_property(col, "position", base_pos + Vector2(4, 0), 0.04)
	tw.tween_property(col, "position", base_pos, 0.04)


# ── Chaser Logic ─────────────────────────────────────────────────────────────

func _check_chaser_trigger() -> void:
	if not Config.chaser_enabled or _chaser_active:
		return

	var threshold: int = 6 if Config.difficulty <= 1 else 10
	if _move_count >= threshold:
		_spawn_chaser()


func _spawn_chaser() -> void:
	_chaser_active = true
	var start_cell: MazeData.CellData = _current_maze.get_start_cell()
	if not start_cell: return

	_chaser = ChaserScene.instantiate()
	_chaser.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_chaser)
	_chaser.grid_pos = start_cell.coords
	_chaser.position = maze_renderer.grid_to_pixel(_chaser.grid_pos)
	_chaser.setup(maze_renderer)

	_chaser.request_move.connect(_on_chaser_request_move)
	_chaser.move_finished.connect(_check_chaser_collision)


func _on_chaser_request_move() -> void:
	if not _chaser or not _nav_map: return

	var player_pos: Vector2i = player.grid_pos
	var chaser_pos: Vector2i = _chaser.grid_pos

	if player_pos == chaser_pos:
		_on_chaser_caught_player()
		return

	var id_start: int = chaser_pos.y * _current_maze.grid_size.x + chaser_pos.x
	var id_end: int = player_pos.y * _current_maze.grid_size.x + player_pos.x

	var path: PackedInt64Array = _nav_map.get_id_path(id_start, id_end)
	if path.size() > 1:
		var next_id: int = path[1]
		var next_pos: Vector2i = Vector2i(next_id % _current_maze.grid_size.x, next_id / _current_maze.grid_size.x)
		_chaser.move_to(next_pos)


func _check_chaser_collision() -> void:
	if _chaser and _chaser.grid_pos == player.grid_pos:
		_on_chaser_caught_player()


func _on_chaser_caught_player() -> void:
	if not _chaser_active: return
	_chaser_active = false

	if _chaser: _chaser.stop()

	# Freeze player
	player.set_process(false)
	player.set_physics_process(false)
	player.set_process_input(false)

	var elapsed_int: int = int(_elapsed_time)
	var mm: int = elapsed_int / 60
	var ss: int = elapsed_int % 60
	var time_str: String = "%02d:%02d" % [mm, ss]

	win_screen.show_gotcha(time_str, _move_count)
