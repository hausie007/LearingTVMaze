extends Node
class_name MultiplayerGameManager

@export var avatar_scene: PackedScene

@onready var maze_generator: MazeGenerator = $MazeGenerator
@onready var maze_renderer: MazeRenderer = $MazeRenderer
@onready var players_root: Node2D = %Players
@onready var status_label: Label = %StatusLabel
@onready var network_debug_label: Label = %NetworkDebugLabel

var _maze: MazeData = null
var _avatars: Dictionary = {}
var _held_directions: Dictionary = {}
var _move_cooldowns: Dictionary = {}

var _saved_theme_dir: String = ""
var _saved_difficulty: int = 0

func _ready() -> void:
	if avatar_scene == null:
		push_error("MultiplayerGameManager: avatar_scene is missing")
		return
	if network_debug_label != null:
		network_debug_label.visible = false

	_saved_theme_dir = Config.theme_dir_name
	_saved_difficulty = Config.difficulty

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

	_maze = maze_generator.generate()
	maze_renderer.draw_maze(_maze)
	_spawn_avatars(session)
	status_label.text = tr("mp_game_running")
	_set_network_debug("net", "Game running on host")

func _spawn_avatars(session: Dictionary) -> void:
	for child in players_root.get_children():
		child.queue_free()
	_avatars.clear()
	_held_directions.clear()
	_move_cooldowns.clear()

	var players := session.get("players", {}) as Dictionary
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
		var slot := clampi(int(spawn_slots.get(peer_id, 0)), 0, 3)
		var spawn_grid: Vector2i = corners[slot]
		var avatar := avatar_scene.instantiate() as MultiplayerAvatar
		avatar.setup(peer_id, String(info.get("character_id", "")), maze_renderer, spawn_grid)
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

func _on_network_debug_changed(scope: String, message: String) -> void:
	_set_network_debug(scope, message)

func _set_network_debug(scope: String, message: String) -> void:
	if network_debug_label == null:
		return
	network_debug_label.text = "Network [%s]: %s" % [scope, message]
