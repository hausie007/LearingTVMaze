## chaser_manager.gd
## ---------------------------------------------------------------------------
## Manages the lifecycle and AI movement of the Chaser entity.
##
## Encapsulates chaser spawning, pathfinding via AStar2D, collision detection
## with the player, and cleanup. Communicates exclusively via signals.
##
## Emitted signals:
##   caught_player — the chaser has collided with the player's grid position.
## ---------------------------------------------------------------------------
class_name ChaserManager
extends Node


signal caught_player
signal chaser_moved(new_pos: Vector2i)
signal confusion_changed(remaining_moves: int)


const MissionCatalog := preload("res://scripts/mission_catalog.gd")
const ChaserScene = preload("res://scenes/chaser.tscn")

const CONFUSED_RETREAT_NOISE_CHANCE := 0.10


var _chaser: Chaser = null
var _nav_map: AStar2D = null
var _active: bool = false
var _confusion_moves: int = 0
var _decrement_confusion_after_move: bool = false
var _start_pos: Vector2i = Vector2i.ZERO
var _has_start_pos: bool = false


# ── Public API ───────────────────────────────────────────────────────────────

## Whether the chaser is currently active and pursuing the player.
func is_active() -> bool:
	return _active

func get_chaser_positions() -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	if _chaser != null and is_instance_valid(_chaser):
		positions.append(_chaser.grid_pos)
	return positions

func get_confusion_moves() -> int:
	return _confusion_moves

func add_confusion(moves: int) -> void:
	if moves <= 0 or _chaser == null or not is_instance_valid(_chaser):
		return
	_confusion_moves += moves
	_chaser.set_confused_visual(_confusion_moves > 0)
	_chaser.play_confusion_shake()
	confusion_changed.emit(_confusion_moves)

func clear_confusion() -> void:
	_confusion_moves = 0
	_decrement_confusion_after_move = false
	if _chaser != null and is_instance_valid(_chaser):
		_chaser.set_confused_visual(false)
	confusion_changed.emit(0)


## Build a navigation map from the rendered maze for pathfinding.
func build_nav_map(renderer: MazeRenderer) -> void:
	_nav_map = renderer.get_navigation_map()


## Check if the chaser should spawn based on move count and difficulty.
func check_trigger(move_count: int) -> void:
	if Config.chaser_level == Config.ChaserLevel.OFF or _active:
		return

	var threshold: int = MissionCatalog.calculate_head_start_steps(Config.chaser_level, Config.difficulty)
	if move_count >= threshold:
		# Signal to GameManager that we need spawn context (maze + renderer)
		_active = true


## Return the number of steps remaining until the chaser spawns.
func get_remaining_steps(move_count: int) -> int:
	if Config.chaser_level == Config.ChaserLevel.OFF or _active:
		return 0

	var threshold: int = MissionCatalog.calculate_head_start_steps(Config.chaser_level, Config.difficulty)
	return max(0, threshold - move_count)


## Spawn the chaser at the start cell.
func spawn(maze: MazeData, renderer: MazeRenderer) -> void:
	var start_cell: MazeData.CellData = maze.get_start_cell()
	if not start_cell:
		return

	_start_pos = start_cell.coords
	_has_start_pos = true
	_chaser = ChaserScene.instantiate()
	_chaser.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_chaser)
	_chaser.grid_pos = _start_pos
	_chaser.position = renderer.grid_to_pixel(_chaser.grid_pos)
	_chaser.setup(renderer)

	_chaser.request_move.connect(_on_chaser_request_move)
	_chaser.move_finished.connect(_check_collision)


## Stop and clean up the chaser completely.
func cleanup() -> void:
	_active = false
	clear_confusion()
	if _chaser and is_instance_valid(_chaser):
		if _chaser.request_move.is_connected(_on_chaser_request_move):
			_chaser.request_move.disconnect(_on_chaser_request_move)
		_chaser.queue_free()
	_chaser = null
	_has_start_pos = false


## Stop the chaser movement without removing it (e.g., game end).
func stop() -> void:
	_active = false
	clear_confusion()
	if _chaser:
		_chaser.stop()


## Check collision with the player at the given position.
func check_collision_at(player_pos: Vector2i) -> void:
	if _chaser and _chaser.grid_pos == player_pos:
		_on_caught()


# ── Private ──────────────────────────────────────────────────────────────────

## Player position is fetched from the parent GameManager node structure.
var _player_pos_getter: Callable = Callable()

## Set by GameManager so the chaser knows where the player is.
func set_player_pos_getter(getter: Callable) -> void:
	_player_pos_getter = getter


