class_name ModeSelection
extends Control

const MissionCatalog := preload("res://scripts/mission_catalog.gd")

const PICKUP_CARD_ORDER: Array[String] = [
	MissionCatalog.PICKUP_NUMBERS,
	MissionCatalog.PICKUP_WORDS,
	MissionCatalog.PICKUP_LETTERS,
	MissionCatalog.PICKUP_NONE,
]
const PICKUP_CARD_ICONS := {
	"numbers": "123",
	"words": "W",
	"letters": "ABC",
	"none": ">",
}
const PICKUP_CARD_TITLE_KEYS := {
	"numbers": "training_numbers",
	"words": "training_words",
	"letters": "training_letters",
	"none": "pickup_just_maze",
}
const PICKUP_CARD_SUBTITLE_KEYS := {
	"numbers": "pickup_numbers_short",
	"words": "pickup_words_short",
	"letters": "pickup_letters_short",
	"none": "pickup_none_short",
}
const PICKUP_CARD_GAP := 24

@onready var pickup_numbers_card: Button = %NumbersCard
@onready var pickup_words_card: Button = %WordsCard
@onready var pickup_letters_card: Button = %LettersCard
@onready var pickup_none_card: Button = %MazeCard
@onready var center_container: CenterContainer = $CenterContainer
@onready var main_vbox: VBoxContainer = $CenterContainer/MainVBox
@onready var pickup_row: HBoxContainer = %NumbersCard.get_parent()
@onready var old_none_row: HBoxContainer = %MazeCard.get_parent()
@onready var footer_vbox: VBoxContainer = $CenterContainer/MainVBox/FooterVBox
@onready var config_grid: GridContainer = $CenterContainer/MainVBox/FooterVBox/ConfigGrid

@onready var lang_btn: Button = %LangButton
@onready var theme_btn: Button = %ThemeButton
@onready var diff_btn: Button = %DiffButton

@onready var title_lbl: Label = %TitleLabel
@onready var lang_title_lbl: Label = %LangTitleLabel
@onready var theme_title_lbl: Label = %ThemeTitleLabel
@onready var diff_title_lbl: Label = %DiffTitleLabel

@onready var lang_left: Label = %LangLeftArrow
@onready var lang_right: Label = %LangRightArrow
@onready var theme_left: Label = %ThemeLeftArrow
@onready var theme_right: Label = %ThemeRightArrow
@onready var diff_left: Label = %DiffLeftArrow
@onready var diff_right: Label = %DiffRightArrow

@onready var _player_preview: CharacterPreview = %PlayerAnchor
@onready var _chaser_preview: CharacterPreview = %ChaserAnchor

var temp_lang_idx: int = 0
var temp_diff_idx: int = 0
var temp_chaser_speed_idx: int = 1

var _selected_mission: String = MissionCatalog.DEFAULT_MISSION
var _selected_pickup: String = MissionCatalog.DEFAULT_PICKUP
var _chaser_enabled: bool = false
var _theme_preview_loader: ThemeLoader = null

var _goal_label: Label = null
var _trouble_row: HBoxContainer = null
var _trouble_button: Button = null
var _trouble_left: Label = null
var _trouble_right: Label = null
var _chaser_speed_row: HBoxContainer = null
var _chaser_speed_button: Button = null
var _chaser_speed_left: Label = null
var _chaser_speed_right: Label = null
var _start_button: Button = null
var _pickup_cards: Dictionary = {}

func _ready() -> void:
	Input.warp_mouse(Vector2(-1, -1))
	_initialize_temp_state()
	_prepare_layout()
	_build_pickup_cards()
	_build_context_rows()
	_setup_config_controls()
	_localize_ui()
	_update_labels()
	if Config != null and not Config.on_screen_controls_changed.is_connected(_on_controls_changed):
		Config.on_screen_controls_changed.connect(_on_controls_changed)
	_apply_dpad_layout()
	_apply_responsive_layout()
	_configure_dpad_navigation()
	var initial_focus := _selected_pickup_button()
	if initial_focus != null:
		initial_focus.call_deferred("grab_focus")

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_apply_dpad_layout()
		_apply_responsive_layout()
		_configure_dpad_navigation()

