## collectible_spawner.gd
## ---------------------------------------------------------------------------
## Responsible for spawning and tracking collectible items in the maze.
##
## Handles three game modes:
##   Mode 1: Numbers (1, 2, 3...)
##   Mode 2: Letters (A, B, C...)
##   Mode 3: Words   (individual letters of a word, collected in order)
##
## Emitted signals:
##   collectible_gathered(value_str, collect_index, lang) — when a collectible
##   is picked up by the player.
## ---------------------------------------------------------------------------
class_name CollectibleSpawner
extends Node


signal collectible_gathered(value_str: String, collect_index: int, lang: String)


const CollectibleScene = preload("res://scenes/collectible.tscn")


## Active collectibles keyed by grid position.
var _collectibles: Dictionary = {}  # Dictionary<Vector2i, Collectible>

## Next expected letter index in Words mode.
var _word_next_index: int = 0
var _next_collect_index: int = 0
var _total_collectibles: int = 0
var _game_style: String = Config.STYLE_PATH
var _sequence: Array[Dictionary] = []
var _renderer: MazeRenderer = null
var _maze: MazeData = null
var _revealed_sequence_pos: int = 0
var _used_next_symbol_cells: Dictionary = {}
var _recent_next_symbol_cells: Array[Vector2i] = []
var _last_next_symbol_exit_dist: int = -1
var _player_pos_getter: Callable = Callable()
var _chaser_positions_getter: Callable = Callable()
var _all_players_getter: Callable = Callable()


# ── Public API ───────────────────────────────────────────────────────────────

## Clear all existing collectibles.
func clear() -> void:
	for c in _collectibles.values():
		if is_instance_valid(c):
			c.queue_free()
	_collectibles.clear()
	_word_next_index = 0
	_next_collect_index = 0
	_total_collectibles = 0
	_sequence.clear()
	_renderer = null
	_maze = null
	_revealed_sequence_pos = 0
	_used_next_symbol_cells.clear()
	_recent_next_symbol_cells.clear()
	_last_next_symbol_exit_dist = -1

func configure_dynamic_threat(player_pos_getter: Callable, chaser_positions_getter: Callable) -> void:
	_player_pos_getter = player_pos_getter
	_chaser_positions_getter = chaser_positions_getter

func configure_competitive_mode(all_players_getter: Callable) -> void:
	_all_players_getter = all_players_getter

## Spawn collectibles based on current game mode into the given maze.
func spawn(maze: MazeData, renderer: MazeRenderer, game_style: String = "") -> void:
	clear()
	_renderer = renderer
	_maze = maze
	_game_style = game_style if not game_style.is_empty() else Config.game_style
	if Config.game_mode == Config.GameMode.NORMAL:
		return

	if Config.game_mode == Config.GameMode.WORDS:
		_spawn_word_collectibles(maze, renderer)
	else:
		_spawn_mode_collectibles(maze, renderer)


## Handle player stepping onto a cell. Returns true if a collectible was there.
func check_collection(pos: Vector2i) -> bool:
	if not _collectibles.has(pos):
		return false

	var col: Collectible = _collectibles[pos]

	if col.collect_index >= 0:
		return _try_collect_ordered(col, pos)

	col.collect()
	_collectibles.erase(pos)
	collectible_gathered.emit(col.value_str, col.collect_index, "")
	return true


## Return the current word next index (for HUD syncing in Words mode).
func get_word_next_index() -> int:
	return _word_next_index

func get_next_collect_index() -> int:
	return _next_collect_index

func get_total_collectibles() -> int:
	return _total_collectibles

func is_complete() -> bool:
	return _total_collectibles <= 0 or _next_collect_index >= _total_collectibles

func get_current_target() -> String:
	if is_complete():
		return ""
	if Config.game_mode == Config.GameMode.WORDS:
		var word_full: String = Config.current_word.get("word", "")
		if _word_next_index >= 0 and _word_next_index < word_full.length():
			return word_full[_word_next_index]
		return ""

	for col in _collectibles.values():
		var collectible := col as Collectible
		if collectible != null and collectible.collect_index == _next_collect_index:
			return collectible.value_str
	return ""


