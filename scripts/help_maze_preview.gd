extends Control

## help_maze_preview.gd
## ---------------------------------------------------------------------------
## Draws a high-fidelity 6x5 maze fragment for the help screen.
## Replicates the exact drawing logic from MazeRenderer.gd:
##   1. Background (Texture or Wall Color Base)
##   2. Visited Cells (Floor Color Rects + Connectors)
##   3. Icons (Start and Finish)
## ---------------------------------------------------------------------------

var theme_loader: ThemeLoader = null
var bg_texture: Texture2D = null

var _maze: MazeData = null

func _ready() -> void:
	_generate_maze()

func _generate_maze() -> void:
	# Use a fixed seed for the help screen to keep it consistent
	seed(12345)
	var gen := MazeGenerator.new()
	_maze = gen.generate_custom(Vector2i(8, 4))
	# Reset seed to random for the rest of the game logic
	randomize()

func _draw() -> void:
	if not theme_loader or not _maze: return
	
	var grid_w := _maze.grid_size.x
	var grid_h := _maze.grid_size.y
	# Use floori/int to ensure strictly integer cells in the preview
	# Size is given by the Container's size property
	var margin_x = size.x * 0.02
	var rect_left = margin_x
	var rect_right = size.x - margin_x
	
	var controls = -1
	if is_instance_valid(Config) and "on_screen_controls" in Config:
		controls = Config.on_screen_controls
		
	if controls == Config.ControlsMode.LEFT_HANDED:
		rect_left = (size.x * 0.25) + margin_x
	elif controls == Config.ControlsMode.RIGHT_HANDED:
		rect_right = (size.x * 0.75) - margin_x
	
	var available_w = maxf(10.0, rect_right - rect_left)
	var available_h = size.y
	
	var max_cs_x: float = float(available_w) / float(grid_w)
	var max_cs_y: float = float(available_h) / float(grid_h)
	
	var cell_size := floori(minf(max_cs_x, max_cs_y))
	var wt := int(maxf(2.0, roundf(6.0 * (float(cell_size) / 120.0)))) 
	
	var offset_x = floori(rect_left + (available_w - (grid_w * cell_size)) / 2.0)
	var offset_y = floori((available_h - (grid_h * cell_size)) / 2.0)
	var offset = Vector2(offset_x, offset_y)
	
	# 1. Background layer
	if bg_texture:
		if theme_loader.bg_tiled:
			draw_texture_rect_region(bg_texture, Rect2(offset, Vector2(grid_w * cell_size, grid_h * cell_size)), Rect2(Vector2.ZERO, Vector2(grid_w * cell_size, grid_h * cell_size)))
		else:
			draw_texture_rect(bg_texture, Rect2(offset, Vector2(grid_w * cell_size, grid_h * cell_size)), false)
	else:
		# Draw solid wall color as base
		draw_rect(Rect2(offset, Vector2(grid_w * cell_size, grid_h * cell_size)), theme_loader.color_wall)
	
	var int_cs := int(cell_size)
	var int_wt := int(wt)
	
	# 2. Visited Cells (Floor/Passages)
	for y in range(grid_h):
		for x in range(grid_w):
			var coord := Vector2i(x, y)
			var pos := Vector2(x * int_cs, y * int_cs)
			var cell = _maze.get_cell(coord)
			
			if cell:
				var cmds := MazeCellDrawer.get_cell_draw_commands(cell, offset + pos, int_cs, int_wt, theme_loader, bg_texture != null, _maze, coord)
				
				for r: MazeCellDrawer.RectCmd in cmds["rects"]:
					draw_rect(Rect2(r.pos, r.size), r.color)
					
				for icon: MazeCellDrawer.IconCmd in cmds["icons"]:
					# Icons are drawn later or immediately
					pass

	# 3. Walls (Line-based Tracing)
	_draw_walls_immediate(int_cs, int_wt, offset)

	# 4. Icons
	for y in range(grid_h):
		for x in range(grid_w):
			var coord := Vector2i(x, y)
			var cell = _maze.get_cell(coord)
			if cell:
				var pos := Vector2(x * int_cs, y * int_cs)
				if cell.is_start and theme_loader.start_texture:
					_draw_icon(offset + pos, int_cs, theme_loader.start_texture)
				elif cell.is_end and theme_loader.end_texture:
					_draw_icon(offset + pos, int_cs, theme_loader.end_texture)

func _draw_walls_immediate(cs: int, wt: int, offset: Vector2) -> void:
	var width  := _maze.grid_size.x
	var height := _maze.grid_size.y
	var color  := theme_loader.color_wall
	
	# Horizontal Tracing
	for y in range(height + 1):
		var x := 0
		while x < width:
			var has_wall := false
			if y < height: has_wall = _maze.get_cell(Vector2i(x,y)).wall_north
			else: has_wall = _maze.get_cell(Vector2i(x, y-1)).wall_south
			
			if has_wall:
				var x_start := x
				while x < width:
					var next_w := false
					if y < height: next_w = _maze.get_cell(Vector2i(x,y)).wall_north
					else: next_w = _maze.get_cell(Vector2i(x, y-1)).wall_south
					if not next_w: break
					x += 1
				draw_line(offset + Vector2(x_start * cs, y * cs), offset + Vector2(x * cs, y * cs), color, wt, true) # true = antialiased
			else:
				x += 1

	# Vertical Tracing
	for x in range(width + 1):
		var y := 0
		while y < height:
			var has_wall := false
			if x < width: has_wall = _maze.get_cell(Vector2i(x,y)).wall_west
			else: has_wall = _maze.get_cell(Vector2i(x-1, y)).wall_east
			
			if has_wall:
				var y_start := y
				while y < height:
					var next_w := false
					if x < width: next_w = _maze.get_cell(Vector2i(x,y)).wall_west
					else: next_w = _maze.get_cell(Vector2i(x-1, y)).wall_east
					if not next_w: break
					y += 1
				draw_line(offset + Vector2(x * cs, y_start * cs), offset + Vector2(x * cs, y * cs), color, wt, true)
			else:
				y += 1

func _draw_icon(pos: Vector2, cs: float, tex: Texture2D) -> void:
	var margin := cs * 0.1
	var target_sz := cs - margin * 2.0
	var tex_sz := Vector2(tex.get_width(), tex.get_height())
	var scale_f := target_sz / float(max(tex_sz.x, tex_sz.y))
	var final_sz := tex_sz * scale_f
	var offset := (Vector2(cs, cs) - final_sz) / 2.0
	draw_texture_rect(tex, Rect2(pos + offset, final_sz), false)