func _initialize_temp_state() -> void:
	temp_lang_idx = Config.LANG_CODES.find(Config.learning_language)
	if temp_lang_idx < 0:
		temp_lang_idx = 0
	temp_diff_idx = Config.difficulty

	_selected_mission = Config.selected_mission_id
	if not MissionCatalog.mission_ids().has(_selected_mission):
		_selected_mission = Config.mission_id
	if not MissionCatalog.mission_ids().has(_selected_mission):
		_selected_mission = MissionCatalog.DEFAULT_MISSION

	_selected_pickup = MissionCatalog.default_pickup(_selected_mission)
	var existing_pickup := MissionCatalog.pickup_for_training(Config.training_type)
	if MissionCatalog.allowed_pickups(_selected_mission).has(existing_pickup):
		_selected_pickup = existing_pickup

	_chaser_enabled = MissionCatalog.default_chaser_enabled(_selected_mission, false)
	var speed_idx := MissionCatalog.CHASER_TUNING_LEVELS.find(Config.chaser_level)
	temp_chaser_speed_idx = speed_idx if speed_idx >= 0 else 1
	_normalize_selection()

func _prepare_layout() -> void:
	center_container.anchor_top = 0.0
	center_container.anchor_bottom = 1.0
	center_container.offset_top = 16.0
	center_container.offset_bottom = -16.0
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.custom_minimum_size = Vector2(0, 0)
	main_vbox.add_theme_constant_override("separation", 18)
	footer_vbox.add_theme_constant_override("separation", 10)
	pickup_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pickup_row.add_theme_constant_override("separation", PICKUP_CARD_GAP)

	if pickup_none_card.get_parent() != pickup_row:
		pickup_none_card.get_parent().remove_child(pickup_none_card)
		pickup_row.add_child(pickup_none_card)
	old_none_row.visible = false

	title_lbl.add_theme_font_size_override("font_size", 50)
	_player_preview.custom_minimum_size = Vector2(56, 56)
	_chaser_preview.custom_minimum_size = Vector2(56, 56)

	theme_title_lbl.visible = false
	theme_left.visible = false
	theme_btn.visible = false
	theme_right.visible = false
	diff_title_lbl.visible = false
	diff_left.visible = false
	diff_btn.visible = false
	diff_btn.focus_mode = Control.FOCUS_NONE
	diff_right.visible = false

	config_grid.columns = 4
	config_grid.add_theme_constant_override("h_separation", 6)
	config_grid.add_theme_constant_override("v_separation", 8)

func _build_pickup_cards() -> void:
	_pickup_cards = {
		MissionCatalog.PICKUP_NUMBERS: pickup_numbers_card,
		MissionCatalog.PICKUP_WORDS: pickup_words_card,
		MissionCatalog.PICKUP_LETTERS: pickup_letters_card,
		MissionCatalog.PICKUP_NONE: pickup_none_card,
	}
	for pickup_id in PICKUP_CARD_ORDER:
		var card := _pickup_cards.get(pickup_id, null) as Button
		if card == null:
			continue
		card.pressed.connect(_select_pickup.bind(pickup_id))
		card.focus_entered.connect(_select_pickup_from_focus.bind(pickup_id))