## Return the full ordered sequence of value strings for the HUD tracker.
func get_sequence_strings() -> Array[String]:
	var result: Array[String] = []
	if Config.game_mode == Config.GameMode.WORDS:
		var word: String = Config.current_word.get("word", "")
		for i in range(word.length()):
			result.append(word[i])
	else:
		for entry in _sequence:
			result.append(String(entry.get("value", "")))
	return result


## Update which collectible has the target highlight based on current progress.
func update_target_highlights() -> void:
	var target_index := _next_collect_index
	if Config.game_mode == Config.GameMode.WORDS:
		target_index = _word_next_index
	for col in _collectibles.values():
		var collectible := col as Collectible
		if collectible != null:
			collectible.set_target_highlight(collectible.collect_index == target_index)


# ── Private: Numbers / Letters ───────────────────────────────────────────────

func _spawn_mode_collectibles(maze: MazeData, renderer: MazeRenderer) -> void:
	var path_coords: Array[Vector2i] = maze.main_path_coords
	var temp_path: Array[MazeData.CellData] = []
	for coord in path_coords:
		var c: MazeData.CellData = maze.get_cell(coord)
		if not c.is_start and not c.is_end:
			temp_path.append(c)

	var L: int = temp_path.size()
	if L == 0:
		return

	var max_items: int = 26 if Config.game_mode == Config.GameMode.LETTERS else 50
	var num_items: int = maxi(1, mini(max_items, int(float(L) / 3.0)))
	_total_collectibles = num_items
	var step: float = float(L) / float(num_items)

	for i in range(num_items):
		var idx: int = int(i * step + (step / 2.0))
		idx = mini(idx, L - 1)
		var cell: MazeData.CellData = temp_path[idx]

		var val_str: String = ""
		if Config.game_mode == Config.GameMode.NUMBERS:
			val_str = str(i + 1)
		elif Config.game_mode == Config.GameMode.LETTERS:
			val_str = Config.get_alphabet_char(i, Config.get_effective_learning_language())

		_sequence.append({"cell": cell, "value": val_str, "index": i})

	_spawn_sequence(renderer)


# ── Private: Words Mode ──────────────────────────────────────────────────────

func _spawn_word_collectibles(maze: MazeData, renderer: MazeRenderer) -> void:
	var lang: String = Config.get_effective_learning_language()
	var word_difficulty := _word_difficulty_for_current_style()
	var word_data: Dictionary = WordList.get_random_word(lang, word_difficulty)
	if word_data.is_empty():
		push_warning("CollectibleSpawner: No word found for lang=%s diff=%d" % [lang, word_difficulty])
		return

	Config.current_word = word_data
	_word_next_index = 0

	var word: String = word_data.get("word", "")
	if word.is_empty():
		return

	var path_coords: Array[Vector2i] = maze.main_path_coords
	var temp_path: Array[MazeData.CellData] = []
	for coord in path_coords:
		var c: MazeData.CellData = maze.get_cell(coord)
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
	if num_collectibles == 0:
		return
	_total_collectibles = num_collectibles

	var step: float = float(L) / float(num_collectibles)

	for i in range(num_collectibles):
		var char_idx: int = collectible_chars[i]
		var path_idx: int = int(i * step + (step / 2.0))
		path_idx = mini(path_idx, L - 1)
		var cell: MazeData.CellData = temp_path[path_idx]
		_sequence.append({"cell": cell, "value": word[char_idx], "index": char_idx})

	_spawn_sequence(renderer)

func _word_difficulty_for_current_style() -> int:
	if _game_style == Config.STYLE_RACE:
		return maxi(0, Config.difficulty - 1)
	return Config.difficulty


# ── Private: Word Collection Logic ───────────────────────────────────────────

func _try_collect_ordered(col: Collectible, pos: Vector2i) -> bool:
	if Config.game_mode == Config.GameMode.WORDS:
		if col.collect_index != _word_next_index:
			_shake_collectible(col)
			return false
		return _collect_word_letter(col, pos)

	if col.collect_index != _next_collect_index:
		_shake_collectible(col)
		return false

	col.collect()
	_collectibles.erase(pos)
	_next_collect_index += 1
	_reveal_next_symbol()
	collectible_gathered.emit(col.value_str, col.collect_index, "")
	update_target_highlights()
	return true

