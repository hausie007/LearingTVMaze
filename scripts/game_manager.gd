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
const LearningRecapBuilder := preload("res://scripts/learning_recap.gd")

const FINISH_SHORTCUT_ADD_CHASER := "add_chaser"
const FINISH_SHORTCUT_CALM := "calm"
const FINISH_SHORTCUT_CHASER_PREFIX := "chaser:"
const FINISH_SHORTCUT_PICKUP_PREFIX := "pickup:"
const FINISH_SHORTCUT_TRAPS := "traps"
const CONFUSED_AI_RETREAT_NOISE_CHANCE := 0.10
const FINISH_PICKUP_PROGRESSION: Array[String] = [
	MissionCatalog.PICKUP_NONE,
	MissionCatalog.PICKUP_NUMBERS,
	MissionCatalog.PICKUP_LETTERS,
	MissionCatalog.PICKUP_WORDS,
]

# ── Child-node references ────────────────────────────────────────────────────

@onready var maze_generator:     MazeGenerator      = $MazeGenerator
@onready var maze_renderer:      MazeRenderer        = $MazeRenderer
@onready var player:             PlayerController    = $Player
@onready var hud:                GameHUD             = $HUD
@onready var win_screen:         WinScreen           = $WinScreen
@onready var pause_dialog:       PauseDialog         = $PauseDialog
@onready var collectible_spawner: CollectibleSpawner = $CollectibleSpawner
@onready var chaser_manager: Variant = $ChaserManager


# ── Game State ───────────────────────────────────────────────────────────────

var _current_maze: MazeData = null
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
var _race_robot_grid_pos: Vector2i = Vector2i.ZERO
var _race_robot_confusion_moves: int = 0
var _race_robot_shake_tween: Tween = null
var _race_robot_confusion_visual_version: int = 0
var _trap_manager: TrapManager = null
var _traps_enabled: bool = false
var _player_trap_available: bool = false
var _player_confusion_moves: int = 0
var _trap_input_unlock_msec: int = 0



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
	win_screen.finish_shortcut_pressed.connect(_on_finish_shortcut_pressed)
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
	chaser_manager.chaser_moved.connect(_on_chaser_moved)
	chaser_manager.confusion_changed.connect(func(_remaining: int): _refresh_sp_player_badges())
	chaser_manager.set_player_pos_getter(func() -> Vector2i: return player.grid_pos)

	_trap_manager = TrapManager.new()
	_trap_manager.name = "TrapManager"
	add_child(_trap_manager)

	# Tell the maze renderer to leave space for the HUD bar.
	maze_renderer.top_margin = hud.get_height()

	# Generate and display the first maze.
	_start_new_maze()


func _exit_tree() -> void:
	_player_confusion_moves = 0
	_update_local_dpad_confusion_visual()

func _process(delta: float) -> void:
	if not win_screen.is_active() and not get_tree().paused:
		_process_trap_input()
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
	if DPad != null and DPad.has_method("set_controls_reversed_visual"):
		DPad.call("set_controls_reversed_visual", false)
	DisplayServer.screen_set_keep_on(false)


func _unpause() -> void:
	_is_paused = false
	get_tree().paused = false
	pause_dialog.hide_dialog()
	_arm_trap_input_lockout()
	_update_local_dpad_confusion_visual()
	DisplayServer.screen_set_keep_on(true)


func _on_pause_confirmed() -> void:
	_unpause()
	get_tree().change_scene_to_file(Scenes.HOME)


func _on_pause_cancelled() -> void:
	_unpause()




# ── Game Flow ────────────────────────────────────────────────────────────────

