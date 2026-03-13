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

func _ready() -> void:
	pass


## Configure the collectible's size and visuals based on the maze's cell size.
func setup(cs: float) -> void:
	# Common setup for both labels to centre them over the cell
	for l in [bg_label, text_label]:
		l.size = Vector2(cs, cs)
		# Start at exactly -size/2 to centre on (0,0) in the Node2D local space
		l.position = -l.size / 2.0
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER

	# --- Background Shape ---
	bg_label.text = "⬤" # Large black circle unicode character
	# Make the circle fill about 60% of the cell
	bg_label.add_theme_font_size_override("font_size", int(cs * 0.6))
	# Pale yellow colour for the background
	bg_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
	# Slight drop shadow for the circle itself
	bg_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.2))
	bg_label.add_theme_constant_override("shadow_offset_x", 2)
	bg_label.add_theme_constant_override("shadow_offset_y", 2)
	
	# Nudge the background circle down very slightly (+1%) to visually center it in the cell
	bg_label.position.y += cs * 0.01

	# --- Foreground Text (Number/Letter) ---
	text_label.text = value_str
	
	# Dynamically size the text so 2 digits fit perfectly inside the circle
	var text_scale := 0.40 if value_str.length() == 1 else 0.30
	text_label.add_theme_font_size_override("font_size", int(cs * text_scale))
	
	# Very dark slate/black colour so it stands out against the pale yellow
	text_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.15))
	
	# Stronger white outline text to guarantee readability
	text_label.add_theme_color_override("font_outline_color", Color.WHITE)
	text_label.add_theme_constant_override("outline_size", 4)
	
	# Nudge the text visually to center it in the circle shape.
	# Standard fonts usually sit high, but we over-corrected. 
	# Trying a more subtle +6% nudge down.
	text_label.position.y += cs * 0.06


## Called when the player steps on this collectible.
func collect() -> void:
	# Pop animation and fade out
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.5, 1.5), 0.15).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_callback(self.queue_free)