func _collect_word_letter(col: Collectible, pos: Vector2i) -> bool:
	var word_lang: String = Config.current_word.get("lang", "")
	col.collect()
	_collectibles.erase(pos)
	var current_idx = _word_next_index
	_word_next_index += 1
	_next_collect_index += 1

	# Auto-advance through spaces
	var word_full: String = Config.current_word.get("word", "")
	while _word_next_index < word_full.length() and word_full[_word_next_index] == " ":
		_word_next_index += 1

	_reveal_next_symbol()
	collectible_gathered.emit(col.value_str, current_idx, word_lang)
	update_target_highlights()
	return true


# ── Private: Helpers ─────────────────────────────────────────────────────────

func _instantiate_collectible(cell: MazeData.CellData, val_str: String, idx: int, renderer: MazeRenderer) -> void:
	var col: Collectible = CollectibleScene.instantiate()
	col.process_mode = Node.PROCESS_MODE_PAUSABLE
	col.grid_pos = cell.coords
	col.value_str = val_str
	col.collect_index = idx

	add_child(col)
	col.setup(renderer.get_cell_size(), renderer.maze_theme)
	col.position = renderer.grid_to_pixel(cell.coords)
	_collectibles[cell.coords] = col
	if _game_style == Config.STYLE_NEXT_SYMBOL:
		_used_next_symbol_cells[cell.coords] = true
		_remember_next_symbol_cell(cell.coords)

func _spawn_sequence(renderer: MazeRenderer) -> void:
	if _game_style == Config.STYLE_NEXT_SYMBOL:
		_reveal_next_symbol()
		return

	for item in _sequence:
		var cell := item.get("cell") as MazeData.CellData
		if cell == null:
			continue
		_instantiate_collectible(
			cell,
			String(item.get("value", "")),
			int(item.get("index", -1)),
			renderer
		)
	update_target_highlights()

func _reveal_next_symbol() -> void:
	if _game_style != Config.STYLE_NEXT_SYMBOL:
		return
	if _renderer == null:
		return
	if _revealed_sequence_pos >= _sequence.size():
		return

	var item := _sequence[_revealed_sequence_pos]
	_revealed_sequence_pos += 1
	var cell := item.get("cell") as MazeData.CellData
	if cell == null:
		return
	cell = _pick_next_symbol_cell(cell)
	_instantiate_collectible(
		cell,
		String(item.get("value", "")),
		int(item.get("index", -1)),
		_renderer
	)
	update_target_highlights()

