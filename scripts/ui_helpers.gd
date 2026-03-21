## ui_helpers.gd
## ---------------------------------------------------------------------------
## Static utility class providing shared UI styling functions.
##
## Eliminates copy-pasted StyleBoxFlat button creation across game_manager.gd,
## main_menu.gd, and settings_menu.gd.
##
## Usage:
##   var btn := UIHelpers.create_styled_button("Play", 300, 80)
##   var panel := UIHelpers.create_rounded_stylebox(Color.BLACK, Color.WHITE, 12)
## ---------------------------------------------------------------------------
class_name UIHelpers
extends RefCounted


## Create a fully styled Button matching the game's brand design.
##
## Parameters:
##   btn_text    — The button label text.
##   w, h        — Minimum size in pixels.
##   focus_color — Background color when focused/hovered (default: Sky blue).
##   font_size   — Font size override (default: 42).
static func create_styled_button(
	btn_text: String,
	w: int,
	h: int,
	focus_color: Color = Color("#1188FF"),
	font_size: int = 42,
) -> Button:
	var btn := Button.new()
	btn.text = btn_text
	btn.custom_minimum_size = Vector2(w, h)
	btn.add_theme_font_size_override("font_size", font_size)

	# Normal state
	var normal := create_rounded_stylebox(
		Color(0.15, 0.17, 0.22),
		Color(1, 1, 1, 0.1),
		12, 2
	)
	btn.add_theme_stylebox_override("normal", normal)

	# Focus / Hover / Pressed
	var focus := create_rounded_stylebox(focus_color, Color.WHITE, 12, 4)

	var hover: StyleBoxFlat = focus.duplicate()
	hover.bg_color = focus_color.lightened(0.2)

	btn.add_theme_stylebox_override("focus", focus)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", focus)

	# Text colors
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_focus_color", Color("#112244"))
	btn.add_theme_color_override("font_hover_color", Color("#112244"))
	btn.add_theme_color_override("font_pressed_color", Color("#112244"))

	return btn


## Create a StyleBoxFlat with uniform corner radius and border width.
static func create_rounded_stylebox(
	bg_color: Color,
	border_color: Color = Color.TRANSPARENT,
	corner_radius: int = 12,
	border_width: int = 0,
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.border_color = border_color
	return style
