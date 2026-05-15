class_name PaintedMazeLayer
extends Node2D

var maze: MazeData = null
var maze_theme: ThemeLoader = null
var grid_offset: Vector2 = Vector2.ZERO
var maze_size_px: Vector2 = Vector2.ZERO
var cell_size: float = 0.0


func _draw() -> void:
	MazeWallPainter.draw_maze(self, maze, grid_offset, maze_size_px, cell_size, maze_theme)
