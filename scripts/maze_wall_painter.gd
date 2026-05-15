## maze_wall_painter.gd
## ---------------------------------------------------------------------------
## Paints a raised 2D maze from the existing grid-wall graph.
##
## This is intentionally not isometric geometry. The visual trick is:
##   - a themed floor,
##   - wall tops on every grid wall,
##   - a shorter south/front face only below horizontal wall runs,
##   - soft contact shadows,
##   - junctions drawn at the same wall thickness, never as oversized caps.
## ---------------------------------------------------------------------------
class_name MazeWallPainter
extends RefCounted


static func is_enabled(theme: ThemeLoader) -> bool:
	return (
		theme != null
		and (theme.wall_mode == "painted_raised_2d" or theme.wall_mode == "painted_raised_2d_assets")
	)


static func draw_maze(canvas: CanvasItem, maze: MazeData, offset: Vector2, maze_size_px: Vector2, cs: float, theme: ThemeLoader) -> void:
	if maze == null or theme == null:
		return

	if theme.wall_mode == "painted_raised_2d_assets" and _has_asset_pack(theme):
		_draw_asset_maze(canvas, maze, offset, maze_size_px, cs, theme)
		return

	_draw_floor(canvas, offset, maze_size_px, theme)
	_draw_road_markings(canvas, maze, offset, cs, theme)

	var top_w := _top_width(cs, theme)
	var face_d := _front_depth(cs, theme)
	var shadow_d := _shadow_depth(cs, theme)
	var segments := MazeCellDrawer.get_wall_segments(maze, offset, cs)

	_draw_contact_shadows(canvas, segments, top_w, face_d, shadow_d)
	_draw_front_faces(canvas, maze, offset, cs, top_w, face_d)
	_draw_wall_tops(canvas, segments, top_w, cs)
	_draw_junction_blends(canvas, maze, offset, cs, top_w)


static func _has_asset_pack(theme: ThemeLoader) -> bool:
	return (
		not theme.wall_top_v_textures.is_empty()
		and (
			not theme.wall_h_combined_textures.is_empty()
			or (
				not theme.wall_top_h_textures.is_empty()
				and not theme.wall_face_h_textures.is_empty()
			)
		)
	)


static func _draw_asset_maze(canvas: CanvasItem, maze: MazeData, offset: Vector2, maze_size_px: Vector2, cs: float, theme: ThemeLoader) -> void:
	_draw_asset_floor(canvas, offset, maze_size_px, theme)
	_draw_road_markings(canvas, maze, offset, cs, theme)

	var top_w := _top_width(cs, theme)
	var face_d := _front_depth(cs, theme)
	var shadow_d := _shadow_depth(cs, theme)
	var segments := MazeCellDrawer.get_wall_segments(maze, offset, cs)
	var use_combined_h := not theme.wall_h_combined_textures.is_empty()

	_draw_asset_contact_shadows(canvas, segments, top_w, face_d, shadow_d, theme)
	if use_combined_h:
		_draw_asset_horizontal_combined(canvas, maze, offset, cs, top_w, face_d, theme)
	else:
		_draw_asset_front_faces(canvas, maze, offset, cs, top_w, face_d, theme)
	_draw_asset_wall_tops(canvas, segments, offset, top_w, cs, theme, not use_combined_h)
	_draw_asset_junctions(canvas, maze, offset, cs, top_w, theme)


static func _draw_asset_floor(canvas: CanvasItem, offset: Vector2, maze_size_px: Vector2, theme: ThemeLoader) -> void:
	var floor_tex := _texture_from_list(theme.floor_textures, theme.floor_texture, 0)
	if floor_tex != null and theme.floor_textures.size() <= 1:
		canvas.draw_texture_rect(floor_tex, Rect2(offset, maze_size_px), true)
	elif not theme.floor_textures.is_empty():
		var tile_size := theme.floor_textures[0].get_size()
		if tile_size.x <= 0.0 or tile_size.y <= 0.0:
			_draw_floor(canvas, offset, maze_size_px, theme)
			return
		var row := 0
		var y := offset.y
		while y < offset.y + maze_size_px.y - 0.5:
			var col := 0
			var x := offset.x
			while x < offset.x + maze_size_px.x - 0.5:
				var tex := _texture_from_list(theme.floor_textures, floor_tex, _variant_index(col, row, theme.floor_textures.size()))
				var size := Vector2(minf(tile_size.x, offset.x + maze_size_px.x - x), minf(tile_size.y, offset.y + maze_size_px.y - y))
				if tex != null:
					canvas.draw_texture_rect_region(tex, Rect2(Vector2(x, y), size), Rect2(Vector2.ZERO, size))
				x += tile_size.x
				col += 1
			y += tile_size.y
			row += 1
	else:
		_draw_floor(canvas, offset, maze_size_px, theme)


static func _draw_asset_contact_shadows(canvas: CanvasItem, segments: Array[MazeCellDrawer.WallSegment], top_w: float, face_d: float, shadow_d: float, theme: ThemeLoader) -> void:
	for seg: MazeCellDrawer.WallSegment in segments:
		if seg.orientation == "h":
			var x0 := minf(seg.p0.x, seg.p1.x)
			var x1 := maxf(seg.p0.x, seg.p1.x)
			var y := seg.p0.y
			var rect := Rect2(
				Vector2(x0 - top_w * 0.15, y + top_w * 0.45 + face_d * 0.38),
				Vector2((x1 - x0) + top_w * 0.30, face_d * 0.62 + shadow_d)
			)
			if theme.wall_shadow_h_texture != null:
				if theme.wall_shadow_h_end_left_texture != null and theme.wall_shadow_h_end_right_texture != null and rect.size.x > top_w * 2.4:
					var cap_w := minf(top_w * 1.25, rect.size.x * 0.45)
					var mid_rect := Rect2(rect.position + Vector2(cap_w * 0.50, 0.0), rect.size - Vector2(cap_w, 0.0))
					_draw_tiled_scaled(canvas, theme.wall_shadow_h_texture, mid_rect, true)
					_draw_texture_scaled(canvas, theme.wall_shadow_h_end_left_texture, Rect2(rect.position, Vector2(cap_w, rect.size.y)))
					_draw_texture_scaled(canvas, theme.wall_shadow_h_end_right_texture, Rect2(Vector2(rect.end.x - cap_w, rect.position.y), Vector2(cap_w, rect.size.y)))
				else:
					_draw_tiled_scaled(canvas, theme.wall_shadow_h_texture, rect, true)
			else:
				canvas.draw_rect(rect, Color(0.0, 0.0, 0.0, 0.18))
		elif seg.orientation == "v":
			var y0 := minf(seg.p0.y, seg.p1.y)
			var y1 := maxf(seg.p0.y, seg.p1.y)
			var x := seg.p0.x
			var rect := Rect2(Vector2(x + top_w * 0.40, y0 + top_w * 0.20), Vector2(shadow_d, (y1 - y0) + top_w * 0.15))
			if theme.wall_shadow_v_texture != null:
				_draw_tiled_scaled(canvas, theme.wall_shadow_v_texture, rect, false)
			else:
				canvas.draw_rect(rect, Color(0.0, 0.0, 0.0, 0.12))