## Generate a fresh maze, render it, and place the player.
func _start_new_maze() -> void:
	win_screen.hide_screen()
	win_screen.set_learning_recap({})
	win_screen.set_finish_shortcuts([])
	
	# Ensure tree is unpaused (win/gotcha screens pause the tree via signal)
	get_tree().paused = false
	_move_count = 0
	_completed_word_spoken = false
	_last_spoken_word_segment_end = 0
	_race_robot_finished = false
	_clear_trap_round_state()

	if not [Config.STYLE_PATH, Config.STYLE_NEXT_SYMBOL, Config.STYLE_RACE].has(Config.game_style):
		Config.game_style = Config.STYLE_PATH
	Config.game_mode = Config.game_mode_for_training(Config.training_type) as Config.GameMode
	if Config.game_style == Config.STYLE_RACE:
		Config.chaser_enabled = false
	if not Config.chaser_enabled:
		Config.chaser_level = Config.ChaserLevel.OFF
	_traps_enabled = Config.traps_enabled and Config.traps_allowed_for_session(Config.game_style, Config.chaser_enabled, Config.mission_id)
	_player_trap_available = _traps_enabled
	_arm_trap_input_lockout()
	hud.update_role("" if Config.game_style == Config.STYLE_NEXT_SYMBOL else Config.player_role)

	# Cleanup old entities
	collectible_spawner.clear()
	chaser_manager.cleanup()
	_cleanup_race_robot()

	# Re-enable player
	player.set_process(true)
	player.set_physics_process(true)
	player.set_process_input(true)
	# Reset global idle timer so a fresh maze always starts at full brightness
	IdleManager.reset()
	# 1. Generate
	_current_maze = maze_generator.generate_race(Config.grid_size) if Config.game_style == Config.STYLE_RACE else maze_generator.generate()
	if Config.game_style == Config.STYLE_RACE:
		_set_start_markers([
			Vector2i(0, 0),
			Vector2i(_current_maze.grid_size.x - 1, _current_maze.grid_size.y - 1),
		])

	# 2. Render
	maze_renderer.draw_maze(_current_maze)
	if _trap_manager != null:
		_trap_manager.setup(_current_maze, maze_renderer)

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

	# Show player role badges in single player
	_setup_sp_player_badges()

	# 5. Place player at Start cell
	var start_cell: MazeData.CellData = _current_maze.get_start_cell()
	if Config.game_style == Config.STYLE_RACE:
		start_cell = _current_maze.get_cell(Vector2i(0, 0))
	if start_cell:
		player.reset_movement()
		player.set_controls_reversed(false)
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
	_clear_confusion_states()

	# Stop Chaser
	chaser_manager.stop()

	# Freeze player
	_freeze_player()

	# Full word progress update if word mode
	if Config.game_mode == Config.GameMode.WORDS:
		_refresh_target_hud()
		_speak_completed_word_once()
	elif Config.game_style == Config.STYLE_RACE:
		_speak_race_completion_once()

	win_screen.set_learning_recap(_build_learning_recap())
	win_screen.set_finish_shortcuts(_build_finish_shortcuts(false))
	if Config.game_style == Config.STYLE_RACE:
		win_screen.show_race_win(_race_player_character_id())
	else:
		win_screen.show_win()


func _on_player_moved(new_pos: Vector2i) -> void:
	_move_count += 1
	_consume_player_confusion_move()
	# Any player movement counts as interaction → reset global idle timer
	IdleManager.reset()
	# Check chaser trigger and collision
	if Config.chaser_enabled and not chaser_manager.is_active():
		chaser_manager.check_trigger(_move_count)
		if chaser_manager.is_active():
			chaser_manager.spawn(_current_maze, maze_renderer)
			if hud != null:
				hud.update_chaser_countdown(0)
		elif hud != null:
			hud.update_chaser_countdown(chaser_manager.get_remaining_steps(_move_count))

	chaser_manager.check_collision_at(new_pos)

	# Check collectible
	if collectible_spawner.check_collection(new_pos):
		pass  # Event handled via signal
	_trigger_trap_for_player(new_pos)


# ── Collectible Callbacks ────────────────────────────────────────────────────

func _on_collectible_gathered(value_str: String, collect_index: int, lang: String) -> void:
	if Config.voice_mode != Config.VoiceMode.OFF:
		if Config.game_mode == Config.GameMode.WORDS:
			# Words mode: speak collected letter
			Speech.speak_grapheme(value_str, lang)

			# Speak the whole word once when it is complete.
			var next_idx: int = collectible_spawner.get_word_next_index()
			var word_complete: bool = (next_idx >= collectible_spawner.get_word_grapheme_count())
			if word_complete:
				_speak_completed_word_once(lang)
			elif collectible_spawner.has_word_boundary_between(collect_index + 1, next_idx):
				_speak_completed_word_segment(next_idx, lang)
			# Decode the next letter's clip now rather than when it is wanted.
			Speech.prefetch_grapheme(collectible_spawner.get_word_next_grapheme(), lang)
		else:
			Speech.speak_item(value_str, "")
			if Config.game_mode == Config.GameMode.NUMBERS and value_str.is_valid_int():
				Speech.prefetch_number(value_str.to_int() + 1, "")

	_refresh_target_hud()
	# If all collectibles are now done, rebuild the chip with the exit role.
	if collectible_spawner != null and collectible_spawner.is_complete():
		_refresh_sp_player_badges()


# ── Chaser Callbacks ─────────────────────────────────────────────────────────

func _on_chaser_caught_player() -> void:
	_is_gotcha_screen = true
	_clear_confusion_states()
	_freeze_player()
	win_screen.set_learning_recap({})
	win_screen.set_finish_shortcuts(_build_finish_shortcuts(true))
	win_screen.show_gotcha()


# ── Win Screen Pause Ownership ───────────────────────────────────────────────

## GameManager owns the tree pause state for win/gotcha overlays.
func _on_win_screen_shown() -> void:
	get_tree().paused = true

