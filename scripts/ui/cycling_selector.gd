## cycling_selector.gd
## ---------------------------------------------------------------------------
## Shared factory for the "cycling selector" UI pattern used across the app.
##
## The pattern:  [Label]  < [Button] >  [Extras]
##   - Arrows (< >) appear only when the button is focused (alpha 0→1)
##   - D-pad Left/Right cycles the value via gui_input (prevents focus shift)
##   - OK/press advances forward (+1)
##
## Usage:
##   var row := CyclingSelector.create_row("setting_lang")
##   var btn: Button = row.get_meta("button")
##   CyclingSelector.setup_cycling(btn, _cycle_lang)
##   CyclingSelector.setup_arrow_visibility(btn, row.get_meta("left"), row.get_meta("right"))
## ---------------------------------------------------------------------------
class_name CyclingSelector
extends RefCounted


## Create a complete selector row: [Title Label] [gap] [< arrow] [Button] [> arrow] [Extras HBox].
##
## Returns an HBoxContainer with the following metadata set:
##   - "title"  → Label (the title)
##   - "left"   → Label (< arrow)
##   - "button" → Button (the cycling value button)
##   - "right"  → Label (> arrow)
##   - "extras" → HBoxContainer (for character preview, etc.)
static func create_row(label_key: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size = Vector2(0, 68)

	var label := Label.new()
	label.text = TranslationServer.translate(label_key)
	label.custom_minimum_size = Vector2(245, 0)
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", UIColors.TEXT_SUBTITLE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(12, 0)
	row.add_child(gap)

	var left := create_arrow_label()
	row.add_child(left)

	var button := Button.new()
	button.custom_minimum_size = Vector2(430, 64)
	button.add_theme_font_size_override("font_size", 30)
	UIHelpers.apply_style_to_button(button, UIColors.YELLOW)
	row.add_child(button)

	var right := create_arrow_label()
	right.text = ">"
	row.add_child(right)

	# Extras slot for character preview etc.
	var extras := HBoxContainer.new()
	extras.custom_minimum_size = Vector2(80, 0)
	extras.add_theme_constant_override("separation", 8)
	extras.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_child(extras)

	row.set_meta("title", label)
	row.set_meta("left", left)
	row.set_meta("button", button)
	row.set_meta("right", right)
	row.set_meta("extras", extras)
	return row


## Create a compact selector row that returns a Dictionary for legacy compatibility.
##
## Returns: { "row": HBoxContainer, "left": Label, "button": Button, "right": Label }
## Used by mode_selection.gd and host_setup.gd which expect a Dictionary instead of meta.
static func create_row_dict(label_key: String) -> Dictionary:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size = Vector2(0, 68)

	var label := Label.new()
	label.custom_minimum_size = Vector2(245, 0)
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", UIColors.TEXT_SUBTITLE)
	label.text = TranslationServer.translate(label_key)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	var left := create_arrow_label()
	row.add_child(left)

	var button := Button.new()
	button.custom_minimum_size = Vector2(430, 64)
	button.add_theme_font_size_override("font_size", 30)
	UIHelpers.apply_style_to_button(button, UIColors.YELLOW)
	row.add_child(button)

	var right := create_arrow_label()
	right.text = ">"
	row.add_child(right)
	
	# Extras slot for character preview etc.
	var extras := HBoxContainer.new()
	extras.custom_minimum_size = Vector2(80, 0)
	extras.add_theme_constant_override("separation", 8)
	extras.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_child(extras)
	
	return {"row": row, "left": left, "button": button, "right": right, "extras": extras}


## Create a single arrow label (< or >).
static func create_arrow_label() -> Label:
	var label := Label.new()
	label.custom_minimum_size = Vector2(36, 0)
	label.add_theme_color_override("font_color", UIColors.YELLOW)
	label.add_theme_font_size_override("font_size", 38)
	label.text = "<"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


## Wire a Button's gui_input so D-pad Left/Right cycles the value.
## [cycle_func] receives -1 (left) or +1 (right).
static func setup_cycling(btn: Button, cycle_func: Callable) -> void:
	if btn == null:
		return
	btn.gui_input.connect(func(event: InputEvent):
		if event.is_pressed():
			if event.is_action("ui_left"):
				cycle_func.call(-1)
				btn.get_viewport().set_input_as_handled()
			elif event.is_action("ui_right"):
				cycle_func.call(1)
				btn.get_viewport().set_input_as_handled()
	)


## Wire a Button's gui_input so D-pad Left/Right both call toggle_func.
## Used for On/Off toggles where direction doesn't matter.
static func setup_toggle_cycling(btn: Button, toggle_func: Callable) -> void:
	if btn == null:
		return
	btn.gui_input.connect(func(event: InputEvent):
		if event.is_pressed() and (event.is_action("ui_left") or event.is_action("ui_right")):
			toggle_func.call()
			btn.get_viewport().set_input_as_handled()
	)


## Make arrows visible only when the button is focused.
static func setup_arrow_visibility(btn: Button, left: Label, right: Label) -> void:
	if btn == null or left == null or right == null:
		return
	left.modulate.a = 0.0
	right.modulate.a = 0.0
	btn.focus_entered.connect(func():
		left.modulate.a = 1.0
		right.modulate.a = 1.0
	)
	btn.focus_exited.connect(func():
		left.modulate.a = 0.0
		right.modulate.a = 0.0
	)
