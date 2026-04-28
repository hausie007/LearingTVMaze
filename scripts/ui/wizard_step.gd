## WizardStep — A single collapsible step in the game setup wizard.
##
## Each step manages:
## - A card row (HBoxContainer with ModeCard children)
## - An optional divider between card groups (e.g., SP | MP)
## - A collapsed summary row (chevron + text, focusable, clickable to re-expand)
## - A settings area (VBoxContainer for selector rows placed below cards)
## - State transitions: HIDDEN → ACTIVE ↔ COLLAPSED (with polished animations)
##
## Usage:
##   var step := WizardStep.new()
##   parent.add_child(step)
##   step.setup_cards([{id="numbers", icon="123", title="Numbers", subtitle="Count from 1", group="sp"}])
##   step.activate()       → shows card row
##   step.collapse("Collecting: Numbers")   → hides cards, shows summary row

class_name WizardStep
extends VBoxContainer

signal card_confirmed(card_id: String)
signal card_focus_changed(card_id: String)
signal expand_requested()

enum State { HIDDEN, ACTIVE, COLLAPSED }

const ModeCardScene := preload("res://scenes/ui/mode_card.tscn")
const FADE_DURATION := 0.20
const COLLAPSE_DURATION := 0.30

var _state: int = State.HIDDEN   # using int to avoid GDScript enum typing issues
var _card_row: HBoxContainer = null
var _card_data: Array[Dictionary] = []
var _cards: Dictionary = {}  # card_id → Button
var _selected_card_id: String = ""
var _divider: Control = null  # optional group divider

var _collapse_row: Button = null
var _chevron_label: Label = null
var _summary_label: Label = null

var _settings_area: VBoxContainer = null
var _active_container: VBoxContainer = null  # holds card_row + settings_area

var _title_label: Label = null
var _title_text: String = ""

var _fade_tween: Tween = null

# ── Public API ────────────────────────────────────────────────────────────

func _init() -> void:
	name = "WizardStep"
	add_theme_constant_override("separation", 0)

func _ready() -> void:
	_build_collapse_row()
	_build_active_container()
	# Rebuild cards if setup_cards was called before _ready
	if not _card_data.is_empty():
		_rebuild_cards()
	_apply_state(false)

## Configure the cards this step will show.
## Each entry: { "id": String, "icon": String, "title": String, "subtitle": String, "group": String (optional) }
func setup_cards(cards_data: Array[Dictionary]) -> void:
	_card_data = cards_data
	if _card_row != null:
		_rebuild_cards()
	# If _card_row is null, _rebuild_cards will be called from _ready


## Set which card appears visually selected.
func select_card(card_id: String) -> void:
	_selected_card_id = card_id
	_update_card_selection()

## Set the step title text
func set_step_title(text: String) -> void:
	_title_text = text
	if _title_label != null:
		_title_label.text = text

## Update the title font size based on responsive layout
func set_title_font_size(size: int) -> void:
	if _title_label != null:
		_title_label.add_theme_font_size_override("font_size", size)

## Transition to ACTIVE state (show cards + settings, hide collapse row).
func activate(animated: bool = true) -> void:
	_state = State.ACTIVE
	_apply_state(animated)

## Transition to COLLAPSED state (show summary row, hide cards + settings).
func collapse(summary_text: String, animated: bool = true) -> void:
	if _summary_label != null:
		_summary_label.text = summary_text
	_state = State.COLLAPSED
	_apply_state(animated)

## Transition to HIDDEN state (everything invisible).
func hide_step(animated: bool = true) -> void:
	_state = State.HIDDEN
	_apply_state(animated)

## Get the collapse row Button (for navigation wiring).
func get_collapse_row() -> Button:
	return _collapse_row

## Get focusable card buttons in order.
func get_card_buttons() -> Array[Button]:
	var result: Array[Button] = []
	for data in _card_data:
		var card := _cards.get(String(data.get("id", "")), null) as Button
		if card != null and card.visible and card.focus_mode != Control.FOCUS_NONE:
			result.append(card)
	return result

## Get the settings VBoxContainer to add setting rows to.
func get_settings_area() -> VBoxContainer:
	return _settings_area

## Get the card row for sizing.
func get_card_row() -> HBoxContainer:
	return _card_row

## Get current state.
func get_state() -> int:
	return _state

## Get the currently focused card's ID, or empty string.
func get_focused_card_id() -> String:
	for data in _card_data:
		var id := String(data.get("id", ""))
		var card := _cards.get(id, null) as Button
		if card != null and card.has_focus():
			return id
	return ""

