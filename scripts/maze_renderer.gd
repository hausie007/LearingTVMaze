## maze_renderer.gd
## ---------------------------------------------------------------------------
## Draws a MazeData grid using simple ColorRect nodes and optional theme images.
##
## Visited cells (part of the maze) get:
##   • A floor rectangle (dark slate; green for Start, gold for End).
##   • Connector rects bridging open walls to create corridors.
##   • Optional PNG sprites on Start and End cells (from the theme directory).
##
## Unvisited cells are drawn as solid wall blocks, so the maze looks like
## corridors carved inside a rectangle — no closed boxes.
##
## All tunable parameters are read from the Config autoload singleton.
## ---------------------------------------------------------------------------
class_name MazeRenderer
extends Node2D

# ── State ────────────────────────────────────────────────────────────────────
var _maze: MazeData = null
var theme: ThemeLoader = null

# Dynamic rendering parameters
var _current_cell_size: float = 120.0
var _current_wall_thickness: float = 6.0

## Extra top margin (pixels) reserved for HUD bar above the maze.
var top_margin: float = 0.0


# ── Public API ───────────────────────────────────────────────────────────────

## Clear any previous visuals and draw the provided maze.
func draw_maze(maze: MazeData) -> void:
	_maze = maze
	_clear()

	# Load theme images.
	theme = ThemeLoader.new()
	theme.load_theme()

	# Calculate dynamic cell size to fit the screen.
	var viewport_size := get_viewport_rect().size
	
	# Reserve some padding (e.g., 5% each side) and subtract top_margin
	var margin_percent := 0.05
	var available_size := viewport_size * (1.0 - margin_percent * 2.0)
	available_size.y -= top_margin
	
	# Calculate max possible cell size for both dimensions
	var max_cs_x := available_size.x / maze.grid_size.x
	var max_cs_y := available_size.y / maze.grid_size.y
	
	# Pick the smaller one to fit the whole maze while keeping aspect ratio
	# Use floorf to ensure integer pixel alignment, which prevents sub-pixel gaps.
	_current_cell_size = floorf(minf(max_cs_x, max_cs_y))
	
	# Scale wall thickness proportionally (minimum 1 pixel, also floored).
	var scale_ratio := _current_cell_size / float(Config.cell_size)
	_current_wall_thickness = maxf(1.0, floorf(float(Config.wall_thickness) * scale_ratio))

	var maze_pixel_size := Vector2(
		maze.grid_size.x * _current_cell_size,
		maze.grid_size.y * _current_cell_size,
	)
	# Centre horizontally, shift down by top_margin vertically
	var hpad := (viewport_size.x - maze_pixel_size.x) / 2.0
	var vpad := top_margin + (viewport_size.y - top_margin - maze_pixel_size.y) / 2.0
	var offset := Vector2(hpad, vpad).floor()

	# 1. Background Layer (Strictly contained in maze area)
	if theme.bg_texture:
		if theme.bg_tiled:
			# If tiled, we always clip to the maze area now as requested.
			# We ignore full_screen for now or interpret it as "maze full area".
			_add_tiled_background(offset, maze_pixel_size, theme.bg_texture)
		else:
			# Non-tiled centered background
			_add_sprite(offset, maze_pixel_size.x, theme.bg_texture, maze_pixel_size)

	# 2. Wall Base (only if no background texture, to avoid covering it)
	if not theme.bg_texture:
		_add_rect(offset, maze_pixel_size, theme.color_wall)

	# 3. Draw every cell.
	for x in range(maze.grid_size.x):
		for y in range(maze.grid_size.y):
			var coord := Vector2i(x, y)
			var cell  := maze.get_cell(coord)
			var pos   := offset + Vector2(x * _current_cell_size, y * _current_cell_size)
			_draw_cell(cell, pos)


## Return the pixel position for a given grid coordinate (centred in cell).
func grid_to_pixel(coord: Vector2i) -> Vector2:
	var viewport_size := get_viewport_rect().size
	var maze_pixel_size := Vector2(
		_maze.grid_size.x * _current_cell_size,
		_maze.grid_size.y * _current_cell_size,
	)
	var hpad := (viewport_size.x - maze_pixel_size.x) / 2.0
	var vpad := top_margin + (viewport_size.y - top_margin - maze_pixel_size.y) / 2.0
	var offset := Vector2(hpad, vpad)
	return offset + Vector2(coord.x * _current_cell_size, coord.y * _current_cell_size) + Vector2(_current_cell_size, _current_cell_size) / 2.0


## Return the calculated cell size.
func get_cell_size() -> float:
	return _current_cell_size


## Return the loaded ThemeLoader (so other scripts can reuse it).
func get_theme_loader() -> ThemeLoader:
	return theme


# ── Private: draw helpers ────────────────────────────────────────────────────

## Remove all child nodes (previous maze visuals).
func _clear() -> void:
	for child in get_children():
		child.queue_free()