func _on_win_screen_hidden() -> void:
	get_tree().paused = false
	_arm_trap_input_lockout()

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

	Config.remember_last_single_player_session()
	Config.save_settings()
	_start_new_maze()

func _on_home_pressed() -> void:
	win_screen.hide_screen()
	get_tree().paused = false
	get_tree().change_scene_to_file(Scenes.HOME)

func _on_play_together_pressed() -> void:
	# Build a MP host config from the current SP game settings
	var mission_id := Config.mission_id
	var style := Config.game_style
	var training := Config.training_type
	var chaser_enabled := Config.chaser_enabled
	var chaser_level := Config.chaser_level
	var difficulty := Config.difficulty
	var theme_dir := Config.theme_dir_name
	var multiplayer_chaser_enabled := chaser_enabled and MissionCatalog.chaser_allowed(mission_id) and style != Config.STYLE_RACE
	var multiplayer_chaser_level := chaser_level if multiplayer_chaser_enabled else Config.ChaserLevel.OFF
	var multiplayer_traps_enabled := Config.traps_enabled and Config.traps_allowed_for_session(style, multiplayer_chaser_enabled, mission_id)
	var player_options := MissionCatalog.max_players_options(mission_id, multiplayer_chaser_enabled)
	var max_players := 2
	if not player_options.is_empty():
		max_players = int(player_options[player_options.size() - 1])

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
		"mission_goal_key": MissionCatalog.goal_key(mission_id, pickup_id, multiplayer_chaser_enabled, true),
		"role_summary_key": MissionCatalog.role_summary_key(mission_id, multiplayer_chaser_enabled),
		"game_style": style,
		"game_style_title": tr(mission_title_key),
		"training_type": training,
		"training_type_title": tr(pickup_title_key),
		"chaser_enabled": multiplayer_chaser_enabled,
		"chaser_level": multiplayer_chaser_level,
		"traps_enabled": multiplayer_traps_enabled,
		"rotate_roles_after_round": false,
		"theme_dir": theme_dir,
		"theme_title": theme_title,
		"max_players": max_players,
		"character_id": "%s:player" % theme_dir,
	}

	win_screen.hide_screen()
	get_tree().paused = false
	NetworkManager.configure_host(config)
	var err := NetworkManager.start_host()
	if err != OK:
		push_error("Failed to start host from win screen: %d" % err)
		get_tree().change_scene_to_file(Scenes.HOME)
		return
	get_tree().change_scene_to_file(Scenes.HOST_LOBBY)

func _on_finish_shortcut_pressed(shortcut_id: String) -> void:
	var handled := true
	if shortcut_id == FINISH_SHORTCUT_ADD_CHASER:
		Config.configure_single_player_session(
			Config.game_style,
			Config.training_type,
			true,
			Config.ChaserLevel.SLOW,
			_current_mission_id(),
			Config.traps_enabled,
		)
	elif shortcut_id == FINISH_SHORTCUT_CALM:
		Config.configure_single_player_session(
			Config.game_style,
			Config.training_type,
			false,
			Config.ChaserLevel.OFF,
			_current_mission_id(),
			false,
		)
	elif shortcut_id.begins_with(FINISH_SHORTCUT_CHASER_PREFIX):
		var target_level := int(shortcut_id.substr(FINISH_SHORTCUT_CHASER_PREFIX.length()))
		Config.configure_single_player_session(
			Config.game_style,
			Config.training_type,
			true,
			target_level,
			_current_mission_id(),
			Config.traps_enabled,
		)
	elif shortcut_id.begins_with(FINISH_SHORTCUT_PICKUP_PREFIX):
		var target_pickup := shortcut_id.substr(FINISH_SHORTCUT_PICKUP_PREFIX.length())
		_apply_pickup_shortcut(target_pickup)
	elif shortcut_id == FINISH_SHORTCUT_TRAPS:
		Config.traps_enabled = Config.traps_allowed_for_session(Config.game_style, Config.chaser_enabled, _current_mission_id())
	else:
		handled = false

	if not handled:
		return
	Config.remember_last_single_player_session()
	Config.save_settings()
	_start_new_maze()


# ── Private Helpers ──────────────────────────────────────────────────────────

func _build_finish_shortcuts(is_gotcha: bool) -> Array[Dictionary]:
	var shortcuts: Array[Dictionary] = []
	var pressure_shortcut := _build_pressure_shortcut(is_gotcha)
	_append_finish_shortcut(shortcuts, pressure_shortcut)
	var traps_shortcut := _build_traps_shortcut()
	_append_finish_shortcut(shortcuts, traps_shortcut)
	var task_shortcut := _build_task_mix_shortcut(is_gotcha)
	_append_finish_shortcut(shortcuts, task_shortcut)
	return shortcuts

