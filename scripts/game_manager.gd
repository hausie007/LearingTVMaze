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

# ── Preloads ─────────────────────────────────────────────────────────────────

const MissionCatalog := preload("res://scripts/mission_catalog.gd")

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
var _completed_word_spoken: bool = false
var _last_spoken_word_segment_end: int = 0
var _race_robot: Node2D = null
var _race_robot_path: Array[Vector2i] = []
var _race_robot_index: int = 0
var _race_robot_timer: float = 0.0
var _race_robot_finished: bool = false


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
	win_screen.play_together_pressed.connect(_on_play_together_pressed)
	win_screen.screen_shown.connect(_on_win_screen_shown)
	win_screen.screen_hidden.connect(_on_win_screen_hidden)
	win_screen.set_is_multiplayer(false)

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


func _process(delta: float) -> void:
	# Stopwatch (only while playing, not during win screen or pause)
	if not win_screen.is_active() and not get_tree().paused:
		_elapsed_time += delta
		hud.update_time(_elapsed_time)
		_process_race_robot(delta)


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
	_unpause()
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
	_completed_word_spoken = false
	_last_spoken_word_segment_end = 0
	_race_robot_finished = false
	hud.update_moves(_move_count)
	hud.update_role("" if Config.game_style == Config.STYLE_NEXT_SYMBOL else Config.player_role)

	if not [Config.STYLE_PATH, Config.STYLE_NEXT_SYMBOL, Config.STYLE_RACE].has(Config.game_style):
		Config.game_style = Config.STYLE_PATH
	Config.game_mode = Config.game_mode_for_training(Config.training_type)
	if Config.game_style == Config.STYLE_RACE:
		Config.chaser_enabled = false
	if not Config.chaser_enabled:
		Config.chaser_level = Config.ChaserLevel.OFF

	# Cleanup old entities
	collectible_spawner.clear()
	chaser_manager.cleanup()
	_cleanup_race_robot()

	# Re-enable player
	player.set_process(true)
	player.set_physics_process(true)
	player.set_process_input(true)

	# 1. Generate
	_current_maze = maze_generator.generate_race(Config.grid_size) if Config.game_style == Config.STYLE_RACE else maze_generator.generate()
	if Config.game_style == Config.STYLE_RACE:
		_set_start_markers([
			Vector2i(0, 0),
			Vector2i(_current_maze.grid_size.x - 1, _current_maze.grid_size.y - 1),
		])

	# 2. Render
	maze_renderer.draw_maze(_current_maze)

	# 3. Build navigation for chaser
	chaser_manager.build_nav_map(maze_renderer)
	chaser_manager.set_grid_width(_current_maze.grid_size.x)

	# 4. Spawn collectibles if applicable
	if Config.game_mode != Config.GameMode.NORMAL:
		collectible_spawner.configure_dynamic_threat(
			func() -> Vector2i: return player.grid_pos,
			func() -> Array[Vector2i]: return chaser_manager.get_chaser_positions()
		)
		collectible_spawner.spawn(_current_maze, maze_renderer, Config.game_style)

	# Update word display in HUD
	_refresh_target_hud()

	# 5. Place player at Start cell
	var start_cell: MazeData.CellData = _current_maze.get_start_cell()
	if Config.game_style == Config.STYLE_RACE:
		start_cell = _current_maze.get_cell(Vector2i(0, 0))
	if start_cell:
		player.reset_movement()
		player.grid_pos      = start_cell.coords
		player.maze_data     = _current_maze
		player.maze_renderer = maze_renderer
		player.position      = maze_renderer.grid_to_pixel(start_cell.coords)

	# Rebuild the player visual (picks up theme sprites if available).
	player.rebuild_visual()

	if Config.game_style == Config.STYLE_RACE:
		_spawn_race_robot()


# ── Player Event Handlers ────────────────────────────────────────────────────

