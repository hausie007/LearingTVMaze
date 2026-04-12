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


# ── Public API ───────────────────────────────────────────────────────────────

## Clear all existing collectibles.
func clear() -> void:
	for c in _collectibles.values():
		if is_instance_valid(c):
			c.queue_free()
	_collectibles.clear()
	_word_next_index = 0


## Spawn collectibles based on current game mode into the given maze.
func spawn(maze: MazeData, renderer: MazeRenderer) -> void:
	clear()
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

	if Config.game_mode == Config.GameMode.WORDS and col.collect_index >= 0:
		return _try_collect_word_letter(col, pos)
	else:
		col.collect()
		_collectibles.erase(pos)
		collectible_gathered.emit(col.value_str, col.collect_index, "")
		return true


## Return the current word next index (for HUD syncing in Words mode).
func get_word_next_index() -> int:
	return _word_next_index


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

		_instantiate_collectible(cell, val_str, -1, renderer)


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

	var step: float = float(L) / float(num_collectibles)

	for i in range(num_collectibles):
		var char_idx: int = collectible_chars[i]
		var path_idx: int = int(i * step + (step / 2.0))
		path_idx = mini(path_idx, L - 1)
		var cell: MazeData.CellData = temp_path[path_idx]
		_instantiate_collectible(cell, word[char_idx], char_idx, renderer)


# ── Private: Word Collection Logic ───────────────────────────────────────────

func _try_collect_word_letter(col: Collectible, pos: Vector2i) -> bool:
	if col.collect_index != _word_next_index:
		_shake_collectible(col)
		return false

	var word_lang: String = Config.current_word.get("lang", "")
	col.collect()
	_collectibles.erase(pos)
	var current_idx = _word_next_index
	_word_next_index += 1

	# Auto-advance through spaces
	var word_full: String = Config.current_word.get("word", "")
	while _word_next_index < word_full.length() and word_full[_word_next_index] == " ":
		_word_next_index += 1

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
	col.setup(renderer.get_cell_size(), renderer.theme)
	col.position = renderer.grid_to_pixel(cell.coords)
	_collectibles[cell.coords] = col


func _shake_collectible(col: Collectible) -> void:
	var base_pos: Vector2 = col.position
	var tw: Tween = col.create_tween()
	tw.tween_property(col, "position", base_pos + Vector2(8, 0), 0.04)
	tw.tween_property(col, "position", base_pos + Vector2(-8, 0), 0.04)
	tw.tween_property(col, "position", base_pos + Vector2(4, 0), 0.04)
	tw.tween_property(col, "position", base_pos, 0.04)
