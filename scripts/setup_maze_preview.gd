class_name SetupMazePreview
extends Control

var _theme_loader: ThemeLoader = null
var _maze: MazeData = null
var _theme_dir: String = ""
var _difficulty_idx: int = -1

func configure(theme_dir: String, difficulty_idx: int, _mission_id: String = "") -> void:
	var normalized_theme := theme_dir if not theme_dir.is_empty() else "default"
	var normalized_difficulty := clampi(difficulty_idx, 0, Config.DIFFICULTY_SIZES.size() - 1)
	if (
		_theme_dir == normalized_theme
		and _difficulty_idx == normalized_difficulty
		and _maze != null
	):
		queue_redraw()
		return

	_theme_dir = normalized_theme
	_difficulty_idx = normalized_difficulty
	_theme_loader = ThemeLoader.get_cached(_theme_dir)
	_generate_preview_maze()
	queue_redraw()

func _generate_preview_maze() -> void:
	var size_idx := clampi(_difficulty_idx, 0, Config.DIFFICULTY_SIZES.size() - 1)
	var maze_size := Config.DIFFICULTY_SIZES[size_idx]
	var seed_key := "%s:%d:generic" % [_theme_dir, size_idx]
	seed(abs(seed_key.hash()))
	var gen := MazeGenerator.new()
	_maze = gen.generate_custom(maze_size)
	randomize()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	if _theme_loader == null or _maze == null:
		return

	var preview_rect := Rect2(Vector2.ZERO, size)
	if preview_rect.size.x <= 4.0 or preview_rect.size.y <= 4.0:
		return

	var pad := clampf(minf(preview_rect.size.x, preview_rect.size.y) * 0.02, 2.0, 7.0)
	var content_rect := preview_rect.grow(-pad)
	var grid_w := _maze.grid_size.x
	var grid_h := _maze.grid_size.y
	var painted_layout := MazeWallPainter.is_enabled(_theme_loader)

	var layout_cols := float(grid_w)
	var layout_rows := float(grid_h)
	if painted_layout:
		layout_cols += _theme_loader.wall_top_width_ratio * 1.1
		layout_rows += _theme_loader.wall_top_width_ratio * 0.55 + _theme_loader.wall_face_depth_ratio + _theme_loader.wall_shadow_depth_ratio
	var cell_size := floorf(minf(content_rect.size.x / layout_cols, content_rect.size.y / layout_rows))
	if cell_size < 2.0:
		return

	var visual_bleed := Vector4.ZERO
	if painted_layout:
		visual_bleed = MazeWallPainter.get_visual_bleed(cell_size, _theme_loader)
	var maze_size_px := Vector2(grid_w * cell_size, grid_h * cell_size)
	var visual_size := Vector2(
		maze_size_px.x + visual_bleed.x + visual_bleed.z,
		maze_size_px.y + visual_bleed.y + visual_bleed.w
	)
	var offset := Vector2(
		floorf(content_rect.position.x + (content_rect.size.x - visual_size.x) * 0.5 + visual_bleed.x),
		floorf(content_rect.position.y + (content_rect.size.y - visual_size.y) * 0.5 + visual_bleed.y)
	)

	if painted_layout:
		_draw_painted_preview(offset, maze_size_px, cell_size)
	else:
		_draw_classic_preview(offset, maze_size_px, cell_size)

func _draw_classic_preview(offset: Vector2, maze_size_px: Vector2, cell_size: float) -> void:
	var bg_texture := _theme_loader.bg_texture
	if bg_texture != null:
		_draw_background_texture(bg_texture, Rect2(offset, maze_size_px), _theme_loader.bg_tiled)
	else:
		draw_rect(Rect2(offset, maze_size_px), _theme_loader.color_wall)

	var wall_thickness := maxf(1.0, roundf(float(Config.wall_thickness) * (cell_size / float(Config.cell_size))))
	for y in range(_maze.grid_size.y):
		for x in range(_maze.grid_size.x):
			var coord := Vector2i(x, y)
			var cell := _maze.get_cell(coord)
			if cell == null:
				continue
			var pos := offset + Vector2(x * cell_size, y * cell_size)
			var commands := MazeCellDrawer.get_cell_draw_commands(
				cell,
				pos,
				int(cell_size),
				int(wall_thickness),
				_theme_loader,
				bg_texture != null,
				_maze,
				coord
			)
			for rect_cmd: MazeCellDrawer.RectCmd in commands["rects"]:
				draw_rect(Rect2(rect_cmd.pos, rect_cmd.size), rect_cmd.color)

	for seg: MazeCellDrawer.WallSegment in MazeCellDrawer.get_wall_segments(_maze, offset, int(cell_size)):
		draw_line(seg.p0, seg.p1, _theme_loader.color_wall, wall_thickness, true)

	_draw_maze_icons(offset, cell_size)

func _draw_background_texture(texture: Texture2D, dest_rect: Rect2, tiled: bool) -> void:
	if tiled:
		draw_texture_rect(texture, dest_rect, true)
		return

	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0 or dest_rect.size.x <= 0.0 or dest_rect.size.y <= 0.0:
		return
	var dest_aspect := dest_rect.size.x / dest_rect.size.y
	var texture_aspect := texture_size.x / texture_size.y
	var source_rect := Rect2(Vector2.ZERO, texture_size)
	if texture_aspect > dest_aspect:
		var source_w := texture_size.y * dest_aspect
		source_rect.position.x = (texture_size.x - source_w) * 0.5
		source_rect.size.x = source_w
	elif texture_aspect < dest_aspect:
		var source_h := texture_size.x / dest_aspect
		source_rect.position.y = (texture_size.y - source_h) * 0.5
		source_rect.size.y = source_h
	draw_texture_rect_region(texture, dest_rect, source_rect)

func _draw_painted_preview(offset: Vector2, maze_size_px: Vector2, cell_size: float) -> void:
	MazeWallPainter.draw_maze(self, _maze, offset, maze_size_px, cell_size, _theme_loader)
	_draw_maze_icons(offset, cell_size)

func _draw_maze_icons(offset: Vector2, cell_size: float) -> void:
	for y in range(_maze.grid_size.y):
		for x in range(_maze.grid_size.x):
			var coord := Vector2i(x, y)
			var cell := _maze.get_cell(coord)
			if cell == null:
				continue
			var pos := offset + Vector2(x * cell_size, y * cell_size)
			if cell.is_start and _theme_loader.start_texture != null:
				_draw_icon(pos, cell_size, _theme_loader.start_texture)
			elif cell.is_end and _theme_loader.end_texture != null:
				_draw_icon(pos, cell_size, _theme_loader.end_texture)

func _draw_icon(pos: Vector2, cell_size: float, texture: Texture2D) -> void:
	var margin := cell_size * 0.12
	var target_size := maxf(1.0, cell_size - margin * 2.0)
	var texture_size := texture.get_size()
	var scale_factor := target_size / maxf(texture_size.x, texture_size.y)
	var final_size := texture_size * scale_factor
	var icon_offset := (Vector2(cell_size, cell_size) - final_size) * 0.5
	draw_texture_rect(texture, Rect2(pos + icon_offset, final_size), false)