func _pick_next_symbol_cell(default_cell: MazeData.CellData) -> MazeData.CellData:
	if _maze == null:
		return default_cell
	if not Config.chaser_enabled:
		if not _all_players_getter.is_null():
			return _pick_competitive_symbol_cell(default_cell)
		if not _player_pos_getter.is_null():
			return _pick_solo_symbol_cell(default_cell)
		return default_cell
	if _player_pos_getter.is_null() or _chaser_positions_getter.is_null():
		return default_cell

	var player_pos: Vector2i = _player_pos_getter.call()
	var raw_chasers: Array = _chaser_positions_getter.call()
	var chaser_positions: Array[Vector2i] = []
	for item in raw_chasers:
		if item is Vector2i:
			chaser_positions.append(item)
	if chaser_positions.is_empty():
		return default_cell

	var player_dist := _distance_map_from([player_pos])
	var chaser_dist := _distance_map_from(chaser_positions)
	if player_dist.is_empty() or chaser_dist.is_empty():
		return default_cell

	var end_cell := _maze.get_end_cell()
	if end_cell == null:
		return default_cell
	var exit_dist := _distance_map_from([end_cell.coords])
	if not exit_dist.has(player_pos):
		return default_cell
	var current_exit_dist := int(exit_dist[player_pos])
	var chaser_exit_dist := int(chaser_dist.get(end_cell.coords, 1000000))
	var start_cell := _maze.get_start_cell()
	var total_exit_dist := current_exit_dist
	if start_cell != null and exit_dist.has(start_cell.coords):
		total_exit_dist = maxi(1, int(exit_dist[start_cell.coords]))

	var best_cell: MazeData.CellData = null
	var best_score := -INF
	var safety_margin := _next_symbol_safety_margin()
	var sequence_progress := _next_symbol_sequence_progress()
	var remaining_items := maxi(0, _sequence.size() - _revealed_sequence_pos)
	var exploration_wave := sin(sequence_progress * PI)
	var route_progress_target := _next_symbol_route_progress_target(sequence_progress)
	var route_progress_limit := _next_symbol_route_progress_limit(sequence_progress)
	var allowed_backtrack := int(round(lerpf(9.0, 3.0, sequence_progress))) + floori(float(clampi(Config.difficulty, 0, 6)) / 3.0)
	var last_backtrack_limit := int(round(lerpf(8.0, 3.0, sequence_progress)))
	var ideal_exit_dist := maxf(1.0, float(total_exit_dist) * (1.0 - route_progress_target))
	var min_exit_dist_before_finish := maxf(1.0, float(total_exit_dist) * (1.0 - route_progress_limit))
	var desired_player_steps := lerpf(8.0 + float(Config.difficulty), 5.0 + float(Config.difficulty) * 0.35, sequence_progress)
	var min_player_steps := 3 if remaining_items <= 1 else maxi(4, int(round(desired_player_steps * 0.55)))
	for candidate in _maze.cells.values():
		var cell := candidate as MazeData.CellData
		if cell == null or not cell.is_visited or cell.is_start or cell.is_end:
			continue
		if _collectibles.has(cell.coords):
			continue
		if _used_next_symbol_cells.has(cell.coords):
			continue
		if not player_dist.has(cell.coords):
			continue
		if not chaser_dist.has(cell.coords):
			continue
		if not exit_dist.has(cell.coords):
			continue
		var p_steps := int(player_dist[cell.coords])
		var c_steps := int(chaser_dist[cell.coords])
		var e_steps := int(exit_dist[cell.coords])
		if p_steps <= 0:
			continue
		if p_steps + safety_margin >= c_steps:
			continue
		var progress_delta := current_exit_dist - e_steps
		if remaining_items > 2 and float(e_steps) < min_exit_dist_before_finish:
			continue
		if progress_delta < -allowed_backtrack:
			continue
		if _last_next_symbol_exit_dist >= 0 and e_steps > _last_next_symbol_exit_dist + last_backtrack_limit:
			continue
		if p_steps <= 2 and remaining_items > 1:
			continue
		if _is_too_close_to_recent_next_symbol(cell.coords, sequence_progress):
			continue

		# Avoid tempting the player into a backwards branch while the chaser is
		# already better positioned toward the finish.
		if progress_delta < 0 and chaser_exit_dist + safety_margin < current_exit_dist:
			continue
		var route_buffer := _next_symbol_exit_route_buffer(
			cell.coords,
			p_steps,
			exit_dist,
			chaser_dist,
			safety_margin
		)
		if route_buffer < -safety_margin:
			continue
		if progress_delta <= 0 and route_buffer < 1:
			continue

		var distance_fit := -absf(float(p_steps) - desired_player_steps) * 0.42
		var safety := float(c_steps - p_steps)
		var pressure := -absf(safety - float(safety_margin + 4)) * 0.28
		var pacing_fit := -absf(float(e_steps) - ideal_exit_dist) * 0.38
		var too_far_ahead_penalty := maxf(0.0, min_exit_dist_before_finish - float(e_steps)) * 2.4
		var forward_bonus := maxf(0.0, float(progress_delta)) * lerpf(0.04, 0.50, sequence_progress)
		var backtrack_penalty := absf(minf(0.0, float(progress_delta))) * lerpf(0.50, 2.20, sequence_progress)
		var exit_safety := float(chaser_exit_dist - e_steps)
		var exit_safety_bonus := clampf(exit_safety, -8.0, 10.0) * 0.18
		var route_safety_bonus := clampf(float(route_buffer), -4.0, 8.0) * 0.22
		var side_route_bonus := _next_symbol_side_route_bonus(cell, exploration_wave)
		var close_penalty := maxf(0.0, float(min_player_steps - p_steps)) * 3.5
		var recent_penalty := _recent_next_symbol_penalty(cell.coords, sequence_progress)
		var score := (
			distance_fit
			+ pressure
			+ pacing_fit
			+ forward_bonus
			+ exit_safety_bonus
			+ route_safety_bonus
			+ side_route_bonus
			+ float(p_steps) * 0.10
			- backtrack_penalty
			- close_penalty
			- too_far_ahead_penalty
			- recent_penalty
			+ randf() * 0.01
		)
		if score > best_score:
			best_score = score
			best_cell = cell

	if best_cell != null:
		_last_next_symbol_exit_dist = int(exit_dist.get(best_cell.coords, _last_next_symbol_exit_dist))
		return best_cell
	var relaxed_cell := _pick_relaxed_next_symbol_cell(
		default_cell,
		player_dist,
		chaser_dist,
		exit_dist,
		safety_margin,
		sequence_progress,
		desired_player_steps,
		min_exit_dist_before_finish,
		remaining_items
	)
	if relaxed_cell != null:
		_last_next_symbol_exit_dist = int(exit_dist.get(relaxed_cell.coords, _last_next_symbol_exit_dist))
		return relaxed_cell
	if exit_dist.has(default_cell.coords):
		_last_next_symbol_exit_dist = int(exit_dist[default_cell.coords])
	return default_cell

