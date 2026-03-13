## maze_data.gd
## ---------------------------------------------------------------------------
## Pure-data layer for the maze grid.
##
## MazeData holds every cell in a Dictionary keyed by Vector2i.
## Each cell is a CellData instance that knows its coordinates, which walls
## are open, and whether it belongs to the main (solution) path.
##
## This class is intentionally decoupled from any visual or generation logic
## so future game modes can query / annotate cells freely (e.g. spawn
## collectible letters along is_main_path cells).
## ---------------------------------------------------------------------------
class_name MazeData
extends RefCounted

# ── Inner class: data for a single cell ──────────────────────────────────────
class CellData:
	## Grid coordinates of this cell.
	var coords: Vector2i = Vector2i.ZERO

	## Wall state – true means the wall is PRESENT (blocking).
	var wall_north: bool = true
	var wall_south: bool = true
	var wall_east:  bool = true
	var wall_west:  bool = true

	## Whether this cell has been carved into the maze (visited by generator).
	var is_visited:   bool = false

	## Flags useful for game-mode logic.
	var is_main_path: bool = false
	var is_start:     bool = false
	var is_end:       bool = false

	func _init(p_coords: Vector2i = Vector2i.ZERO) -> void:
		coords = p_coords


# ── Grid storage ─────────────────────────────────────────────────────────────
## Width (x) and height (y) of the grid in cells.
var grid_size: Vector2i = Vector2i.ZERO

## Dictionary<Vector2i, CellData>  – every cell in the grid.
var cells: Dictionary = {}

## Ordered array of coordinates representing the solution path from Start to End.
var main_path_coords: Array[Vector2i] = []


# ── Public helpers ───────────────────────────────────────────────────────────

## Initialise an empty grid with all walls closed.
func init_grid(p_size: Vector2i) -> void:
	grid_size = p_size
	cells.clear()
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			var coord := Vector2i(x, y)
			cells[coord] = CellData.new(coord)


## Safely retrieve a cell, returns null if out of bounds.
func get_cell(coord: Vector2i) -> CellData:
	return cells.get(coord, null)


## Check whether movement from `from` toward `direction` is possible.
## Returns true when the wall between the two cells is OPEN.
func is_wall_open(from: Vector2i, direction: Vector2i) -> bool:
	var cell := get_cell(from)
	if cell == null:
		return false

	# Also verify the target cell exists (inside the grid).
	var target := from + direction
	if get_cell(target) == null:
		return false

	if direction == Vector2i.UP:    return not cell.wall_north
	if direction == Vector2i.DOWN:  return not cell.wall_south
	if direction == Vector2i.RIGHT: return not cell.wall_east
	if direction == Vector2i.LEFT:  return not cell.wall_west
	return false


## Open the wall between two adjacent cells (both sides).
func open_wall_between(a: Vector2i, b: Vector2i) -> void:
	var cell_a := get_cell(a)
	var cell_b := get_cell(b)
	if cell_a == null or cell_b == null:
		return

	var diff := b - a
	if diff == Vector2i.UP:
		cell_a.wall_north = false
		cell_b.wall_south = false
	elif diff == Vector2i.DOWN:
		cell_a.wall_south = false
		cell_b.wall_north = false
	elif diff == Vector2i.RIGHT:
		cell_a.wall_east  = false
		cell_b.wall_west  = false
	elif diff == Vector2i.LEFT:
		cell_a.wall_west  = false
		cell_b.wall_east  = false


## Return the start cell (first found). Null if none flagged.
func get_start_cell() -> CellData:
	for cell: CellData in cells.values():
		if cell.is_start:
			return cell
	return null


## Return the end cell (first found). Null if none flagged.
func get_end_cell() -> CellData:
	for cell: CellData in cells.values():
		if cell.is_end:
			return cell
	return null


## Return an ordered list of all main-path cells from start → end.
## Useful for spawning sequential items along the solution later.
func get_main_path_cells() -> Array[CellData]:
	var result: Array[CellData] = []
	for cell: CellData in cells.values():
		if cell.is_main_path:
			result.append(cell)
	return result