## Get the currently selected card Button, or null.
func get_selected_card_button() -> Button:
	var btn := _cards.get(_selected_card_id, null) as Button
	if btn != null and btn.visible and btn.focus_mode != Control.FOCUS_NONE:
		return btn
	return null

## Focus the selected card (or the first card).
func focus_selected_card() -> void:
	var btn := _cards.get(_selected_card_id, null) as Button
	if btn == null or not btn.visible or btn.focus_mode == Control.FOCUS_NONE:
		var buttons := get_card_buttons()
		btn = buttons[0] if not buttons.is_empty() else null
	if btn != null:
		btn.call_deferred("grab_focus")

## Set card row gap.
func set_card_gap(gap: int) -> void:
	if _card_row != null:
		_card_row.add_theme_constant_override("separation", gap)

# ── Build UI ──────────────────────────────────────────────────────────────

func _build_collapse_row() -> void:
	_collapse_row = Button.new()
	_collapse_row.name = "CollapseRow"
	_collapse_row.flat = true
	_collapse_row.custom_minimum_size = Vector2(0, 52)
	_collapse_row.focus_mode = Control.FOCUS_ALL
	_collapse_row.mouse_filter = Control.MOUSE_FILTER_STOP

	# Style: subtle dark background, lighter on focus
	var normal_style := UIHelpers.create_rounded_stylebox(
		Color(UIColors.BG_DARK.r, UIColors.BG_DARK.g, UIColors.BG_DARK.b, 0.6),
		Color(1, 1, 1, 0.08), 10, 1
	)
	normal_style.content_margin_left = 24
	normal_style.content_margin_right = 24
	var focus_style := UIHelpers.create_rounded_stylebox(
		Color(UIColors.BG_DARK.r, UIColors.BG_DARK.g, UIColors.BG_DARK.b, 0.85),
		UIColors.YELLOW, 10, 2
	)
	focus_style.content_margin_left = 24
	focus_style.content_margin_right = 24
	_collapse_row.add_theme_stylebox_override("normal", normal_style)
	_collapse_row.add_theme_stylebox_override("focus", focus_style)
	_collapse_row.add_theme_stylebox_override("hover", focus_style)
	_collapse_row.add_theme_stylebox_override("pressed", focus_style)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	hbox.add_theme_constant_override("separation", 12)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_collapse_row.add_child(hbox)

	_chevron_label = Label.new()
	_chevron_label.text = "▾"
	_chevron_label.add_theme_font_size_override("font_size", 28)
	_chevron_label.add_theme_color_override("font_color", UIColors.YELLOW)
	_chevron_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chevron_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_chevron_label.custom_minimum_size = Vector2(30, 0)
	hbox.add_child(_chevron_label)

	_summary_label = Label.new()
	_summary_label.name = "SummaryText"
	_summary_label.add_theme_font_size_override("font_size", 30)
	_summary_label.add_theme_color_override("font_color", UIColors.TEXT_SECONDARY)
	_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_summary_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_summary_label.text = ""
	hbox.add_child(_summary_label)

	_collapse_row.pressed.connect(_on_collapse_row_pressed)
	add_child(_collapse_row)

func _build_active_container() -> void:
	_active_container = VBoxContainer.new()
	_active_container.name = "ActiveContent"
	_active_container.add_theme_constant_override("separation", 4)
	add_child(_active_container)

	# Top spacer — room for card scale-up without overlapping breadcrumbs
	var top_pad := Control.new()
	top_pad.name = "CardTopPad"
	top_pad.custom_minimum_size = Vector2(0, 16)
	_active_container.add_child(top_pad)

	_title_label = Label.new()
	_title_label.name = "StepTitle"
	_title_label.add_theme_font_size_override("font_size", 36)
	_title_label.add_theme_color_override("font_color", UIColors.YELLOW)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.text = _title_text
	_active_container.add_child(_title_label)
	
	var title_pad := Control.new()
	title_pad.name = "TitleBottomPad"
	title_pad.custom_minimum_size = Vector2(0, 28)
	_active_container.add_child(title_pad)

	_card_row = HBoxContainer.new()
	_card_row.name = "CardRow"
	_card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_card_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_row.add_theme_constant_override("separation", 48)
	_active_container.add_child(_card_row)

	# Bottom spacer — breathing room between cards and settings
	var bottom_pad := Control.new()
	bottom_pad.name = "CardBottomPad"
	bottom_pad.custom_minimum_size = Vector2(0, 40)
	_active_container.add_child(bottom_pad)

	_settings_area = VBoxContainer.new()
	_settings_area.name = "StepSettings"
	_settings_area.alignment = BoxContainer.ALIGNMENT_CENTER
	_settings_area.add_theme_constant_override("separation", 8)
	_active_container.add_child(_settings_area)