static func _draw_road_markings(canvas: CanvasItem, maze: MazeData, offset: Vector2, cs: float, theme: ThemeLoader) -> void:
	if maze == null or theme == null or not theme.road_markings_enabled:
		return

	var dash_len := clampf(cs * theme.road_marking_dash_length_ratio, cs * 0.22, cs * 0.55)
	var line_w := clampf(cs * theme.road_marking_width_ratio, 1.6, 4.5)
	for y in range(maze.grid_size.y):
		for x in range(maze.grid_size.x):
			var cell := maze.get_cell(Vector2i(x, y))
			if cell == null:
				continue

			var open_horizontal := not cell.wall_west or not cell.wall_east
			var open_vertical := not cell.wall_north or not cell.wall_south
			var center := offset + Vector2((float(x) + 0.5) * cs, (float(y) + 0.5) * cs)
			if open_horizontal and not open_vertical:
				_draw_road_dash(canvas, center - Vector2(dash_len * 0.5, 0.0), center + Vector2(dash_len * 0.5, 0.0), line_w, theme)
			elif open_vertical and not open_horizontal:
				_draw_road_dash(canvas, center - Vector2(0.0, dash_len * 0.5), center + Vector2(0.0, dash_len * 0.5), line_w, theme)


static func _draw_road_dash(canvas: CanvasItem, start: Vector2, end: Vector2, line_w: float, theme: ThemeLoader) -> void:
	canvas.draw_line(start + Vector2(0.0, line_w * 0.35), end + Vector2(0.0, line_w * 0.35), theme.road_marking_shadow_color, line_w * 1.55, true)
	canvas.draw_line(start, end, theme.road_marking_color, line_w, true)




static func _draw_asset_front_faces(canvas: CanvasItem, maze: MazeData, offset: Vector2, cs: float, top_w: float, face_d: float, theme: ThemeLoader) -> void:
	var width := maze.grid_size.x
	var height := maze.grid_size.y
	for y in range(height + 1):
		var x := 0
		while x < width:
			if not _has_horizontal_wall(maze, x, y):
				x += 1
				continue

			var start_x := x
			while x < width and _has_horizontal_wall(maze, x, y):
				x += 1
			var end_x := x

			_draw_asset_front_face_run(canvas, maze, offset, cs, start_x, end_x, y, top_w, face_d, theme)


static func _draw_asset_horizontal_combined(canvas: CanvasItem, maze: MazeData, offset: Vector2, cs: float, top_w: float, face_d: float, theme: ThemeLoader) -> void:
	var width := maze.grid_size.x
	var height := maze.grid_size.y
	for y in range(height + 1):
		var x := 0
		while x < width:
			if not _has_horizontal_wall(maze, x, y):
				x += 1
				continue

			var start_x := x
			while x < width and _has_horizontal_wall(maze, x, y):
				x += 1
			var end_x := x

			_draw_asset_horizontal_combined_run(canvas, maze, offset, cs, start_x, end_x, y, top_w, face_d, theme)


static func _draw_asset_horizontal_combined_run(canvas: CanvasItem, maze: MazeData, offset: Vector2, cs: float, x_start: int, x_end: int, y_grid: int, top_w: float, face_d: float, theme: ThemeLoader) -> void:
	if theme.wall_h_combined_textures.is_empty():
		return
	var run_x0 := offset.x + x_start * cs
	var run_x1 := offset.x + x_end * cs
	if run_x1 <= run_x0 + 2.0:
		return

	var y := offset.y + y_grid * cs
	var tex := _texture_from_list(theme.wall_h_combined_textures, null, _variant_index(x_start, y_grid, theme.wall_h_combined_textures.size()))
	if tex != null:
		_draw_tiled_scaled(canvas, tex, Rect2(Vector2(run_x0, y - top_w * 0.50), Vector2(run_x1 - run_x0, top_w * 0.95 + face_d)), true)

	var left_exposed := _is_exposed_horizontal_end(maze, x_start, y_grid)
	var right_exposed := _is_exposed_horizontal_end(maze, x_end, y_grid)
	if left_exposed:
		_draw_asset_face_piece(canvas, run_x0, y, top_w, face_d, true, theme.wall_face_end_left_textures, x_start, y_grid)
	else:
		_draw_asset_face_piece(canvas, run_x0, y, top_w, face_d, true, theme.wall_face_corner_left_textures, x_start, y_grid)
	if right_exposed:
		_draw_asset_face_piece(canvas, run_x1, y, top_w, face_d, false, theme.wall_face_end_right_textures, x_end, y_grid)
	else:
		_draw_asset_face_piece(canvas, run_x1, y, top_w, face_d, false, theme.wall_face_corner_right_textures, x_end, y_grid)