func _pick_competitive_symbol_cell(default_cell: MazeData.CellData) -> MazeData.CellData:
	var raw_players: Array = _all_players_getter.call()
	var player_positions: Array[Vector2i] = []
	for item in raw_players:
		if item is Vector2i:
			player_positions.append(item)
	if player_positions.size() <= 1:
		return default_cell

	var dists: Array[Dictionary] = []
	for p in player_positions:
		dists.append(_distance_map_from([p]))

	var best_cell: MazeData.CellData = null
	var best_score := -INF
	var remaining_items := maxi(0, _sequence.size() - _revealed_sequence_pos)
	var sequence_progress := _next_symbol_sequence_progress()

	var end_cell := _maze.get_end_cell()
	var exit_dist := _distance_map_from([end_cell.coords]) if end_cell != null else {}
	var start_cell := _maze.get_start_cell()
	var total_exit_dist := 1
	if start_cell != null and exit_dist.has(start_cell.coords):
		total_exit_dist = maxi(1, int(exit_dist[start_cell.coords]))
	var ideal_exit_dist := maxf(1.0, float(total_exit_dist) * (1.0 - sequence_progress))
	
	for candidate in _maze.cells.values():
		var cell := candidate as MazeData.CellData
		if cell == null or not cell.is_visited or cell.is_start or cell.is_end:
			continue
		if _collectibles.has(cell.coords) or _used_next_symbol_cells.has(cell.coords):
			continue
		if _is_too_close_to_recent_next_symbol(cell.coords, sequence_progress):
			continue

		var min_d := 1000000
		var max_d := -1000000
		var sum_d := 0.0
		var valid := true
		for d_map in dists:
			if not d_map.has(cell.coords):
				valid = false
				break
			var d := int(d_map[cell.coords])
			min_d = mini(min_d, d)
			max_d = maxi(max_d, d)
			sum_d += float(d)
			
		if not valid:
			continue

		if min_d <= 2 and remaining_items > 1:
			continue
		
		var variance_penalty := float(max_d - min_d) * 3.5
		var recent_penalty := _recent_next_symbol_penalty(cell.coords, sequence_progress)
		var exit_fit := 0.0
		if exit_dist.has(cell.coords):
			exit_fit = -absf(float(exit_dist[cell.coords]) - ideal_exit_dist) * 0.4
			
		var distance_bonus := minf(sum_d, 20.0) * 0.15
		var side_route_bonus := 0.0
		if not cell.is_main_path:
			side_route_bonus = 1.5
			
		var score := distance_bonus - variance_penalty + exit_fit - recent_penalty + side_route_bonus + randf() * 0.5
		if score > best_score:
			best_score = score
			best_cell = cell

	if best_cell != null:
		return best_cell
	return default_cell