func _append_finish_shortcut(shortcuts: Array[Dictionary], shortcut: Dictionary) -> void:
	if shortcuts.size() >= 2 or shortcut.is_empty():
		return
	shortcuts.append(shortcut)

func _build_pressure_shortcut(is_gotcha: bool) -> Dictionary:
	var mission_id := _current_mission_id()
	if Config.game_style == Config.STYLE_RACE or not MissionCatalog.chaser_allowed(mission_id):
		return {}

	if not Config.chaser_enabled:
		if is_gotcha:
			return {}
		return _finish_shortcut(
			FINISH_SHORTCUT_ADD_CHASER,
			tr("play_with_chaser"),
			UIColors.YELLOW,
		)

	var level_idx := MissionCatalog.CHASER_TUNING_LEVELS.find(int(Config.chaser_level))
	if level_idx < 0:
		level_idx = 0

	if is_gotcha:
		if level_idx > 0:
			var easier_level: int = MissionCatalog.CHASER_TUNING_LEVELS[level_idx - 1]
			return _finish_shortcut(
				FINISH_SHORTCUT_CHASER_PREFIX + str(easier_level),
				tr("finish_slower_chaser"),
				UIColors.YELLOW,
			)
		return _finish_shortcut(
			FINISH_SHORTCUT_CALM,
			tr("play_calm"),
			UIColors.YELLOW,
		)

	if level_idx < MissionCatalog.CHASER_TUNING_LEVELS.size() - 1:
		var harder_level: int = MissionCatalog.CHASER_TUNING_LEVELS[level_idx + 1]
		return _finish_shortcut(
			FINISH_SHORTCUT_CHASER_PREFIX + str(harder_level),
			tr("finish_faster_chaser"),
			UIColors.YELLOW,
		)

	return {}

func _build_task_mix_shortcut(is_gotcha: bool) -> Dictionary:
	var current_pickup := MissionCatalog.pickup_for_training(Config.training_type)
	var pickup_idx := FINISH_PICKUP_PROGRESSION.find(current_pickup)
	if pickup_idx < 0:
		return {}
	var target_idx := pickup_idx - 1 if is_gotcha else pickup_idx + 1
	if target_idx < 0 or target_idx >= FINISH_PICKUP_PROGRESSION.size():
		return {}
	var target_pickup: String = FINISH_PICKUP_PROGRESSION[target_idx]
	return _finish_shortcut(
		FINISH_SHORTCUT_PICKUP_PREFIX + target_pickup,
		tr(_pickup_title_key(target_pickup)),
		UIColors.BLUE,
	)

func _build_traps_shortcut() -> Dictionary:
	if Config.traps_enabled:
		return {}
	if not Config.traps_allowed_for_session(Config.game_style, Config.chaser_enabled, _current_mission_id()):
		return {}
	return _finish_shortcut(
		FINISH_SHORTCUT_TRAPS,
		tr("setting_use_traps"),
		UIColors.BLUE,
		_trap_icon_path(Config.theme_dir_name),
	)

func _finish_shortcut(shortcut_id: String, text: String, color: Color, icon_path: String = "") -> Dictionary:
	return {
		"id": shortcut_id,
		"text": text,
		"color": color,
		"icon": icon_path,
	}

func _trap_icon_path(theme_dir: String) -> String:
	var path := "res://themes/%s/trap.png" % theme_dir
	if FileAccess.file_exists(path):
		return path
	return "res://themes/default/trap.png"

func _apply_pickup_shortcut(target_pickup: String) -> void:
	var mission_id := Config.MISSION_RACE_MIDDLE if Config.game_style == Config.STYLE_RACE else _mission_for_pickup_shortcut(target_pickup)
	var style := MissionCatalog.style_for_mission(mission_id)
	var training := MissionCatalog.training_for_pickup(target_pickup)
	var use_chaser := Config.chaser_enabled and MissionCatalog.chaser_allowed(mission_id) and style != Config.STYLE_RACE
	var chaser_level := int(Config.chaser_level) if use_chaser else Config.ChaserLevel.OFF
	if use_chaser and chaser_level == Config.ChaserLevel.OFF:
		chaser_level = Config.ChaserLevel.SLOW
	Config.configure_single_player_session(style, training, use_chaser, chaser_level, mission_id, Config.traps_enabled)

func _mission_for_pickup_shortcut(target_pickup: String) -> String:
	if target_pickup == MissionCatalog.PICKUP_NONE:
		return Config.MISSION_FIND_EXIT
	var mission_id := _current_mission_id()
	if [Config.MISSION_FOLLOW_TRAIL, Config.MISSION_FIND_NEXT].has(mission_id):
		return mission_id
	return Config.MISSION_FOLLOW_TRAIL