func _on_chaser_request_move() -> void:
	if not _chaser or not _nav_map:
		return

	var player_pos: Vector2i = _player_pos_getter.call()
	var chaser_pos: Vector2i = _chaser.grid_pos

	if player_pos == chaser_pos:
		_on_caught()
		return

	var grid_size_x: int = _get_grid_width()
	var id_start: int = chaser_pos.y * grid_size_x + chaser_pos.x
	var id_end: int = player_pos.y * grid_size_x + player_pos.x

	if not _nav_map.has_point(id_start) or not _nav_map.has_point(id_end):
		return

	var path: PackedInt64Array = _nav_map.get_id_path(id_start, id_end)
	if path.size() <= 1:
		return
	var next_id: int = path[1]
	@warning_ignore("integer_division")
	var intended_pos: Vector2i = Vector2i(next_id % grid_size_x, next_id / grid_size_x)
	var next_pos := intended_pos
	var is_confused := _confusion_moves > 0
	if is_confused:
		next_pos = _confused_next_pos(chaser_pos, intended_pos, player_pos)
		if next_pos == chaser_pos:
			_consume_confusion_move()
			return
	_decrement_confusion_after_move = is_confused
	_chaser.move_to(next_pos)


func _check_collision() -> void:
	if not _chaser:
		return
	if _decrement_confusion_after_move:
		_decrement_confusion_after_move = false
		_consume_confusion_move()
	chaser_moved.emit(_chaser.grid_pos)
	var player_pos: Vector2i = _player_pos_getter.call()
	if _chaser.grid_pos == player_pos:
		_on_caught()


func _on_caught() -> void:
	if not _active:
		return
	_active = false
	if _chaser:
		_chaser.stop()
	caught_player.emit()


## Cached grid width for AStar ID calculations.
var _grid_width: int = 0

func set_grid_width(w: int) -> void:
	_grid_width = w

func _get_grid_width() -> int:
	return _grid_width

func _consume_confusion_move() -> void:
	if _confusion_moves <= 0:
		return
	_confusion_moves = maxi(0, _confusion_moves - 1)
	if _chaser != null and is_instance_valid(_chaser):
		_chaser.set_confused_visual(_confusion_moves > 0)
		if _confusion_moves == 0:
			_chaser.play_confusion_shake()
	confusion_changed.emit(_confusion_moves)

func _confused_next_pos(from_pos: Vector2i, intended_pos: Vector2i, _target_pos: Vector2i) -> Vector2i:
	var legal_dirs := _legal_dirs(from_pos)
	if legal_dirs.is_empty():
		return from_pos

	var retreat_pos := _retreat_next_pos(from_pos)
	var retreat_dir := retreat_pos - from_pos
	if retreat_dir == Vector2i.ZERO or not legal_dirs.has(retreat_dir):
		return from_pos

	var intended_dir := intended_pos - from_pos
	var noise_dirs := _confused_retreat_noise_dirs(legal_dirs, retreat_dir, intended_dir)
	if not noise_dirs.is_empty() and randf() < CONFUSED_RETREAT_NOISE_CHANCE:
		return from_pos + _pick_confused_dir(noise_dirs)
	return retreat_pos

func _retreat_next_pos(from_pos: Vector2i) -> Vector2i:
	if not _has_start_pos or _nav_map == null or _grid_width <= 0 or from_pos == _start_pos:
		return from_pos
	var id_from := from_pos.y * _grid_width + from_pos.x
	var id_to := _start_pos.y * _grid_width + _start_pos.x
	if not _nav_map.has_point(id_from) or not _nav_map.has_point(id_to):
		return from_pos
	var path := _nav_map.get_id_path(id_from, id_to)
	if path.size() <= 1:
		return from_pos
	var next_id: int = path[1]
	@warning_ignore("integer_division")
	var next_pos := Vector2i(next_id % _grid_width, next_id / _grid_width)
	return next_pos

func _legal_dirs(from_pos: Vector2i) -> Array[Vector2i]:
	var legal_dirs: Array[Vector2i] = []
	for dir in MazeGenerator.DIRECTIONS:
		if _can_move(from_pos, dir):
			legal_dirs.append(dir)
	return legal_dirs

func _confused_retreat_noise_dirs(legal_dirs: Array[Vector2i], retreat_dir: Vector2i, intended_dir: Vector2i) -> Array[Vector2i]:
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

func _pick_confused_dir(dirs: Array[Vector2i]) -> Vector2i:
	if dirs.is_empty():
		return Vector2i.ZERO
	return dirs[randi() % dirs.size()]

func _can_move(from_pos: Vector2i, dir: Vector2i) -> bool:
	if _nav_map == null or _grid_width <= 0:
		return false
	var to_pos := from_pos + dir
	var id_from := from_pos.y * _grid_width + from_pos.x
	var id_to := to_pos.y * _grid_width + to_pos.x
	return _nav_map.has_point(id_from) and _nav_map.has_point(id_to) and _nav_map.are_points_connected(id_from, id_to)
