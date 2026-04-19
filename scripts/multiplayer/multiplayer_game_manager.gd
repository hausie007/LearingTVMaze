extends Node
class_name MultiplayerGameManager

const CollectibleScene := preload("res://scenes/collectible.tscn")
const MissionCatalog := preload("res://scripts/mission_catalog.gd")

@export var avatar_scene: PackedScene

@onready var maze_generator: MazeGenerator = $MazeGenerator
@onready var maze_renderer: MazeRenderer = $MazeRenderer
@onready var hud: GameHUD = $HUD
@onready var players_root: Node2D = %Players
@onready var status_label: Label = %StatusLabel
@onready var network_debug_label: Label = %NetworkDebugLabel

var _maze: MazeData = null
var _elapsed_time: float = 0.0
var _display_move_count: int = 0
var _collectible_spawner: CollectibleSpawner = null
var _avatars: Dictionary = {}
var _held_directions: Dictionary = {}
var _move_cooldowns: Dictionary = {}
var _game_style: String = NetworkManager.STYLE_PATH
var _mission_id: String = NetworkManager.MISSION_FOLLOW_TRAIL
var _training_type: String = NetworkManager.TRAINING_WORDS
var _chaser_enabled: bool = false
var _collector_peer_id: int = 0
var _collector_caught: bool = false
var _catching_chaser_peer_id: int = 0
var _collector_move_count: int = 0
var _path_chasers_released: bool = true
var _delayed_chaser_peer_ids: Array[int] = []
var _completed_word_spoken: bool = false
var _round_complete: bool = false
var _race_finished: bool = false
var _race_winner_peer_id: int = 0
var _race_sequence: Array[Dictionary] = []
var _race_sequences_by_peer: Dictionary = {}
var _race_progress: Dictionary = {}
var _race_colors_by_peer: Dictionary = {}
var _race_markers_by_peer: Dictionary = {}
var _race_marker_root: Node2D = null
var _race_collect_player: AudioStreamPlayer = null
var _win_screen: WinScreen = null

var _saved_theme_dir: String = ""
var _saved_difficulty: int = 0
var _saved_game_style: String = ""
var _saved_mission_id: String = ""
var _saved_training_type: String = ""
var _saved_game_mode: int = 0
var _saved_current_word: Dictionary = {}

func _ready() -> void:
	if avatar_scene == null:
		push_error("MultiplayerGameManager: avatar_scene is missing")
		return
	if network_debug_label != null:
		network_debug_label.visible = false
	if status_label != null:
		status_label.visible = false
	if hud != null:
		maze_renderer.top_margin = hud.get_height()

	_saved_theme_dir = Config.theme_dir_name
	_saved_difficulty = Config.difficulty
	_saved_game_style = Config.game_style
	_saved_mission_id = Config.mission_id
	_saved_training_type = Config.training_type
	_saved_game_mode = Config.game_mode
	_saved_current_word = Config.current_word.duplicate(true)

	_collectible_spawner = CollectibleSpawner.new()
	_collectible_spawner.name = "CollectibleSpawner"
	add_child(_collectible_spawner)
	_collectible_spawner.collectible_gathered.connect(_on_collectible_gathered)

	_race_marker_root = Node2D.new()
	_race_marker_root.name = "RaceMarkers"
	add_child(_race_marker_root)

	_win_screen = WinScreen.new()
	_win_screen.set_swap_roles_enabled(true)
	_win_screen.set_chaser_suggestion_enabled(false)
	_win_screen.next_round_pressed.connect(_on_next_round_pressed)
	_win_screen.home_pressed.connect(_on_home_pressed)
	_win_screen.swap_roles_pressed.connect(_on_swap_roles_pressed)
	add_child(_win_screen)

	_build_race_collect_sound()

	NetworkManager.input_received.connect(_on_input_received)
	NetworkManager.peer_disconnected.connect(_on_peer_disconnected)
	NetworkManager.game_started.connect(_on_game_started)
	NetworkManager.debug_status_changed.connect(_on_network_debug_changed)

	var session := NetworkManager.current_session
	if session.is_empty():
		if status_label != null:
			status_label.text = tr("mp_game_waiting")
		return

	_apply_session(session)

func _exit_tree() -> void:
	Config.theme_dir_name = _saved_theme_dir
	Config.difficulty = _saved_difficulty
	Config.game_style = _saved_game_style
	Config.mission_id = _saved_mission_id
	Config.training_type = _saved_training_type
	Config.game_mode = _saved_game_mode
	Config.current_word = _saved_current_word

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		var viewport: Viewport = get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
		NetworkManager.leave_session()
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _process(delta: float) -> void:
	if _maze != null and (_win_screen == null or not _win_screen.is_active()):
		_elapsed_time += delta
		if hud != null:
			hud.update_time(_elapsed_time)
	if not multiplayer.is_server():
		return

	_process_host_local_input()
	_process_held_input(delta)

func _on_game_started(session: Dictionary) -> void:
	if _maze == null:
		_apply_session(session)

