## maze_generator.gd
## ---------------------------------------------------------------------------
## Procedural maze generator — compact (fills every cell).
##
## Algorithm:
##   1. Create an empty MazeData grid (all walls closed).
##   2. Start = bottom-left corner, End = top-right corner.
##   3. Random-walk from Start → End, carving the main solution path.
##      Every cell on this path is flagged `is_main_path = true`.
##   4. Fill ALL remaining cells using a recursive backtracker that grows
##      from already-visited cells.  This guarantees zero empty spaces —
##      the maze is a perfect spanning tree covering every cell.
##
## The result looks like corridors carved into a solid rectangle with no
## unused blocks.  Dead ends form naturally during the fill step.
## ---------------------------------------------------------------------------
class_name MazeGenerator
extends Node


# ── Cardinal directions helper ───────────────────────────────────────────────
const DIRECTIONS: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.RIGHT,
]


# ── Public API ───────────────────────────────────────────────────────────────

## Generate and return a new MazeData instance using Config defaults.
func generate() -> MazeData:
	return generate_custom(Config.grid_size)


## Generate and return a new MazeData instance with a specific size.
func generate_custom(custom_size: Vector2i) -> MazeData:
	var maze := MazeData.new()
	maze.init_grid(custom_size)

	# -- 1. Start = bottom-left, End = top-right --
	var start_coord := Vector2i(0, custom_size.y - 1)
	var end_coord   := Vector2i(custom_size.x - 1, 0)

	maze.get_cell(start_coord).is_start = true
	maze.get_cell(end_coord).is_end     = true

	# -- 2. Build the main path via constrained random walk --
	var visited: Dictionary = {}          # Dictionary<Vector2i, bool>
	var path: Array[Vector2i] = []        # Ordered main-path coords
	_build_main_path(maze, start_coord, end_coord, visited, path, custom_size)

	# -- 3. Fill ALL remaining cells (no empty spaces) --
	_fill_remaining_cells(maze, visited, custom_size)

	return maze


# ── Private: main-path generation ────────────────────────────────────────────

## Depth-first random walk from `start` to `goal`.
## Backtracks when stuck, guaranteeing we reach the goal.
func _build_main_path(
	maze: MazeData,
	start: Vector2i,
	goal: Vector2i,
	visited: Dictionary,
	path: Array[Vector2i],
	grid_size: Vector2i,
) -> bool:
	
	# Stack stores state: {"pos": Vector2i, "dirs": Array[Vector2i]}
	var stack: Array = []
	
	visited[start] = true
	maze.get_cell(start).is_visited = true
	path.append(start)
	
	var initial_dirs := DIRECTIONS.duplicate()
	initial_dirs.shuffle()
	stack.append({"pos": start, "dirs": initial_dirs})
	
	while not stack.is_empty():
		var current = stack.back()
		var pos: Vector2i = current["pos"]
		var dirs: Array = current["dirs"]
		
		# Reached the goal – mark every cell on the path as main.
		if pos == goal:
			maze.main_path_coords = path.duplicate()
			for coord in path:
				maze.get_cell(coord).is_main_path = true
			return true
			
		# Try next direction
		if dirs.is_empty():
			stack.pop_back()
			path.pop_back()
			continue
			
		var dir: Vector2i = dirs.pop_back()
		var next := pos + dir
		
		if _is_in_bounds(next, grid_size) and not visited.has(next):
			maze.open_wall_between(pos, next)
			
			visited[next] = true
			maze.get_cell(next).is_visited = true
			path.append(next)
			
			var next_dirs := DIRECTIONS.duplicate()
			next_dirs.shuffle()
			stack.append({"pos": next, "dirs": next_dirs})
			
	return false


# ── Private: fill remaining cells ────────────────────────────────────────────

## Grow from every visited cell into unvisited neighbours until every cell
## in the grid is part of the maze.  Uses iterative randomised DFS
## (recursive backtracker) to produce natural-looking corridors.
func _fill_remaining_cells(
	maze: MazeData,
	visited: Dictionary,
	grid_size: Vector2i,
) -> void:
	var total_cells: int = grid_size.x * grid_size.y

	# Already done?
	if visited.size() >= total_cells:
		return

	# Collect all currently visited cells as potential starting points.
	# Shuffle so the fill doesn't always grow from the same end of the path.
	var frontier: Array = visited.keys().duplicate()
	frontier.shuffle()

	# Iterative DFS (stack-based) to avoid deep recursion on large grids.
	var stack: Array[Vector2i] = []
	for coord: Vector2i in frontier:
		stack.append(coord)

	while stack.size() > 0:
		var current: Vector2i = stack.back()

		# Find an unvisited neighbour.
		var dirs := DIRECTIONS.duplicate()
		dirs.shuffle()
		var found_unvisited := false

		for dir: Vector2i in dirs:
			var next := current + dir
			if _is_in_bounds(next, grid_size) and not visited.has(next):
				visited[next] = true
				maze.get_cell(next).is_visited = true
				maze.open_wall_between(current, next)
				stack.append(next)
				found_unvisited = true
				break

		if not found_unvisited:
			# Backtrack.
			stack.pop_back()


# ── Private: utility ─────────────────────────────────────────────────────────

## Check whether a coordinate is inside the grid.
func _is_in_bounds(coord: Vector2i, grid_size: Vector2i) -> bool:
	return (
		coord.x >= 0 and coord.x < grid_size.x and
		coord.y >= 0 and coord.y < grid_size.y
	)
