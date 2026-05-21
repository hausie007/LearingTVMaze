extends Node
class_name MultiplayerGameManager

const CollectibleScene := preload("res://scenes/collectible.tscn")
const MissionCatalog := preload("res://scripts/mission_catalog.gd")
const LearningRecapBuilder := preload("res://scripts/learning_recap.gd")
const MpHudBadgeManager := preload("res://scripts/multiplayer/mp_hud_badge_manager.gd")
const AvatarSpawner := preload("res://scripts/multiplayer/avatar_spawner.gd")

const FINISH_SHORTCUT_MP_CHASER := "mp_chaser"
const FINISH_SHORTCUT_PICKUP_PREFIX := "pickup:"
const FINISH_SHORTCUT_TRAPS := "traps"
const FINISH_PICKUP_PROGRESSION: Array[String] = [
	MissionCatalog.PICKUP_NONE,
	MissionCatalog.PICKUP_NUMBERS,
	MissionCatalog.PICKUP_LETTERS,
	MissionCatalog.PICKUP_WORDS,
]

@export var avatar_scene: PackedScene

@onready var maze_generator: MazeGenerator = $MazeGenerator
@onready var maze_renderer: MazeRenderer = $MazeRenderer
@onready var hud: GameHUD = $HUD
@onready var players_root: Node2D = %Players
@onready var status_label: Label = %StatusLabel
@onready var network_debug_label: Label = %NetworkDebugLabel

var _maze: MazeData = null
var _display_move_count: int = 0
var _collectible_spawner: CollectibleSpawner = null
var _trap_manager: TrapManager = null
var _avatars: Dictionary = {}
var _held_directions: Dictionary = {}
var _move_cooldowns: Dictionary = {}
var _previous_cells_by_peer: Dictionary = {}
var _trap_available_by_peer: Dictionary = {}
var _confusion_moves_by_peer: Dictionary = {}
var _game_style: String = NetworkManager.STYLE_PATH
var _mission_id: String = NetworkManager.MISSION_FOLLOW_TRAIL
var _training_type: String = NetworkManager.TRAINING_WORDS
var _chaser_enabled: bool = false
var _traps_enabled: bool = false
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
var _pause_dialog: PauseDialog = null
var _finished_peers: Dictionary = {}
var _trap_input_unlock_msec: int = 0

var _saved_theme_dir: String = ""
var _saved_difficulty: int = 0
var _saved_game_style: String = ""
var _saved_mission_id: String = ""
var _saved_training_type: String = ""
var _saved_game_mode: int = 0
var _saved_current_word: Dictionary = {}
var _saved_traps_enabled: bool = false

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
	_saved_traps_enabled = Config.traps_enabled

	_collectible_spawner = CollectibleSpawner.new()
	_collectible_spawner.name = "CollectibleSpawner"
	add_child(_collectible_spawner)
	_collectible_spawner.collectible_gathered.connect(_on_collectible_gathered)

	_trap_manager = TrapManager.new()
	_trap_manager.name = "TrapManager"
	add_child(_trap_manager)

	_race_marker_root = Node2D.new()
	_race_marker_root.name = "RaceMarkers"
	add_child(_race_marker_root)

	_win_screen = WinScreen.new()
	_win_screen.set_swap_roles_enabled(false)
	_win_screen.set_is_multiplayer(true)
	_win_screen.next_round_pressed.connect(_on_next_round_pressed)
	_win_screen.harder_pressed.connect(_on_harder_pressed)
	_win_screen.home_pressed.connect(_on_home_pressed)
	_win_screen.swap_roles_pressed.connect(_on_swap_roles_pressed)
	_win_screen.play_alone_pressed.connect(_on_play_alone_pressed)
	_win_screen.finish_shortcut_pressed.connect(_on_finish_shortcut_pressed)
	add_child(_win_screen)

	_pause_dialog = PauseDialog.new()
	_pause_dialog.confirmed.connect(func(): _pause_dialog.hide_dialog(); NetworkManager.leave_session(); get_tree().change_scene_to_file(Scenes.HOME))
	_pause_dialog.cancelled.connect(func(): _pause_dialog.hide_dialog(); _arm_trap_input_lockout(); _update_local_dpad_confusion_visual(_is_peer_confused(NetworkManager.HOST_PEER_ID)))
	add_child(_pause_dialog)

	_build_race_collect_sound()

	NetworkManager.input_received.connect(_on_input_received)
	NetworkManager.trap_use_received.connect(_on_trap_use_received)
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
	if NetworkManager.input_received.is_connected(_on_input_received):
		NetworkManager.input_received.disconnect(_on_input_received)
	if NetworkManager.trap_use_received.is_connected(_on_trap_use_received):
		NetworkManager.trap_use_received.disconnect(_on_trap_use_received)
	if NetworkManager.peer_disconnected.is_connected(_on_peer_disconnected):
		NetworkManager.peer_disconnected.disconnect(_on_peer_disconnected)
	if NetworkManager.game_started.is_connected(_on_game_started):
		NetworkManager.game_started.disconnect(_on_game_started)
	if NetworkManager.debug_status_changed.is_connected(_on_network_debug_changed):
		NetworkManager.debug_status_changed.disconnect(_on_network_debug_changed)

	_update_local_dpad_confusion_visual(false)
	Config.theme_dir_name = _saved_theme_dir
	Config.difficulty = _saved_difficulty
	Config.game_style = _saved_game_style
	Config.mission_id = _saved_mission_id
	Config.training_type = _saved_training_type
	Config.game_mode = _saved_game_mode
	Config.current_word = _saved_current_word
	Config.traps_enabled = _saved_traps_enabled

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		var viewport: Viewport = get_viewport()
		if _win_screen != null and _win_screen.is_active():
			return
		if viewport != null:
			viewport.set_input_as_handled()
		_toggle_pause()

func _toggle_pause() -> void:
	if _pause_dialog.visible:
		_pause_dialog.hide_dialog()
		_arm_trap_input_lockout()
		_update_local_dpad_confusion_visual(_is_peer_confused(NetworkManager.HOST_PEER_ID))
	else:
		_pause_dialog.show_dialog()
		_update_local_dpad_confusion_visual(false)

