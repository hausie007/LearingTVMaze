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
			
			if cell:
				var cmds := MazeCellDrawer.get_cell_draw_commands(cell, pos, cell_size, wt, theme_loader, bg_texture != null)
				
				for r: MazeCellDrawer.RectCmd in cmds["rects"]:
					draw_rect(Rect2(r.pos, r.size), r.color)
					
				for icon: MazeCellDrawer.IconCmd in cmds["icons"]:
					_draw_icon(icon.pos, icon.cell_size, icon.texture)

func _draw_icon(pos: Vector2, cs: float, tex: Texture2D) -> void:
	var margin := cs * 0.1
	var target_sz := cs - margin * 2.0
	var tex_sz := Vector2(tex.get_width(), tex.get_height())
	var scale_f := target_sz / float(max(tex_sz.x, tex_sz.y))
	var final_sz := tex_sz * scale_f
	var offset := (Vector2(cs, cs) - final_sz) / 2.0
	draw_texture_rect(tex, Rect2(pos + offset, final_sz), false)