func _current_mission_id() -> String:
	if MissionCatalog.mission_ids().has(Config.mission_id):
		return Config.mission_id
	return MissionCatalog.mission_from_config(Config.game_style, Config.training_type)

func _pickup_title_key(pickup: String) -> String:
	if pickup == MissionCatalog.PICKUP_NONE:
		return "pickup_just_maze"
	return MissionCatalog.pickup_title_key(pickup)

## Freeze player processing (used when game ends or chaser catches).
func _freeze_player() -> void:
	player.set_process(false)
	player.set_physics_process(false)
	player.set_process_input(false)

func _process_trap_input() -> void:
	if not _can_accept_trap_input():
		return
	if Input.is_action_just_pressed("ui_accept"):
		_try_drop_player_trap()

func _can_accept_trap_input() -> bool:
	if not _traps_enabled or not _player_trap_available:
		return false
	if _current_maze == null or _trap_manager == null:
		return false
	if win_screen != null and win_screen.is_active():
		return false
	if get_tree().paused or _is_paused:
		return false
	return Time.get_ticks_msec() >= _trap_input_unlock_msec

func _arm_trap_input_lockout() -> void:
	_trap_input_unlock_msec = Time.get_ticks_msec() + int(Config.TRAP_INPUT_LOCKOUT_SEC * 1000.0)

func _try_drop_player_trap() -> void:
	if not _player_trap_available or not player.has_previous_grid_pos:
		return
	var coord := player.previous_grid_pos
	if not _trap_manager.can_drop_on(coord, _important_trap_blocked_cells()):
		return
	if not _trap_manager.drop_trap(1, coord):
		return
	player.play_confusion_shake()
	_player_trap_available = false
	_refresh_sp_player_badges()

func _important_trap_blocked_cells() -> Dictionary:
	var blocked := {}
	if player != null:
		blocked[player.grid_pos] = true
	if chaser_manager != null:
		for pos in chaser_manager.get_chaser_positions():
			blocked[pos] = true
	if _race_robot != null and is_instance_valid(_race_robot):
		blocked[_race_robot_grid_pos] = true
	if collectible_spawner != null:
		for pos in collectible_spawner.get_collectible_positions():
			blocked[pos] = true
	if _trap_manager != null:
		for pos in _trap_manager.get_trap_positions():
			blocked[pos] = true
	return blocked

func _trigger_trap_for_player(pos: Vector2i) -> void:
	if not _traps_enabled or _trap_manager == null:
		return
	if win_screen != null and win_screen.is_active():
		return
	if not _trap_manager.trigger_at(pos):
		return
	_player_confusion_moves += Config.TRAP_CONFUSION_MOVES
	player.set_controls_reversed(_player_confusion_moves > 0, true, Config.tween_duration)
	_update_local_dpad_confusion_visual()
	_refresh_sp_player_badges()

func _consume_player_confusion_move() -> void:
	if _player_confusion_moves <= 0:
		return
	var was_confused := _player_confusion_moves > 0
	_player_confusion_moves = maxi(0, _player_confusion_moves - 1)
	var recovered := was_confused and _player_confusion_moves == 0
	player.set_controls_reversed(_player_confusion_moves > 0, recovered, Config.tween_duration if recovered else 0.0)
	_update_local_dpad_confusion_visual()
	_refresh_sp_player_badges()

func _on_chaser_moved(new_pos: Vector2i) -> void:
	if not _traps_enabled or _trap_manager == null:
		return
	if _trap_manager.trigger_at(new_pos):
		chaser_manager.add_confusion(Config.TRAP_CONFUSION_MOVES)

func _trigger_trap_for_race_robot(pos: Vector2i) -> void:
	if not _traps_enabled or _trap_manager == null:
		return
	if _trap_manager.trigger_at(pos):
		_race_robot_confusion_moves += Config.TRAP_CONFUSION_MOVES
		_update_race_robot_confused_visual(true, Config.tween_duration)
		_refresh_sp_player_badges()

func _consume_race_robot_confusion_move() -> void:
	if _race_robot_confusion_moves <= 0:
		return
	var was_confused := _race_robot_confusion_moves > 0
	_race_robot_confusion_moves = maxi(0, _race_robot_confusion_moves - 1)
	var recovered := was_confused and _race_robot_confusion_moves == 0
	_update_race_robot_confused_visual(recovered, Config.tween_duration if recovered else 0.0)
	_refresh_sp_player_badges()

func _update_race_robot_confused_visual(shake: bool = false, visual_delay_sec: float = 0.0) -> void:
	_race_robot_confusion_visual_version += 1
	var version := _race_robot_confusion_visual_version
	if visual_delay_sec > 0.0:
		_update_race_robot_confused_visual_later(shake, visual_delay_sec, version)
		return
	_apply_race_robot_confused_visual(shake)