func _build_context_rows() -> void:
	_goal_label = Label.new()
	_goal_label.name = "GoalLabel"
	_goal_label.custom_minimum_size = Vector2(0, 78)
	_goal_label.add_theme_font_size_override("font_size", 30)
	_goal_label.add_theme_color_override("font_color", UIColors.YELLOW)
	_goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_goal_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main_vbox.add_child(_goal_label)
	main_vbox.move_child(_goal_label, pickup_row.get_index() + 1)

	var trouble := _create_selector_row("setting_trouble")
	_trouble_row = trouble["row"] as HBoxContainer
	_trouble_left = trouble["left"] as Label
	_trouble_button = trouble["button"] as Button
	_trouble_right = trouble["right"] as Label
	footer_vbox.add_child(_trouble_row)
	footer_vbox.move_child(_trouble_row, 0)

	var speed := _create_selector_row("setting_chaser_speed")
	_chaser_speed_row = speed["row"] as HBoxContainer
	_chaser_speed_left = speed["left"] as Label
	_chaser_speed_button = speed["button"] as Button
	_chaser_speed_right = speed["right"] as Label
	footer_vbox.add_child(_chaser_speed_row)
	footer_vbox.move_child(_chaser_speed_row, 1)

	_start_button = Button.new()
	_start_button.name = "StartAdventureButton"
	_start_button.custom_minimum_size = Vector2(560, 72)
	_start_button.add_theme_font_size_override("font_size", 32)
	_start_button.pressed.connect(_start_game)
	UIHelpers.apply_style_to_button(_start_button, UIColors.BLUE)
	footer_vbox.add_child(_start_button)

	_trouble_button.pressed.connect(_toggle_chaser)
	_setup_toggle_cycling(_trouble_button, _toggle_chaser)
	_chaser_speed_button.pressed.connect(func(): _cycle_chaser_speed(1))
	_setup_cycling(_chaser_speed_button, _cycle_chaser_speed)
	_setup_arrow_visibility(_trouble_button, _trouble_left, _trouble_right)
	_setup_arrow_visibility(_chaser_speed_button, _chaser_speed_left, _chaser_speed_right)

func _create_selector_row(label_key: String) -> Dictionary:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size = Vector2(0, 52)

	var label := Label.new()
	label.custom_minimum_size = Vector2(190, 0)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", UIColors.TEXT_SUBTITLE)
	label.text = tr(label_key)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	var left := _create_arrow_label()
	row.add_child(left)

	var button := Button.new()
	button.custom_minimum_size = Vector2(260, 46)
	button.add_theme_font_size_override("font_size", 24)
	UIHelpers.apply_style_to_button(button, UIColors.YELLOW)
	row.add_child(button)

	var right := _create_arrow_label()
	right.text = ">"
	row.add_child(right)
	return {"row": row, "left": left, "button": button, "right": right}

func _create_arrow_label() -> Label:
	var label := Label.new()
	label.custom_minimum_size = Vector2(28, 0)
	label.add_theme_color_override("font_color", UIColors.YELLOW)
	label.add_theme_font_size_override("font_size", 30)
	label.text = "<"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label

func _setup_config_controls() -> void:
	lang_btn.pressed.connect(func(): _cycle_lang(1))
	_setup_cycling(lang_btn, _cycle_lang)
	_setup_arrow_visibility(lang_btn, lang_left, lang_right)
	UIHelpers.apply_style_to_button(lang_btn, UIColors.YELLOW)
	_configure_option_control_size(lang_title_lbl, lang_left, lang_btn, lang_right)

func _configure_option_control_size(title: Label, left: Label, btn: Button, right: Label) -> void:
	title.add_theme_font_size_override("font_size", 20)
	title.custom_minimum_size = Vector2(190, 0)
	left.add_theme_font_size_override("font_size", 24)
	left.custom_minimum_size = Vector2(24, 0)
	btn.custom_minimum_size = Vector2(250, 42)
	btn.add_theme_font_size_override("font_size", 22)
	right.add_theme_font_size_override("font_size", 24)
	right.custom_minimum_size = Vector2(24, 0)

