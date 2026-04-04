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
##   5. Delegate collectible management to CollectibleSpawner.
##   6. Delegate chaser AI lifecycle to ChaserManager.
##   7. Delegate pause UI to PauseDialog.
##
## UI, HUD, and TTS are handled by child components:
##   - GameHUD      → top-bar stopwatch, word display, move counter
##   - WinScreen    → win/gotcha overlay, countdown, mode suggestions
##   - TTSManager   → background-threaded voice hints
## ---------------------------------------------------------------------------
class_name GameManager
extends Node


# ── Child-node references ────────────────────────────────────────────────────

@onready var maze_generator:     MazeGenerator      = $MazeGenerator
@onready var maze_renderer:      MazeRenderer        = $MazeRenderer
@onready var player:             PlayerController    = $Player
@onready var hud:                GameHUD             = $HUD
@onready var win_screen:         WinScreen           = $WinScreen
@onready var pause_dialog:       PauseDialog         = $PauseDialog
@onready var collectible_spawner: CollectibleSpawner = $CollectibleSpawner
@onready var chaser_manager:     ChaserManager       = $ChaserManager


# ── Game State ───────────────────────────────────────────────────────────────

var _current_maze: MazeData = null
var _elapsed_time: float = 0.0
var _move_count: int = 0
var _is_paused: bool = false
var _is_gotcha_screen: bool = false


# ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	# GameManager remains active to handle pause, but pauses children by default
	process_mode = Node.PROCESS_MODE_ALWAYS
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	maze_generator.process_mode = Node.PROCESS_MODE_PAUSABLE
	maze_renderer.process_mode = Node.PROCESS_MODE_PAUSABLE
	hud.process_mode = Node.PROCESS_MODE_PAUSABLE

	# Wire up the player signals.
	player.reached_end.connect(_on_player_reached_end)
	player.moved.connect(_on_player_moved)

	# Wire up the win screen signals.
	win_screen.next_round_pressed.connect(_on_next_round_pressed)
	win_screen.harder_pressed.connect(_on_harder_pressed)
	win_screen.home_pressed.connect(_on_home_pressed)
	win_screen.suggestion_pressed.connect(_on_suggestion_pressed)
	win_screen.chaser_toggled_pressed.connect(_on_chaser_toggled_pressed)
	win_screen.screen_shown.connect(_on_win_screen_shown)
	win_screen.screen_hidden.connect(_on_win_screen_hidden)

	# Wire up the pause dialog signals.
	pause_dialog.confirmed.connect(_on_pause_confirmed)
	pause_dialog.cancelled.connect(_on_pause_cancelled)

	# Wire up the collectible spawner.
	collectible_spawner.collectible_gathered.connect(_on_collectible_gathered)

	# Wire up the chaser manager.
	chaser_manager.caught_player.connect(_on_chaser_caught_player)
	chaser_manager.set_player_pos_getter(func() -> Vector2i: return player.grid_pos)

	# Tell the maze renderer to leave space for the HUD bar.
	maze_renderer.top_margin = hud.get_height()

	# Generate and display the first maze.
	_start_new_maze()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if not win_screen.is_active():
			_toggle_pause()


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
		_toggle_pause()
		get_viewport().set_input_as_handled()


# ── Pause ────────────────────────────────────────────────────────────────────

func _toggle_pause() -> void:
	if _is_paused:
		_unpause()
	else:
		_pause()


func _pause() -> void:
	_is_paused = true
	get_tree().paused = true
	pause_dialog.show_dialog()


func _unpause() -> void:
	_is_paused = false
	get_tree().paused = false
	pause_dialog.hide_dialog()


func _on_pause_confirmed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_pause_cancelled() -> void:
	_unpause()


# ── Game Flow ────────────────────────────────────────────────────────────────

## Generate a fresh maze, render it, and place the player.
func _start_new_maze() -> void:
	win_screen.hide_screen()
	
	# Ensure tree is unpaused (win/gotcha screens pause the tree via signal)
	get_tree().paused = false
	_elapsed_time = 0.0
	_move_count = 0
	hud.update_moves(_move_count)

	# Cleanup old entities
	collectible_spawner.clear()
	chaser_manager.cleanup()

	# Re-enable player
	player.set_process(true)
	player.set_physics_process(true)
	player.set_process_input(true)

	# 1. Generate
	_current_maze = maze_generator.generate()

	# 2. Render
	maze_renderer.draw_maze(_current_maze)

	# 3. Build navigation for chaser
	chaser_manager.build_nav_map(maze_renderer)
	chaser_manager.set_grid_width(_current_maze.grid_size.x)

	# 4. Spawn collectibles if applicable
	if Config.game_mode != Config.GameMode.NORMAL:
		collectible_spawner.spawn(_current_maze, maze_renderer)

	# Update word display in HUD
	hud.update_word_display(Config.current_word, Config.game_mode)

	# 5. Place player at Start cell
	var start_cell: MazeData.CellData = _current_maze.get_start_cell()
	if start_cell:
		player.reset_movement()
		player.grid_pos      = start_cell.coords
		player.maze_data     = _current_maze
		player.maze_renderer = maze_renderer
		player.position      = maze_renderer.grid_to_pixel(start_cell.coords)

	# Rebuild the player visual (picks up theme sprites if available).
	player.rebuild_visual()


