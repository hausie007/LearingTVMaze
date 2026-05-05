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


const MissionCatalog := preload("res://scripts/mission_catalog.gd")
const ChaserScene = preload("res://scenes/chaser.tscn")


var _chaser: Chaser = null
var _nav_map: AStar2D = null
var _active: bool = false


# ── Public API ───────────────────────────────────────────────────────────────

## Whether the chaser is currently active and pursuing the player.
func is_active() -> bool:
	return _active

func get_chaser_positions() -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	if _chaser != null and is_instance_valid(_chaser):
		positions.append(_chaser.grid_pos)
	return positions


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

	_chaser = ChaserScene.instantiate()
	_chaser.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_chaser)
	_chaser.grid_pos = start_cell.coords
	_chaser.position = renderer.grid_to_pixel(_chaser.grid_pos)
	_chaser.setup(renderer)

	_chaser.request_move.connect(_on_chaser_request_move)
	_chaser.move_finished.connect(_check_collision)


## Stop and clean up the chaser completely.
func cleanup() -> void:
	_active = false
	if _chaser and is_instance_valid(_chaser):
		if _chaser.request_move.is_connected(_on_chaser_request_move):
			_chaser.request_move.disconnect(_on_chaser_request_move)
		_chaser.queue_free()
	_chaser = null


## Stop the chaser movement without removing it (e.g., game end).
func stop() -> void:
	_active = false
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
	if path.size() > 1:
		var next_id: int = path[1]
		@warning_ignore("integer_division")
		var next_pos: Vector2i = Vector2i(next_id % grid_size_x, next_id / grid_size_x)
		_chaser.move_to(next_pos)


func _check_collision() -> void:
	if not _chaser:
		return
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