func _process(delta: float) -> void:
	if _maze != null and (_win_screen == null or not _win_screen.is_active()):
		pass  # Timer removed; nothing to tick per-frame for HUD.
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
		_traps_enabled = bool(cfg.get("traps_enabled", false)) and Config.traps_allowed_for_session(Config.game_style, _chaser_enabled, _mission_id)
		Config.traps_enabled = _traps_enabled
	_completed_word_spoken = false
	_round_complete = false
	_display_move_count = 0
	_collector_caught = false
	_catching_chaser_peer_id = 0
	_collector_move_count = 0
	_path_chasers_released = not _is_chaser_variant()
	_delayed_chaser_peer_ids.clear()
	_previous_cells_by_peer.clear()
	_trap_available_by_peer.clear()
	_confusion_moves_by_peer.clear()
	_race_finished = false
	_race_winner_peer_id = 0
	_race_sequence.clear()
	_race_sequences_by_peer.clear()
	_race_progress.clear()
	_race_colors_by_peer.clear()
	_race_markers_by_peer.clear()
	_finished_peers.clear()
	_update_win_screen_options()
	if _win_screen != null:
		_win_screen.set_learning_recap({})

	_maze = maze_generator.generate_race(Config.grid_size) if _is_race_mode() else maze_generator.generate()
	_set_start_markers(_spawn_positions_for_session(session))
	if hud != null:
		maze_renderer.top_margin = hud.get_height()
		hud.update_role(_hud_role_key())
	else:
		maze_renderer.top_margin = GameHUD.HUD_HEIGHT
	maze_renderer.draw_maze(_maze)
	if _trap_manager != null:
		_trap_manager.setup(_maze, maze_renderer)
	_clear_race_markers()
	if _is_race_mode():
		_build_race_sequence()  # Must run before _spawn_avatars so per-peer paths are populated.
	_spawn_avatars(session)
	_initialize_trap_state_for_session(session)
	if _collectible_spawner != null:
		_collectible_spawner.clear()
		if _uses_shared_collectibles():
			if _is_roleless_next_symbol_mode():
				_collectible_spawner.configure_competitive_mode(_get_all_player_positions)
			_collectible_spawner.spawn(_maze, maze_renderer, Config.game_style)
	_setup_mp_player_badges(session)
	if _is_race_mode():
		_spawn_race_markers()
		_setup_race_hud()
		_update_all_race_highlights()
	_check_path_chaser_release()
	_arm_trap_input_lockout()
	_refresh_status_label()
	_set_network_debug("net", "Game running on host")

func _setup_mp_player_badges(session: Dictionary) -> void:
	MpHudBadgeManager.setup_mp_player_badges(self, session)

func _spawn_avatars(session: Dictionary) -> void:
	AvatarSpawner.spawn_avatars(self, session)

func _initialize_trap_state_for_session(session: Dictionary) -> void:
	_trap_available_by_peer.clear()
	_confusion_moves_by_peer.clear()
	var players := session.get("players", {}) as Dictionary
	for key in _avatars.keys():
		var peer_id := int(key)
		var info := players.get(peer_id, players.get(str(peer_id), {})) as Dictionary
		var is_ai := bool(info.get("is_ai", false))
		_trap_available_by_peer[peer_id] = _traps_enabled and not is_ai
		_confusion_moves_by_peer[peer_id] = 0
		var avatar := _avatars[peer_id] as MultiplayerAvatar
		if avatar != null:
			avatar.set_confused_visual(false)
		_send_trap_status(peer_id)

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

