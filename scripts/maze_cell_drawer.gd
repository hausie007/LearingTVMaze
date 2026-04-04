## maze_cell_drawer.gd
## ---------------------------------------------------------------------------
## Shared cell-drawing logic used by both MazeRenderer (node-based) and
## HelpMazePreview (immediate-mode _draw()).
##
## Returns arrays of rectangle descriptors so the caller can render them
## using whichever API it needs (ColorRect children vs draw_rect calls).
##
## This eliminates the duplicated branching logic that previously existed
## in both maze_renderer.gd and help_maze_preview.gd.
## ---------------------------------------------------------------------------
class_name MazeCellDrawer
extends RefCounted


## A rectangle to draw: position, size, and color.
## Used as a lightweight struct passed between the shared logic and renderers.
class RectCmd:
	var pos: Vector2
	var size: Vector2
	var color: Color

	func _init(p: Vector2, s: Vector2, c: Color) -> void:
		pos = p
		size = s
		color = c


## An icon/texture to draw on a cell (start marker, end marker).
class IconCmd:
	var pos: Vector2
	var cell_size: float
	var texture: Texture2D

	func _init(p: Vector2, cs: float, tex: Texture2D) -> void:
		pos = p
		cell_size = cs
		texture = tex


## Compute all rectangles and icons needed to draw a single maze cell.
##
## Parameters:
##   cell    — the MazeData.CellData to draw
##   pos     — pixel position of the cell's top-left corner
##   cs      — cell size in pixels
##   wt      — wall thickness in pixels
##   theme   — ThemeLoader with colors and textures
##   has_bg  — whether a background texture is active
##   maze    — the full MazeData for neighbor lookups
##   coord   — coordinates of the cell being drawn
##
## Returns: { "rects": Array[RectCmd], "icons": Array[IconCmd] }
static func get_cell_draw_commands(
	cell: MazeData.CellData,
	pos: Vector2,
	cs: float,
	wt: float,
	theme: ThemeLoader,
	has_bg: bool,
	maze: MazeData,
	coord: Vector2i,
) -> Dictionary:
	var rects: Array[RectCmd] = []
	var icons: Array[IconCmd] = []

	# FORCE strict integer math to eliminate sub-pixel drift (zig-zags)
	var r_pos := Vector2(roundf(pos.x), roundf(pos.y))
	var r_cs  := int(roundf(cs))
	var r_wt  := int(roundf(wt))

	# ── UNVISITED: Draw solid wall block ──
	if not cell.is_visited:
		rects.append(RectCmd.new(r_pos, Vector2(r_cs, r_cs), theme.color_wall))
		return {"rects": rects, "icons": icons}

	# Helper for neighbor checks
	var wall_continues = func(direction: Vector2i, wall_type: String):
		if not maze: return false
		var neighbor := maze.get_cell(coord + direction)
		if not neighbor: return false
		return neighbor.get(wall_type) == true

	# ── VISITED: Corridor Mode ──
	# If has_bg is true, the background image IS the floor, so we don't draw solid rects.
	if not has_bg:
		var floor_color := theme.color_floor
		if cell.is_start: floor_color = theme.color_start
		elif cell.is_end: floor_color = theme.color_end

		# Central floor area
		rects.append(RectCmd.new(r_pos + Vector2(r_wt, r_wt), Vector2(r_cs - r_wt * 2, r_cs - r_wt * 2), floor_color))

		# Passages
		var bleed := 1.0 
		if not cell.wall_north:
			rects.append(RectCmd.new(r_pos + Vector2(r_wt, -bleed), Vector2(r_cs - r_wt * 2, r_wt + bleed * 2), floor_color))
		if not cell.wall_south:
			rects.append(RectCmd.new(r_pos + Vector2(r_wt, r_cs - r_wt - bleed), Vector2(r_cs - r_wt * 2, r_wt + bleed * 2), floor_color))
		if not cell.wall_west:
			rects.append(RectCmd.new(r_pos + Vector2(-bleed, r_wt), Vector2(r_wt + bleed * 2, r_cs - r_wt * 2), floor_color))
		if not cell.wall_east:
			rects.append(RectCmd.new(r_pos + Vector2(r_cs - r_wt - bleed, r_wt), Vector2(r_wt + bleed * 2, r_cs - r_wt * 2), floor_color))

	# ── Minimalist Wall Rendering ──
	# (Borders/rims removed to ensure high contrast and zero visual artifacts)

	# ── Icons ──
	if cell.is_start and theme.start_texture:
		icons.append(IconCmd.new(r_pos, r_cs, theme.start_texture))
	elif cell.is_end and theme.end_texture:
		icons.append(IconCmd.new(r_pos, r_cs, theme.end_texture))

	return {"rects": rects, "icons": icons}