static func _draw_asset_front_face_run(canvas: CanvasItem, maze: MazeData, offset: Vector2, cs: float, x_start: int, x_end: int, y_grid: int, top_w: float, face_d: float, theme: ThemeLoader) -> void:
	var run_x0 := offset.x + x_start * cs
	var run_x1 := offset.x + x_end * cs
	var x0 := run_x0 + top_w * 0.58
	var x1 := run_x1 - top_w * 0.58
	if x1 <= x0 + 2.0:
		return

	var y := offset.y + y_grid * cs
	var face_rect := Rect2(Vector2(x0, y + top_w * 0.45), Vector2(x1 - x0, face_d))
	var face_tex := _texture_from_list(theme.wall_face_h_textures, theme.wall_face_h_texture, _variant_index(x_start, y_grid, theme.wall_face_h_textures.size()))
	if face_tex != null:
		_draw_tiled_scaled(canvas, face_tex, face_rect, true)
	else:
		canvas.draw_rect(face_rect, Color(0.17, 0.165, 0.205))

	var left_exposed := _is_exposed_horizontal_end(maze, x_start, y_grid)
	var right_exposed := _is_exposed_horizontal_end(maze, x_end, y_grid)
	if left_exposed:
		_draw_asset_face_piece(canvas, run_x0, y, top_w, face_d, true, theme.wall_face_end_left_textures, x_start, y_grid)
	else:
		_draw_asset_face_piece(canvas, run_x0, y, top_w, face_d, true, theme.wall_face_corner_left_textures, x_start, y_grid)
	if right_exposed:
		_draw_asset_face_piece(canvas, run_x1, y, top_w, face_d, false, theme.wall_face_end_right_textures, x_end, y_grid)
	else:
		_draw_asset_face_piece(canvas, run_x1, y, top_w, face_d, false, theme.wall_face_corner_right_textures, x_end, y_grid)


static func _draw_asset_face_piece(canvas: CanvasItem, vertex_x: float, y: float, top_w: float, face_d: float, is_left: bool, textures: Array[Texture2D], seed_x: int, seed_y: int) -> void:
	if textures.is_empty():
		return
	var tex := _texture_from_list(textures, null, _variant_index(seed_x, seed_y, textures.size()))
	if tex == null:
		return
	var piece_w := top_w * 0.94
	var x := vertex_x + top_w * 0.02 if is_left else vertex_x - piece_w - top_w * 0.02
	_draw_texture_scaled(canvas, tex, Rect2(Vector2(x, y + top_w * 0.45), Vector2(piece_w, face_d)))


static func _draw_asset_wall_tops(canvas: CanvasItem, segments: Array[MazeCellDrawer.WallSegment], offset: Vector2, top_w: float, cs: float, theme: ThemeLoader, draw_horizontal: bool = true) -> void:
	for seg: MazeCellDrawer.WallSegment in segments:
		if draw_horizontal and seg.orientation == "h":
			_draw_asset_top_run_h(canvas, seg, offset, top_w, cs, theme)
	for seg: MazeCellDrawer.WallSegment in segments:
		if seg.orientation == "v":
			_draw_asset_top_run_v(canvas, seg, offset, top_w, cs, theme)


static func _draw_asset_top_run_h(canvas: CanvasItem, seg: MazeCellDrawer.WallSegment, offset: Vector2, top_w: float, cs: float, theme: ThemeLoader) -> void:
	var x0 := minf(seg.p0.x, seg.p1.x)
	var x1 := maxf(seg.p0.x, seg.p1.x)
	var y := seg.p0.y
	var grid_x := int(roundf((x0 - offset.x) / maxf(1.0, cs)))
	var grid_y := int(roundf((y - offset.y) / maxf(1.0, cs)))
	var tex := _texture_from_list(theme.wall_top_h_textures, theme.wall_top_h_texture, _variant_index(grid_x, grid_y, theme.wall_top_h_textures.size()))
	if tex != null:
		_draw_tiled_scaled(canvas, tex, Rect2(Vector2(x0, y - top_w * 0.50), Vector2(x1 - x0, top_w)), true)


static func _draw_asset_top_run_v(canvas: CanvasItem, seg: MazeCellDrawer.WallSegment, offset: Vector2, top_w: float, cs: float, theme: ThemeLoader) -> void:
	var y0 := minf(seg.p0.y, seg.p1.y)
	var y1 := maxf(seg.p0.y, seg.p1.y)
	var x := seg.p0.x
	var grid_x := int(roundf((x - offset.x) / maxf(1.0, cs)))
	var grid_y := int(roundf((y0 - offset.y) / maxf(1.0, cs)))
	var tex := _texture_from_list(theme.wall_top_v_textures, theme.wall_top_v_texture, _variant_index(grid_x, grid_y, theme.wall_top_v_textures.size()))
	if tex != null:
		_draw_tiled_scaled(canvas, tex, Rect2(Vector2(x - top_w * 0.50, y0), Vector2(top_w, y1 - y0)), false)


static func _draw_asset_junctions(canvas: CanvasItem, maze: MazeData, offset: Vector2, cs: float, top_w: float, theme: ThemeLoader) -> void:
	for vertex_info: Dictionary in _wall_vertex_masks(maze):
		var mask := int(vertex_info["mask"])
		if mask == 5 or mask == 10:
			continue

		var vertex: Vector2i = vertex_info["coord"]
		var center := offset + Vector2(vertex.x * cs, vertex.y * cs)
		var tex: Texture2D = null
		var degree := _mask_degree(mask)
		if degree <= 1:
			match mask:
				1:
					tex = _texture_from_list(theme.wall_top_end_south_textures, null, _variant_index(vertex.x, vertex.y, theme.wall_top_end_south_textures.size()))
				2:
					tex = _texture_from_list(theme.wall_top_end_left_textures, null, _variant_index(vertex.x, vertex.y, theme.wall_top_end_left_textures.size()))
				4:
					tex = _texture_from_list(theme.wall_top_end_north_textures, null, _variant_index(vertex.x, vertex.y, theme.wall_top_end_north_textures.size()))
				8:
					tex = _texture_from_list(theme.wall_top_end_right_textures, null, _variant_index(vertex.x, vertex.y, theme.wall_top_end_right_textures.size()))
		else:
			tex = _texture_from_joint_value(theme.wall_joint_textures.get(mask, null), vertex.x, vertex.y)

		if tex != null:
			var asset_size := top_w * (1.04 if degree > 1 else 1.08)
			var themed_size := cs * theme.wall_node_scale_ratio
			var overlay_size := maxf(asset_size, themed_size)
			_draw_texture_scaled(canvas, tex, Rect2(center - Vector2(overlay_size, overlay_size) * 0.5, Vector2(overlay_size, overlay_size)))