func _setup_cycling(btn: Button, cycle_func: Callable) -> void:
	btn.gui_input.connect(func(event: InputEvent):
		if event.is_pressed():
			if event.is_action("ui_left"):
				cycle_func.call(-1)
				get_viewport().set_input_as_handled()
			elif event.is_action("ui_right"):
				cycle_func.call(1)
				get_viewport().set_input_as_handled()
	)

func _setup_toggle_cycling(btn: Button, toggle_func: Callable) -> void:
	btn.gui_input.connect(func(event: InputEvent):
		if event.is_pressed() and (event.is_action("ui_left") or event.is_action("ui_right")):
			toggle_func.call()
			get_viewport().set_input_as_handled()
	)

func _setup_arrow_visibility(btn: Button, left: Label, right: Label) -> void:
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

func _localize_ui() -> void:
	title_lbl.text = tr(MissionCatalog.mission_title_key(_selected_mission))
	lang_title_lbl.text = tr("setting_learning_lang")
	_start_button.text = tr("setup_start_adventure")

func _cycle_lang(dir: int) -> void:
	temp_lang_idx = (temp_lang_idx + dir + Config.LANG_CODES.size()) % Config.LANG_CODES.size()
	_update_labels()

func _cycle_diff(dir: int) -> void:
	if Config.DIFF_KEYS.is_empty():
		return
	temp_diff_idx = (temp_diff_idx + dir + Config.DIFF_KEYS.size()) % Config.DIFF_KEYS.size()
	_update_labels()

func _cycle_chaser_speed(dir: int) -> void:
	temp_chaser_speed_idx = (temp_chaser_speed_idx + dir + MissionCatalog.CHASER_TUNING_LEVELS.size()) % MissionCatalog.CHASER_TUNING_LEVELS.size()
	_update_labels()

func _select_pickup(pickup_id: String) -> void:
	if not MissionCatalog.allowed_pickups(_selected_mission).has(pickup_id):
		return
	if _selected_pickup == pickup_id:
		return
	_selected_pickup = pickup_id
	_update_labels()
	_configure_dpad_navigation()

func _select_pickup_from_focus(pickup_id: String) -> void:
	if MissionCatalog.allowed_pickups(_selected_mission).has(pickup_id):
		_select_pickup(pickup_id)

func _toggle_chaser() -> void:
	if not MissionCatalog.chaser_allowed(_selected_mission):
		return
	_chaser_enabled = not _chaser_enabled
	_normalize_selection()
	_update_labels()
	_configure_dpad_navigation()

func _normalize_selection() -> void:
	if not MissionCatalog.mission_ids().has(_selected_mission):
		_selected_mission = MissionCatalog.DEFAULT_MISSION
	var pickups := MissionCatalog.allowed_pickups(_selected_mission)
	if not pickups.has(_selected_pickup):
		_selected_pickup = MissionCatalog.default_pickup(_selected_mission)
	if MissionCatalog.chaser_forced_off(_selected_mission):
		_chaser_enabled = false

func _update_labels() -> void:
	_normalize_selection()
	_update_theme_preview()
	_update_pickup_cards()
	_update_context_rows()
	title_lbl.text = tr(MissionCatalog.mission_title_key(_selected_mission))

	var ui_idx: int = Config.LANG_CODES.find(Config.ui_language)
	if ui_idx < 0:
		ui_idx = 0
	lang_btn.text = Config.get_lang_display_name(temp_lang_idx, true, ui_idx)

func _update_theme_preview() -> void:
	_theme_preview_loader = ThemeLoader.get_cached(Config.theme_dir_name)
	if _theme_preview_loader != null:
		_player_preview.set_character(_theme_preview_loader.player_frames, _theme_preview_loader.player_fps)
		_chaser_preview.set_character(_theme_preview_loader.chaser_frames, _theme_preview_loader.chaser_fps)