func _apply_session(session: Dictionary) -> void:
	var cfg := session.get("config", {}) as Dictionary
	if not cfg.is_empty():
		Config.theme_dir_name = String(cfg.get("theme_dir", Config.theme_dir_name))
		Config.difficulty = int(cfg.get("difficulty", Config.difficulty))
		_mission_id = String(cfg.get("mission_id", MissionCatalog.mission_from_config(
			String(cfg.get("game_style", NetworkManager.STYLE_PATH)),
			String(cfg.get("training_type", NetworkManager.TRAINING_WORDS))
		)))
		_game_style = String(cfg.get("game_style", NetworkManager.STYLE_PATH))
		_training_type = String(cfg.get("training_type", NetworkManager.TRAINING_WORDS))
		Config.game_style = _game_style if [Config.STYLE_PATH, Config.STYLE_NEXT_SYMBOL, Config.STYLE_RACE].has(_game_style) else Config.STYLE_PATH
		Config.mission_id = _mission_id
		Config.training_type = _training_type if [Config.TRAINING_NONE, Config.TRAINING_NUMBERS, Config.TRAINING_LETTERS, Config.TRAINING_WORDS].has(_training_type) else Config.TRAINING_WORDS
		Config.game_mode = Config.game_mode_for_training(Config.training_type)
		_chaser_enabled = bool(cfg.get("chaser_enabled", false)) and Config.game_style != Config.STYLE_RACE
		_collector_peer_id = int(cfg.get("collector_peer_id", 0))
		Config.chaser_enabled = _chaser_enabled
		Config.chaser_level = int(cfg.get("chaser_level", Config.ChaserLevel.SLOW)) if Config.chaser_enabled else Config.ChaserLevel.OFF
		if Config.chaser_enabled and Config.chaser_level == Config.ChaserLevel.OFF:
			Config.chaser_level = Config.ChaserLevel.SLOW
		if Config.game_style == Config.STYLE_RACE:
			Config.chaser_enabled = false
			Config.player_role = Config.ROLE_RACER
		else:
			Config.player_role = Config.ROLE_COLLECTOR
	_completed_word_spoken = false
	_round_complete = false
	_elapsed_time = 0.0
	_display_move_count = 0
	_collector_caught = false
	_catching_chaser_peer_id = 0
	_collector_move_count = 0
	_path_chasers_released = not _is_chaser_variant()
	_delayed_chaser_peer_ids.clear()
	_race_finished = false
	_race_winner_peer_id = 0
	_race_sequence.clear()
	_race_sequences_by_peer.clear()
	_race_progress.clear()
	_race_colors_by_peer.clear()
	_race_markers_by_peer.clear()

	_maze = maze_generator.generate_race(Config.grid_size) if _is_race_mode() else maze_generator.generate()
	_set_start_markers(_spawn_positions_for_session(session))
	if hud != null:
		maze_renderer.top_margin = hud.get_height()
		hud.update_time(_elapsed_time)
		hud.update_moves(_display_move_count)
		hud.update_role(_hud_role_key())
	else:
		maze_renderer.top_margin = GameHUD.HUD_HEIGHT
	maze_renderer.draw_maze(_maze)
	_clear_race_markers()
	if _collectible_spawner != null:
		_collectible_spawner.clear()
		if _uses_shared_collectibles():
			_collectible_spawner.spawn(_maze, maze_renderer, Config.game_style)
	if _is_race_mode():
		_build_race_sequence()
	_spawn_avatars(session)
	if _is_race_mode():
		_spawn_race_markers()
	_refresh_status_label()
	_set_network_debug("net", "Game running on host")

func _spawn_avatars(session: Dictionary) -> void:
	for child in players_root.get_children():
		child.queue_free()
	_avatars.clear()
	_held_directions.clear()
	_move_cooldowns.clear()

	var players := session.get("players", {}) as Dictionary
	var roles := session.get("roles", {}) as Dictionary
	var spawn_slots := session.get("spawn_slots", {}) as Dictionary
	var corners := [
		Vector2i(0, 0),
		Vector2i(_maze.grid_size.x - 1, 0),
		Vector2i(0, _maze.grid_size.y - 1),
		Vector2i(_maze.grid_size.x - 1, _maze.grid_size.y - 1),
	]

	var peer_ids: Array[int] = []
	for raw_key in players.keys():
		peer_ids.append(int(raw_key))
	peer_ids.sort()
	for peer_id in peer_ids:
		var info := players.get(peer_id, players.get(str(peer_id), {})) as Dictionary
		var slot := clampi(int(spawn_slots.get(peer_id, spawn_slots.get(str(peer_id), 0))), 0, 3)
		var role := String(roles.get(peer_id, roles.get(str(peer_id), info.get("role", NetworkManager.ROLE_COLLECTOR))))
		if _is_roleless_next_symbol_mode():
			role = ""
		if _is_maze_race_mode():
			role = NetworkManager.ROLE_RACER
		if _is_race_mode():
			role = NetworkManager.ROLE_RACER
		var spawn_grid := _spawn_for_mode(role, slot, corners)
		var avatar := avatar_scene.instantiate() as MultiplayerAvatar
		avatar.setup(peer_id, String(info.get("character_id", "")), maze_renderer, spawn_grid, role)
		if _should_delay_path_chaser(role):
			avatar.visible = false
			_delayed_chaser_peer_ids.append(peer_id)
		players_root.add_child(avatar)
		_avatars[peer_id] = avatar
		_move_cooldowns[peer_id] = 0.0
		if _is_race_mode():
			_race_progress[peer_id] = 0
			_race_sequences_by_peer[peer_id] = _race_sequence_for_start(spawn_grid)
			_race_colors_by_peer[peer_id] = _distinct_race_color(peer_id, String(info.get("character_id", "")))

