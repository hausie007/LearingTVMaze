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

## Cached layout offset (set after draw_maze, reused in grid_to_pixel/pixel_to_grid).
var _cached_offset: Vector2 = Vector2.ZERO


# ── Public API ───────────────────────────────────────────────────────────────

## Clear any previous visuals and draw the provided maze.
func draw_maze(maze: MazeData) -> void:
	_maze = maze
	_clear()

	# Use cached theme from Config
	theme = Config.theme

	# Calculate dynamic cell size to fit the screen.
	var viewport_size := get_viewport_rect().size
	
	# Reserve some padding (e.g., 5% each side) and subtract top_margin
	# Define minimum margins
	var margin_x = viewport_size.x * 0.02
	
	# Compute horizontal boundaries spanning the whole screen
	var rect_left = margin_x
	var rect_right = viewport_size.x - margin_x
	
	# If D-pad is active, carve out its reserved screen fraction
	var controls = -1
	if is_instance_valid(Config) and "on_screen_controls" in Config:
		controls = Config.on_screen_controls
		
	if controls == Config.ControlsMode.LEFT_HANDED:
		rect_left = (viewport_size.x * UIHelpers.DPAD_SCREEN_FRACTION) + margin_x
	elif controls == Config.ControlsMode.RIGHT_HANDED:
		rect_right = (viewport_size.x * (1.0 - UIHelpers.DPAD_SCREEN_FRACTION)) - margin_x
		
	# Compute maximum available dimensions strictly within the dynamic boundaries
	var available_w = maxf(10.0, rect_right - rect_left)
	var available_h = maxf(10.0, viewport_size.y - top_margin - (viewport_size.y * 0.02))
	
	# Calculate max possible cell size for both dimensions
	var max_cs_x: float = available_w / float(maze.grid_size.x)
	var max_cs_y: float = available_h / float(maze.grid_size.y)
	
	# Pick the smaller one to fit the whole maze while keeping aspect ratio
	_current_cell_size = floorf(minf(max_cs_x, max_cs_y))
	
	# Scale wall thickness
	var scale_ratio := _current_cell_size / float(Config.cell_size)
	_current_wall_thickness = maxf(2.0, floorf(float(Config.wall_thickness) * scale_ratio))

	var maze_pixel_size := Vector2i(
		int(maze.grid_size.x * _current_cell_size),
		int(maze.grid_size.y * _current_cell_size),
	)
	
	# Center the maze strictly inside the newly carved out available\_w window
	var hpad := floori(rect_left + (available_w - maze_pixel_size.x) / 2.0)
		
	var vpad := floori(top_margin + (viewport_size.y - top_margin - maze_pixel_size.y) / 2.0)
	var offset := Vector2i(hpad, vpad)
	_cached_offset = Vector2(offset)

	# 1. Background Layer (Strictly contained in maze area)
	if theme.bg_texture:
		var bg_node: Sprite2D = null
		if theme.bg_tiled:
			bg_node = _add_tiled_background(offset, maze_pixel_size, theme.bg_texture)
		else:
			bg_node = _add_sprite(offset, maze_pixel_size.x, theme.bg_texture, maze_pixel_size)
			
		if bg_node:
			bg_node.modulate = theme.bg_modulate # Apply modulation ONLY to BG
			if not theme.bg_frames.is_empty():
				var animator := FrameAnimator.new()
				bg_node.add_child(animator)
				animator.start(bg_node, theme.bg_frames, theme.bg_fps)

	# 2. Wall Base (only if no background texture, to avoid covering it)
	if not theme.bg_texture:
		_add_rect(offset, maze_pixel_size, theme.color_wall)

	# 3. Apply Visual Environment (Glow, MSAA, etc.)
	UIHelpers.configure_environment(self, theme, Config.performance_mode)

	# 4. Draw Maze Surfaces (Floor)
	# Non-wall elements (floor, icons) are still drawn per-cell
	var int_cs := int(_current_cell_size)
	var int_off_x := int(offset.x)
	var int_off_y := int(offset.y)

	for x in range(maze.grid_size.x):
		for y in range(maze.grid_size.y):
			var coord := Vector2i(x, y)
			var cell  := maze.get_cell(coord)
			var pos   := Vector2(int_off_x + x * int_cs, int_off_y + y * int_cs)
			_draw_cell_corridors(cell, pos, coord)

	# 5. Draw Walls using Line2D (Rounded Paths)
	_draw_walls_line2d(offset, int_cs)


## Return the pixel position for a given grid coordinate (centred in cell).
func grid_to_pixel(coord: Vector2i) -> Vector2:
	if not _maze: return Vector2.ZERO
	return _cached_offset + Vector2(coord.x * _current_cell_size, coord.y * _current_cell_size) + Vector2(_current_cell_size, _current_cell_size) / 2.0


## Return the calculated cell size.
func get_cell_size() -> float:
	return _current_cell_size


## Return the loaded ThemeLoader (so other scripts can reuse it).
func get_theme_loader() -> ThemeLoader:
	return theme


