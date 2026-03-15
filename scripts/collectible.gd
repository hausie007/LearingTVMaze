## collectible.gd
## ---------------------------------------------------------------------------
## A collectible item placed in the maze (number or letter).
## ---------------------------------------------------------------------------
class_name Collectible
extends Node2D

var grid_pos: Vector2i = Vector2i.ZERO
var value_str: String = ""

## Index in the word for order validation in Words mode.
## -1 means no order enforcement (Numbers / Letters modes).
var collect_index: int = -1

@onready var bg_label: Label = $BackgroundLabel
@onready var text_label: Label = $TextLabel
@onready var sprite: Sprite2D = Sprite2D.new()

func _ready() -> void:
	# Add sprite as child 0 so it's behind everything else
	add_child(sprite)
	move_child(sprite, 0)
	sprite.visible = false
	
	# Explicitly ensure Labels are above the sprite
	# (Control nodes in Node2D usually draw in tree order)


const ZOOM_FACTOR: float = 3.5

## Configure the collectible's size and visuals based on theme properties.
## We render at 'high res' (target zoom size) and scale down for the maze to keep it sharp.
func setup(cs: float, theme: ThemeLoader = null) -> void:
	# Calculate the 'enlarged' size we want for the center of the screen
	var large_cs := cs * ZOOM_FACTOR
	
	# Default colors
	var bg_color := Color(1.0, 0.95, 0.6)
	var text_color := Color(0.1, 0.1, 0.15)
	var texture: Texture2D = null
	
	if theme:
		bg_color = theme.col_color
		text_color = theme.col_text_color
		texture = theme.col_texture

	# Common setup for both labels - use large_cs
	for l in [bg_label, text_label]:
		l.size = Vector2(large_cs, large_cs)
		l.position = -l.size / 2.0
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER

	# --- Background Shape or Image ---
	if texture:
		bg_label.visible = false
		sprite.visible = true
		sprite.texture = texture
		# Scale image to fit well inside 'large' corridor
		var img_size := texture.get_size()
		var target_size := large_cs * 0.7
		sprite.scale = Vector2(target_size / img_size.x, target_size / img_size.y)
		sprite.position = Vector2.ZERO # Centered
	else:
		bg_label.visible = true
		sprite.visible = false
		bg_label.text = "⬤"
		bg_label.add_theme_font_size_override("font_size", int(large_cs * 0.6))
		bg_label.add_theme_color_override("font_color", bg_color)
		bg_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.2))
		bg_label.add_theme_constant_override("shadow_offset_x", int(ZOOM_FACTOR))
		bg_label.add_theme_constant_override("shadow_offset_y", int(ZOOM_FACTOR))
		bg_label.position.y += large_cs * 0.01

	# --- Foreground Text ---
	text_label.text = value_str
	var text_scale := 0.40 if value_str.length() == 1 else 0.30
	text_label.add_theme_font_size_override("font_size", int(large_cs * text_scale))
	text_label.add_theme_color_override("font_color", text_color)
	text_label.add_theme_color_override("font_outline_color", Color.WHITE if text_color.v < 0.8 else Color.BLACK)
	text_label.add_theme_constant_override("outline_size", int(4 * ZOOM_FACTOR))
	text_label.position.y += large_cs * 0.06
	
	# --- Scale Down for Maze ---
	# The node itself is now centered at 0,0 and drawn large. 
	# We scale it down so it fits the corridor.
	self.scale = Vector2(1.0 / ZOOM_FACTOR, 1.0 / ZOOM_FACTOR)


## Called when the player steps on this collectible.
func collect() -> void:
	# 1. Prepare for animation
	var viewport_center := get_viewport_rect().size / 2.0
	
	z_index = 200 # Way on top
	
	var tw := create_tween()
	# Step 1: Zoom to center (fast) 
	# We tween scale back to 1.0 (which is the high-res size we setup)
	tw.set_parallel(true)
	tw.tween_property(self, "global_position", viewport_center, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Step 2: Hold (wait)
	tw.set_parallel(false)
	tw.tween_interval(0.5)
	
	# Step 3: Fade out
	tw.tween_property(self, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# Cleanup
	tw.tween_callback(self.queue_free)