func _spawn_positions_for_session(session: Dictionary) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	if _maze == null:
		return positions

	var players := session.get("players", {}) as Dictionary
	var roles := session.get("roles", {}) as Dictionary
	var spawn_slots := session.get("spawn_slots", {}) as Dictionary
	var corners := [
		Vector2i(0, 0),
		Vector2i(_maze.grid_size.x - 1, 0),
		Vector2i(0, _maze.grid_size.y - 1),
		Vector2i(_maze.grid_size.x - 1, _maze.grid_size.y - 1),
	]

	var peer_ids: Array[int] = []
	for raw_key in players.keys():
		peer_ids.append(int(raw_key))
	peer_ids.sort()
	for peer_id in peer_ids:
		var info := players.get(peer_id, players.get(str(peer_id), {})) as Dictionary
		var slot := clampi(int(spawn_slots.get(peer_id, spawn_slots.get(str(peer_id), 0))), 0, 3)
		var role := String(roles.get(peer_id, roles.get(str(peer_id), info.get("role", NetworkManager.ROLE_COLLECTOR))))
		if _is_roleless_next_symbol_mode():
			role = ""
		if _is_maze_race_mode():
			role = NetworkManager.ROLE_RACER
		if _is_race_mode():
			role = NetworkManager.ROLE_RACER

		var spawn_grid := _spawn_for_mode(role, slot, corners)
		if not positions.has(spawn_grid):
			positions.append(spawn_grid)
	return positions

func _set_start_markers(spawn_cells: Array[Vector2i]) -> void:
	if _maze == null:
		return
	for raw_cell in _maze.cells.values():
		var cell := raw_cell as MazeData.CellData
		if cell != null:
			cell.is_start = false
	for coords in spawn_cells:
		var cell := _maze.get_cell(coords)
		if cell != null:
			cell.is_start = true
			cell.is_visited = true