## Create floor + wall rects for a single cell.
func _draw_cell(cell: MazeData.CellData, pos: Vector2) -> void:
	var cs := _current_cell_size
	var wt := _current_wall_thickness
	var floor_color := theme.color_floor
	var wall_color := theme.color_wall
	var has_bg := theme.bg_texture != null

	# ── UNVISITED: Draw solid wall block ──
	if not cell.is_visited:
		_add_rect(pos, Vector2(cs, cs), wall_color)
		return

	# ── VISITED: Corridors ──
	# Only draw solid floor if NO background is present.
	# This allows the background to serve as the "floor".
	if not has_bg:
		if cell.is_start:
			floor_color = theme.color_start
		elif cell.is_end:
			floor_color = theme.color_end
			
		_add_rect(
			pos + Vector2(wt, wt),
			Vector2(cs - wt * 2, cs - wt * 2),
			floor_color,
		)
		
		# Connectors for transparent floor (when bg is present, we don't need these as background is continuous)
		var bleed := 1.0
		if not cell.wall_north:
			_add_rect(pos + Vector2(wt, -bleed), Vector2(cs - wt * 2, wt + bleed * 2), floor_color)
		if not cell.wall_south:
			_add_rect(pos + Vector2(wt, cs - wt - bleed), Vector2(cs - wt * 2, wt + bleed * 2), floor_color)
		if not cell.wall_west:
			_add_rect(pos + Vector2(-bleed, wt), Vector2(wt + bleed * 2, cs - wt * 2), floor_color)
		if not cell.wall_east:
			_add_rect(pos + Vector2(cs - wt - bleed, wt), Vector2(wt + bleed * 2, cs - wt * 2), floor_color)
	else:
		# BACKGROUND MODE: If background is the floor, we need to draw CLOSED walls as solid colors
		# or wall borders to maintain the maze structure.
		if cell.wall_north: _add_rect(pos, Vector2(cs, wt), wall_color)
		if cell.wall_south: _add_rect(pos + Vector2(0, cs - wt), Vector2(cs, wt), wall_color)
		if cell.wall_west:  _add_rect(pos, Vector2(wt, cs), wall_color)
		if cell.wall_east:  _add_rect(pos + Vector2(cs - wt, 0), Vector2(wt, cs), wall_color)

	# ── Wall Borders (optional, always draw if defined) ──
	if theme.color_wall_border.a > 0.0:
		var bw := maxf(1.0, wt * 0.5)
		if cell.wall_north: _add_rect(pos + Vector2(0, 0), Vector2(cs, bw), theme.color_wall_border)
		if cell.wall_south: _add_rect(pos + Vector2(0, cs - bw), Vector2(cs, bw), theme.color_wall_border)
		if cell.wall_west:  _add_rect(pos + Vector2(0, 0), Vector2(bw, cs), theme.color_wall_border)
		if cell.wall_east:  _add_rect(pos + Vector2(cs - bw, 0), Vector2(bw, cs), theme.color_wall_border)

	# ── Start/End markers ──
	# We still draw markers, possibly with a faint tint if it's backgrounds mode?
	# For now, icons are usually enough.
	if cell.is_start and theme.start_texture:
		_add_sprite(pos, cs, theme.start_texture)
	elif cell.is_end and theme.end_texture:
		_add_sprite(pos, cs, theme.end_texture)


## Instantiate a simple ColorRect child.
func _add_rect(pos: Vector2, size: Vector2, color: Color) -> void:
	var rect := ColorRect.new()
	rect.position = pos
	rect.size     = size
	rect.color    = color
	add_child(rect)


## Instantiate a Sprite2D centred in the cell, scaled to fit.
func _add_sprite(cell_pos: Vector2, cell_size_px: float, texture: Texture2D, custom_size: Vector2 = Vector2.ZERO) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = true

	# Scale the sprite to fit inside the cell (with a small margin).
	var target_box_size := cell_size_px
	if custom_size != Vector2.ZERO:
		target_box_size = max(custom_size.x, custom_size.y)
	
	var margin := cell_size_px * 0.1 if custom_size == Vector2.ZERO else 0.0
	var target_size := target_box_size - margin * 2
	
	var tex_size := Vector2(texture.get_width(), texture.get_height())
	var scale_factor: float = target_size / float(max(tex_size.x, tex_size.y))
	sprite.scale = Vector2(scale_factor, scale_factor)

	# Position at the centre of the cell/box.
	var offset := Vector2(cell_size_px, cell_size_px) / 2.0
	if custom_size != Vector2.ZERO:
		offset = custom_size / 2.0
		
	sprite.position = cell_pos + offset
	add_child(sprite)

func _add_tiled_background(pos: Vector2, size: Vector2, texture: Texture2D) -> void:
	# Using Sprite2D with region_rect is more robust for clipping in Node2D
	# than TextureRect (which is a Control).
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.position = pos
	
	# Enable tiling
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	
	# Calculate region to center the tiling pattern optionally
	# This ensures if the tile is big, we see the center part in the maze.
	var tex_size := Vector2(texture.get_width(), texture.get_height())
	var offset_vec := (tex_size - size) * 0.5
	
	sprite.region_enabled = true
	sprite.region_rect = Rect2(offset_vec, size)
	
	add_child(sprite)
