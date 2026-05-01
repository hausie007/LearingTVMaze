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

var _animator: FrameAnimator = null
var _accent_tint: Color = Color(0, 0, 0, 0)

## Target highlight state — shows a halo + pulse on the current target collectible.
var _highlight_ring: HighlightHalo = null
var _highlight_tween: Tween = null
var is_current_target: bool = false

func _ready() -> void:
	# Add sprite as child 0 so it's behind everything else
	add_child(sprite)
	move_child(sprite, 0)
	sprite.visible = false
	
	_animator = FrameAnimator.new()
	add_child(_animator)


var _last_cs: float = 120.0
var _last_theme: ThemeLoader = null

const ZOOM_FACTOR: float = 3.5

## Configure the collectible's size and visuals based on theme properties.
func setup(cs: float, theme: ThemeLoader = null) -> void:
	_last_cs = cs
	_last_theme = theme
	
	# Reset scale to 1.0 for the maze (sharp native rendering)
	self.scale = Vector2.ONE
	_apply_visuals(cs)

func set_accent_tint(color: Color) -> void:
	_accent_tint = color
	if _last_cs > 0.0:
		_apply_visuals(_last_cs)

## Internal helper to render the visuals at a specific absolute pixel size.
func _apply_visuals(effective_cs: float) -> void:
	# Default colors
	var bg_color := Color(1.0, 0.95, 0.6)
	var text_color := Color(0.1, 0.1, 0.15)
	var texture: Texture2D = null
	
	if _last_theme:
		bg_color = _last_theme.col_color
		text_color = _last_theme.col_text_color
		texture = _last_theme.col_texture

	if _accent_tint.a > 0.0:
		bg_color = _accent_tint.lerp(Color.WHITE, 0.20)
		text_color = Color(0.08, 0.08, 0.10, 1.0) if bg_color.get_luminance() > 0.58 else Color.WHITE

	# Common setup for both labels
	for l in [bg_label, text_label]:
		l.size = Vector2(effective_cs, effective_cs)
		l.position = -l.size / 2.0
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER

	# --- Background Shape or Image ---
	if texture:
		bg_label.visible = false
		sprite.visible = true
		sprite.texture = texture
		# Use Linear filtering with mipmaps for smoother downscaling in the maze
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		
		var img_size := texture.get_size()
		var target_size := effective_cs * 0.7
		sprite.scale = Vector2(target_size / img_size.x, target_size / img_size.y)
		sprite.position = Vector2.ZERO
		sprite.modulate = _accent_tint.lerp(Color.WHITE, 0.22) if _accent_tint.a > 0.0 else Color.WHITE
		
		if _last_theme and not _last_theme.col_frames.is_empty():
			_animator.start(sprite, _last_theme.col_frames, _last_theme.col_fps)
		else:
			_animator.stop()
	else:
		bg_label.visible = true
		sprite.visible = false
		sprite.modulate = Color.WHITE
		_animator.stop()
		bg_label.text = "⬤"
		bg_label.add_theme_font_size_override("font_size", int(effective_cs * 0.6))
		bg_label.add_theme_color_override("font_color", bg_color)
		bg_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.2))
		
		# Proportional shadow
		var shadow_off: int = maxi(1, int(effective_cs * 0.015))
		bg_label.add_theme_constant_override("shadow_offset_x", shadow_off)
		bg_label.add_theme_constant_override("shadow_offset_y", shadow_off)
		bg_label.position.y += effective_cs * 0.01

	# --- Foreground Text ---
	text_label.text = value_str
	var text_scale := 0.40 if value_str.length() == 1 else 0.30
	text_label.add_theme_font_size_override("font_size", int(effective_cs * text_scale))
	text_label.add_theme_color_override("font_color", text_color)
	text_label.add_theme_color_override("font_outline_color", Color.WHITE if text_color.v < 0.8 else Color.BLACK)
	
	# Proportional outline
	var out_size: int = maxi(1, int(effective_cs * 0.04))
	text_label.add_theme_constant_override("outline_size", out_size)
	text_label.position.y += effective_cs * 0.06


# ── Target Highlight ─────────────────────────────────────────────────────────

## Enable/disable the target highlight effect (halo + pulse).
func set_target_highlight(enabled: bool) -> void:
	is_current_target = enabled
	if enabled:
		_start_highlight()
	else:
		_stop_highlight()


func _start_highlight() -> void:
	# 1. Add halo ring behind the collectible
	if _highlight_ring == null:
		_highlight_ring = HighlightHalo.new()
		_highlight_ring.name = "TargetHighlight"
		add_child(_highlight_ring)
		move_child(_highlight_ring, 0)  # Behind everything
	_highlight_ring.radius = _last_cs * 0.45
	# Use player accent tint for race mode, otherwise theme highlight color.
	if _accent_tint.a > 0.0:
		_highlight_ring.halo_color = _accent_tint
	else:
		_highlight_ring.halo_color = _last_theme.highlight_color if _last_theme else UIColors.HIGHLIGHT_HALO
	_highlight_ring.visible = true
	_highlight_ring.queue_redraw()

	# 2. Start pronounced pulse animation
	if _highlight_tween and _highlight_tween.is_valid():
		_highlight_tween.kill()
	self.scale = Vector2.ONE
	_highlight_tween = create_tween().set_loops()
	_highlight_tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.45) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_highlight_tween.tween_property(self, "scale", Vector2.ONE, 0.45) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_highlight() -> void:
	if _highlight_tween and _highlight_tween.is_valid():
		_highlight_tween.kill()
		_highlight_tween = null
	self.scale = Vector2.ONE
	if _highlight_ring != null:
		_highlight_ring.visible = false

## Called when the player steps on this collectible.
func collect() -> void:
	_stop_highlight()
	# 1. Hot-swap to High-Res rendering immediately
	# We render at the LARGE size, then immediately scale node down by the same factor
	# so it *looks* identical to the player initially but is ready to zoom sharply.
	_apply_visuals(_last_cs * ZOOM_FACTOR)
	self.scale = Vector2(1.0/ZOOM_FACTOR, 1.0/ZOOM_FACTOR)
	
	var viewport_center := get_viewport_rect().size / 2.0
	z_index = 200 # Way on top
	
	var tw := create_tween()
	# Step 1: Zoom to center (fast)
	# Zoom means scale goes from (1/ZOOM_FACTOR) -> 1.0 (sharp native size of large render)
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