func _update_race_robot_confused_visual_later(shake: bool, delay_sec: float, version: int) -> void:
	await get_tree().create_timer(delay_sec).timeout
	if version != _race_robot_confusion_visual_version:
		return
	_apply_race_robot_confused_visual(shake)

func _apply_race_robot_confused_visual(shake: bool = false) -> void:
	if _race_robot != null and is_instance_valid(_race_robot):
		_race_robot.rotation = PI if _race_robot_confusion_moves > 0 else 0.0
		if shake:
			_play_race_robot_confusion_shake()

func _play_race_robot_confusion_shake() -> void:
	if _race_robot == null or not is_instance_valid(_race_robot):
		return
	if _race_robot.get_child_count() <= 0:
		return
	var visual := _race_robot.get_child(0)
	if not (visual is CanvasItem):
		return
	if _race_robot_shake_tween and _race_robot_shake_tween.is_valid():
		_race_robot_shake_tween.kill()
	var base_pos := Vector2.ZERO
	if visual is Control:
		var control := visual as Control
		base_pos = -control.size / 2.0
	elif visual is Node2D:
		base_pos = Vector2.ZERO
	visual.set("position", base_pos)
	var offset := Vector2((maze_renderer.get_cell_size() if maze_renderer != null else 120.0) * 0.13, 0.0)
	_race_robot_shake_tween = create_tween()
	_race_robot_shake_tween.bind_node(visual)
	_race_robot_shake_tween.tween_property(visual, "position", base_pos + offset, 0.045).set_trans(Tween.TRANS_SINE)
	_race_robot_shake_tween.tween_property(visual, "position", base_pos - offset, 0.065).set_trans(Tween.TRANS_SINE)
	_race_robot_shake_tween.tween_property(visual, "position", base_pos + offset * 0.45, 0.045).set_trans(Tween.TRANS_SINE)
	_race_robot_shake_tween.tween_property(visual, "position", base_pos, 0.08).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func _clear_trap_round_state() -> void:
	_player_trap_available = false
	_player_confusion_moves = 0
	_race_robot_confusion_moves = 0
	if player != null:
		player.set_controls_reversed(false)
	_update_local_dpad_confusion_visual()
	_race_robot_confusion_visual_version += 1
	if _race_robot != null and is_instance_valid(_race_robot):
		_race_robot.rotation = 0.0
	if chaser_manager != null:
		chaser_manager.clear_confusion()
	if _trap_manager != null:
		_trap_manager.clear()

func _clear_confusion_states() -> void:
	_player_confusion_moves = 0
	if player != null:
		player.set_controls_reversed(false)
	_update_local_dpad_confusion_visual()
	_race_robot_confusion_moves = 0
	_update_race_robot_confused_visual()
	if chaser_manager != null:
		chaser_manager.clear_confusion()
	_refresh_sp_player_badges()

func _trap_texture() -> Texture2D:
	if maze_renderer == null:
		return null
	var theme := maze_renderer.get_theme_loader()
	return theme.trap_texture if theme != null else null

func _update_local_dpad_confusion_visual() -> void:
	if DPad != null and DPad.has_method("set_controls_reversed_visual"):
		DPad.call("set_controls_reversed_visual", _player_confusion_moves > 0)


func _build_learning_recap() -> Dictionary:
	if Config.game_mode == Config.GameMode.NORMAL:
		return {}
	if collectible_spawner == null or not collectible_spawner.is_complete():
		return {}
	var sequence := collectible_spawner.get_sequence_strings()
	var word := String(Config.current_word.get("word", ""))
	var word_lang := String(Config.current_word.get("lang", ""))
	return LearningRecapBuilder.build(Config.game_mode, sequence, word, word_lang)


func _refresh_target_hud() -> void:
	var seq := collectible_spawner.get_sequence_strings()
	var current_idx: int
	var collected: int
	var lt := _learning_type_string()
	var emoji := ""

	if Config.game_mode == Config.GameMode.WORDS:
		current_idx = collectible_spawner.get_word_next_index()
		collected = current_idx
		emoji = String(Config.current_word.get("emoji", ""))
	else:
		current_idx = collectible_spawner.get_next_collect_index()
		collected = current_idx

	hud.update_tracker(seq, current_idx, collected, lt, emoji)
	_update_hud_mission_description()


func _learning_type_string() -> String:
	match Config.game_mode:
		Config.GameMode.NUMBERS:
			return "numbers"
		Config.GameMode.LETTERS:
			return "letters"
		Config.GameMode.WORDS:
			return "words"
		_:
			return ""