static func get_visual_bleed(cs: float, theme: ThemeLoader) -> Vector4:
	var top_w := _top_width(cs, theme)
	var face_d := _front_depth(cs, theme)
	var shadow_d := _shadow_depth(cs, theme)
	return Vector4(
		top_w * 0.62,
		top_w * 0.62,
		top_w * 0.62,
		top_w * 0.62 + face_d + shadow_d
	)


static func _draw_floor(canvas: CanvasItem, offset: Vector2, maze_size_px: Vector2, theme: ThemeLoader) -> void:
	var bounds := Rect2(offset, maze_size_px)
	canvas.draw_rect(bounds, Color(0.105, 0.135, 0.165))

	var row_h := clampf(maze_size_px.y / 18.0, 18.0, 34.0)
	var y := offset.y
	var row := 0
	while y < bounds.end.y - 1.0:
		var h := minf(row_h + (_hash01(row, 91) - 0.5) * 6.0, bounds.end.y - y)
		var x := offset.x
		var col := 0
		if row % 2 == 1:
			x -= row_h * (0.65 + _hash01(row, 12) * 0.35)
		while x < bounds.end.x - 1.0:
			var w := clampf(row_h * (1.45 + _hash01(col + 17, row + 33) * 1.25), 26.0, 72.0)
			var stone := Rect2(Vector2(maxf(x, bounds.position.x), y), Vector2(minf(w, bounds.end.x - maxf(x, bounds.position.x)), h))
			if stone.size.x > 1.0 and stone.size.y > 1.0:
				var shade := _hash01(col * 19, row * 23)
				var tint := Color(0.115 + shade * 0.030, 0.145 + shade * 0.035, 0.175 + shade * 0.040, 1.0)
				canvas.draw_rect(stone.grow(-0.8), tint)
				canvas.draw_rect(stone, Color(0.025, 0.035, 0.045, 0.40), false, 1.0)
				if shade > 0.68:
					_draw_crack(canvas, stone.grow(-4.0), col + 400, row + 300, Color(0.025, 0.030, 0.038, 0.38))
			x += w
			col += 1
		y += h
		row += 1

	canvas.draw_rect(bounds, Color(0.0, 0.0, 0.0, 0.10), false, 1.0)


static func _draw_contact_shadows(canvas: CanvasItem, segments: Array[MazeCellDrawer.WallSegment], top_w: float, face_d: float, shadow_d: float) -> void:
	for seg: MazeCellDrawer.WallSegment in segments:
		if seg.orientation == "h":
			var x0 := minf(seg.p0.x, seg.p1.x)
			var x1 := maxf(seg.p0.x, seg.p1.x)
			var y := seg.p0.y
			var shadow_rect := Rect2(
				Vector2(x0 - top_w * 0.15, y + top_w * 0.45),
				Vector2((x1 - x0) + top_w * 0.3, face_d + shadow_d)
			)
			canvas.draw_rect(shadow_rect, Color(0.0, 0.0, 0.0, 0.22))
			canvas.draw_rect(
				Rect2(Vector2(shadow_rect.position.x, shadow_rect.end.y - shadow_d), Vector2(shadow_rect.size.x, shadow_d)),
				Color(0.0, 0.0, 0.0, 0.14)
			)
		elif seg.orientation == "v":
			var y0 := minf(seg.p0.y, seg.p1.y)
			var y1 := maxf(seg.p0.y, seg.p1.y)
			var x := seg.p0.x
			canvas.draw_rect(
				Rect2(Vector2(x + top_w * 0.40, y0 + top_w * 0.20), Vector2(shadow_d, (y1 - y0) + top_w * 0.15)),
				Color(0.0, 0.0, 0.0, 0.14)
			)


static func _draw_front_faces(canvas: CanvasItem, maze: MazeData, offset: Vector2, cs: float, top_w: float, face_d: float) -> void:
	var width := maze.grid_size.x
	var height := maze.grid_size.y
	for y in range(height + 1):
		var x := 0
		while x < width:
			if not _has_horizontal_wall(maze, x, y):
				x += 1
				continue

			var start_x := x
			while x < width and _has_horizontal_wall(maze, x, y):
				x += 1
			var end_x := x

			_draw_front_face_run(canvas, maze, offset, cs, start_x, end_x, y, top_w, face_d)