func _on_trap_use_received(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	_try_drop_trap(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	if _avatars.has(peer_id):
		var avatar := _avatars[peer_id] as MultiplayerAvatar
		if is_instance_valid(avatar):
			avatar.queue_free()
		_avatars.erase(peer_id)
		_held_directions.erase(peer_id)
		_move_cooldowns.erase(peer_id)
		_previous_cells_by_peer.erase(peer_id)
		_trap_available_by_peer.erase(peer_id)
		_confusion_moves_by_peer.erase(peer_id)
	_finished_peers.erase(peer_id)
	_delayed_chaser_peer_ids.erase(peer_id)

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
	if Input.is_action_just_pressed("ui_accept"):
		_try_drop_trap(host_id)

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
	var actual_direction := -direction if _is_peer_confused(peer_id) else direction
	var target := avatar.grid_pos + actual_direction
	if _maze == null:
		return
	if not _maze.is_wall_open(avatar.grid_pos, actual_direction):
		avatar.shake_wall(actual_direction, maze_renderer)
		return

	_previous_cells_by_peer[peer_id] = avatar.grid_pos
	avatar.move_to_grid(target, maze_renderer, Config.tween_duration)
	_consume_peer_confusion_move(peer_id)
	_display_move_count += 1
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
	_trigger_trap_for_peer(peer_id, target)

func _can_accept_trap_input(peer_id: int) -> bool:
	if not _traps_enabled:
		return false
	if not _avatars.has(peer_id):
		return false
	if _win_screen != null and _win_screen.is_active():
		return false
	if _pause_dialog != null and _pause_dialog.visible:
		return false
	if _round_complete or _race_finished:
		return false
	if Time.get_ticks_msec() < _trap_input_unlock_msec:
		return false
	return bool(_trap_available_by_peer.get(peer_id, false))

func _arm_trap_input_lockout() -> void:
	_trap_input_unlock_msec = Time.get_ticks_msec() + int(Config.TRAP_INPUT_LOCKOUT_SEC * 1000.0)

func _try_drop_trap(peer_id: int) -> void:
	if not _can_accept_trap_input(peer_id):
		return
	if not _previous_cells_by_peer.has(peer_id):
		return
	var coord := _previous_cells_by_peer[peer_id] as Vector2i
	if _trap_manager == null or not _trap_manager.can_drop_on(coord, _important_trap_blocked_cells(peer_id)):
		return
	if not _trap_manager.drop_trap(peer_id, coord):
		return
	var avatar := _avatars.get(peer_id, null) as MultiplayerAvatar
	if avatar != null:
		avatar.play_confusion_shake(maze_renderer)
	_trap_available_by_peer[peer_id] = false
	_send_trap_status(peer_id)
	_refresh_player_badges_for_traps()

func _important_trap_blocked_cells(dropper_peer_id: int = 0) -> Dictionary:
	var blocked := {}
	for key in _avatars.keys():
		var avatar := _avatars[key] as MultiplayerAvatar
		if avatar != null:
			blocked[avatar.grid_pos] = true
	if _collectible_spawner != null:
		for pos in _collectible_spawner.get_collectible_positions():
			blocked[pos] = true
	for pos in _race_marker_positions():
		blocked[pos] = true
	if _trap_manager != null:
		for pos in _trap_manager.get_trap_positions():
			blocked[pos] = true
	if dropper_peer_id != 0 and _avatars.has(dropper_peer_id):
		var dropper := _avatars[dropper_peer_id] as MultiplayerAvatar
		if dropper != null:
			blocked[dropper.grid_pos] = true
	return blocked

func _race_marker_positions() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for markers_value in _race_markers_by_peer.values():
		var markers := markers_value as Array
		for marker_value in markers:
			if is_instance_valid(marker_value):
				var marker := marker_value as Collectible
				if marker != null:
					result.append(marker.grid_pos)
	return result

func _trigger_trap_for_peer(peer_id: int, pos: Vector2i) -> void:
	if not _traps_enabled or _trap_manager == null:
		return
	if _round_complete or _race_finished:
		return
	if not _trap_manager.trigger_at(pos):
		return
	var remaining := int(_confusion_moves_by_peer.get(peer_id, 0)) + Config.TRAP_CONFUSION_MOVES
	_set_peer_confusion(peer_id, remaining, Config.tween_duration)

func _is_peer_confused(peer_id: int) -> bool:
	return int(_confusion_moves_by_peer.get(peer_id, 0)) > 0

func _consume_peer_confusion_move(peer_id: int) -> void:
	var remaining := int(_confusion_moves_by_peer.get(peer_id, 0))
	if remaining <= 0:
		return
	var next_remaining := maxi(0, remaining - 1)
	var recovered := remaining > 0 and next_remaining == 0
	_set_peer_confusion(peer_id, next_remaining, Config.tween_duration if recovered else 0.0)

func _set_peer_confusion(peer_id: int, remaining: int, visual_delay_sec: float = 0.0) -> void:
	var old_remaining := int(_confusion_moves_by_peer.get(peer_id, 0))
	var new_remaining := maxi(0, remaining)
	_confusion_moves_by_peer[peer_id] = new_remaining
	var avatar := _avatars.get(peer_id, null) as MultiplayerAvatar
	if avatar != null:
		var should_shake := new_remaining > old_remaining or (old_remaining > 0 and new_remaining == 0)
		avatar.set_confused_visual(new_remaining > 0, should_shake, maze_renderer, visual_delay_sec if should_shake else 0.0)
	if peer_id == NetworkManager.HOST_PEER_ID:
		_update_local_dpad_confusion_visual(new_remaining > 0)
	_send_trap_status(peer_id)
	_refresh_player_badges_for_traps()

func _clear_all_traps_and_confusion() -> void:
	if _trap_manager != null:
		_trap_manager.clear()
	for key in _avatars.keys():
		var peer_id := int(key)
		_confusion_moves_by_peer[peer_id] = 0
		var avatar := _avatars[peer_id] as MultiplayerAvatar
		if avatar != null:
			avatar.set_confused_visual(false)
		if peer_id == NetworkManager.HOST_PEER_ID:
			_update_local_dpad_confusion_visual(false)
		_send_trap_status(peer_id)
	_refresh_player_badges_for_traps()

func _send_trap_status(peer_id: int) -> void:
	var available := bool(_trap_available_by_peer.get(peer_id, false))
	var remaining := int(_confusion_moves_by_peer.get(peer_id, 0))
	if peer_id != NetworkManager.HOST_PEER_ID:
		if multiplayer.get_peers().has(peer_id):
			NetworkManager.rpc_id(peer_id, "rpc_update_remote_trap_status", available, remaining)

func _refresh_player_badges_for_traps() -> void:
	if hud == null:
		return
	if _is_race_mode():
		_setup_race_hud()
		_refresh_race_hud()
	else:
		_refresh_mp_player_badges()

func _trap_texture() -> Texture2D:
	if maze_renderer == null:
		return null
	var theme := maze_renderer.get_theme_loader()
	return theme.trap_texture if theme != null else null

func _update_local_dpad_confusion_visual(enabled: bool) -> void:
	if DPad != null and DPad.has_method("set_controls_reversed_visual"):
		DPad.call("set_controls_reversed_visual", enabled)

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

func _has_shared_collectibles() -> bool:
	return (
		_uses_shared_collectibles()
		and _collectible_spawner != null
		and _collectible_spawner.get_total_collectibles() > 0
	)

func _is_shared_collectible_phase_active() -> bool:
	return _has_shared_collectibles() and not _collectible_spawner.is_complete()

func _on_collectible_gathered(value_str: String, collect_index: int, lang: String) -> void:
	if Config.voice_hints:
		if Config.game_mode == Config.GameMode.WORDS:
			TTS.speak(value_str, 0.85, lang)
			_speak_completed_word_if_needed(lang)
		else:
			TTS.speak(value_str, 0.85)
	# For next-symbol mode, do NOT set _round_complete here.
	# Coop: finish requires all players on end cell (handled by _check_shared_finish).
	# Chaser variant: collector must still reach exit AND can still be caught.
	_refresh_status_label()

func _refresh_status_label() -> void:
	if _is_race_mode():
		if status_label != null:
			status_label.text = _format_race_status()
		_refresh_race_hud()
		_update_hud_mission_description()
		return
	if not _uses_shared_collectibles() or _collectible_spawner == null:
		if status_label != null:
			status_label.text = tr("mp_game_running")
		_update_hud_mission_description()
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
	if _round_complete:
		if status_label != null:
			status_label.text = "%s  %d/%d" % [tr("you_win"), total, total]
		_refresh_shared_hud()
		return

	if (_is_next_symbol_mode() and total > 0 and current >= total):
		if _is_roleless_next_symbol_mode():
			if status_label != null:
				status_label.text = tr("mission_goal_exit_multi")
			_refresh_mp_player_badges()
			_refresh_shared_hud()
			return
		else:
			if status_label != null:
				status_label.text = "%s  %d/%d" % [tr("you_win"), total, total]
			_refresh_mp_player_badges()
			_refresh_shared_hud()
			return

	var target := _collectible_spawner.get_current_target()
	var progress := ""
	if total > 0:
		progress = "  %d/%d" % [mini(current + 1, total), total]
	if _is_path_mode() and total > 0 and current >= total:
		if status_label != null:
			status_label.text = "%s  %d/%d" % [tr("style_path"), total, total]
		_refresh_mp_player_badges()
		_refresh_shared_hud()
		return
	if status_label != null:
		status_label.text = "%s: %s%s" % [tr("hud_target_now"), target, progress]
	_refresh_shared_hud()

## Rebuild player chips after a role phase change so label and emoji stay in sync.
func _refresh_mp_player_badges() -> void:
	MpHudBadgeManager.refresh_mp_player_badges(self)

func _refresh_shared_hud() -> void:
	if hud == null or _collectible_spawner == null:
		return
	var seq := _collectible_spawner.get_sequence_strings()
	var current_idx: int
	var collected: int
	var lt := _learning_type_string()
	var emoji := ""

	if Config.game_mode == Config.GameMode.WORDS:
		current_idx = _collectible_spawner.get_word_next_index()
		collected = current_idx
		emoji = String(Config.current_word.get("emoji", ""))
	else:
		current_idx = _collectible_spawner.get_next_collect_index()
		collected = current_idx

	hud.update_tracker(seq, current_idx, collected, lt, emoji)
	_update_hud_mission_description()

func _refresh_race_hud() -> void:
	if hud == null:
		return
	var seq_len := _race_sequence.size()
	# Update each player's individual tracker.
	for key in _race_progress.keys():
		var peer_id := int(key)
		var progress := int(_race_progress.get(peer_id, 0))
		var display_idx := progress
		if Config.game_mode == Config.GameMode.WORDS:
			if progress < seq_len:
				display_idx = _race_sequence[progress].get("word_index", progress)
			else:
				var word_full := String(Config.current_word.get("word", ""))
				display_idx = word_full.length()
		hud.update_race_tracker(peer_id, display_idx, display_idx)


func _setup_race_hud() -> void:
	if hud == null:
		return
	# Build the per-player race sequence for the tracker display.
	var seq: Array[String] = []
	if Config.game_mode == Config.GameMode.WORDS:
		var word: String = Config.current_word.get("word", "")
		for i in range(word.length()):
			seq.append(word[i])
	else:
		for item in _race_sequence:
			seq.append(String(item.get("value", "")))
	var lt := _learning_type_string()

	# Collect player data for each racer.
	var players_data: Array[Dictionary] = []
	var peer_ids: Array[int] = []
	for raw_key in _avatars.keys():
		peer_ids.append(int(raw_key))
	peer_ids.sort()

	var is_race := _is_race_mode()
	var is_host := multiplayer.get_unique_id() == NetworkManager.HOST_PEER_ID
	
	# We need the player data from session to get character_ids
	var session := NetworkManager.current_session
	var players := session.get("players", {}) as Dictionary

	for peer_id in peer_ids:
		var info := players.get(peer_id, players.get(str(peer_id), {})) as Dictionary
		var character_id := String(info.get("character_id", ""))
		var color: Color = _race_colors_by_peer.get(peer_id, Color("#5AC8FF"))
		if not is_race:
			var palette := AvatarAccent.palette_from_character_id(character_id)
			color = palette.get("accent", UIColors.BLUE if is_host else Color("#FF5555"))
		var role := _role_for_peer(peer_id)
		players_data.append({
			"peer_id": peer_id,
			"character_id": character_id,
			"color": color,
			"role": role,
			"trap_available": bool(_trap_available_by_peer.get(peer_id, false)),
			"trap_texture": _trap_texture(),
			"confusion_moves": int(_confusion_moves_by_peer.get(peer_id, 0)),
			"is_confused": int(_confusion_moves_by_peer.get(peer_id, 0)) > 0,
		})

	hud.setup_race_trackers(players_data, seq, lt)

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

func _update_hud_mission_description() -> void:
	if _avatars.is_empty():
		return
		
	var enlarge_hud := Config.game_mode != Config.GameMode.WORDS
	
	# When the tracker is active (collectible phase), suppress verbose goal text
	# on the host HUD — the tracker itself is the visual instruction.
	# Remote D-Pad peers still receive the full text.
	var is_collecting := _collectible_spawner != null and not _collectible_spawner.is_complete()
	
	for key in _avatars.keys():
		var peer_id := int(key)
		var goal_str := _get_role_goal(peer_id)
		
		if peer_id == NetworkManager.HOST_PEER_ID:
			if hud != null:
				if _should_delay_path_chaser(_role_for_peer(peer_id)) and not _path_chasers_released:
					var initial_moves := _path_chaser_trigger_moves()
					hud.set_mission_description(tr("mp_chaser_waiting_steps") % initial_moves, enlarge_hud)
				elif is_collecting and not _is_race_mode():
					# Tracker handles the display during collection.
					hud.set_mission_description("", false)
				else:
					hud.set_mission_description(goal_str, enlarge_hud)
		else:
			if multiplayer.get_peers().has(peer_id):
				NetworkManager.rpc_id(peer_id, "rpc_update_remote_goal", goal_str, _chip_role_for_peer(peer_id))

func _get_role_goal(peer_id: int) -> String:
	var role := _role_for_peer(peer_id)

	if _is_race_mode():
		return tr("mp_goal_maze_race_first")

	var is_phase_one := _is_shared_collectible_phase_active()

	# Chaser role is the same regardless of phase
	if role == NetworkManager.ROLE_CHASER:
		return tr("mp_goal_chaser_catch")

	# Maze race (find-exit multiplayer) — no collectibles
	if _is_maze_race_mode():
		return tr("mp_goal_maze_race_first")

	# Collectible phase: pick key based on game mode, player count, and chaser
	if is_phase_one:
		if _is_chaser_variant():
			match Config.game_mode:
				Config.GameMode.NUMBERS: return tr("mp_goal_collect_numbers_chaser")
				Config.GameMode.WORDS:   return tr("mp_goal_collect_words_chaser")
				_:                       return tr("mp_goal_collect_letters_chaser")
		elif _avatars.size() > 1:
			match Config.game_mode:
				Config.GameMode.NUMBERS: return tr("mp_goal_collect_together_numbers")
				Config.GameMode.WORDS:   return tr("mp_goal_collect_together_words")
				_:                       return tr("mp_goal_collect_together_letters")
		else:
			match Config.game_mode:
				Config.GameMode.NUMBERS: return tr("mp_goal_collect_numbers")
				Config.GameMode.WORDS:   return tr("mp_goal_collect_words")
				_:                       return tr("mp_goal_collect_letters")

	# Find-exit mission with no active collectibles — show "find the exit"
	if _mission_id == MissionCatalog.MISSION_FIND_EXIT:
		return tr("mp_goal_find_exit")

	# Phase 2: all collectibles gathered — find the exit
	if _is_roleless_next_symbol_mode():
		return tr("mp_goal_exit_together")
	if _is_path_mode():
		if _is_chaser_variant():
			return tr("mp_goal_exit_no_catch")
		return tr("mp_goal_find_exit")
	return tr("mp_goal_exit_together")

func _chip_role_for_peer(peer_id: int, role_override: String = "") -> String:
	var role := role_override
	if role.is_empty():
		role = _role_for_peer(peer_id)
	if _is_race_mode() or _is_maze_race_mode():
		return NetworkManager.ROLE_RACER
	if role == NetworkManager.ROLE_CHASER:
		return NetworkManager.ROLE_CHASER
	if _is_shared_collectible_phase_active():
		return role
	if _mission_id == MissionCatalog.MISSION_FIND_EXIT:
		return "exit"
	if _has_shared_collectibles() and _collectible_spawner.is_complete():
		return "exit"
	if _is_roleless_next_symbol_mode():
		return ""
	return role

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
		return Config.ROLE_COLLECTOR
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
	get_tree().create_timer(1.0).timeout.connect(func():
		if not is_inside_tree() or get_tree() == null:
			return
		if _win_screen != null and _win_screen.is_active():
			return
		TTS.speak(phrase, 0.7, word_lang)
	)

func _spawn_for_role(role: String, slot: int) -> Vector2i:
	if _maze == null:
		return Vector2i.ZERO
	var end_cell := _maze.get_end_cell()
	var collector_start := Vector2i(0, _maze.grid_size.y - 1)
	if role == NetworkManager.ROLE_COLLECTOR:
		return collector_start
	if _is_chaser_variant():
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
	var trigger_moves := _path_chaser_trigger_moves()
	var remaining := trigger_moves - _collector_move_count
	
	if hud != null:
		hud.update_chaser_countdown(maxi(0, remaining))
	
	if remaining > 0:
		for peer_id in _delayed_chaser_peer_ids:
			if peer_id == NetworkManager.HOST_PEER_ID:
				if hud != null:
					hud.set_mission_description(tr("mp_chaser_get_ready_steps") % remaining, false)
			else:
				if multiplayer.get_peers().has(peer_id):
					NetworkManager.rpc_id(peer_id, "rpc_chaser_countdown", remaining)
			
	if _collector_move_count < trigger_moves:
		return
	_release_path_chasers()
	if hud != null:
		hud.update_chaser_countdown(0)

func _path_chaser_trigger_moves() -> int:
	var level := Config.chaser_level
	if level == Config.ChaserLevel.OFF:
		level = Config.ChaserLevel.SLOW
	return MissionCatalog.calculate_head_start_steps(level, Config.difficulty)

func _release_path_chasers() -> void:
	_path_chasers_released = true
	for peer_id in _delayed_chaser_peer_ids:
		var avatar := _avatars.get(peer_id, null) as MultiplayerAvatar
		if avatar != null and is_instance_valid(avatar):
			avatar.visible = true
		
		if peer_id == NetworkManager.HOST_PEER_ID:
			if hud != null:
				hud.set_mission_description(tr("mp_chaser_go"), false)
				var timer := get_tree().create_timer(1.5)
				timer.timeout.connect(func():
					if not is_inside_tree() or get_tree() == null:
						return
					if hud != null and is_instance_valid(hud):
						var enlarge_hud := Config.game_mode != Config.GameMode.WORDS
						hud.set_mission_description(_get_role_goal(NetworkManager.HOST_PEER_ID), enlarge_hud)
				)
		else:
			if multiplayer.get_peers().has(peer_id):
				NetworkManager.rpc_id(peer_id, "rpc_chaser_released")
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
			if _is_roleless_next_symbol_mode():
				# Coop: all active players must reach the end cell.
				var end_cell := _maze.get_end_cell() if _maze != null else null
				if end_cell != null and end_cell.coords == pos:
					_finished_peers[peer_id] = true
					if _avatars.has(peer_id):
						var avatar = _avatars[peer_id] as MultiplayerAvatar
						avatar.visible = false
						_held_directions.erase(peer_id)
					if _finished_peers.size() >= _avatars.size():
						_round_complete = true
						_held_directions.clear()
						_speak_completed_word_if_needed()
						_refresh_status_label()
						_show_coop_win_screen()
				_refresh_status_label()
			else:
				# Chaser variant: collector must reach end cell to win.
				if _is_chaser_variant() and _role_for_peer(peer_id) == NetworkManager.ROLE_COLLECTOR:
					var end_cell := _maze.get_end_cell() if _maze != null else null
					if end_cell != null and end_cell.coords == pos:
						_round_complete = true
						_held_directions.clear()
						_speak_completed_word_if_needed()
						_refresh_status_label()
						_show_shared_win_screen(peer_id)
			if not _is_chaser_variant():
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

func _get_all_player_positions() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for avatar_value in _avatars.values():
		var avatar := avatar_value as MultiplayerAvatar
		if avatar != null:
			result.append(avatar.grid_pos)
	return result

func _collector_avatar() -> MultiplayerAvatar:
	if _collector_peer_id != 0 and _avatars.has(_collector_peer_id):
		return _avatars[_collector_peer_id] as MultiplayerAvatar
	for avatar_value in _avatars.values():
		var avatar := avatar_value as MultiplayerAvatar
		if avatar != null and avatar.role == NetworkManager.ROLE_COLLECTOR:
			return avatar
	return null

func _build_shared_learning_recap() -> Dictionary:
	if Config.game_mode == Config.GameMode.NORMAL:
		return {}
	if _collectible_spawner == null or not _collectible_spawner.is_complete():
		return {}
	var sequence := _collectible_spawner.get_sequence_strings()
	var word := String(Config.current_word.get("word", ""))
	var word_lang := String(Config.current_word.get("lang", ""))
	return LearningRecapBuilder.build(Config.game_mode, sequence, word, word_lang)

func _build_race_learning_recap(peer_id: int) -> Dictionary:
	if Config.game_mode == Config.GameMode.NORMAL:
		return {}
	var sequence := _race_sequence_values_for_peer(peer_id)
	if sequence.is_empty():
		return {}
	var word := String(Config.current_word.get("word", ""))
	var word_lang := String(Config.current_word.get("lang", ""))
	return LearningRecapBuilder.build(Config.game_mode, sequence, word, word_lang)

func _race_sequence_values_for_peer(peer_id: int) -> Array[String]:
	var result: Array[String] = []
	for item in _race_sequence_for_peer(peer_id):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var marker_data: Dictionary = item
		var value := String(marker_data.get("value", "")).strip_edges()
		if not value.is_empty():
			result.append(value)
	return result

func _show_gotcha_screen() -> void:
	if _win_screen == null:
		return
	_clear_all_traps_and_confusion()
	var chaser_id := ""
	if _catching_chaser_peer_id != 0:
		chaser_id = _character_id_for_peer(_catching_chaser_peer_id)
	if chaser_id.is_empty() and not Config.theme_dir_name.is_empty():
		chaser_id = Config.theme_dir_name + ":chaser"
	_win_screen.set_learning_recap({})
	_win_screen.set_finish_shortcuts(_build_finish_shortcuts(true))
	_win_screen.show_gotcha(chaser_id)
	_send_remote_result(tr("gotcha"), _mirrored_character_ids(chaser_id))

func _show_shared_win_screen(peer_id: int) -> void:
	if _win_screen == null:
		return
	_clear_all_traps_and_confusion()
	var winner_id := _character_id_for_peer(peer_id)
	_win_screen.set_learning_recap(_build_shared_learning_recap())
	_win_screen.set_finish_shortcuts(_build_finish_shortcuts(false))
	_win_screen.show_race_win(winner_id)
	_send_remote_result(tr("race_i_won"), _mirrored_character_ids(winner_id))

func _show_coop_win_screen() -> void:
	if _win_screen == null:
		return
	_clear_all_traps_and_confusion()
	var ids: Array[String] = []
	for key in _avatars.keys():
		var avatar := _avatars[key] as MultiplayerAvatar
		if avatar != null:
			ids.append(avatar.character_id)
	_win_screen.set_learning_recap(_build_shared_learning_recap())
	_win_screen.set_finish_shortcuts(_build_finish_shortcuts(false))
	_win_screen.show_coop_win(ids)
	_send_remote_result(tr("mp_you_won_together"), ids)

func _update_win_screen_options() -> void:
	if _win_screen == null:
		return
	_win_screen.set_swap_roles_enabled(_is_chaser_variant())
	_win_screen.set_finish_shortcuts([])

func _on_next_round_pressed() -> void:
	if _win_screen != null:
		_win_screen.hide_screen()
	_apply_session(NetworkManager.current_session)

func _on_swap_roles_pressed() -> void:
	# Find the chaser peer — works for both gotcha (catching chaser) and win (any chaser avatar).
	var chaser_peer_id := _catching_chaser_peer_id
	if chaser_peer_id == 0:
		for key in _avatars.keys():
			var avatar := _avatars[key] as MultiplayerAvatar
			if avatar != null and avatar.role == NetworkManager.ROLE_CHASER:
				chaser_peer_id = avatar.peer_id
				break
	if chaser_peer_id != 0:
		NetworkManager.swap_collector_with_peer(chaser_peer_id)
	if _win_screen != null:
		_win_screen.hide_screen()
	_apply_session(NetworkManager.current_session)

func _on_harder_pressed() -> void:
	var max_diff := Config.DIFFICULTY_SIZES.size() - 1
	if _collector_caught:
		# Gotcha screen → make it easier
		Config.difficulty = clampi(Config.difficulty - 1, 0, max_diff)
	else:
		# Win screen → make it harder
		if Config.difficulty >= max_diff:
			return
		Config.difficulty = clampi(Config.difficulty + 1, 0, max_diff)
	Config.save_settings()
	# Update session config difficulty so all peers receive the new value.
	var session := NetworkManager.current_session
	if not session.is_empty():
		var cfg := session.get("config", {}) as Dictionary
		cfg["difficulty"] = Config.difficulty
		session["config"] = cfg
		if multiplayer.is_server():
			Config.remember_last_multiplayer_host_session(cfg)
			Config.save_settings()
	if _win_screen != null:
		_win_screen.hide_screen()
	_apply_session(NetworkManager.current_session)

func _on_home_pressed() -> void:
	if _win_screen != null:
		_win_screen.hide_screen()
	NetworkManager.leave_session()
	get_tree().change_scene_to_file(Scenes.HOME)

func _on_play_alone_pressed() -> void:
	if _win_screen != null:
		_win_screen.hide_screen()

	# Determine closest SP variant:
	# - Coop (no chaser) → SP solo (no chaser)
	# - Versus (chaser) → SP with chaser
	var session := NetworkManager.current_session
	var cfg := session.get("config", {}) as Dictionary
	var style: String = String(cfg.get("game_style", Config.game_style))
	var training: String = String(cfg.get("training_type", Config.training_type))
	var has_chaser: bool = bool(cfg.get("chaser_enabled", false))
	var chaser_lvl: int = int(cfg.get("chaser_level", Config.ChaserLevel.SLOW))
	var mission: String = String(cfg.get("mission_id", Config.mission_id))
	var traps_enabled: bool = bool(cfg.get("traps_enabled", false))

	NetworkManager.leave_session()

	Config.configure_single_player_session(style, training, has_chaser, chaser_lvl, mission, traps_enabled)
	Config.remember_last_single_player_session()
	Config.save_settings()
	UIHelpers.go_to_scene_with_loading(get_tree(), Scenes.GAME)

func _on_finish_shortcut_pressed(shortcut_id: String) -> void:
	if not multiplayer.is_server():
		return

	var cfg := _current_session_config()
	if cfg.is_empty():
		return

	var handled := true
	if shortcut_id == FINISH_SHORTCUT_MP_CHASER:
		_apply_multiplayer_config_values(cfg, _current_mission_id(), MissionCatalog.pickup_for_training(_training_type), true, Config.ChaserLevel.SLOW)
	elif shortcut_id == FINISH_SHORTCUT_TRAPS:
		cfg["traps_enabled"] = _traps_allowed_for_config(cfg)
	elif shortcut_id.begins_with(FINISH_SHORTCUT_PICKUP_PREFIX):
		var target_pickup := shortcut_id.substr(FINISH_SHORTCUT_PICKUP_PREFIX.length())
		var mission_id := _mission_for_multiplayer_pickup_shortcut(target_pickup)
		var keep_chaser := _chaser_enabled and MissionCatalog.chaser_allowed(mission_id) and mission_id != MissionCatalog.MISSION_RACE_MIDDLE
		_apply_multiplayer_config_values(cfg, mission_id, target_pickup, keep_chaser, int(Config.chaser_level))
	else:
		handled = false

	if not handled:
		return

	NetworkManager.update_current_session_config(cfg)
	Config.remember_last_multiplayer_host_session(cfg)
	Config.save_settings()
	if _win_screen != null:
		_win_screen.hide_screen()
	_apply_session(NetworkManager.current_session)

func _build_finish_shortcuts(is_gotcha: bool) -> Array[Dictionary]:
	var shortcuts: Array[Dictionary] = []
	var traps_shortcut := _build_traps_shortcut()
	_append_finish_shortcut(shortcuts, traps_shortcut)
	var pressure_shortcut := _build_pressure_shortcut(is_gotcha)
	_append_finish_shortcut(shortcuts, pressure_shortcut)
	var task_shortcut := _build_task_mix_shortcut(is_gotcha)
	_append_finish_shortcut(shortcuts, task_shortcut)
	return shortcuts

func _append_finish_shortcut(shortcuts: Array[Dictionary], shortcut: Dictionary) -> void:
	if shortcuts.size() >= 2 or shortcut.is_empty():
		return
	shortcuts.append(shortcut)

func _build_pressure_shortcut(is_gotcha: bool) -> Dictionary:
	if is_gotcha or _is_race_mode() or _chaser_enabled:
		return {}
	if _avatars.size() != 2:
		return {}
	if not MissionCatalog.chaser_allowed(_current_mission_id()):
		return {}
	return _finish_shortcut(
		FINISH_SHORTCUT_MP_CHASER,
		tr("start_vs_chaser"),
		UIColors.YELLOW,
	)

func _build_task_mix_shortcut(is_gotcha: bool) -> Dictionary:
	var current_pickup := MissionCatalog.pickup_for_training(_training_type)
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
	var cfg := _current_session_config()
	if cfg.is_empty() or bool(cfg.get("traps_enabled", false)):
		return {}
	if not _traps_allowed_for_config(cfg):
		return {}
	return _finish_shortcut(
		FINISH_SHORTCUT_TRAPS,
		tr("setting_use_traps"),
		UIColors.BLUE,
		_trap_icon_path(String(cfg.get("theme_dir", Config.theme_dir_name))),
	)

func _finish_shortcut(shortcut_id: String, text: String, color: Color, icon_path: String = "") -> Dictionary:
	return {
		"id": shortcut_id,
		"text": text,
		"color": color,
		"icon": icon_path,
	}

func _traps_allowed_for_config(cfg: Dictionary) -> bool:
	return Config.traps_allowed_for_session(
		String(cfg.get("game_style", _game_style)),
		bool(cfg.get("chaser_enabled", _chaser_enabled)),
		String(cfg.get("mission_id", _mission_id)),
	)

func _trap_icon_path(theme_dir: String) -> String:
	var path := "res://themes/%s/trap.png" % theme_dir
	if FileAccess.file_exists(path):
		return path
	return "res://themes/default/trap.png"

func _current_session_config() -> Dictionary:
	var session := NetworkManager.current_session
	if session.is_empty():
		return {}
	var cfg := session.get("config", {}) as Dictionary
	return cfg.duplicate(true)

func _current_mission_id() -> String:
	if MissionCatalog.mission_ids().has(_mission_id):
		return _mission_id
	return MissionCatalog.mission_from_config(_game_style, _training_type)

func _mission_for_multiplayer_pickup_shortcut(target_pickup: String) -> String:
	if _is_race_mode():
		return MissionCatalog.MISSION_RACE_MIDDLE
	if target_pickup == MissionCatalog.PICKUP_NONE:
		return MissionCatalog.MISSION_FIND_EXIT
	var mission_id := _current_mission_id()
	if [MissionCatalog.MISSION_FOLLOW_TRAIL, MissionCatalog.MISSION_FIND_NEXT].has(mission_id):
		return mission_id
	return MissionCatalog.MISSION_FOLLOW_TRAIL if _chaser_enabled else MissionCatalog.MISSION_FIND_NEXT

func _apply_multiplayer_config_values(cfg: Dictionary, mission_id: String, pickup: String, use_chaser: bool, chaser_level: int) -> void:
	var style := MissionCatalog.style_for_mission(mission_id)
	var chaser_enabled := use_chaser and MissionCatalog.chaser_allowed(mission_id) and style != MissionCatalog.STYLE_RACE
	if MissionCatalog.chaser_required(mission_id, true):
		chaser_enabled = true
	if MissionCatalog.chaser_forced_off(mission_id):
		chaser_enabled = false

	var training := MissionCatalog.training_for_pickup(pickup)
	var difficulty := clampi(int(cfg.get("difficulty", Config.difficulty)), 0, max(0, Config.DIFF_KEYS.size() - 1))
	var pickup_key := _pickup_title_key(pickup)
	var mission_title_key := MissionCatalog.mission_title_key(mission_id)

	cfg["difficulty"] = difficulty
	cfg["difficulty_key"] = Config.DIFF_KEYS[difficulty]
	cfg["mission_id"] = mission_id
	cfg["mission_title"] = tr(mission_title_key)
	cfg["mission_goal_key"] = MissionCatalog.goal_key(mission_id, pickup, chaser_enabled, true)
	cfg["role_summary_key"] = MissionCatalog.role_summary_key(mission_id, chaser_enabled)
	cfg["game_style"] = style
	cfg["game_style_title"] = tr(mission_title_key)
	cfg["training_type"] = training
	cfg["training_type_title"] = tr(pickup_key)
	cfg["chaser_enabled"] = chaser_enabled
	cfg["chaser_level"] = _normalized_chaser_level(chaser_level, chaser_enabled)
	cfg["traps_enabled"] = bool(cfg.get("traps_enabled", false)) and Config.traps_allowed_for_session(style, chaser_enabled, mission_id)
	_apply_max_players_for_config(cfg, mission_id, chaser_enabled)

func _normalized_chaser_level(chaser_level: int, chaser_enabled: bool) -> int:
	if not chaser_enabled:
		return Config.ChaserLevel.OFF
	if chaser_level == Config.ChaserLevel.OFF:
		return Config.ChaserLevel.SLOW
	return clampi(chaser_level, Config.ChaserLevel.SLOW, Config.ChaserLevel.TURBO)

func _apply_max_players_for_config(cfg: Dictionary, mission_id: String, chaser_enabled: bool) -> void:
	var player_options := MissionCatalog.max_players_options(mission_id, chaser_enabled)
	if player_options.is_empty():
		cfg["max_players"] = maxi(2, _avatars.size())
		return
	var current_players := maxi(2, _avatars.size())
	var desired_max := int(cfg.get("max_players", current_players))
	if player_options.has(desired_max):
		cfg["max_players"] = desired_max
	elif player_options.has(current_players):
		cfg["max_players"] = current_players
	else:
		cfg["max_players"] = int(player_options[0])

func _pickup_title_key(pickup: String) -> String:
	if pickup == MissionCatalog.PICKUP_NONE:
		return "pickup_just_maze"
	return MissionCatalog.pickup_title_key(pickup)

func _build_race_sequence() -> void:
	_race_sequence.clear()
	if _maze == null:
		return
	# NORMAL (no collectibles) still builds no sequence — that is correct.
	# But only skip for true NORMAL; LETTERS/NUMBERS/WORDS must get their sequence.
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
	
	var is_race := _is_race_mode()
	var is_host := multiplayer.get_unique_id() == NetworkManager.HOST_PEER_ID
	var session := NetworkManager.current_session
	var players := session.get("players", {}) as Dictionary
	
	for peer_id in peer_ids:
		var sequence := _race_sequence_for_peer(peer_id)
		var markers: Array[Collectible] = []
		var info := players.get(peer_id, players.get(str(peer_id), {})) as Dictionary
		var character_id := String(info.get("character_id", ""))
		var accent: Color = _race_colors_by_peer.get(peer_id, Color("#5AC8FF"))
		if not is_race:
			var palette := AvatarAccent.palette_from_character_id(character_id)
			accent = palette.get("accent", UIColors.BLUE if is_host else Color("#FF5555"))
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
	# Highlight the next target for this player.
	_update_race_highlight_for_peer(peer_id)


## Highlight the current target collectible for each player in race mode.
func _update_all_race_highlights() -> void:
	for key in _race_markers_by_peer.keys():
		_update_race_highlight_for_peer(int(key))


## Highlight the next uncollected marker for a single player.
func _update_race_highlight_for_peer(peer_id: int) -> void:
	var markers := _race_markers_by_peer.get(peer_id, []) as Array
	var progress := int(_race_progress.get(peer_id, 0))
	for i in range(markers.size()):
		var m = markers[i]
		if typeof(m) != TYPE_OBJECT or not is_instance_valid(m):
			continue
		var marker := m as Collectible
		if marker != null:
			marker.set_target_highlight(i == progress)

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
	_clear_all_traps_and_confusion()
	_refresh_status_label()
	if _should_play_race_learning_recap():
		_speak_race_completion_once()
	if _win_screen != null:
		var recap := _build_race_learning_recap(peer_id) if _should_play_race_learning_recap() else {}
		_win_screen.set_learning_recap(recap)
		_win_screen.set_finish_shortcuts(_build_finish_shortcuts(false))
		var winner_id := _character_id_for_peer(peer_id)
		_win_screen.show_race_win(winner_id)
		_send_remote_result(tr("race_i_won"), _mirrored_character_ids(winner_id))


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
	var center := _race_center()
	var mirror_x := start.x > center.x
	var mirror_y := start.y > center.y
	var peer_used: Dictionary = {}
	for item in _race_sequence:
		var source := item as Dictionary
		var source_cell := source.get("cell") as MazeData.CellData
		if source_cell == null:
			continue

		var target_coords := _mirror_race_route_coord(source_cell.coords, mirror_x, mirror_y)
		var final_cell := _maze.get_cell(target_coords)
		if final_cell == null or final_cell.is_start or final_cell.is_end:
			continue
		if peer_used.has(final_cell.coords):
			continue
		peer_used[final_cell.coords] = true

		var marker_data: Dictionary = {
			"cell": final_cell,
			"value": String(source.get("value", "")),
			"index": int(source.get("index", 0)),
		}
		if source.has("word_index"):
			marker_data["word_index"] = int(source.get("word_index", 0))
		result.append(marker_data)
	return result

func _mirror_race_route_coord(coord: Vector2i, mirror_x: bool, mirror_y: bool) -> Vector2i:
	if _maze == null:
		return coord
	var x := _maze.grid_size.x - 1 - coord.x if mirror_x else coord.x
	var y := _maze.grid_size.y - 1 - coord.y if mirror_y else coord.y
	return Vector2i(x, y)

func _race_center() -> Vector2i:
	var end_cell := _maze.get_end_cell() if _maze != null else null
	if end_cell != null:
		return end_cell.coords
	return Vector2i.ZERO

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

func _mirrored_character_ids(character_id: String) -> Array[String]:
	if character_id.is_empty():
		return []
	return [character_id, character_id]

func _send_remote_result(title_text: String, character_ids: Array[String]) -> void:
	if not multiplayer.is_server():
		return
	for key in _avatars.keys():
		var peer_id := int(key)
		if peer_id != NetworkManager.HOST_PEER_ID:
			if multiplayer.get_peers().has(peer_id):
				NetworkManager.rpc_id(peer_id, "rpc_update_remote_result", title_text, character_ids)

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
	get_tree().create_timer(0.8).timeout.connect(func():
		if not is_inside_tree() or get_tree() == null:
			return
		if _win_screen != null and _win_screen.is_active():
			return
		TTS.speak(phrase, 0.7, word_lang)
	)

func _should_play_race_learning_recap() -> bool:
	# Multiplayer race markers use visual progress and a short collect sound, not
	# per-item learning TTS. Keep the finish screen consistent with that silence.
	return false

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
