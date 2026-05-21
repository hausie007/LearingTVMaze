# SlotStyler
# Static helper utility to apply uniform styleboxes (empty/filled/focused) to slot frames.
class_name SlotStyler
extends RefCounted

## Applies a filled slot style to a given Control (Button or PanelContainer).
static func apply_filled_style(control: Control, border_color: Color, focus_color: Color = Color.TRANSPARENT) -> void:
	var bg_color := Color(UIColors.BG_DARK.r, UIColors.BG_DARK.g, UIColors.BG_DARK.b, 0.9)
	var style := UIHelpers.create_rounded_stylebox(bg_color, border_color, 12, 2)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10

	if control is Button:
		control.add_theme_stylebox_override("normal", style)
		control.add_theme_stylebox_override("hover", style)
		control.add_theme_stylebox_override("pressed", style)
		control.add_theme_stylebox_override("disabled", style)

		if focus_color != Color.TRANSPARENT:
			var focus_style := UIHelpers.create_rounded_stylebox(bg_color, focus_color, 12, 6)
			focus_style.content_margin_left = 10
			focus_style.content_margin_right = 10
			focus_style.content_margin_top = 10
			focus_style.content_margin_bottom = 10
			control.add_theme_stylebox_override("focus", focus_style)
	elif control is PanelContainer:
		control.add_theme_stylebox_override("panel", style)

## Applies an empty slot style to a given Control (Button or PanelContainer).
static func apply_empty_style(control: Control, border_color: Color, bg_color: Color) -> void:
	var style := UIHelpers.create_rounded_stylebox(bg_color, border_color, 12, 2)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.draw_center = true

	if control is Button:
		control.add_theme_stylebox_override("normal", style)
		control.add_theme_stylebox_override("hover", style)
		control.add_theme_stylebox_override("pressed", style)
		control.add_theme_stylebox_override("disabled", style)
	elif control is PanelContainer:
		control.add_theme_stylebox_override("panel", style)