func _on_player_reached_end() -> void:
	if win_screen.is_active(): return
	if not collectible_spawner.is_complete():
		_refresh_target_hud()
		return
	_is_gotcha_screen = false

	# Stop Chaser
	chaser_manager.stop()

	# Freeze player
	_freeze_player()

	# Full word progress update if word mode
	if Config.game_mode == Config.GameMode.WORDS:
		hud.light_up_letter(collectible_spawner.get_word_next_index())
		_speak_completed_word_once()
	elif Config.game_style == Config.STYLE_RACE:
		_speak_race_completion_once()

	if Config.game_style == Config.STYLE_RACE:
		win_screen.show_race_win(_format_time(), _move_count, _race_player_character_id())
	else:
		win_screen.show_win(_format_time(), _move_count)


func _on_player_moved(new_pos: Vector2i) -> void:
	_move_count += 1
	hud.update_moves(_move_count)

	# Check chaser trigger and collision
	if Config.chaser_enabled and not chaser_manager.is_active():
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

		# Speak the whole word once when it is complete.
		var word_full: String = Config.current_word.get("word", "")
		var word_complete: bool = (next_idx >= word_full.length())
		if word_complete:
			_speak_completed_word_once(lang)
		elif next_idx > collect_index + 1:
			_speak_completed_word_segment(next_idx, lang)
	else:
		TTS.speak(value_str, 0.85)
	_refresh_target_hud()


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
	var max_diff: int = Config.DIFFICULTY_SIZES.size() - 1
	if _is_gotcha_screen:
		# Gotcha = make it easier
		Config.difficulty = clampi(Config.difficulty - 1, 0, max_diff)
	else:
		# Win = make it harder
		if Config.difficulty >= max_diff: return
		Config.difficulty = clampi(Config.difficulty + 1, 0, max_diff)

	Config.save_settings()
	_start_new_maze()

func _on_home_pressed() -> void:
	win_screen.hide_screen()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_play_together_pressed() -> void:
	# Build a MP host config from the current SP game settings
	var mission_id := Config.mission_id
	var style := Config.game_style
	var training := Config.training_type
	var chaser_enabled := Config.chaser_enabled
	var chaser_level := Config.chaser_level
	var difficulty := Config.difficulty
	var theme_dir := Config.theme_dir_name

	var loader := ThemeLoader.get_cached(theme_dir)
	var theme_title := loader.get_display_title(theme_dir) if loader != null else theme_dir.capitalize()
	var mission_title_key := MissionCatalog.mission_title_key(mission_id)
	var pickup_id := MissionCatalog.pickup_for_training(training)
	var pickup_title_key := MissionCatalog.pickup_title_key(pickup_id)

	var config: Dictionary = {
		"difficulty": difficulty,
		"difficulty_key": Config.DIFF_KEYS[difficulty] if difficulty < Config.DIFF_KEYS.size() else "medium",
		"mission_id": mission_id,
		"mission_title": tr(mission_title_key),
		"mission_goal_key": MissionCatalog.goal_key(mission_id, pickup_id, chaser_enabled, true),
		"role_summary_key": MissionCatalog.role_summary_key(mission_id, chaser_enabled),
		"game_style": style,
		"game_style_title": tr(mission_title_key),
		"training_type": training,
		"training_type_title": tr(pickup_title_key),
		"chaser_enabled": chaser_enabled and style != Config.STYLE_RACE,
		"chaser_level": chaser_level,
		"rotate_roles_after_round": false,
		"theme_dir": theme_dir,
		"theme_title": theme_title,
		"max_players": 2,
		"character_id": "",
	}

	win_screen.hide_screen()
	get_tree().paused = false
	NetworkManager.configure_host(config)
	var err := NetworkManager.start_host()
	if err != OK:
		push_error("Failed to start host from win screen: %d" % err)
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return
	get_tree().change_scene_to_file("res://scenes/multiplayer/host_lobby.tscn")


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