func _pick_solo_symbol_cell(default_cell: MazeData.CellData) -> MazeData.CellData:
	if _player_pos_getter.is_null():
		return default_cell
		
	var player_pos: Vector2i = _player_pos_getter.call()
	var player_dist := _distance_map_from([player_pos])
	if player_dist.is_empty():
		return default_cell
		
	var end_cell := _maze.get_end_cell()
	var exit_dist := _distance_map_from([end_cell.coords]) if end_cell != null else {}
	var start_cell := _maze.get_start_cell()
	var total_exit_dist := maxi(1, int(exit_dist.get(start_cell.coords, 1))) if start_cell != null else 1
	var current_exit_dist := int(exit_dist.get(player_pos, total_exit_dist))
	
	var remaining_items := maxi(0, _sequence.size() - _revealed_sequence_pos)
	if remaining_items == 0:
		return default_cell
		
	var sequence_progress := _next_symbol_sequence_progress()
	var min_player_steps := int(round(lerpf(3.0, 7.0, sequence_progress)))
	var min_exit_dist_before_finish := float(remaining_items) * 2.0
	var ideal_exit_dist := maxf(1.0, float(total_exit_dist) * (1.0 - sequence_progress))
	var allowed_backtrack := int(round(lerpf(9.0, 3.0, sequence_progress)))
	var last_backtrack_limit := int(round(lerpf(7.0, 2.0, sequence_progress)))
	var exploration_wave := sin(sequence_progress * PI * 2.0)
	var desired_player_steps := float(min_player_steps) + maxf(0.0, exploration_wave) * 4.0
	
	var best_cell: MazeData.CellData = null
	var best_score := -INF
	
	for candidate in _maze.cells.values():
		var cell := candidate as MazeData.CellData
		if cell == null or not cell.is_visited or cell.is_start or cell.is_end:
			continue
		if _collectibles.has(cell.coords) or _used_next_symbol_cells.has(cell.coords):
			continue
			
		var p_steps := int(player_dist.get(cell.coords, -1))
		if p_steps <= 0:
			continue
		var e_steps := int(exit_dist.get(cell.coords, -1))
		
		var progress_delta := current_exit_dist - e_steps
		
		if remaining_items > 2 and float(e_steps) < min_exit_dist_before_finish:
			continue
		if progress_delta < -allowed_backtrack:
			continue
		if _last_next_symbol_exit_dist >= 0 and e_steps > _last_next_symbol_exit_dist + last_backtrack_limit:
			continue
		if p_steps <= 2 and remaining_items > 1:
			continue
		if _is_too_close_to_recent_next_symbol(cell.coords, sequence_progress):
			continue
			
		var distance_fit := -absf(float(p_steps) - desired_player_steps) * 0.42
		var pacing_fit := -absf(float(e_steps) - ideal_exit_dist) * 0.38
		var too_far_ahead_penalty := maxf(0.0, min_exit_dist_before_finish - float(e_steps)) * 2.4
		var forward_bonus := maxf(0.0, float(progress_delta)) * lerpf(0.04, 0.50, sequence_progress)
		var backtrack_penalty := absf(minf(0.0, float(progress_delta))) * lerpf(0.50, 2.20, sequence_progress)
		var side_route_bonus := _next_symbol_side_route_bonus(cell, exploration_wave)
		var close_penalty := maxf(0.0, float(min_player_steps - p_steps)) * 3.5
		var recent_penalty := _recent_next_symbol_penalty(cell.coords, sequence_progress)
		
		var score := distance_fit + pacing_fit + forward_bonus - backtrack_penalty - too_far_ahead_penalty - close_penalty - recent_penalty + side_route_bonus + randf() * 0.5
		
		if score > best_score:
			best_score = score
			best_cell = cell
			
	if best_cell != null:
		if exit_dist.has(best_cell.coords):
			_last_next_symbol_exit_dist = int(exit_dist[best_cell.coords])
		return best_cell
		
	if exit_dist.has(default_cell.coords):
		_last_next_symbol_exit_dist = int(exit_dist[default_cell.coords])
	return default_cell

