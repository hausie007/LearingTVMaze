extends Node
class_name MultiplayerGameManager

@export var avatar_scene: PackedScene

@onready var maze_generator: MazeGenerator = $MazeGenerator
@onready var maze_renderer: MazeRenderer = $MazeRenderer
@onready var players_root: Node2D = %Players
@onready var status_label: Label = %StatusLabel
@onready var network_debug_label: Label = %NetworkDebugLabel

var _maze: MazeData = null
var _collectible_spawner: CollectibleSpawner = null
var _avatars: Dictionary = {}
var _held_directions: Dictionary = {}
var _move_cooldowns: Dictionary = {}
var _game_style: String = NetworkManager.STYLE_PATH
var _training_type: String = NetworkManager.TRAINING_WORDS
var _completed_word_spoken: bool = false
var _round_complete: bool = false

var _saved_theme_dir: String = ""
var _saved_difficulty: int = 0
var _saved_game_style: String = ""
var _saved_training_type: String = ""
var _saved_game_mode: int = 0
var _saved_current_word: Dictionary = {}

func _ready() -> void:
	if avatar_scene == null:
		push_error("MultiplayerGameManager: avatar_scene is missing")
		return
	if network_debug_label != null:
		network_debug_label.visible = false

	_saved_theme_dir = Config.theme_dir_name
	_saved_difficulty = Config.difficulty
	_saved_game_style = Config.game_style
	_saved_training_type = Config.training_type
	_saved_game_mode = Config.game_mode
	_saved_current_word = Config.current_word.duplicate(true)

	_collectible_spawner = CollectibleSpawner.new()
	_collectible_spawner.name = "CollectibleSpawner"
	add_child(_collectible_spawner)
	_collectible_spawner.collectible_gathered.connect(_on_collectible_gathered)

	NetworkManager.input_received.connect(_on_input_received)
	NetworkManager.peer_disconnected.connect(_on_peer_disconnected)
	NetworkManager.game_started.connect(_on_game_started)
	NetworkManager.debug_status_changed.connect(_on_network_debug_changed)

	var session := NetworkManager.current_session
	if session.is_empty():
		status_label.text = tr("mp_game_waiting")
		return

	_apply_session(session)

func _exit_tree() -> void:
	Config.theme_dir_name = _saved_theme_dir
	Config.difficulty = _saved_difficulty
	Config.game_style = _saved_game_style
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
		_game_style = String(cfg.get("game_style", NetworkManager.STYLE_PATH))
		_training_type = String(cfg.get("training_type", NetworkManager.TRAINING_WORDS))
		Config.game_style = _game_style if [Config.STYLE_PATH, Config.STYLE_NEXT_SYMBOL, Config.STYLE_RACE].has(_game_style) else Config.STYLE_PATH
		Config.training_type = _training_type if [Config.TRAINING_NUMBERS, Config.TRAINING_LETTERS, Config.TRAINING_WORDS].has(_training_type) else Config.TRAINING_WORDS
		Config.game_mode = Config.game_mode_for_training(Config.training_type)
		if Config.game_style == Config.STYLE_NEXT_SYMBOL:
			Config.chaser_enabled = false
			Config.player_role = Config.ROLE_COLLECTOR
	_completed_word_spoken = false
	_round_complete = false

	_maze = maze_generator.generate()
	maze_renderer.draw_maze(_maze)
	if _collectible_spawner != null:
		_collectible_spawner.clear()
		if _is_next_symbol_mode():
			_collectible_spawner.spawn(_maze, maze_renderer, Config.STYLE_NEXT_SYMBOL)
	_spawn_avatars(session)
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
		Vector2i(0, _maze.grid_size.y - 1),
		Vector2i(_maze.grid_size.x - 1, 0),
		Vector2i(_maze.grid_size.x - 1, _maze.grid_size.y - 1),
	]

	for key in players.keys():
		var peer_id := int(key)
		var info := players[key] as Dictionary
		var slot := clampi(int(spawn_slots.get(peer_id, spawn_slots.get(str(peer_id), 0))), 0, 3)
		var role := String(roles.get(peer_id, roles.get(str(peer_id), info.get("role", NetworkManager.ROLE_COLLECTOR))))
		if _is_next_symbol_mode():
			role = ""
		var spawn_grid: Vector2i = corners[slot]
		var avatar := avatar_scene.instantiate() as MultiplayerAvatar
		avatar.setup(peer_id, String(info.get("character_id", "")), maze_renderer, spawn_grid, role)
		players_root.add_child(avatar)
		_avatars[peer_id] = avatar
		_move_cooldowns[peer_id] = 0.0

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

	var avatar := _avatars[peer_id] as MultiplayerAvatar
	var target := avatar.grid_pos + direction
	if _maze == null:
		return
	if not _maze.is_wall_open(avatar.grid_pos, direction):
		return

	avatar.move_to_grid(target, maze_renderer, Config.tween_duration)
	if _is_next_symbol_mode() and _collectible_spawner != null and not _round_complete:
		_collectible_spawner.check_collection(target)

func _on_network_debug_changed(scope: String, message: String) -> void:
	_set_network_debug(scope, message)

func _set_network_debug(scope: String, message: String) -> void:
	if network_debug_label == null:
		return
	network_debug_label.text = "Network [%s]: %s" % [scope, message]

func _is_next_symbol_mode() -> bool:
	return Config.game_style == Config.STYLE_NEXT_SYMBOL

func _on_collectible_gathered(value_str: String, collect_index: int, lang: String) -> void:
	if Config.voice_hints:
		if Config.game_mode == Config.GameMode.WORDS:
			TTS.speak(value_str, 0.85, lang)
			_speak_completed_word_if_needed(lang)
		else:
			TTS.speak(value_str, 0.85)
	if _collectible_spawner != null and _collectible_spawner.is_complete():
		_round_complete = true
	_refresh_status_label()

func _refresh_status_label() -> void:
	if status_label == null:
		return
	if not _is_next_symbol_mode() or _collectible_spawner == null:
		status_label.text = tr("mp_game_running")
		return

	var total := _collectible_spawner.get_total_collectibles()
	var current := _collectible_spawner.get_next_collect_index()
	if _round_complete or (total > 0 and current >= total):
		status_label.text = "%s  %d/%d" % [tr("you_win"), total, total]
		return

	var target := _collectible_spawner.get_current_target()
	var progress := ""
	if total > 0:
		progress = "  %d/%d" % [mini(current + 1, total), total]
	status_label.text = "%s: %s%s" % [tr("hud_target_now"), target, progress]

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