func _update_pickup_cards() -> void:
	var allowed_pickups := MissionCatalog.allowed_pickups(_selected_mission)
	for pickup_id in PICKUP_CARD_ORDER:
		var card := _pickup_cards.get(pickup_id, null) as Button
		if card == null:
			continue
		var allowed := allowed_pickups.has(pickup_id)
		card.visible = allowed
		card.focus_mode = Control.FOCUS_ALL if allowed else Control.FOCUS_NONE
		card.call(
			"setup",
			String(PICKUP_CARD_ICONS.get(pickup_id, "?")),
			tr(String(PICKUP_CARD_TITLE_KEYS.get(pickup_id, "training_words"))),
			tr(String(PICKUP_CARD_SUBTITLE_KEYS.get(pickup_id, "pickup_words_short")))
		)
		card.call("set_selected", pickup_id == _selected_pickup)
	_apply_responsive_layout()

func _update_context_rows() -> void:
	var show_trouble := MissionCatalog.chaser_allowed(_selected_mission)
	_set_option_button_enabled(_trouble_button, show_trouble)
	_trouble_row.modulate.a = 1.0 if show_trouble else 0.45
	_trouble_button.text = tr("trouble_chaser") if _chaser_enabled else tr("trouble_no_chaser")

	_set_option_button_enabled(_chaser_speed_button, _chaser_enabled)
	_chaser_speed_row.modulate.a = 1.0 if _chaser_enabled else 0.45
	var speed_level := MissionCatalog.CHASER_TUNING_LEVELS[temp_chaser_speed_idx]
	_chaser_speed_button.text = tr(Config.CHASER_LEVEL_KEYS[speed_level]) if _chaser_enabled else tr("trouble_no_chaser")

	var goal_key := MissionCatalog.goal_key(_selected_mission, _selected_pickup, _chaser_enabled, false)
	_goal_label.text = tr(goal_key)
	_goal_label.visible = false
	_chaser_preview.modulate.a = 1.0 if _chaser_enabled else 0.28

func _set_option_button_enabled(button: Button, enabled: bool) -> void:
	if button == null:
		return
	button.disabled = not enabled
	button.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE

func _apply_responsive_layout() -> void:
	var available_width := _available_setup_width()
	main_vbox.custom_minimum_size.x = available_width
	if _goal_label != null:
		_goal_label.custom_minimum_size = Vector2(available_width, 78)

	var visible_cards := _pickup_card_buttons(true)
	if visible_cards.is_empty():
		return
	var gaps := float(PICKUP_CARD_GAP * max(0, visible_cards.size() - 1))
	var card_width := floorf((available_width - gaps) / float(visible_cards.size()))
	if visible_cards.size() == 1:
		card_width = clampf(card_width, 420.0, 620.0)
	else:
		card_width = clampf(card_width, 240.0, 340.0)
	var card_height := 150.0 if visible_cards.size() == 1 else 230.0
	for card in visible_cards:
		card.custom_minimum_size = Vector2(card_width, card_height)
		card.pivot_offset = Vector2(card_width * 0.5, card_height * 0.5)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.call("configure_compact", 52, 30, 19)

func _available_setup_width() -> float:
	var viewport_size := get_viewport_rect().size
	var controls_mode := Config.ControlsMode.OFF
	if Config != null:
		controls_mode = Config.on_screen_controls
	var content_rect := UIHelpers.get_content_rect(viewport_size, controls_mode)
	return clampf(content_rect.size.x, 760.0, 1400.0)