func _refresh_target_hud() -> void:
	if Config.game_mode == Config.GameMode.WORDS:
		hud.update_word_display(Config.current_word, Config.game_mode)
		for i in range(collectible_spawner.get_word_next_index()):
			hud.light_up_letter(i)
	else:
		hud.update_target_display(
			collectible_spawner.get_current_target(),
			collectible_spawner.get_next_collect_index(),
			collectible_spawner.get_total_collectibles()
		)
	_update_hud_mission_description()

func _update_hud_mission_description() -> void:
	var enlarge_hud := Config.game_mode != Config.GameMode.WORDS
	var goal_str := _get_solo_goal()
	
	if hud != null:
		hud.set_mission_description(goal_str, enlarge_hud)

func _get_solo_goal() -> String:
	if Config.game_style == Config.STYLE_RACE:
		return "Run to the middle first."
		
	var is_phase_one := false
	if Config.game_style in [Config.STYLE_PATH, Config.STYLE_NEXT_SYMBOL] and collectible_spawner != null:
		is_phase_one = not collectible_spawner.is_complete()
		
	if Config.game_style == Config.STYLE_PATH and not Config.chaser_enabled and Config.game_mode == Config.GameMode.NORMAL:
		return "Find the exit from the maze."
		
	var payload_text := "all letters"
	if Config.game_mode == Config.GameMode.NUMBERS:
		payload_text = "all numbers"
	elif Config.game_mode == Config.GameMode.WORDS:
		payload_text = "the words"
		
	if is_phase_one:
		if Config.chaser_enabled:
			return "Collect %s and do not get caught." % payload_text
		else:
			return "Collect %s." % payload_text
	else:
		return "Find the exit from the maze."

func _speak_completed_word_once(lang_override: String = "") -> void:
	if _completed_word_spoken or not Config.voice_hints:
		return
	var phrase: String = String(Config.current_word.get("word", "")).strip_edges()
	if phrase.is_empty():
		return
	_completed_word_spoken = true
	_last_spoken_word_segment_end = phrase.length()
	var word_lang: String = lang_override
	if word_lang.is_empty():
		word_lang = String(Config.current_word.get("lang", ""))
	get_tree().create_timer(1.2).timeout.connect(
		func(): TTS.speak(phrase, 0.7, word_lang)
	)

func _speak_completed_word_segment(segment_end: int, lang_override: String = "") -> void:
	if not Config.voice_hints:
		return
	var word_full: String = String(Config.current_word.get("word", ""))
	var clamped_end := clampi(segment_end, 0, word_full.length())
	if clamped_end <= _last_spoken_word_segment_end:
		return
	var phrase := word_full.substr(0, clamped_end).strip_edges()
	if phrase.is_empty():
		return
	_last_spoken_word_segment_end = clamped_end
	var word_lang: String = lang_override
	if word_lang.is_empty():
		word_lang = String(Config.current_word.get("lang", ""))
	get_tree().create_timer(1.45).timeout.connect(
		func(): TTS.speak(phrase, 0.7, word_lang)
	)

func _spawn_race_robot() -> void:
	if _current_maze == null or maze_renderer == null:
		return
	var center := _race_center()
	var robot_start := Vector2i(_current_maze.grid_size.x - 1, _current_maze.grid_size.y - 1)
	_race_robot_path = _race_path_from_corner(robot_start, center)
	if _race_robot_path.is_empty():
		return

	_race_robot = Node2D.new()
	_race_robot.name = "RaceRobot"
	var sprite := Sprite2D.new()
	var texture := Config.theme.chaser_texture if Config.theme != null else null
	if texture != null:
		sprite.texture = texture
		var cell_size := maze_renderer.get_cell_size()
		var tex_size := texture.get_size()
		if maxf(tex_size.x, tex_size.y) > 0.0:
			sprite.scale = Vector2.ONE * ((cell_size * 0.62) / maxf(tex_size.x, tex_size.y))
	else:
		var fallback := ColorRect.new()
		var size := maze_renderer.get_cell_size() * 0.52
		fallback.size = Vector2(size, size)
		fallback.position = -fallback.size / 2.0
		fallback.color = Color(1.0, 0.35, 0.35, 1.0)
		_race_robot.add_child(fallback)
		sprite = null
	if sprite != null:
		_race_robot.add_child(sprite)
	add_child(_race_robot)
	_race_robot_index = 0
	_race_robot_timer = _race_robot_step_interval()
	_race_robot.position = maze_renderer.grid_to_pixel(_race_robot_path[0])