static func _draw_front_face_run(canvas: CanvasItem, maze: MazeData, offset: Vector2, cs: float, x_start: int, x_end: int, y_grid: int, top_w: float, face_d: float) -> void:
	var run_x0 := offset.x + x_start * cs
	var run_x1 := offset.x + x_end * cs
	var x0 := run_x0 + top_w * 0.58
	var x1 := run_x1 - top_w * 0.58
	if x1 <= x0 + 2.0:
		return

	var y := offset.y + y_grid * cs
	var rect := Rect2(Vector2(x0, y + top_w * 0.45), Vector2(x1 - x0, face_d))
	canvas.draw_rect(rect, Color(0.17, 0.165, 0.205))
	canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x, maxf(1.0, face_d * 0.18))), Color(0.30, 0.29, 0.35))
	canvas.draw_rect(Rect2(Vector2(rect.position.x, rect.end.y - maxf(2.0, face_d * 0.20)), Vector2(rect.size.x, maxf(2.0, face_d * 0.20))), Color(0.055, 0.050, 0.075, 0.70))

	var cursor := x0
	var index := 0
	while cursor < x1 - 1.0:
		var block_w := _stone_length(cs, x_start + index, y_grid, false)
		block_w = minf(block_w, x1 - cursor)
		var shade := _hash01(x_start + index * 17, y_grid * 13)
		var color := Color(0.18 + shade * 0.05, 0.175 + shade * 0.045, 0.22 + shade * 0.055, 1.0)
		_draw_chipped_rect(canvas, Rect2(Vector2(cursor, rect.position.y + 1.0), Vector2(maxf(1.0, block_w - 1.0), rect.size.y - 1.0)), color, x_start + index, y_grid, 1.5)
		canvas.draw_line(Vector2(cursor, rect.position.y), Vector2(cursor, rect.end.y), Color(0.07, 0.065, 0.09, 0.50), 1.0)
		if block_w > cs * 0.22:
			_draw_crack(canvas, Rect2(Vector2(cursor, rect.position.y), Vector2(block_w, rect.size.y)), x_start + index, y_grid + 73, Color(0.06, 0.055, 0.08, 0.48))
		cursor += block_w
		index += 1
	canvas.draw_line(Vector2(x0, rect.position.y), Vector2(x1, rect.position.y), Color(0.40, 0.39, 0.46, 0.70), 1.0)
	canvas.draw_line(Vector2(x0, rect.end.y), Vector2(x1, rect.end.y), Color(0.035, 0.032, 0.052, 0.78), 2.0)

	var left_exposed := _is_exposed_horizontal_end(maze, x_start, y_grid)
	var right_exposed := _is_exposed_horizontal_end(maze, x_end, y_grid)
	if left_exposed:
		_draw_front_face_end(canvas, run_x0, y, top_w, face_d, true, x_start, y_grid)
	else:
		_draw_front_face_corner_return(canvas, run_x0, y, top_w, face_d, true, x_start, y_grid)
	if right_exposed:
		_draw_front_face_end(canvas, run_x1, y, top_w, face_d, false, x_end, y_grid)
	else:
		_draw_front_face_corner_return(canvas, run_x1, y, top_w, face_d, false, x_end, y_grid)


static func _draw_front_face_end(canvas: CanvasItem, vertex_x: float, y: float, top_w: float, face_d: float, is_left: bool, seed_x: int, seed_y: int) -> void:
	var face_y := y + top_w * 0.45
	var cap_w := top_w * 0.78
	var x := vertex_x + top_w * 0.06 if is_left else vertex_x - top_w * 0.84
	var cap := Rect2(Vector2(x, face_y), Vector2(cap_w, face_d))
	var shade := _hash01(seed_x + 81, seed_y + 17)
	var color := Color(0.155 + shade * 0.035, 0.150 + shade * 0.030, 0.195 + shade * 0.042, 1.0)

	_draw_rounded_side_rect(canvas, cap, color, "left" if is_left else "right")
	canvas.draw_rect(Rect2(cap.position + Vector2(0.0, 1.0), Vector2(cap.size.x, maxf(1.0, face_d * 0.16))), Color(0.29, 0.28, 0.34, 0.62))
	canvas.draw_line(
		Vector2(cap.position.x + cap.size.x * 0.56 if is_left else cap.position.x + cap.size.x * 0.44, cap.position.y + 2.0),
		Vector2(cap.position.x + cap.size.x * 0.56 if is_left else cap.position.x + cap.size.x * 0.44, cap.end.y - 2.0),
		Color(0.050, 0.045, 0.065, 0.42),
		1.0
	)
	canvas.draw_line(Vector2(cap.position.x, cap.end.y), Vector2(cap.end.x, cap.end.y), Color(0.035, 0.032, 0.052, 0.78), 1.6)


static func _draw_front_face_corner_return(canvas: CanvasItem, vertex_x: float, y: float, top_w: float, face_d: float, is_left: bool, seed_x: int, seed_y: int) -> void:
	var face_y := y + top_w * 0.45
	var return_w := top_w * 0.62
	var x := vertex_x + top_w * 0.22 if is_left else vertex_x - top_w * 0.84
	var rect := Rect2(Vector2(x, face_y + 1.0), Vector2(return_w, face_d - 1.0))
	var shade := _hash01(seed_x + 47, seed_y + 89)
	var color := Color(0.145 + shade * 0.030, 0.140 + shade * 0.026, 0.185 + shade * 0.036, 1.0)

	_draw_chipped_rect(canvas, rect, color, seed_x + (31 if is_left else 37), seed_y + 53, 1.0)
	canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x, maxf(1.0, face_d * 0.13))), Color(0.27, 0.26, 0.32, 0.56))
	canvas.draw_line(Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.end.y), Color(0.035, 0.032, 0.052, 0.72), 1.4)


static func _draw_wall_tops(canvas: CanvasItem, segments: Array[MazeCellDrawer.WallSegment], top_w: float, cs: float) -> void:
	for seg: MazeCellDrawer.WallSegment in segments:
		if seg.orientation == "h":
			_draw_top_run_h(canvas, seg, top_w, cs)
	for seg: MazeCellDrawer.WallSegment in segments:
		if seg.orientation == "v":
			_draw_top_run_v(canvas, seg, top_w, cs)


static func _draw_top_run_h(canvas: CanvasItem, seg: MazeCellDrawer.WallSegment, top_w: float, cs: float) -> void:
	var x0 := minf(seg.p0.x, seg.p1.x)
	var x1 := maxf(seg.p0.x, seg.p1.x)
	var y := seg.p0.y
	var top_rect := Rect2(Vector2(x0, y - top_w * 0.50), Vector2(x1 - x0, top_w))
	canvas.draw_rect(top_rect, Color(0.48, 0.48, 0.54))
	canvas.draw_rect(Rect2(top_rect.position, Vector2(top_rect.size.x, top_w * 0.22)), Color(0.70, 0.70, 0.76, 0.86))
	canvas.draw_rect(Rect2(Vector2(top_rect.position.x, top_rect.end.y - top_w * 0.24), Vector2(top_rect.size.x, top_w * 0.24)), Color(0.30, 0.30, 0.37, 0.84))

	var cursor := x0
	var seed_y := int(roundf(y / maxf(1.0, cs)))
	var index := 0
	while cursor < x1 - 1.0:
		var block_w := _stone_length(cs, int(roundf(cursor / maxf(1.0, cs))) + index, seed_y, true)
		block_w = minf(block_w, x1 - cursor)
		_draw_top_stone(canvas, Rect2(Vector2(cursor, top_rect.position.y), Vector2(block_w, top_w)), index, seed_y, true)
		cursor += block_w
		index += 1

	canvas.draw_line(Vector2(x0, top_rect.position.y), Vector2(x1, top_rect.position.y), Color(0.86, 0.85, 0.90, 0.56), 1.0)
	canvas.draw_line(Vector2(x0, top_rect.end.y), Vector2(x1, top_rect.end.y), Color(0.16, 0.15, 0.22, 0.72), 2.0)