## Build and return an AStar2D map for navigation within the current maze.
func get_navigation_map() -> AStar2D:
	if _maze == null:
		return null
		
	var astar := AStar2D.new()
	var size := _maze.grid_size
	
	# 1. Add all cells as points
	for x in range(size.x):
		for y in range(size.y):
			var id := y * size.x + x
			astar.add_point(id, Vector2(x, y))
			
	# 2. Connect points where walls are open
	for x in range(size.x):
		for y in range(size.y):
			var curr := Vector2i(x, y)
			var id_curr := y * size.x + x
			
			# We only need to check East and South neighbors to connect all
			var neighbors = [
				{"dir": Vector2i.RIGHT, "id_off": 1},
				{"dir": Vector2i.DOWN,  "id_off": size.x}
			]
			
			for n: Dictionary in neighbors:
				var d: Vector2i = n.dir
				var next: Vector2i = curr + d
				if next.x < size.x and next.y < size.y:
					if _maze.is_wall_open(curr, d):
						var id_next := id_curr + int(n.id_off)
						astar.connect_points(id_curr, id_next)
						
	return astar


## Convert a pixel position back to game grid coordinates.
func pixel_to_grid(pixel_pos: Vector2) -> Vector2i:
	if not _maze: return Vector2i.ZERO
	var relative: Vector2 = pixel_pos - _cached_offset
	return Vector2i(
		int(relative.x / _current_cell_size),
		int(relative.y / _current_cell_size)
	)


# ── Private: draw helpers ────────────────────────────────────────────────────

## Remove all child nodes (previous maze visuals).
func _clear() -> void:
	for child in get_children():
		child.queue_free()


## Draw only the floor/passages and icons. Walls are handled by _draw_walls_line2d.
func _draw_cell_corridors(cell: MazeData.CellData, pos: Vector2, coord: Vector2i) -> void:
	var cs := _current_cell_size
	var wt := _current_wall_thickness
	var has_bg := theme.bg_texture != null

	var cmds := MazeCellDrawer.get_cell_draw_commands(cell, pos, cs, wt, theme, has_bg, _maze, coord)

	for r: MazeCellDrawer.RectCmd in cmds["rects"]:
		# Floor and passage rects only — walls use Line2D (drawn separately).
		_add_rect(r.pos, r.size, r.color)

	for icon: MazeCellDrawer.IconCmd in cmds["icons"]:
		_add_sprite(icon.pos, icon.cell_size, icon.texture)


## Trace and draw walls using continuous Line2D segments.
func _draw_walls_line2d(offset: Vector2, cs: int) -> void:
	var width  := _maze.grid_size.x
	var height := _maze.grid_size.y
	
	# Group Horizontal (North-facing) walls
	for y in range(height + 1):
		var x := 0
		while x < width:
			var has_wall := false
			if y < height: has_wall = _maze.get_cell(Vector2i(x, y)).wall_north
			else: has_wall = _maze.get_cell(Vector2i(x, y-1)).wall_south
			
			if has_wall:
				var x_start := x
				while x < width:
					var next_wall := false
					if y < height: next_wall = _maze.get_cell(Vector2i(x, y)).wall_north
					else: next_wall = _maze.get_cell(Vector2i(x, y-1)).wall_south
					if not next_wall: break
					x += 1
				
				# Draw horizontal line from x_start to x
				var p0 := offset + Vector2(x_start * cs, y * cs)
				var p1 := offset + Vector2(x * cs, y * cs)
				_add_wall_line(p0, p1)
			else:
				x += 1

	# Group Vertical (West-facing) walls
	for x in range(width + 1):
		var y := 0
		while y < height:
			var has_wall := false
			if x < width: has_wall = _maze.get_cell(Vector2i(x, y)).wall_west
			else: has_wall = _maze.get_cell(Vector2i(x-1, y)).wall_east
			
			if has_wall:
				var y_start := y
				while y < height:
					var next_wall := false
					if x < width: next_wall = _maze.get_cell(Vector2i(x, y)).wall_west
					else: next_wall = _maze.get_cell(Vector2i(x-1, y)).wall_east
					if not next_wall: break
					y += 1
				
				# Draw vertical line from y_start to y
				var p0 := offset + Vector2(x * cs, y_start * cs)
				var p1 := offset + Vector2(x * cs, y * cs)
				_add_wall_line(p0, p1)
			else:
				y += 1

func _add_wall_line(p0: Vector2, p1: Vector2) -> void:
	var line := Line2D.new()
	line.add_point(p0)
	line.add_point(p1)
	
	line.width = _current_wall_thickness
	
	# Apply glow factor only to the wall lines.
	# Multiplier brings it above HDR threshold (1.5) if set in manifest.
	line.default_color = theme.color_wall * theme.wall_glow_factor
	
	# Modern rounded styling
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.antialiased = not Config.performance_mode
	
	add_child(line)

## Instantiate a simple ColorRect child.
func _add_rect(pos: Vector2, size: Vector2, color: Color) -> void:
	var rect := ColorRect.new()
	rect.position = pos
	rect.size     = size
	rect.color    = color
	add_child(rect)


## Instantiate a Sprite2D centred in the cell, scaled to fit.
func _add_sprite(cell_pos: Vector2, cell_size_px: float, texture: Texture2D, custom_size: Vector2 = Vector2.ZERO) -> Sprite2D:
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
	return sprite

func _add_tiled_background(pos: Vector2, size: Vector2, texture: Texture2D) -> Sprite2D:
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
	return sprite
