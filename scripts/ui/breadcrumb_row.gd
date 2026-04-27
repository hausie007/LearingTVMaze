## breadcrumb_row.gd
## ---------------------------------------------------------------------------
## Static factory for the read-only breadcrumb row used in multiplayer screens.
##
## A breadcrumb is a non-focusable Button styled as a subtle dark bar with
## a chevron (▾) and summary text. Used by host_lobby.gd and join_flow.gd
## to show collapsed step summaries.
##
## Metadata stored on the returned Button:
##   - "summary" → Label (the summary text)
##   - "chevron" → Label (the ▾ chevron)
##
## Usage:
##   var bread := BreadcrumbRow.create()
##   BreadcrumbRow.set_text(bread, "Follow Trail • Thiefs • Easy")
## ---------------------------------------------------------------------------
class_name BreadcrumbRow
extends RefCounted


## Create a new breadcrumb row Button.
## By default: non-focusable, non-interactive (read-only display).
static func create() -> Button:
	var btn := Button.new()
	btn.flat = true
	btn.custom_minimum_size = Vector2(0, 48)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var normal_style := UIHelpers.create_rounded_stylebox(
		Color(UIColors.BG_DARK.r, UIColors.BG_DARK.g, UIColors.BG_DARK.b, 0.6),
		Color(1, 1, 1, 0.08), 10, 1
	)
	normal_style.content_margin_left = 24
	normal_style.content_margin_right = 24
	for state_name in ["normal", "focus", "hover", "pressed"]:
		btn.add_theme_stylebox_override(state_name, normal_style)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	hbox.add_theme_constant_override("separation", 12)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.add_child(hbox)

	var chevron := Label.new()
	chevron.text = "▾"
	chevron.add_theme_font_size_override("font_size", 26)
	chevron.add_theme_color_override("font_color", UIColors.YELLOW)
	chevron.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chevron.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chevron.custom_minimum_size = Vector2(28, 0)
	hbox.add_child(chevron)

	var summary := Label.new()
	summary.name = "SummaryText"
	summary.add_theme_font_size_override("font_size", 28)
	summary.add_theme_color_override("font_color", UIColors.TEXT_SECONDARY)
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(summary)

	btn.set_meta("summary", summary)
	btn.set_meta("chevron", chevron)
	return btn


## Set the summary text on a breadcrumb row.
static func set_text(breadcrumb: Button, text: String) -> void:
	if breadcrumb == null:
		return
	var summary := breadcrumb.get_meta("summary") as Label
	if summary != null:
		summary.text = text


## Set font sizes on a breadcrumb row (for responsive layout).
static func set_font_size(breadcrumb: Button, summary_size: int, chevron_size: int = -1) -> void:
	if breadcrumb == null:
		return
	var summary := breadcrumb.get_meta("summary") as Label
	if summary != null:
		summary.add_theme_font_size_override("font_size", summary_size)
	if chevron_size > 0:
		var chevron := breadcrumb.get_meta("chevron") as Label
		if chevron != null:
			chevron.add_theme_font_size_override("font_size", chevron_size)