func _rebuild_cards() -> void:
	# Clear existing cards + divider
	for child in _card_row.get_children():
		_card_row.remove_child(child)
		child.queue_free()
	_cards.clear()
	_divider = null

	var prev_group := ""
	for data in _card_data:
		var group := String(data.get("group", ""))

		# Insert divider between groups
		if not prev_group.is_empty() and not group.is_empty() and group != prev_group:
			_divider = _create_group_divider()
			_card_row.add_child(_divider)

		var card := ModeCardScene.instantiate() as Button
		var id := String(data.get("id", ""))
		card.custom_minimum_size = Vector2(300, 260)
		card.pivot_offset = Vector2(150, 130)
		card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card.call("configure_compact", 52, 30, 19)
		card.call(
			"setup",
			String(data.get("icon", "?")),
			String(data.get("title", "")),
			String(data.get("subtitle", ""))
		)
		card.pressed.connect(_on_card_pressed.bind(id))
		card.focus_entered.connect(_on_card_focus_entered.bind(id))
		_card_row.add_child(card)
		_cards[id] = card

		prev_group = group

	_update_card_selection()

func _create_group_divider() -> Control:
	var container := Control.new()
	container.name = "GroupDivider"
	container.custom_minimum_size = Vector2(32, 0)
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.15)
	line.custom_minimum_size = Vector2(2, 0)
	line.size_flags_vertical = Control.SIZE_EXPAND_FILL
	line.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	line.anchor_top = 0.15
	line.anchor_bottom = 0.85
	line.anchor_left = 0.5
	line.anchor_right = 0.5
	line.offset_left = -1
	line.offset_right = 1
	container.add_child(line)
	return container

func _update_card_selection() -> void:
	for data in _card_data:
		var id := String(data.get("id", ""))
		var card := _cards.get(id, null) as Button
		if card != null:
			card.call("set_selected", id == _selected_card_id, false)

# ── State Transitions ─────────────────────────────────────────────────────

func _apply_state(animated: bool) -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
		_fade_tween = null

	match _state:
		State.HIDDEN:
			_set_visible_immediate(_collapse_row, false)
			_set_visible_immediate(_active_container, false)
			custom_minimum_size.y = 0

		State.ACTIVE:
			if animated:
				_animate_expand()
			else:
				_set_visible_immediate(_collapse_row, false)
				_set_visible_immediate(_active_container, true)
				custom_minimum_size.y = 0
			_collapse_row.focus_mode = Control.FOCUS_NONE

		State.COLLAPSED:
			if animated:
				_animate_collapse()
			else:
				_set_visible_immediate(_active_container, false)
				_set_visible_immediate(_collapse_row, true)
				custom_minimum_size.y = 0
			_collapse_row.focus_mode = Control.FOCUS_ALL

func _set_visible_immediate(node: Control, vis: bool) -> void:
	if node == null:
		return
	node.visible = vis
	node.modulate.a = 1.0 if vis else 0.0

## Collapse: instant cut. Hide cards immediately, show breadcrumb immediately.
func _animate_collapse() -> void:
	# Instantly hide active content
	if _active_container != null:
		_active_container.visible = false
		_active_container.modulate.a = 0.0
		_active_container.scale = Vector2.ONE
	# Instantly show collapse row
	if _collapse_row != null:
		_collapse_row.visible = true
		_collapse_row.modulate.a = 1.0
	custom_minimum_size.y = 0

## Expand: instant show + quick fade-in with subtle scale-up.
func _animate_expand() -> void:
	# Instantly hide collapse row
	if _collapse_row != null:
		_collapse_row.visible = false
		_collapse_row.modulate.a = 0.0
	# Show active content starting invisible and slightly small
	if _active_container != null:
		_active_container.visible = true
		_active_container.modulate.a = 0.0
		_active_container.scale = Vector2(0.97, 0.97)
	custom_minimum_size.y = 0

	# Quick polish fade-in
	_fade_tween = create_tween()
	_fade_tween.set_parallel(true)
	_fade_tween.tween_property(_active_container, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_fade_tween.tween_property(_active_container, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

# ── Callbacks ─────────────────────────────────────────────────────────────

func _on_card_pressed(card_id: String) -> void:
	_selected_card_id = card_id
	_update_card_selection()
	card_confirmed.emit(card_id)

func _on_card_focus_entered(card_id: String) -> void:
	_selected_card_id = card_id
	_update_card_selection()
	card_focus_changed.emit(card_id)

func _on_collapse_row_pressed() -> void:
	expand_requested.emit()
