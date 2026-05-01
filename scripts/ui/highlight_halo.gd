## highlight_halo.gd
## ---------------------------------------------------------------------------
## Simple Node2D that draws a filled circle as a glow/halo behind a
## collectible to indicate it is the current target.
##
## Usage:
##   var halo := HighlightHalo.new()
##   halo.radius = 40.0
##   halo.halo_color = UIColors.HIGHLIGHT_HALO
##   add_child(halo)
## ---------------------------------------------------------------------------
class_name HighlightHalo
extends Node2D


## Radius of the halo circle in pixels.
var radius: float = 40.0

## Color of the halo (should include alpha for translucency).
var halo_color: Color = UIColors.HIGHLIGHT_HALO


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, halo_color)