func _pick_relaxed_next_symbol_cell(
	default_cell: MazeData.CellData,
	player_dist: Dictionary,
	chaser_dist: Dictionary,
	exit_dist: Dictionary,
	safety_margin: int,
	sequence_progress: float,
	desired_player_steps: float,
	min_exit_dist_before_finish: float,
	remaining_items: int
) -> MazeData.CellData:
	var fallback_cell: MazeData.CellData = null
	var fallback_score := -INF
	var exploration_wave := sin(sequence_progress * PI)
	for candidate in _maze.cells.values():
		var cell := candidate as MazeData.CellData
		if cell == null or not cell.is_visited or cell.is_start or cell.is_end:
			continue
		if cell.coords == default_cell.coords:
			continue
		if _collectibles.has(cell.coords):
			continue
		if _used_next_symbol_cells.has(cell.coords):
			continue
		if not player_dist.has(cell.coords) or not chaser_dist.has(cell.coords) or not exit_dist.has(cell.coords):
			continue

		var p_steps := int(player_dist[cell.coords])
		var c_steps := int(chaser_dist[cell.coords])
		var e_steps := int(exit_dist[cell.coords])
		if p_steps <= 2:
			continue
		if p_steps + safety_margin >= c_steps:
			continue
		if remaining_items > 2 and float(e_steps) < min_exit_dist_before_finish:
			continue

		var route_buffer := _next_symbol_exit_route_buffer(
			cell.coords,
			p_steps,
			exit_dist,
			chaser_dist,
			safety_margin
		)
		if route_buffer < -safety_margin:
			continue

		var distance_fit := -absf(float(p_steps) - desired_player_steps) * 0.46
		var safety_bonus := clampf(float(c_steps - p_steps), 0.0, 10.0) * 0.22
		var route_safety_bonus := clampf(float(route_buffer), -4.0, 8.0) * 0.20
		var too_far_ahead_penalty := maxf(0.0, min_exit_dist_before_finish - float(e_steps)) * 2.4
		var recent_penalty := _recent_next_symbol_penalty(cell.coords, sequence_progress) * 1.35
		var score := (
			distance_fit
			+ safety_bonus
			+ route_safety_bonus
			+ _next_symbol_side_route_bonus(cell, exploration_wave)
			- too_far_ahead_penalty
			- recent_penalty
			+ randf() * 0.01
		)
		if score > fallback_score:
			fallback_score = score
			fallback_cell = cell
	return fallback_cell

func _next_symbol_sequence_progress() -> float:
	if _sequence.is_empty():
		return 0.0
	return clampf(float(_revealed_sequence_pos) / float(_sequence.size()), 0.0, 1.0)

func _next_symbol_route_progress_target(sequence_progress: float) -> float:
	if sequence_progress < 0.78:
		var t := smoothstep(0.0, 0.78, sequence_progress)
		return lerpf(0.08, 0.52, t)
	var end_t := smoothstep(0.78, 1.0, sequence_progress)
	return lerpf(0.52, 0.96, end_t)

func _next_symbol_route_progress_limit(sequence_progress: float) -> float:
	if sequence_progress < 0.82:
		var t := smoothstep(0.0, 0.82, sequence_progress)
		return lerpf(0.18, 0.66, t)
	var end_t := smoothstep(0.82, 1.0, sequence_progress)
	return lerpf(0.66, 0.99, end_t)

func _remember_next_symbol_cell(coords: Vector2i) -> void:
	_recent_next_symbol_cells.append(coords)
	while _recent_next_symbol_cells.size() > 7:
		_recent_next_symbol_cells.pop_front()