func _on_input_received(peer_id: int, direction: Vector2i, pressed: bool) -> void:
	if not multiplayer.is_server():
		return
	if not _avatars.has(peer_id):
		return

	if pressed:
		_held_directions[peer_id] = direction
	else:
		_held_directions.erase(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	if _avatars.has(peer_id):
		var avatar := _avatars[peer_id] as MultiplayerAvatar
		if is_instance_valid(avatar):
			avatar.queue_free()
		_avatars.erase(peer_id)
		_held_directions.erase(peer_id)
		_move_cooldowns.erase(peer_id)

func _process_host_local_input() -> void:
	var host_id := multiplayer.get_unique_id()
	if not _avatars.has(host_id):
		return

	var direction := Vector2i.ZERO
	if Input.is_action_pressed("ui_up"):
		direction = Vector2i.UP
	elif Input.is_action_pressed("ui_down"):
		direction = Vector2i.DOWN
	elif Input.is_action_pressed("ui_left"):
		direction = Vector2i.LEFT
	elif Input.is_action_pressed("ui_right"):
		direction = Vector2i.RIGHT

	if direction == Vector2i.ZERO:
		_held_directions.erase(host_id)
	else:
		_held_directions[host_id] = direction

func _process_held_input(delta: float) -> void:
	for key in _avatars.keys():
		var peer_id := int(key)
		var cooldown := float(_move_cooldowns.get(peer_id, 0.0))
		cooldown -= delta
		_move_cooldowns[peer_id] = cooldown

		if cooldown > 0.0:
			continue
		if not _held_directions.has(peer_id):
			continue

		var direction := _held_directions[peer_id] as Vector2i
		_try_move(peer_id, direction)
		_move_cooldowns[peer_id] = Config.move_cooldown

func _try_move(peer_id: int, direction: Vector2i) -> void:
	if not _avatars.has(peer_id):
		return
	if _is_race_mode() and _race_finished:
		return
	if _win_screen != null and _win_screen.is_active():
		return
	if _delayed_chaser_peer_ids.has(peer_id):
		return

	var avatar := _avatars[peer_id] as MultiplayerAvatar
	var target := avatar.grid_pos + direction
	if _maze == null:
		return
	if not _maze.is_wall_open(avatar.grid_pos, direction):
		return

	avatar.move_to_grid(target, maze_renderer, Config.tween_duration)
	_display_move_count += 1
	if hud != null:
		hud.update_moves(_display_move_count)
	if _is_chaser_variant() and avatar.role == NetworkManager.ROLE_COLLECTOR:
		_collector_move_count += 1
		_check_path_chaser_release()
	if _uses_shared_collectibles() and _collectible_spawner != null and not _round_complete:
		if _can_collect(peer_id):
			_collectible_spawner.check_collection(target)
		_check_shared_finish(peer_id, target)
		_check_chaser_catch()
	elif _is_race_mode() and not _race_finished:
		_check_race_collection(peer_id, target)
		_check_race_finish(peer_id, target)

func _on_network_debug_changed(scope: String, message: String) -> void:
	_set_network_debug(scope, message)

func _set_network_debug(scope: String, message: String) -> void:
	if network_debug_label == null:
		return
	network_debug_label.text = "Network [%s]: %s" % [scope, message]

func _is_next_symbol_mode() -> bool:
	return Config.game_style == Config.STYLE_NEXT_SYMBOL

func _is_path_mode() -> bool:
	return Config.game_style == Config.STYLE_PATH

func _is_race_mode() -> bool:
	return Config.game_style == Config.STYLE_RACE

func _is_maze_race_mode() -> bool:
	return _is_path_mode() and not _chaser_enabled and Config.game_mode == Config.GameMode.NORMAL

func _is_chaser_variant() -> bool:
	return _chaser_enabled and (Config.game_style == Config.STYLE_PATH or Config.game_style == Config.STYLE_NEXT_SYMBOL)

func _is_roleless_next_symbol_mode() -> bool:
	return _is_next_symbol_mode() and not _chaser_enabled

func _uses_shared_collectibles() -> bool:
	return _is_path_mode() or _is_next_symbol_mode()

func _on_collectible_gathered(value_str: String, collect_index: int, lang: String) -> void:
	if Config.voice_hints:
		if Config.game_mode == Config.GameMode.WORDS:
			TTS.speak(value_str, 0.85, lang)
			_speak_completed_word_if_needed(lang)
		else:
			TTS.speak(value_str, 0.85)
	if _is_next_symbol_mode() and _collectible_spawner != null and _collectible_spawner.is_complete():
		_round_complete = true
		_held_directions.clear()
	_refresh_status_label()

func _refresh_status_label() -> void:
	if _is_race_mode():
		if status_label != null:
			status_label.text = _format_race_status()
		_refresh_race_hud()
		return
	if not _uses_shared_collectibles() or _collectible_spawner == null:
		if status_label != null:
			status_label.text = tr("mp_game_running")
		return
	if _is_maze_race_mode():
		if status_label != null:
			status_label.text = tr("mission_goal_exit_multi")
		_refresh_shared_hud()
		return

	var total := _collectible_spawner.get_total_collectibles()
	var current := _collectible_spawner.get_next_collect_index()
	if _collector_caught:
		if status_label != null:
			status_label.text = tr("gotcha")
		return
	if _round_complete or (_is_next_symbol_mode() and total > 0 and current >= total):
		if status_label != null:
			status_label.text = "%s  %d/%d" % [tr("you_win"), total, total]
		_refresh_shared_hud()
		return

	var target := _collectible_spawner.get_current_target()
	var progress := ""
	if total > 0:
		progress = "  %d/%d" % [mini(current + 1, total), total]
	if _is_path_mode() and total > 0 and current >= total:
		if status_label != null:
			status_label.text = "%s  %d/%d" % [tr("style_path"), total, total]
		_refresh_shared_hud()
		return
	if status_label != null:
		status_label.text = "%s: %s%s" % [tr("hud_target_now"), target, progress]
	_refresh_shared_hud()

func _refresh_shared_hud() -> void:
	if hud == null or _collectible_spawner == null:
		return
	if Config.game_mode == Config.GameMode.WORDS:
		hud.update_word_display(Config.current_word, Config.game_mode)
		for i in range(_collectible_spawner.get_word_next_index()):
			hud.light_up_letter(i)
	else:
		hud.update_target_display(
			_collectible_spawner.get_current_target(),
			_collectible_spawner.get_next_collect_index(),
			_collectible_spawner.get_total_collectibles()
		)
	hud.update_role(_hud_role_key())

func _refresh_race_hud() -> void:
	if hud == null:
		return
	var total := _race_sequence.size()
	if _race_finished:
		hud.update_target_display(_player_name(_race_winner_peer_id), total, total)
		return
	var leader_peer_id := _race_leader_peer_id()
	var progress := int(_race_progress.get(leader_peer_id, 0)) if leader_peer_id != 0 else 0
	var target := _race_target_for_peer(leader_peer_id) if leader_peer_id != 0 else ""
	hud.update_target_display(target, progress, total)
	hud.update_role(Config.ROLE_RACER)

func _race_leader_peer_id() -> int:
	var best_peer_id := 0
	var best_progress := -1
	for key in _race_progress.keys():
		var peer_id := int(key)
		var progress := int(_race_progress.get(peer_id, 0))
		if progress > best_progress:
			best_progress = progress
			best_peer_id = peer_id
	return best_peer_id

func _hud_role_key() -> String:
	if _is_race_mode():
		return Config.ROLE_RACER
	if _is_maze_race_mode():
		return Config.ROLE_RACER
	if _is_roleless_next_symbol_mode():
		return ""
	if _is_chaser_variant():
		return Config.ROLE_COLLECTOR
	return Config.ROLE_COLLECTOR

func _speak_completed_word_if_needed(lang_override: String = "") -> void:
	if _completed_word_spoken:
		return
	if _collectible_spawner == null or not _collectible_spawner.is_complete():
		return
	var phrase := String(Config.current_word.get("word", "")).strip_edges()
	if phrase.is_empty():
		return
	_completed_word_spoken = true
	var word_lang := lang_override
	if word_lang.is_empty():
		word_lang = String(Config.current_word.get("lang", ""))
	get_tree().create_timer(1.0).timeout.connect(func(): TTS.speak(phrase, 0.7, word_lang))

func _spawn_for_role(role: String, slot: int) -> Vector2i:
	if _maze == null:
		return Vector2i.ZERO
	var end_cell := _maze.get_end_cell()
	var collector_start := Vector2i(0, _maze.grid_size.y - 1)
	if role == NetworkManager.ROLE_COLLECTOR:
		return collector_start
	if _is_path_mode():
		return collector_start

	var candidates: Array[Vector2i] = []
	if end_cell != null:
		candidates.append(end_cell.coords)
	candidates.append(Vector2i(_maze.grid_size.x - 1, 0))
	candidates.append(Vector2i(_maze.grid_size.x - 1, _maze.grid_size.y - 1))
	candidates.append(Vector2i(0, 0))
	candidates.append(Vector2i(0, _maze.grid_size.y - 1))

	var chaser_idx := maxi(0, slot - 1)
	for i in range(candidates.size()):
		var candidate := candidates[(chaser_idx + i) % candidates.size()]
		if candidate != collector_start and _maze.get_cell(candidate) != null:
			return candidate
	return collector_start

func _spawn_for_mode(role: String, slot: int, corners: Array) -> Vector2i:
	var clamped_slot := clampi(slot, 0, maxi(0, corners.size() - 1))
	if _is_path_mode():
		var path_role := role
		if not _is_chaser_variant():
			path_role = NetworkManager.ROLE_COLLECTOR
		return _spawn_for_role(path_role, clamped_slot)
	if _is_chaser_variant():
		return _spawn_for_role(role, clamped_slot)
	return corners[clamped_slot] as Vector2i

func _should_delay_path_chaser(role: String) -> bool:
	return _is_chaser_variant() and role == NetworkManager.ROLE_CHASER

func _check_path_chaser_release() -> void:
	if _path_chasers_released:
		return
	if _collector_move_count < _path_chaser_trigger_moves():
		return
	_release_path_chasers()

func _path_chaser_trigger_moves() -> int:
	var level := Config.chaser_level
	if level == Config.ChaserLevel.OFF:
		level = Config.ChaserLevel.SLOW
	match level:
		Config.ChaserLevel.SLOW:
			return 10 + Config.difficulty * 5
		Config.ChaserLevel.MEDIUM:
			return 6 + Config.difficulty * 3
		Config.ChaserLevel.FAST:
			return 3 + Config.difficulty * 2
		Config.ChaserLevel.TURBO:
			return 1
		_:
			return 10 + Config.difficulty * 5

func _release_path_chasers() -> void:
	_path_chasers_released = true
	for peer_id in _delayed_chaser_peer_ids:
		var avatar := _avatars.get(peer_id, null) as MultiplayerAvatar
		if avatar != null and is_instance_valid(avatar):
			avatar.visible = true
	_delayed_chaser_peer_ids.clear()

func _can_collect(peer_id: int) -> bool:
	if not _is_chaser_variant():
		return true
	return _role_for_peer(peer_id) == NetworkManager.ROLE_COLLECTOR

func _role_for_peer(peer_id: int) -> String:
	var avatar: MultiplayerAvatar = _avatars.get(peer_id, null) as MultiplayerAvatar
	if avatar != null:
		return avatar.role
	return NetworkManager.ROLE_COLLECTOR

func _check_shared_finish(peer_id: int, pos: Vector2i) -> void:
	if _round_complete or _collectible_spawner == null:
		return
	if _is_next_symbol_mode():
		if _collectible_spawner.is_complete():
			_round_complete = true
			_held_directions.clear()
			_speak_completed_word_if_needed()
			_refresh_status_label()
		return
	if not _is_path_mode():
		return
	if _is_chaser_variant() and _role_for_peer(peer_id) != NetworkManager.ROLE_COLLECTOR:
		return
	var end_cell := _maze.get_end_cell() if _maze != null else null
	if end_cell == null or end_cell.coords != pos:
		return
	if not _collectible_spawner.is_complete():
		return
	_round_complete = true
	_held_directions.clear()
	_speak_completed_word_if_needed()
	_refresh_status_label()
	if Config.game_mode == Config.GameMode.NORMAL or _is_chaser_variant():
		_show_shared_win_screen(peer_id)

func _check_chaser_catch() -> void:
	if not _is_chaser_variant() or _round_complete:
		return
	var collector := _collector_avatar()
	if collector == null:
		return
	for avatar_value in _avatars.values():
		var avatar := avatar_value as MultiplayerAvatar
		if avatar == null or avatar.peer_id == collector.peer_id:
			continue
		if _delayed_chaser_peer_ids.has(avatar.peer_id):
			continue
		if avatar.role == NetworkManager.ROLE_CHASER and avatar.grid_pos == collector.grid_pos:
			_collector_caught = true
			_catching_chaser_peer_id = avatar.peer_id
			_round_complete = true
			_held_directions.clear()
			_refresh_status_label()
			_show_gotcha_screen()
			return

func _collector_avatar() -> MultiplayerAvatar:
	if _collector_peer_id != 0 and _avatars.has(_collector_peer_id):
		return _avatars[_collector_peer_id] as MultiplayerAvatar
	for avatar_value in _avatars.values():
		var avatar := avatar_value as MultiplayerAvatar
		if avatar != null and avatar.role == NetworkManager.ROLE_COLLECTOR:
			return avatar
	return null

func _show_gotcha_screen() -> void:
	if _win_screen == null:
		return
	_win_screen.show_gotcha(_format_time(), _collector_move_count)

func _show_shared_win_screen(peer_id: int) -> void:
	if _win_screen == null:
		return
	_win_screen.show_race_win(_format_time(), _display_move_count, _character_id_for_peer(peer_id))

func _on_next_round_pressed() -> void:
	if _win_screen != null:
		_win_screen.hide_screen()
	_apply_session(NetworkManager.current_session)

func _on_swap_roles_pressed() -> void:
	if _catching_chaser_peer_id != 0:
		NetworkManager.swap_collector_with_peer(_catching_chaser_peer_id)
	if _win_screen != null:
		_win_screen.hide_screen()
	_apply_session(NetworkManager.current_session)

func _on_home_pressed() -> void:
	if _win_screen != null:
		_win_screen.hide_screen()
	NetworkManager.leave_session()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _build_race_sequence() -> void:
	_race_sequence.clear()
	if _maze == null:
		return
	if Config.game_mode == Config.GameMode.NORMAL:
		return
	var path_cells := _eligible_main_path_cells()
	if path_cells.is_empty():
		return

	if Config.game_mode == Config.GameMode.WORDS:
		_build_race_word_sequence(path_cells)
	else:
		_build_race_symbol_sequence(path_cells)

func _eligible_main_path_cells() -> Array[MazeData.CellData]:
	var result: Array[MazeData.CellData] = []
	if _maze == null:
		return result
	for coord in _maze.main_path_coords:
		var cell := _maze.get_cell(coord)
		if cell != null and not cell.is_start and not cell.is_end:
			result.append(cell)
	return result

func _build_race_symbol_sequence(path_cells: Array[MazeData.CellData]) -> void:
	var max_items: int = 26 if Config.game_mode == Config.GameMode.LETTERS else 50
	var item_count: int = maxi(1, mini(max_items, path_cells.size() / 3))
	var step := float(path_cells.size()) / float(item_count)
	for i in range(item_count):
		var path_idx := mini(int(i * step + (step / 2.0)), path_cells.size() - 1)
		var value := str(i + 1)
		if Config.game_mode == Config.GameMode.LETTERS:
			value = Config.get_alphabet_char(i, Config.get_effective_learning_language())
		_race_sequence.append({
			"cell": path_cells[path_idx],
			"value": value,
			"index": i,
		})

func _build_race_word_sequence(path_cells: Array[MazeData.CellData]) -> void:
	var lang := Config.get_effective_learning_language()
	var word_data := WordList.get_random_word(lang, _race_word_difficulty())
	if word_data.is_empty():
		return
	Config.current_word = word_data
	var word := String(word_data.get("word", ""))
	var chars: Array[int] = []
	for i in range(word.length()):
		if word[i] != " ":
			chars.append(i)
	if chars.is_empty():
		return
	var step := float(path_cells.size()) / float(chars.size())
	for i in range(chars.size()):
		var char_idx := chars[i]
		var path_idx := mini(int(i * step + (step / 2.0)), path_cells.size() - 1)
		_race_sequence.append({
			"cell": path_cells[path_idx],
			"value": word[char_idx],
			"index": i,
			"word_index": char_idx,
		})

func _race_word_difficulty() -> int:
	return maxi(0, Config.difficulty - 1)

func _spawn_race_markers() -> void:
	_clear_race_markers()
	if _race_marker_root == null:
		return
	var peer_ids: Array[int] = []
	for key in _race_sequences_by_peer.keys():
		peer_ids.append(int(key))
	peer_ids.sort()
	for peer_id in peer_ids:
		var sequence := _race_sequence_for_peer(peer_id)
		var markers: Array[Collectible] = []
		var accent: Color = _race_colors_by_peer.get(peer_id, Color("#5AC8FF"))
		for item in sequence:
			var marker_data := item as Dictionary
			var cell := marker_data.get("cell") as MazeData.CellData
			if cell == null:
				continue
			var marker := CollectibleScene.instantiate() as Collectible
			marker.grid_pos = cell.coords
			marker.value_str = String(marker_data.get("value", ""))
			marker.collect_index = int(marker_data.get("index", -1))
			_race_marker_root.add_child(marker)
			marker.setup(maze_renderer.get_cell_size(), maze_renderer.maze_theme)
			marker.set_accent_tint(accent)
			marker.position = maze_renderer.grid_to_pixel(cell.coords)
			marker.name = "RaceMarker_%d_%d" % [peer_id, marker.collect_index]
			markers.append(marker)
		_race_markers_by_peer[peer_id] = markers

func _clear_race_markers() -> void:
	if _race_marker_root == null:
		return
	for child in _race_marker_root.get_children():
		child.queue_free()
	_race_markers_by_peer.clear()

func _check_race_collection(peer_id: int, pos: Vector2i) -> void:
	var sequence := _race_sequence_for_peer(peer_id)
	var progress := int(_race_progress.get(peer_id, 0))
	if progress < 0 or progress >= sequence.size():
		return
	var item := sequence[progress] as Dictionary
	var cell := item.get("cell") as MazeData.CellData
	if cell == null or cell.coords != pos:
		return
	var markers := _race_markers_by_peer.get(peer_id, []) as Array
	if progress >= 0 and progress < markers.size():
		var marker := markers[progress] as Collectible
		if marker != null and is_instance_valid(marker):
			marker.collect()
	_race_progress[peer_id] = progress + 1
	_play_race_collect_sound()
	_refresh_status_label()

func _check_race_finish(peer_id: int, pos: Vector2i) -> void:
	if _race_finished:
		return
	if _maze == null:
		return
	var end_cell := _maze.get_end_cell()
	if end_cell == null or end_cell.coords != pos:
		return
	if int(_race_progress.get(peer_id, 0)) < _race_sequence_for_peer(peer_id).size():
		return
	_race_finished = true
	_race_winner_peer_id = peer_id
	_held_directions.clear()
	_refresh_status_label()
	_speak_race_completion_once()
	if _win_screen != null:
		_win_screen.show_race_win(_format_time(), int(_race_progress.get(peer_id, 0)), _character_id_for_peer(peer_id))

func _format_time() -> String:
	var elapsed_int: int = int(_elapsed_time)
	return "%02d:%02d" % [elapsed_int / 60, elapsed_int % 60]

func _format_race_status() -> String:
	var total := _race_sequence.size()
	if _race_finished:
		return "%s: %s" % [tr("you_win"), _player_name(_race_winner_peer_id)]
	var lines: Array[String] = [tr("style_race")]
	var peer_ids: Array[int] = []
	for key in _avatars.keys():
		peer_ids.append(int(key))
	peer_ids.sort()
	for peer_id in peer_ids:
		var progress := int(_race_progress.get(peer_id, 0))
		var target := _race_target_for_peer(peer_id)
		var target_text := ""
		if not target.is_empty():
			target_text = " | %s: %s" % [tr("hud_target_now"), target]
		lines.append("%s  %d/%d%s" % [_player_name(peer_id), progress, total, target_text])
	var packed_lines := PackedStringArray()
	for line in lines:
		packed_lines.append(line)
	return "\n".join(packed_lines)

func _race_target_for_peer(peer_id: int) -> String:
	var sequence := _race_sequence_for_peer(peer_id)
	var progress := int(_race_progress.get(peer_id, 0))
	if progress < 0 or progress >= sequence.size():
		return ""
	return String((sequence[progress] as Dictionary).get("value", ""))

func _race_sequence_for_peer(peer_id: int) -> Array:
	return (_race_sequences_by_peer.get(peer_id, []) as Array)

func _race_sequence_for_start(start: Vector2i) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if _race_sequence.is_empty() or _maze == null:
		return result
	var canonical_cells := _eligible_main_path_cells()
	var center := _race_center()
	var path := _race_path_from_corner(start, center)
	var cells := _eligible_cells_from_path(path)
	if cells.is_empty():
		return result
	for item in _race_sequence:
		var source := item as Dictionary
		var source_cell := source.get("cell") as MazeData.CellData
		if source_cell == null:
			continue
		var canonical_idx := canonical_cells.find(source_cell)
		if canonical_idx < 0:
			canonical_idx = int(source.get("index", 0))
		var cell := cells[clampi(canonical_idx, 0, cells.size() - 1)]
		result.append({
			"cell": cell,
			"value": String(source.get("value", "")),
			"index": int(source.get("index", 0)),
		})
	return result

func _eligible_cells_from_path(path: Array[Vector2i]) -> Array[MazeData.CellData]:
	var result: Array[MazeData.CellData] = []
	if _maze == null:
		return result
	for coord in path:
		var cell := _maze.get_cell(coord)
		if cell != null and not cell.is_start and not cell.is_end:
			result.append(cell)
	return result

func _race_center() -> Vector2i:
	var end_cell := _maze.get_end_cell() if _maze != null else null
	if end_cell != null:
		return end_cell.coords
	return Vector2i.ZERO

func _race_path_from_corner(start: Vector2i, center: Vector2i) -> Array[Vector2i]:
	if _maze == null:
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
			if not _maze.is_wall_open(pos, dir):
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

func _distinct_race_color(peer_id: int, character_id: String) -> Color:
	var palette := AvatarAccent.palette_from_character_id(character_id)
	var color: Color = palette.get("accent", Color("#5AC8FF"))
	color.a = 1.0

	var used: Array[Color] = []
	for key in _race_colors_by_peer.keys():
		if int(key) == peer_id:
			continue
		used.append(_race_colors_by_peer[key] as Color)

	var hsv := _rgb_to_hsv(color)
	var candidate := Color.from_hsv(hsv.x, clampf(maxf(hsv.y, 0.70), 0.0, 1.0), clampf(maxf(hsv.z, 0.86), 0.0, 1.0), 1.0)
	for i in range(8):
		if _race_color_is_distinct(candidate, used):
			return candidate
		var hue := fposmod(hsv.x + 0.23 * float(i + 1), 1.0)
		candidate = Color.from_hsv(hue, 0.82, 0.94, 1.0)
	return candidate

func _race_color_is_distinct(color: Color, used: Array[Color]) -> bool:
	var hsv := _rgb_to_hsv(color)
	for other in used:
		var other_hsv := _rgb_to_hsv(other)
		var hue_delta: float = absf(hsv.x - other_hsv.x)
		hue_delta = minf(hue_delta, 1.0 - hue_delta)
		var rgb_delta := Vector3(color.r - other.r, color.g - other.g, color.b - other.b).length()
		if hue_delta < 0.12 or rgb_delta < 0.32:
			return false
	return true

func _rgb_to_hsv(color: Color) -> Vector3:
	var r: float = color.r
	var g: float = color.g
	var b: float = color.b
	var max_c: float = max(r, max(g, b))
	var min_c: float = min(r, min(g, b))
	var delta: float = max_c - min_c
	var hue: float = 0.0
	if delta > 0.000001:
		if max_c == r:
			hue = fposmod((g - b) / delta, 6.0)
		elif max_c == g:
			hue = ((b - r) / delta) + 2.0
		else:
			hue = ((r - g) / delta) + 4.0
		hue /= 6.0
	var saturation: float = 0.0 if max_c <= 0.000001 else delta / max_c
	return Vector3(hue, saturation, max_c)

func _player_name(peer_id: int) -> String:
	var session_players := NetworkManager.current_session.get("players", {}) as Dictionary
	var info := session_players.get(peer_id, session_players.get(str(peer_id), {})) as Dictionary
	var character_id := String(info.get("character_id", ""))
	var display := CharacterCatalog.display_name_for_id(character_id)
	if display.is_empty():
		display = "%s %d" % [tr("mp_host_player"), peer_id]
	return display

func _character_id_for_peer(peer_id: int) -> String:
	var session_players := NetworkManager.current_session.get("players", {}) as Dictionary
	var info := session_players.get(peer_id, session_players.get(str(peer_id), {})) as Dictionary
	return String(info.get("character_id", ""))

func _speak_race_completion_once() -> void:
	if not Config.voice_hints:
		return
	if Config.game_mode != Config.GameMode.WORDS:
		return
	if _completed_word_spoken:
		return
	var phrase := String(Config.current_word.get("word", "")).strip_edges()
	if phrase.is_empty():
		return
	_completed_word_spoken = true
	var word_lang := String(Config.current_word.get("lang", ""))
	get_tree().create_timer(0.8).timeout.connect(func(): TTS.speak(phrase, 0.7, word_lang))

func _build_race_collect_sound() -> void:
	_race_collect_player = AudioStreamPlayer.new()
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 22050.0
	stream.buffer_length = 0.08
	_race_collect_player.stream = stream
	add_child(_race_collect_player)

func _play_race_collect_sound() -> void:
	if _race_collect_player == null:
		return
	_race_collect_player.play()
	var playback := _race_collect_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	var mix_rate := 22050.0
	var frames := int(mix_rate * 0.055)
	for i in range(frames):
		var fade := 1.0 - (float(i) / float(frames))
		var sample := sin(TAU * 880.0 * float(i) / mix_rate) * 0.12 * fade
		playback.push_frame(Vector2(sample, sample))