func _setup_sp_player_badges() -> void:
	if hud == null:
		return
	var players: Array[Dictionary] = []

	# Determine the correct role tag for the player chip.
	# ROLE_COLLECTOR is only right when there are actually collectibles to collect.
	# For find-exit missions and normal (no-collectible) path mode, show "Find Exit".
	var player_role: String
	if Config.game_style == Config.STYLE_RACE:
		player_role = Config.ROLE_RACER
	elif Config.game_mode == Config.GameMode.NORMAL:
		# No collectibles — always show "Find Exit"
		player_role = "exit"
	else:
		# Collectible mission — show "Collect" until done, then "Find Exit"
		var done := collectible_spawner != null and collectible_spawner.is_complete()
		player_role = "exit" if done else Config.ROLE_COLLECTOR

	var player_char_id := "%s:player" % Config.theme_dir_name
	var player_palette := AvatarAccent.palette_from_character_id(player_char_id)
	players.append({
		"character_id": player_char_id,
		"color": player_palette.get("accent", UIColors.YELLOW),
		"role": player_role,
		"trap_available": _player_trap_available,
		"trap_texture": _trap_texture(),
		"confusion_moves": _player_confusion_moves,
		"is_confused": _player_confusion_moves > 0,
	})

	# AI Opponent badge (Chaser or Robot Racer)
	if Config.chaser_enabled or Config.game_style == Config.STYLE_RACE:
		var ai_role := Config.ROLE_RACER if Config.game_style == Config.STYLE_RACE else Config.ROLE_CHASER
		var ai_char_id := _race_robot_character_id()
		var palette := AvatarAccent.palette_from_character_id(ai_char_id)
		players.append({
			"character_id": ai_char_id,
			"color": palette.get("accent", Color("#FF5555")),
			"role": ai_role,
			"is_ai": true,
			"confusion_moves": _race_robot_confusion_moves if Config.game_style == Config.STYLE_RACE else chaser_manager.get_confusion_moves(),
			"is_confused": (_race_robot_confusion_moves if Config.game_style == Config.STYLE_RACE else chaser_manager.get_confusion_moves()) > 0,
		})

	hud.set_players(players)
	if Config.chaser_enabled and not chaser_manager.is_active():
		hud.update_chaser_countdown(chaser_manager.get_remaining_steps(_move_count))


## Rebuild player chips after a role phase change so label and emoji stay in sync.
func _refresh_sp_player_badges() -> void:
	_setup_sp_player_badges()



func _update_hud_mission_description() -> void:
	var enlarge_hud := Config.game_mode != Config.GameMode.WORDS
	var goal_str := _get_solo_goal()
	
	if hud != null:
		hud.set_mission_description(goal_str, enlarge_hud)

func _get_solo_goal() -> String:
	if Config.game_style == Config.STYLE_RACE:
		return ""  # Tracker shows race progress

	if Config.game_style == Config.STYLE_PATH and not Config.chaser_enabled and Config.game_mode == Config.GameMode.NORMAL:
		return tr("hud_desc_sp_path")

	var is_phase_one := false
	if Config.game_style in [Config.STYLE_PATH, Config.STYLE_NEXT_SYMBOL] and collectible_spawner != null:
		is_phase_one = not collectible_spawner.is_complete()

	if is_phase_one:
		# Tracker handles the visual instruction during collection phase.
		return ""
	else:
		return tr("hud_desc_sp_path")

func _speak_completed_word_once(lang_override: String = "") -> void:
	if _completed_word_spoken or Config.voice_mode == Config.VoiceMode.OFF:
		return
	var phrase: String = String(Config.current_word.get("word", "")).strip_edges()
	if phrase.is_empty():
		return
	_completed_word_spoken = true
	# Grapheme count, not character count — see _speak_completed_word_segment.
	if collectible_spawner != null:
		_last_spoken_word_segment_end = collectible_spawner.get_word_grapheme_count()
	var word_lang: String = lang_override
	if word_lang.is_empty():
		word_lang = String(Config.current_word.get("lang", ""))
	get_tree().create_timer(1.2).timeout.connect(
		func():
			if win_screen != null and win_screen.is_active():
				return
			Speech.speak_word(phrase, word_lang)
	)

