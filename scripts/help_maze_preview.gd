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
	var cell_size := size.x / float(grid_w)
	# Exact wall thickness scaling from MazeRenderer.gd
	var wt := maxf(1.0, floorf(6.0 * (cell_size / 120.0))) 
	
	# 1. Background layer
	if bg_texture:
		if theme_loader.bg_tiled:
			draw_texture_rect_region(bg_texture, Rect2(Vector2.ZERO, size), Rect2(Vector2.ZERO, size))
		else:
			draw_texture_rect(bg_texture, Rect2(Vector2.ZERO, size), false)
	else:
		# Draw solid wall color as base
		draw_rect(Rect2(Vector2.ZERO, size), theme_loader.color_wall)
	
	# 2. Visited Cells (Paths)
	for y in range(grid_h):
		for x in range(grid_w):
			var coord := Vector2i(x, y)
			var pos := Vector2(x * cell_size, y * cell_size)
			var cell = _maze.get_cell(coord)
			
			if cell and cell.is_visited:
				# ── VISITED ──
				var floor_c = theme_loader.color_floor
				if cell.is_start: floor_c = theme_loader.color_start
				if cell.is_end:   floor_c = theme_loader.color_end
				
				# Only draw floor rects if no bg texture (allows bg to show through corridors)
				if not bg_texture:
					# Central floor
					draw_rect(Rect2(pos + Vector2(wt, wt), Vector2(cell_size - wt*2, cell_size - wt*2)), floor_c)
					# Connectors (allow overlap/bleed just like MazeRenderer)
					var bleed := 1.0
					if not cell.wall_north: draw_rect(Rect2(pos + Vector2(wt, -bleed), Vector2(cell_size - wt*2, wt + bleed*2)), floor_c)
					if not cell.wall_south: draw_rect(Rect2(pos + Vector2(wt, cell_size - wt - bleed), Vector2(cell_size - wt*2, wt + bleed*2)), floor_c)
					if not cell.wall_west:  draw_rect(Rect2(pos + Vector2(-bleed, wt), Vector2(wt + bleed * 2, cell_size - wt*2)), floor_c)
					if not cell.wall_east:  draw_rect(Rect2(pos + Vector2(cell_size - wt - bleed, wt), Vector2(wt + bleed * 2, cell_size - wt*2)), floor_c)
				else:
					# BG Mode: Draw CLOSED wall rectangles as obstacles
					if cell.wall_north: draw_rect(Rect2(pos, Vector2(cell_size, wt)), theme_loader.color_wall)
					if cell.wall_south: draw_rect(Rect2(pos + Vector2(0, cell_size - wt), Vector2(cell_size, wt)), theme_loader.color_wall)
					if cell.wall_west:  draw_rect(Rect2(pos, Vector2(wt, cell_size)), theme_loader.color_wall)
					if cell.wall_east:  draw_rect(Rect2(pos + Vector2(cell_size - wt, 0), Vector2(wt, cell_size)), theme_loader.color_wall)
				
				# ── Borders (Always draw if defined) ──
				if theme_loader.color_wall_border.a > 0.0:
					var bw := maxf(1.0, wt * 0.5)
					if cell.wall_north: draw_rect(Rect2(pos, Vector2(cell_size, bw)), theme_loader.color_wall_border)
					if cell.wall_south: draw_rect(Rect2(pos + Vector2(0, cell_size - bw), Vector2(cell_size, bw)), theme_loader.color_wall_border)
					if cell.wall_west:  draw_rect(Rect2(pos, Vector2(bw, cell_size)), theme_loader.color_wall_border)
					if cell.wall_east:  draw_rect(Rect2(pos + Vector2(cell_size - bw, 0), Vector2(bw, cell_size)), theme_loader.color_wall_border)
					# Fix for vertical borders height
					# Actually draw_rect for borders should match MazeRenderer logic exactly.
					# Let's re-verify MazeRenderer.gd:220
					# 222: if cell.wall_west:  _add_rect(pos + Vector2(0, 0), Vector2(bw, cs), theme.color_wall_border)
				
				# ── Icons ──
				if cell.is_start and theme_loader.start_texture:
					_draw_icon(pos, cell_size, theme_loader.start_texture)
				elif cell.is_end and theme_loader.end_texture:
					_draw_icon(pos, cell_size, theme_loader.end_texture)
			else:
				# ── UNVISITED (Solid Wall) ──
				# This handles the areas not carved by the generator
				draw_rect(Rect2(pos, Vector2(cell_size, cell_size)), theme_loader.color_wall)

func _draw_icon(pos: Vector2, cs: float, tex: Texture2D) -> void:
	var margin := cs * 0.1
	var target_sz := cs - margin * 2.0
	var tex_sz := Vector2(tex.get_width(), tex.get_height())
	var scale_f := target_sz / float(max(tex_sz.x, tex_sz.y))
	var final_sz := tex_sz * scale_f
	var offset := (Vector2(cs, cs) - final_sz) / 2.0
	draw_texture_rect(tex, Rect2(pos + offset, final_sz), false)