static func _draw_top_run_v(canvas: CanvasItem, seg: MazeCellDrawer.WallSegment, top_w: float, cs: float) -> void:
	var y0 := minf(seg.p0.y, seg.p1.y)
	var y1 := maxf(seg.p0.y, seg.p1.y)
	var x := seg.p0.x
	var top_rect := Rect2(Vector2(x - top_w * 0.50, y0), Vector2(top_w, y1 - y0))
	canvas.draw_rect(top_rect, Color(0.46, 0.46, 0.52))
	canvas.draw_rect(Rect2(top_rect.position, Vector2(top_w * 0.24, top_rect.size.y)), Color(0.67, 0.67, 0.73, 0.74))
	canvas.draw_rect(Rect2(Vector2(top_rect.end.x - top_w * 0.24, top_rect.position.y), Vector2(top_w * 0.24, top_rect.size.y)), Color(0.27, 0.27, 0.34, 0.72))

	var cursor := y0
	var seed_x := int(roundf(x / maxf(1.0, cs)))
	var index := 0
	while cursor < y1 - 1.0:
		var block_h := _stone_length(cs, seed_x, int(roundf(cursor / maxf(1.0, cs))) + index, false)
		block_h = minf(block_h, y1 - cursor)
		_draw_top_stone(canvas, Rect2(Vector2(top_rect.position.x, cursor), Vector2(top_w, block_h)), seed_x, index, false)
		cursor += block_h
		index += 1

	canvas.draw_line(Vector2(top_rect.position.x, y0), Vector2(top_rect.position.x, y1), Color(0.84, 0.83, 0.88, 0.46), 1.0)
	canvas.draw_line(Vector2(top_rect.end.x, y0), Vector2(top_rect.end.x, y1), Color(0.15, 0.15, 0.22, 0.66), 2.0)


static func _draw_top_stone(canvas: CanvasItem, rect: Rect2, a: int, b: int, horizontal: bool) -> void:
	var jitter := _hash01(a * 31 + 7, b * 19 + 3)
	var inset := 1.0
	var color := Color(0.48 + jitter * 0.12, 0.48 + jitter * 0.11, 0.54 + jitter * 0.12, 1.0)
	var inner := Rect2(rect.position + Vector2(inset, inset), rect.size - Vector2(inset * 2.0, inset * 2.0))
	if inner.size.x <= 0.0 or inner.size.y <= 0.0:
		return

	_draw_chipped_rect(canvas, inner, color, a, b, 2.4)
	canvas.draw_line(inner.position, Vector2(inner.end.x, inner.position.y), Color(0.86, 0.85, 0.90, 0.48), 1.0)
	canvas.draw_line(Vector2(inner.position.x, inner.end.y), inner.end, Color(0.22, 0.21, 0.29, 0.62), 1.0)

	if horizontal:
		canvas.draw_line(Vector2(rect.end.x, rect.position.y + 2.0), Vector2(rect.end.x, rect.end.y - 2.0), Color(0.18, 0.17, 0.23, 0.50), 1.0)
	else:
		canvas.draw_line(Vector2(rect.position.x + 2.0, rect.end.y), Vector2(rect.end.x - 2.0, rect.end.y), Color(0.18, 0.17, 0.23, 0.50), 1.0)

	if minf(rect.size.x, rect.size.y) > 8.0 and maxf(rect.size.x, rect.size.y) > 22.0:
		_draw_crack(canvas, inner, a + 211, b + 503, Color(0.17, 0.16, 0.22, 0.34))


static func _draw_junction_blends(canvas: CanvasItem, maze: MazeData, offset: Vector2, cs: float, top_w: float) -> void:
	for vertex_info: Dictionary in _wall_vertex_masks(maze):
		var mask := int(vertex_info["mask"])
		if mask == 5 or mask == 10:
			continue

		var vertex: Vector2i = vertex_info["coord"]
		var center := offset + Vector2(vertex.x * cs, vertex.y * cs)
		_draw_junction_mask(canvas, center, mask, top_w, vertex)


static func _draw_junction_mask(canvas: CanvasItem, center: Vector2, mask: int, top_w: float, vertex: Vector2i) -> void:
	var jitter := _hash01(vertex.x, vertex.y)
	var color := Color(0.49 + jitter * 0.07, 0.49 + jitter * 0.07, 0.55 + jitter * 0.07, 1.0)
	var shadow := Color(0.18, 0.17, 0.24, 0.48)
	var half := top_w * 0.5
	var core := Rect2(center - Vector2(half, half) * 0.72, Vector2(top_w * 0.72, top_w * 0.72))
	var degree := _mask_degree(mask)

	if degree <= 1:
		_draw_top_dead_end(canvas, center, mask, top_w, color, vertex)
		return

	_draw_chipped_rect(canvas, core, color, vertex.x, vertex.y, 1.8)
	if (mask & 1) != 0:
		_draw_chipped_rect(canvas, Rect2(Vector2(center.x - half * 0.72, center.y - half), Vector2(top_w * 0.72, half * 0.92)), color, vertex.x + 1, vertex.y, 1.4)
	if (mask & 4) != 0:
		_draw_chipped_rect(canvas, Rect2(Vector2(center.x - half * 0.72, center.y + half * 0.08), Vector2(top_w * 0.72, half * 0.92)), color, vertex.x + 2, vertex.y, 1.4)
	if (mask & 2) != 0:
		_draw_chipped_rect(canvas, Rect2(Vector2(center.x + half * 0.08, center.y - half * 0.72), Vector2(half * 0.92, top_w * 0.72)), color, vertex.x, vertex.y + 1, 1.4)
	if (mask & 8) != 0:
		_draw_chipped_rect(canvas, Rect2(Vector2(center.x - half, center.y - half * 0.72), Vector2(half * 0.92, top_w * 0.72)), color, vertex.x, vertex.y + 2, 1.4)

	canvas.draw_line(center + Vector2(-half * 0.48, -half * 0.46), center + Vector2(half * 0.48, -half * 0.46), Color(0.86, 0.85, 0.90, 0.28), 1.0)
	canvas.draw_line(center + Vector2(-half * 0.48, half * 0.46), center + Vector2(half * 0.48, half * 0.46), shadow, 1.0)