func _cleanup_race_robot() -> void:
	if _race_robot != null and is_instance_valid(_race_robot):
		_race_robot.queue_free()
	_race_robot = null
	_race_robot_path.clear()
	_race_robot_index = 0
	_race_robot_timer = 0.0
	_race_robot_finished = false

func _process_race_robot(delta: float) -> void:
	if Config.game_style != Config.STYLE_RACE:
		return
	if _race_robot == null or _race_robot_finished or win_screen.is_active():
		return
	if _race_robot_path.is_empty():
		return
	_race_robot_timer -= delta
	if _race_robot_timer > 0.0:
		return
	_race_robot_timer = _race_robot_step_interval()
	_race_robot_index += 1
	if _race_robot_index >= _race_robot_path.size():
		_race_robot_finished = true
		_is_gotcha_screen = true
		_freeze_player()
		win_screen.show_race_gotcha(_format_time(), _move_count, _race_robot_character_id())
		return
	var target := maze_renderer.grid_to_pixel(_race_robot_path[_race_robot_index])
	var tween := _race_robot.create_tween()
	tween.tween_property(_race_robot, "position", target, Config.tween_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _race_robot_step_interval() -> float:
	var base := 0.72
	var difficulty_factor := 1.0 - (float(clampi(Config.difficulty, 0, 6)) * 0.055)
	return maxf(0.34, base * difficulty_factor)

func _speak_race_completion_once() -> void:
	if not Config.voice_hints:
		return
	if Config.game_mode == Config.GameMode.WORDS:
		_speak_completed_word_once()

func _race_center() -> Vector2i:
	var end_cell := _current_maze.get_end_cell() if _current_maze != null else null
	if end_cell != null:
		return end_cell.coords
	return Vector2i.ZERO

func _race_player_character_id() -> String:
	return "%s:player" % Config.theme_dir_name

func _race_robot_character_id() -> String:
	return "%s:chaser" % Config.theme_dir_name

func _race_path_from_corner(start: Vector2i, center: Vector2i) -> Array[Vector2i]:
	if _current_maze == null:
		return []
	var queue: Array[Vector2i] = [start]
	var came_from: Dictionary = {start: start}
	var head := 0
	while head < queue.size():
		var pos := queue[head]
		head += 1
		if pos == center:
			break
		for dir in MazeGenerator.DIRECTIONS:
			var next := pos + dir
			if came_from.has(next):
				continue
			if not _current_maze.is_wall_open(pos, dir):
				continue
			came_from[next] = pos
			queue.append(next)

	if not came_from.has(center):
		return [start]

	var reversed_path: Array[Vector2i] = []
	var cursor := center
	while cursor != start:
		reversed_path.append(cursor)
		cursor = came_from[cursor]
	reversed_path.append(start)
	reversed_path.reverse()
	return reversed_path

func _set_start_markers(spawn_cells: Array[Vector2i]) -> void:
	if _current_maze == null:
		return
	for raw_cell in _current_maze.cells.values():
		var cell := raw_cell as MazeData.CellData
		if cell != null:
			cell.is_start = false
	for coords in spawn_cells:
		var cell := _current_maze.get_cell(coords)
		if cell != null:
			cell.is_start = true
			cell.is_visited = true
