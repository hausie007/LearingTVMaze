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
##   has_bg  — whether a background texture is active (changes draw mode)
##
## Returns: { "rects": Array[RectCmd], "icons": Array[IconCmd] }
static func get_cell_draw_commands(
	cell: MazeData.CellData,
	pos: Vector2,
	cs: float,
	wt: float,
	theme: ThemeLoader,
	has_bg: bool,
) -> Dictionary:
	var rects: Array[RectCmd] = []
	var icons: Array[IconCmd] = []

	# ── UNVISITED: Draw solid wall block ──
	if not cell.is_visited:
		rects.append(RectCmd.new(pos, Vector2(cs, cs), theme.color_wall))
		return {"rects": rects, "icons": icons}

	# ── VISITED: Corridors ──
	if not has_bg:
		# Determine floor color based on cell type
		var floor_color: Color = theme.color_floor
		if cell.is_start:
			floor_color = theme.color_start
		elif cell.is_end:
			floor_color = theme.color_end

		# Central floor rect
		rects.append(RectCmd.new(
			pos + Vector2(wt, wt),
			Vector2(cs - wt * 2, cs - wt * 2),
			floor_color,
		))

		# Connector rects bridging open walls to create corridors
		var bleed := 1.0
		if not cell.wall_north:
			rects.append(RectCmd.new(pos + Vector2(wt, -bleed), Vector2(cs - wt * 2, wt + bleed * 2), floor_color))
		if not cell.wall_south:
			rects.append(RectCmd.new(pos + Vector2(wt, cs - wt - bleed), Vector2(cs - wt * 2, wt + bleed * 2), floor_color))
		if not cell.wall_west:
			rects.append(RectCmd.new(pos + Vector2(-bleed, wt), Vector2(wt + bleed * 2, cs - wt * 2), floor_color))
		if not cell.wall_east:
			rects.append(RectCmd.new(pos + Vector2(cs - wt - bleed, wt), Vector2(wt + bleed * 2, cs - wt * 2), floor_color))
	else:
		# BACKGROUND MODE: draw closed walls as solid rects over the background
		if cell.wall_north: rects.append(RectCmd.new(pos, Vector2(cs, wt), theme.color_wall))
		if cell.wall_south: rects.append(RectCmd.new(pos + Vector2(0, cs - wt), Vector2(cs, wt), theme.color_wall))
		if cell.wall_west:  rects.append(RectCmd.new(pos, Vector2(wt, cs), theme.color_wall))
		if cell.wall_east:  rects.append(RectCmd.new(pos + Vector2(cs - wt, 0), Vector2(wt, cs), theme.color_wall))

	# ── Wall borders (optional, always draw if defined) ──
	if theme.color_wall_border.a > 0.0:
		var bw := maxf(1.0, wt * 0.5)
		if cell.wall_north: rects.append(RectCmd.new(pos, Vector2(cs, bw), theme.color_wall_border))
		if cell.wall_south: rects.append(RectCmd.new(pos + Vector2(0, cs - bw), Vector2(cs, bw), theme.color_wall_border))
		if cell.wall_west:  rects.append(RectCmd.new(pos, Vector2(bw, cs), theme.color_wall_border))
		if cell.wall_east:  rects.append(RectCmd.new(pos + Vector2(cs - bw, 0), Vector2(bw, cs), theme.color_wall_border))

	# ── Start/End marker icons ──
	if cell.is_start and theme.start_texture:
		icons.append(IconCmd.new(pos, cs, theme.start_texture))
	elif cell.is_end and theme.end_texture:
		icons.append(IconCmd.new(pos, cs, theme.end_texture))

	return {"rects": rects, "icons": icons}