static func _draw_top_dead_end(canvas: CanvasItem, center: Vector2, mask: int, top_w: float, color: Color, vertex: Vector2i) -> void:
	var half := top_w * 0.5
	var rect := Rect2()
	var side := ""
	if (mask & 8) != 0:
		rect = Rect2(Vector2(center.x - top_w * 0.72, center.y - half * 0.82), Vector2(top_w * 0.78, top_w * 0.82))
		side = "right"
	elif (mask & 2) != 0:
		rect = Rect2(Vector2(center.x - top_w * 0.06, center.y - half * 0.82), Vector2(top_w * 0.78, top_w * 0.82))
		side = "left"
	elif (mask & 1) != 0:
		rect = Rect2(Vector2(center.x - half * 0.82, center.y - top_w * 0.72), Vector2(top_w * 0.82, top_w * 0.78))
		side = "bottom"
	elif (mask & 4) != 0:
		rect = Rect2(Vector2(center.x - half * 0.82, center.y - top_w * 0.06), Vector2(top_w * 0.82, top_w * 0.78))
		side = "top"
	else:
		return

	_draw_rounded_side_rect(canvas, rect, color, side)
	canvas.draw_line(rect.position + Vector2(1.0, 1.0), Vector2(rect.end.x - 1.0, rect.position.y + 1.0), Color(0.86, 0.85, 0.90, 0.32), 1.0)
	canvas.draw_line(Vector2(rect.position.x + 1.0, rect.end.y - 1.0), rect.end - Vector2(1.0, 1.0), Color(0.18, 0.17, 0.24, 0.42), 1.0)


static func _draw_crack(canvas: CanvasItem, rect: Rect2, a: int, b: int, color: Color) -> void:
	var r := _hash01(a, b)
	if r < 0.34:
		return

	var p0 := rect.position + Vector2(rect.size.x * (0.20 + _hash01(a + 3, b) * 0.55), rect.size.y * (0.25 + _hash01(a, b + 5) * 0.45))
	var p1 := p0 + Vector2((r - 0.5) * rect.size.x * 0.22, rect.size.y * (0.18 + _hash01(a + 9, b + 9) * 0.14))
	var p2 := p1 + Vector2((_hash01(a + 4, b + 6) - 0.5) * rect.size.x * 0.18, rect.size.y * 0.12)
	canvas.draw_line(p0, p1, color, 1.0)
	canvas.draw_line(p1, p2, color, 1.0)


static func _draw_chipped_rect(canvas: CanvasItem, rect: Rect2, color: Color, a: int, b: int, max_chip: float) -> void:
	if rect.size.x < 5.0 or rect.size.y < 5.0:
		canvas.draw_rect(rect, color)
		return

	var max_allowed := minf(max_chip, minf(rect.size.x, rect.size.y) * 0.22)
	var chip_a := 0.5 + _hash01(a + 5, b + 7) * max_allowed
	var chip_b := 0.5 + _hash01(a + 11, b + 13) * max_allowed
	var chip_c := 0.5 + _hash01(a + 17, b + 19) * max_allowed
	var chip_d := 0.5 + _hash01(a + 23, b + 29) * max_allowed
	var points := PackedVector2Array([
		rect.position + Vector2(chip_a, 0.0),
		Vector2(rect.end.x - chip_b, rect.position.y),
		Vector2(rect.end.x, rect.position.y + chip_b),
		rect.end - Vector2(chip_c, 0.0),
		Vector2(rect.position.x + chip_d, rect.end.y),
		Vector2(rect.position.x, rect.end.y - chip_d),
	])
	canvas.draw_colored_polygon(points, color)


static func _draw_rounded_side_rect(canvas: CanvasItem, rect: Rect2, color: Color, side: String) -> void:
	if rect.size.x < 3.0 or rect.size.y < 3.0:
		canvas.draw_rect(rect, color)
		return

	var points := PackedVector2Array()
	var steps := 8
	var center := Vector2.ZERO
	var rx := 0.0
	var ry := 0.0

	match side:
		"right":
			center = Vector2(rect.position.x, rect.position.y + rect.size.y * 0.5)
			rx = rect.size.x
			ry = rect.size.y * 0.5
			for i in range(steps + 1):
				var a := lerpf(-PI * 0.5, PI * 0.5, float(i) / float(steps))
				points.append(center + Vector2(cos(a) * rx, sin(a) * ry))
		"left":
			center = Vector2(rect.end.x, rect.position.y + rect.size.y * 0.5)
			rx = rect.size.x
			ry = rect.size.y * 0.5
			for i in range(steps + 1):
				var a := lerpf(-PI * 0.5, -PI * 1.5, float(i) / float(steps))
				points.append(center + Vector2(cos(a) * rx, sin(a) * ry))
		"bottom":
			center = Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y)
			rx = rect.size.x * 0.5
			ry = rect.size.y
			for i in range(steps + 1):
				var a := lerpf(PI, 0.0, float(i) / float(steps))
				points.append(center + Vector2(cos(a) * rx, sin(a) * ry))
		"top":
			center = Vector2(rect.position.x + rect.size.x * 0.5, rect.end.y)
			rx = rect.size.x * 0.5
			ry = rect.size.y
			for i in range(steps + 1):
				var a := lerpf(PI, PI * 2.0, float(i) / float(steps))
				points.append(center + Vector2(cos(a) * rx, sin(a) * ry))
		_:
			canvas.draw_rect(rect, color)
			return

	canvas.draw_colored_polygon(points, color)


