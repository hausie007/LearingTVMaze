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
var _revealed_sequence_pos: int = 0


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
	_revealed_sequence_pos = 0


## Spawn collectibles based on current game mode into the given maze.
func spawn(maze: MazeData, renderer: MazeRenderer, game_style: String = "") -> void:
	clear()
	_renderer = renderer
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
	var num_items: int = maxi(1, mini(max_items, L / 3))
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
	var word_data: Dictionary = WordList.get_random_word(lang, Config.difficulty)
	if word_data.is_empty():
		push_warning("CollectibleSpawner: No word found for lang=%s diff=%d" % [lang, Config.difficulty])
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
	_instantiate_collectible(
		cell,
		String(item.get("value", "")),
		int(item.get("index", -1)),
		_renderer
	)


func _shake_collectible(col: Collectible) -> void:
	var base_pos: Vector2 = col.position
	var tw: Tween = col.create_tween()
	tw.tween_property(col, "position", base_pos + Vector2(8, 0), 0.04)
	tw.tween_property(col, "position", base_pos + Vector2(-8, 0), 0.04)
	tw.tween_property(col, "position", base_pos + Vector2(4, 0), 0.04)
	tw.tween_property(col, "position", base_pos, 0.04)