func _recent_next_symbol_penalty(coords: Vector2i, sequence_progress: float) -> float:
	var penalty := 0.0
	var late_multiplier := lerpf(1.0, 2.0, sequence_progress)
	for recent in _recent_next_symbol_cells:
		var distance := absi(coords.x - recent.x) + absi(coords.y - recent.y)
		if distance <= 2:
			penalty += 6.0 * late_multiplier
		elif distance <= 4:
			penalty += 2.8 * late_multiplier
		elif distance <= 6:
			penalty += 0.9 * late_multiplier
	return penalty

func _is_too_close_to_recent_next_symbol(coords: Vector2i, sequence_progress: float) -> bool:
	var hard_radius := 2 if sequence_progress < 0.65 else 3
	for recent in _recent_next_symbol_cells:
		var distance := absi(coords.x - recent.x) + absi(coords.y - recent.y)
		if distance <= hard_radius:
			return true
	return false

func _next_symbol_side_route_bonus(cell: MazeData.CellData, exploration_wave: float) -> float:
	var bonus := 0.0
	if not cell.is_main_path:
		bonus += 1.2 + exploration_wave * 1.4
	if _open_neighbor_count(cell.coords) <= 1:
		bonus += 0.8
	return bonus

func _open_neighbor_count(coords: Vector2i) -> int:
	var count := 0
	for dir in MazeGenerator.DIRECTIONS:
		if _maze.is_wall_open(coords, dir):
			count += 1
	return count

func _next_symbol_exit_route_buffer(
	start: Vector2i,
	player_steps_to_start: int,
	exit_dist: Dictionary,
	chaser_dist: Dictionary,
	safety_margin: int
) -> int:
	if not exit_dist.has(start):
		return -1000000

	var cursor := start
	var remaining := int(exit_dist[start])
	var steps_after_pickup := 0
	var lookahead := mini(remaining, 8 + safety_margin * 2)
	var weakest_buffer := 1000000
	while steps_after_pickup <= lookahead:
		var player_arrival := player_steps_to_start + steps_after_pickup
		var chaser_arrival := int(chaser_dist.get(cursor, 1000000))
		weakest_buffer = mini(weakest_buffer, chaser_arrival - player_arrival)
		if remaining <= 0:
			break

		var best_next := cursor
		var best_remaining := remaining
		for dir in MazeGenerator.DIRECTIONS:
			var next := cursor + dir
			if not _maze.is_wall_open(cursor, dir):
				continue
			if not exit_dist.has(next):
				continue
			var next_remaining := int(exit_dist[next])
			if next_remaining < best_remaining:
				best_next = next
				best_remaining = next_remaining
		if best_next == cursor:
			break
		cursor = best_next
		remaining = best_remaining
		steps_after_pickup += 1
	return weakest_buffer

func _distance_map_from(starts: Array[Vector2i]) -> Dictionary:
	var result: Dictionary = {}
	if _maze == null:
		return result
	var queue: Array[Vector2i] = []
	for start in starts:
		if _maze.get_cell(start) == null:
			continue
		if result.has(start):
			continue
		result[start] = 0
		queue.append(start)

	var head := 0
	while head < queue.size():
		var pos := queue[head]
		head += 1
		var base_dist := int(result[pos])
		for dir in MazeGenerator.DIRECTIONS:
			var next := pos + dir
			if result.has(next):
				continue
			if not _maze.is_wall_open(pos, dir):
				continue
			result[next] = base_dist + 1
			queue.append(next)
	return result

func _next_symbol_safety_margin() -> int:
	match Config.chaser_level:
		Config.ChaserLevel.SLOW:
			return 2
		Config.ChaserLevel.MEDIUM:
			return 3
		Config.ChaserLevel.FAST:
			return 4
		Config.ChaserLevel.TURBO:
			return 5
		_:
			return 3


func _shake_collectible(col: Collectible) -> void:
	var base_pos: Vector2 = col.position
	var tw: Tween = col.create_tween()
	tw.tween_property(col, "position", base_pos + Vector2(8, 0), 0.04)
	tw.tween_property(col, "position", base_pos + Vector2(-8, 0), 0.04)
	tw.tween_property(col, "position", base_pos + Vector2(4, 0), 0.04)
	tw.tween_property(col, "position", base_pos, 0.04)