static func _draw_texture_scaled(canvas: CanvasItem, texture: Texture2D, rect: Rect2) -> void:
	if texture == null or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	canvas.draw_texture_rect(texture, rect, false)


static func _draw_tiled_scaled(canvas: CanvasItem, texture: Texture2D, rect: Rect2, horizontal: bool) -> void:
	if texture == null or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return

	var tex_size := texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return

	if horizontal:
		var scale := rect.size.y / tex_size.y
		var tile_w := tex_size.x * scale
		var x := rect.position.x
		while x < rect.end.x - 0.5:
			var w := minf(tile_w, rect.end.x - x)
			var src_w := tex_size.x * (w / tile_w)
			canvas.draw_texture_rect_region(texture, Rect2(Vector2(x, rect.position.y), Vector2(w, rect.size.y)), Rect2(Vector2.ZERO, Vector2(src_w, tex_size.y)))
			x += w
	else:
		var scale := rect.size.x / tex_size.x
		var tile_h := tex_size.y * scale
		var y := rect.position.y
		while y < rect.end.y - 0.5:
			var h := minf(tile_h, rect.end.y - y)
			var src_h := tex_size.y * (h / tile_h)
			canvas.draw_texture_rect_region(texture, Rect2(Vector2(rect.position.x, y), Vector2(rect.size.x, h)), Rect2(Vector2.ZERO, Vector2(tex_size.x, src_h)))
			y += h


static func _texture_from_list(textures: Array[Texture2D], fallback: Texture2D, index: int) -> Texture2D:
	if not textures.is_empty():
		return textures[index % textures.size()]
	return fallback


static func _texture_from_joint_value(value: Variant, seed_x: int, seed_y: int) -> Texture2D:
	if value is Texture2D:
		return value
	if value is Array:
		var textures: Array = value
		if textures.is_empty():
			return null
		var tex: Texture2D = textures[_variant_index(seed_x, seed_y, textures.size())] as Texture2D
		return tex
	return null


static func _variant_index(a: int, b: int, count: int) -> int:
	if count <= 1:
		return 0
	var h := int((a * 92837111) ^ (b * 689287499) ^ 0x45d9f3b)
	return absi(h) % count


static func _mask_degree(mask: int) -> int:
	var degree := 0
	if (mask & 1) != 0:
		degree += 1
	if (mask & 2) != 0:
		degree += 1
	if (mask & 4) != 0:
		degree += 1
	if (mask & 8) != 0:
		degree += 1
	return degree


static func _top_width(cs: float, theme: ThemeLoader) -> float:
	return clampf(cs * theme.wall_top_width_ratio, 10.0, 30.0)


static func _front_depth(cs: float, theme: ThemeLoader) -> float:
	return clampf(cs * theme.wall_face_depth_ratio, 8.0, 24.0)


static func _shadow_depth(cs: float, theme: ThemeLoader) -> float:
	return clampf(cs * theme.wall_shadow_depth_ratio, 4.0, 14.0)


static func _stone_length(cs: float, a: int, b: int, horizontal: bool) -> float:
	var base := clampf(cs * 0.42, 24.0, 74.0)
	var spread := clampf(cs * 0.18, 8.0, 32.0)
	var r := _hash01(a + (13 if horizontal else 47), b + (101 if horizontal else 29))
	return base + (r - 0.5) * spread


static func _hash01(a: int, b: int) -> float:
	var h := int((a * 374761393) ^ (b * 668265263) ^ 0x9e3779b9)
	h = int((h ^ (h >> 13)) * 1274126177)
	h = h ^ (h >> 16)
	return float(h & 0x7fffffff) / 2147483647.0


static func _wall_vertex_masks(maze: MazeData) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var width := maze.grid_size.x
	var height := maze.grid_size.y

	for x in range(width + 1):
		for y in range(height + 1):
			var west := x > 0 and _has_horizontal_wall(maze, x - 1, y)
			var east := x < width and _has_horizontal_wall(maze, x, y)
			var north := y > 0 and _has_vertical_wall(maze, x, y - 1)
			var south := y < height and _has_vertical_wall(maze, x, y)
			var mask := 0
			if north:
				mask |= 1
			if east:
				mask |= 2
			if south:
				mask |= 4
			if west:
				mask |= 8
			if mask == 0:
				continue
			result.append({"coord": Vector2i(x, y), "mask": mask})

	return result


static func _is_exposed_horizontal_end(maze: MazeData, vertex_x: int, vertex_y: int) -> bool:
	var vertical_from_north := vertex_y > 0 and _has_vertical_wall(maze, vertex_x, vertex_y - 1)
	var vertical_to_south := vertex_y < maze.grid_size.y and _has_vertical_wall(maze, vertex_x, vertex_y)
	return not vertical_from_north and not vertical_to_south


static func _has_horizontal_wall(maze: MazeData, x: int, y: int) -> bool:
	if x < 0 or x >= maze.grid_size.x or y < 0 or y > maze.grid_size.y:
		return false
	if y < maze.grid_size.y:
		var north_cell := maze.get_cell(Vector2i(x, y))
		return north_cell != null and north_cell.wall_north
	var south_cell := maze.get_cell(Vector2i(x, y - 1))
	return south_cell != null and south_cell.wall_south


static func _has_vertical_wall(maze: MazeData, x: int, y: int) -> bool:
	if y < 0 or y >= maze.grid_size.y or x < 0 or x > maze.grid_size.x:
		return false
	if x < maze.grid_size.x:
		var west_cell := maze.get_cell(Vector2i(x, y))
		return west_cell != null and west_cell.wall_west
	var east_cell := maze.get_cell(Vector2i(x - 1, y))
	return east_cell != null and east_cell.wall_east