## `segment_end` is a GRAPHEME index; the substring needs a character offset.
func _speak_completed_word_segment(segment_end: int, lang_override: String = "") -> void:
	if Config.voice_mode == Config.VoiceMode.OFF or collectible_spawner == null:
		return
	var word_full: String = String(Config.current_word.get("word", ""))
	var clamped_end := clampi(segment_end, 0, collectible_spawner.get_word_grapheme_count())
	if clamped_end <= _last_spoken_word_segment_end:
		return
	var char_end := collectible_spawner.get_word_char_offset(clamped_end)
	var phrase := word_full.substr(0, char_end).strip_edges()
	if phrase.is_empty():
		return
	_last_spoken_word_segment_end = clamped_end
	var word_lang: String = lang_override
	if word_lang.is_empty():
		word_lang = String(Config.current_word.get("lang", ""))
	get_tree().create_timer(1.45).timeout.connect(
		func():
			if win_screen != null and win_screen.is_active():
				return
			# A partial phrase has no recording of its own. Speech plays the
			# full phrase and stops it at the word boundary, so each stage is
			# the same reading heard a little further.
			Speech.speak_word(phrase, word_lang)
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
	_race_robot_grid_pos = _race_robot_path[0]
	_update_race_robot_confused_visual()
	_race_robot.position = maze_renderer.grid_to_pixel(_race_robot_path[0])

func _cleanup_race_robot() -> void:
	if _race_robot_shake_tween and _race_robot_shake_tween.is_valid():
		_race_robot_shake_tween.kill()
	if _race_robot != null and is_instance_valid(_race_robot):
		_race_robot.queue_free()
	_race_robot = null
	_race_robot_shake_tween = null
	_race_robot_path.clear()
	_race_robot_index = 0
	_race_robot_timer = 0.0
	_race_robot_finished = false
	_race_robot_grid_pos = Vector2i.ZERO
	_race_robot_confusion_moves = 0
	_race_robot_confusion_visual_version += 1

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
	var center := _race_center()
	if _race_robot_grid_pos == center:
		_finish_race_robot()
		return

	var path := _race_path_from_corner(_race_robot_grid_pos, center)
	if path.size() <= 1:
		_finish_race_robot()
		return

	var intended_next := path[1]
	var next_pos := intended_next
	if _race_robot_confusion_moves > 0:
		var robot_start := _race_robot_path[0]
		next_pos = _confused_ai_next_pos(_race_robot_grid_pos, intended_next, robot_start)
		if next_pos == _race_robot_grid_pos:
			_consume_race_robot_confusion_move()
			return
		_consume_race_robot_confusion_move()

	_race_robot_grid_pos = next_pos
	var target := maze_renderer.grid_to_pixel(next_pos)
	var tween := _race_robot.create_tween()
	tween.tween_property(_race_robot, "position", target, Config.tween_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_trigger_trap_for_race_robot(next_pos)
	if next_pos == center:
		await tween.finished
		_finish_race_robot()

func _finish_race_robot() -> void:
	if _race_robot_finished:
		return
	_race_robot_finished = true
	_is_gotcha_screen = true
	_clear_confusion_states()
	_freeze_player()
	win_screen.set_finish_shortcuts(_build_finish_shortcuts(true))
	win_screen.show_race_gotcha(_race_robot_character_id())

func _confused_ai_next_pos(from_pos: Vector2i, intended_pos: Vector2i, target_pos: Vector2i) -> Vector2i:
	if _current_maze == null:
		return from_pos
	var legal_dirs: Array[Vector2i] = []
	for dir in MazeGenerator.DIRECTIONS:
		if _current_maze.is_wall_open(from_pos, dir):
			legal_dirs.append(dir)
	if legal_dirs.is_empty():
		return from_pos

	var retreat_path := _race_path_from_corner(from_pos, target_pos)
	if retreat_path.size() <= 1:
		return from_pos
	var retreat_pos := retreat_path[1]
	var retreat_dir := retreat_pos - from_pos
	if not legal_dirs.has(retreat_dir):
		return from_pos

	var intended_dir := intended_pos - from_pos
	var noise_dirs := _confused_ai_retreat_noise_dirs(legal_dirs, retreat_dir, intended_dir)
	if not noise_dirs.is_empty() and randf() < CONFUSED_AI_RETREAT_NOISE_CHANCE:
		return from_pos + _pick_confused_ai_dir(noise_dirs)
	return retreat_pos

func _confused_ai_retreat_noise_dirs(legal_dirs: Array[Vector2i], retreat_dir: Vector2i, intended_dir: Vector2i) -> Array[Vector2i]:
	var options: Array[Vector2i] = []
	var away_from_start := -retreat_dir
	for dir in legal_dirs:
		if dir != retreat_dir and dir != away_from_start and dir != intended_dir:
			options.append(dir)
	if not options.is_empty():
		return options
	for dir in legal_dirs:
		if dir != retreat_dir and dir != away_from_start:
			options.append(dir)
	return options

func _pick_confused_ai_dir(dirs: Array[Vector2i]) -> Vector2i:
	if dirs.is_empty():
		return Vector2i.ZERO
	return dirs[randi() % dirs.size()]

func _race_robot_step_interval() -> float:
	var base := 0.72
	var difficulty_factor := 1.0 - (float(clampi(Config.difficulty, 0, 6)) * 0.055)
	return maxf(0.34, base * difficulty_factor)

func _speak_race_completion_once() -> void:
	if Config.voice_mode == Config.VoiceMode.OFF:
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