# ── Player Event Handlers ────────────────────────────────────────────────────

func _on_player_reached_end() -> void:
	if win_screen.is_active(): return
	_is_gotcha_screen = false

	# Stop Chaser
	chaser_manager.stop()

	# Freeze player
	_freeze_player()

	# Full word progress update if word mode
	if Config.game_mode == Config.GameMode.WORDS:
		hud.light_up_letter(collectible_spawner.get_word_next_index())

	win_screen.show_win(_format_time(), _move_count)
	win_screen.update_suggestions(Config.game_mode)


func _on_player_moved(new_pos: Vector2i) -> void:
	_move_count += 1
	hud.update_moves(_move_count)

	# Check chaser trigger and collision
	if not chaser_manager.is_active():
		chaser_manager.check_trigger(_move_count)
		if chaser_manager.is_active():
			chaser_manager.spawn(_current_maze, maze_renderer)

	chaser_manager.check_collision_at(new_pos)

	# Check collectible
	if collectible_spawner.check_collection(new_pos):
		pass  # Event handled via signal


# ── Collectible Callbacks ────────────────────────────────────────────────────

func _on_collectible_gathered(value_str: String, collect_index: int, lang: String) -> void:
	if not Config.voice_hints: return
	
	if Config.game_mode == Config.GameMode.WORDS:
		# Words mode: light up letter and speak it
		hud.light_up_letter(collect_index)
		TTS.speak(value_str, 0.85, lang)

		# Auto-advanced spaces: light them up in the HUD
		var next_idx: int = collectible_spawner.get_word_next_index()
		for i in range(collect_index + 1, next_idx):
			hud.light_up_letter(i)

		# Check for word/sub-word boundary (spaces were skipped) or full completion
		var word_full: String = Config.current_word.get("word", "")
		var crossed_space: bool = (next_idx > collect_index + 1)
		var word_complete: bool = (next_idx >= word_full.length())

		if crossed_space or word_complete:
			var phrase_so_far: String = word_full.substr(0, next_idx).strip_edges()
			if not phrase_so_far.is_empty():
				var word_lang: String = lang
				get_tree().create_timer(0.6).timeout.connect(
					func(): TTS.speak(phrase_so_far, 0.7, word_lang)
				)
	else:
		TTS.speak(value_str, 0.85)


# ── Chaser Callbacks ─────────────────────────────────────────────────────────

func _on_chaser_caught_player() -> void:
	_is_gotcha_screen = true
	_freeze_player()
	win_screen.show_gotcha(_format_time(), _move_count)


# ── Win Screen Pause Ownership ───────────────────────────────────────────────

## GameManager owns the tree pause state for win/gotcha overlays.
func _on_win_screen_shown() -> void:
	get_tree().paused = true

func _on_win_screen_hidden() -> void:
	get_tree().paused = false

func _on_next_round_pressed() -> void:
	_start_new_maze()

func _on_harder_pressed() -> void:
	if _is_gotcha_screen:
		# Gotcha = make it easier
		Config.difficulty = clampi(Config.difficulty - 1, 0, 4)
	else:
		# Win = make it harder
		if Config.difficulty >= 6: return
		Config.difficulty = clampi(Config.difficulty + 1, 0, 6)

	Config.save_settings()
	_start_new_maze()

func _on_home_pressed() -> void:
	win_screen.hide_screen()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_suggestion_pressed(target_mode: int) -> void:
	Config.game_mode = target_mode
	Config.save_settings()
	_start_new_maze()

func _on_chaser_toggled_pressed(target_level: int) -> void:
	Config.chaser_level = target_level
	Config.save_settings()
	_start_new_maze()


# ── Private Helpers ──────────────────────────────────────────────────────────

## Freeze player processing (used when game ends or chaser catches).
func _freeze_player() -> void:
	player.set_process(false)
	player.set_physics_process(false)
	player.set_process_input(false)


## Format elapsed time as MM:SS string.
func _format_time() -> String:
	var elapsed_int: int = int(_elapsed_time)
	return "%02d:%02d" % [elapsed_int / 60, elapsed_int % 60]