func _start_game() -> void:
	_normalize_selection()
	Config.learning_language = Config.LANG_CODES[temp_lang_idx]
	Config.difficulty = temp_diff_idx
	Config.configure_single_player_session(
		MissionCatalog.style_for_mission(_selected_mission),
		MissionCatalog.training_for_pickup(_selected_pickup),
		_chaser_enabled,
		MissionCatalog.CHASER_TUNING_LEVELS[temp_chaser_speed_idx],
		_selected_mission,
	)
	Config.save_settings()
	UIHelpers.go_to_scene_with_loading(get_tree(), "res://scenes/main.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()

func _apply_dpad_layout() -> void:
	if center_container != null and Config != null:
		UIHelpers.apply_dpad_layout(center_container, Config.on_screen_controls)

func _on_controls_changed(_new_mode: int) -> void:
	_apply_dpad_layout()
	_apply_responsive_layout()
	_configure_dpad_navigation()

func _configure_dpad_navigation() -> void:
	var pickup_buttons := _pickup_card_buttons(true)
	_configure_card_row_navigation(pickup_buttons, _start_button, _first_context_button())
	if _is_focusable(_trouble_button):
		_configure_single_button_navigation(_trouble_button, _selected_pickup_button(), _next_after_trouble_button())
	if _is_focusable(_chaser_speed_button):
		_configure_single_button_navigation(_chaser_speed_button, _previous_before_speed_button(), lang_btn)
	_configure_single_button_navigation(lang_btn, _last_context_button(), _start_button)
	_configure_single_button_navigation(_start_button, lang_btn, _selected_pickup_button())

func _configure_card_row_navigation(cards: Array, above: Control, below: Control) -> void:
	var row := _valid_buttons(cards)
	if row.is_empty():
		return
	for i in range(row.size()):
		var card := row[i] as Button
		var left := row[(i - 1 + row.size()) % row.size()] as Button
		var right := row[(i + 1) % row.size()] as Button
		card.focus_neighbor_left = card.get_path_to(left)
		card.focus_neighbor_right = card.get_path_to(right)
		if above != null:
			card.focus_neighbor_top = card.get_path_to(above)
		if below != null:
			card.focus_neighbor_bottom = card.get_path_to(below)

func _configure_single_button_navigation(button: Control, top: Control, bottom: Control) -> void:
	if button == null:
		return
	button.focus_neighbor_left = button.get_path_to(button)
	button.focus_neighbor_right = button.get_path_to(button)
	if top != null:
		button.focus_neighbor_top = button.get_path_to(top)
	if bottom != null:
		button.focus_neighbor_bottom = button.get_path_to(bottom)

func _first_context_button() -> Button:
	if _is_focusable(_trouble_button):
		return _trouble_button
	if _is_focusable(_chaser_speed_button):
		return _chaser_speed_button
	return lang_btn

func _last_context_button() -> Button:
	if _is_focusable(_chaser_speed_button):
		return _chaser_speed_button
	if _is_focusable(_trouble_button):
		return _trouble_button
	return _selected_pickup_button()

func _next_after_trouble_button() -> Button:
	if _is_focusable(_chaser_speed_button):
		return _chaser_speed_button
	return lang_btn

func _previous_before_speed_button() -> Button:
	if _is_focusable(_trouble_button):
		return _trouble_button
	return _selected_pickup_button()

func _pickup_card_buttons(only_focusable: bool = false) -> Array[Button]:
	var buttons: Array[Button] = []
	for pickup_id in PICKUP_CARD_ORDER:
		var button := _pickup_cards.get(pickup_id, null) as Button
		if button == null:
			continue
		if only_focusable and not _is_focusable(button):
			continue
		buttons.append(button)
	return buttons

func _selected_pickup_button() -> Button:
	var selected := _pickup_cards.get(_selected_pickup, null) as Button
	if _is_focusable(selected):
		return selected
	var buttons := _pickup_card_buttons(true)
	return buttons[0] if not buttons.is_empty() else null

func _is_focusable(button: Control) -> bool:
	if button == null:
		return false
	if button is Button:
		var btn := button as Button
		if btn.disabled:
			return false
	return button.visible and button.focus_mode != Control.FOCUS_NONE

func _valid_buttons(items: Array) -> Array[Button]:
	var result: Array[Button] = []
	for item in items:
		if item is Button and is_instance_valid(item):
			var button := item as Button
			if button.visible:
				result.append(button)
	return result
