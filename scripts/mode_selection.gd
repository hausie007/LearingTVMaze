class_name ModeSelection
extends Control

const MissionCatalog := preload("res://scripts/mission_catalog.gd")

# Pickup card constants — aliased from MissionCatalog (single source of truth).
const PICKUP_CARD_ORDER = MissionCatalog.PICKUP_CARD_ORDER
const PICKUP_CARD_ICONS = MissionCatalog.PICKUP_CARD_ICONS
const PICKUP_CARD_TITLE_KEYS = MissionCatalog.PICKUP_CARD_TITLE_KEYS
const PICKUP_CARD_SUBTITLE_KEYS = MissionCatalog.PICKUP_CARD_SUBTITLE_KEYS

@onready var center_container: CenterContainer = $CenterContainer

var _home_vbox: VBoxContainer = null
var _top_spacer: Control = null
var _title_row: HBoxContainer = null
var _title_label: Label = null
var _player_preview: CharacterPreview = null
var _chaser_preview: CharacterPreview = null
var _title_cards_spacer: Control = null
var _pickup_row: HBoxContainer = null
var _start_button: Button = null
var _cards_settings_spacer: Control = null
var _settings_vbox: VBoxContainer = null

var _trouble_row: HBoxContainer = null
var _trouble_button: Button = null
var _trouble_left: Label = null
var _trouble_right: Label = null
var _chaser_speed_row: HBoxContainer = null
var _chaser_speed_button: Button = null
var _chaser_speed_left: Label = null
var _chaser_speed_right: Label = null
var _lang_row: HBoxContainer = null
var _lang_button: Button = null
var _lang_left: Label = null
var _lang_right: Label = null

var temp_lang_idx: int = 0
var temp_diff_idx: int = 0
var temp_chaser_speed_idx: int = 1

var _selected_mission: String = MissionCatalog.DEFAULT_MISSION
var _selected_pickup: String = MissionCatalog.DEFAULT_PICKUP
var _chaser_enabled: bool = false
var _theme_preview_loader: ThemeLoader = null

var _pickup_cards: Dictionary = {}

func _ready() -> void:
	Input.warp_mouse(Vector2(-1, -1))
	_initialize_temp_state()
	_build_layout()
	_update_labels()
	if Config != null and not Config.on_screen_controls_changed.is_connected(_on_controls_changed):
		Config.on_screen_controls_changed.connect(_on_controls_changed)
	_apply_dpad_layout()
	_apply_responsive_layout()
	_configure_dpad_navigation()
	var initial_focus := _selected_pickup_button()
	if initial_focus != null:
		initial_focus.call_deferred("grab_focus")
	else:
		# Only one card or no cards — focus the first settings button
		var first_btn := _lang_button
		if first_btn != null:
			first_btn.call_deferred("grab_focus")

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

	_chaser_enabled = Config.chaser_enabled and MissionCatalog.chaser_allowed(_selected_mission)
	var speed_idx := MissionCatalog.CHASER_TUNING_LEVELS.find(Config.chaser_level)
	temp_chaser_speed_idx = speed_idx if speed_idx >= 0 else 1
	_normalize_selection()

func _build_layout() -> void:
	# Clear existing scene children from CenterContainer
	for child in center_container.get_children():
		center_container.remove_child(child)
		child.queue_free()

	# Main VBox — fills entire viewport like main menu
	_home_vbox = VBoxContainer.new()
	_home_vbox.name = "SetupHome"
	_home_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	_home_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_home_vbox.add_theme_constant_override("separation", 18)
	center_container.add_child(_home_vbox)

	# Top spacer
	_top_spacer = Control.new()
	_top_spacer.name = "TopSpacer"
	_top_spacer.custom_minimum_size = Vector2(0, 60)
	_home_vbox.add_child(_top_spacer)

	# Title row: [PlayerPreview] [Title] [ChaserPreview]
	_title_row = HBoxContainer.new()
	_title_row.name = "TitleRow"
	_title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_title_row.add_theme_constant_override("separation", 20)
	_home_vbox.add_child(_title_row)

	_player_preview = CharacterPreview.new()
	_player_preview.name = "PlayerPreview"
	_player_preview.custom_minimum_size = Vector2(72, 72)
	_player_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_player_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_title_row.add_child(_player_preview)

	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.add_theme_font_size_override("font_size", 62)
	_title_label.add_theme_color_override("font_color", UIColors.YELLOW)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_row.add_child(_title_label)

	_chaser_preview = CharacterPreview.new()
	_chaser_preview.name = "ChaserPreview"
	_chaser_preview.custom_minimum_size = Vector2(72, 72)
	_chaser_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_chaser_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_title_row.add_child(_chaser_preview)

	# Spacer between title and cards
	_title_cards_spacer = Control.new()
	_title_cards_spacer.name = "TitleCardsSpacer"
	_title_cards_spacer.custom_minimum_size = Vector2(0, 18)
	_home_vbox.add_child(_title_cards_spacer)

	# Pickup card row
	_pickup_row = HBoxContainer.new()
	_pickup_row.name = "PickupRow"
	_pickup_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_pickup_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pickup_row.add_theme_constant_override("separation", 48)
	_home_vbox.add_child(_pickup_row)
	_build_pickup_cards()

	# Action button row: [Start Adventure] — centered below cards
	var action_spacer := Control.new()
	action_spacer.name = "ActionSpacer"
	action_spacer.custom_minimum_size = Vector2(0, 10)
	_home_vbox.add_child(action_spacer)

	var action_row := HBoxContainer.new()
	action_row.name = "ActionRow"
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_home_vbox.add_child(action_row)

	_start_button = Button.new()
	_start_button.text = tr("setup_start_adventure")
	_start_button.custom_minimum_size = Vector2(320, 68)
	_start_button.add_theme_font_size_override("font_size", 30)
	UIHelpers.apply_style_to_button(_start_button, UIColors.BLUE)
	_start_button.pressed.connect(_start_game)
	action_row.add_child(_start_button)

	# Spacer between action button and settings
	_cards_settings_spacer = Control.new()
	_cards_settings_spacer.name = "CardsSettingsSpacer"
	_cards_settings_spacer.custom_minimum_size = Vector2(0, 56)
	_home_vbox.add_child(_cards_settings_spacer)

	# Settings block
	_settings_vbox = VBoxContainer.new()
	_settings_vbox.name = "SettingsBlock"
	_settings_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_settings_vbox.add_theme_constant_override("separation", 12)
	_home_vbox.add_child(_settings_vbox)

	# Language row (always visible — placed first to avoid jumping when chaser toggles)
	var lang := CyclingSelector.create_row_dict("setting_learning_lang")
	_lang_row = lang["row"] as HBoxContainer
	_lang_left = lang["left"] as Label
	_lang_button = lang["button"] as Button
	_lang_right = lang["right"] as Label
	_lang_button.pressed.connect(func(): _cycle_lang(1))
	CyclingSelector.setup_cycling(_lang_button, _cycle_lang)
	CyclingSelector.setup_arrow_visibility(_lang_button, _lang_left, _lang_right)
	_settings_vbox.add_child(_lang_row)

	# Trouble row
	var trouble := CyclingSelector.create_row_dict("setting_trouble")
	_trouble_row = trouble["row"] as HBoxContainer
	_trouble_left = trouble["left"] as Label
	_trouble_button = trouble["button"] as Button
	_trouble_right = trouble["right"] as Label
	_trouble_button.pressed.connect(_toggle_chaser)
	CyclingSelector.setup_toggle_cycling(_trouble_button, _toggle_chaser)
	CyclingSelector.setup_arrow_visibility(_trouble_button, _trouble_left, _trouble_right)
	_settings_vbox.add_child(_trouble_row)

	# Chaser speed row
	var speed := CyclingSelector.create_row_dict("setting_chaser_speed")
	_chaser_speed_row = speed["row"] as HBoxContainer
	_chaser_speed_left = speed["left"] as Label
	_chaser_speed_button = speed["button"] as Button
	_chaser_speed_right = speed["right"] as Label
	_chaser_speed_button.pressed.connect(func(): _cycle_chaser_speed(1))
	CyclingSelector.setup_cycling(_chaser_speed_button, _cycle_chaser_speed)
	CyclingSelector.setup_arrow_visibility(_chaser_speed_button, _chaser_speed_left, _chaser_speed_right)
	_settings_vbox.add_child(_chaser_speed_row)

func _build_pickup_cards() -> void:
	for pickup_id in PICKUP_CARD_ORDER:
		var card := preload("res://scenes/ui/mode_card.tscn").instantiate() as Button
		card.custom_minimum_size = Vector2(300, 230)
		card.pivot_offset = Vector2(150, 115)
		card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card.call("configure_compact", 52, 30, 19)
		card.pressed.connect(_on_card_pressed.bind(pickup_id))
		card.focus_entered.connect(_select_pickup_from_focus.bind(pickup_id))
		_pickup_row.add_child(card)
		_pickup_cards[pickup_id] = card

func _on_card_pressed(pickup_id: String) -> void:
	if not MissionCatalog.allowed_pickups(_selected_mission).has(pickup_id):
		return
	_selected_pickup = pickup_id
	_start_game()

# Selector row and arrow label creation delegated to CyclingSelector.

# Cycling, toggle cycling, and arrow visibility delegated to CyclingSelector.

func _cycle_lang(dir: int) -> void:
	temp_lang_idx = (temp_lang_idx + dir + Config.LANG_CODES.size()) % Config.LANG_CODES.size()
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
	_title_label.text = tr(MissionCatalog.mission_title_key(_selected_mission))

	var ui_idx: int = Config.LANG_CODES.find(Config.ui_language)
	if ui_idx < 0:
		ui_idx = 0
	_lang_button.text = Config.get_lang_display_name(temp_lang_idx, true, ui_idx)

func _update_theme_preview() -> void:
	_theme_preview_loader = ThemeLoader.get_cached(Config.theme_dir_name)
	if _theme_preview_loader != null:
		_player_preview.set_character(_theme_preview_loader.player_frames, _theme_preview_loader.player_fps)
		_chaser_preview.set_character(_theme_preview_loader.chaser_frames, _theme_preview_loader.chaser_fps)

func _update_pickup_cards() -> void:
	var allowed_pickups := MissionCatalog.allowed_pickups(_selected_mission)
	var visible_count := 0
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
		card.call("set_selected", pickup_id == _selected_pickup, false)
		if allowed:
			visible_count += 1

	# Show card row if at least 1 card is visible
	_pickup_row.visible = visible_count > 0
	_title_cards_spacer.visible = visible_count > 0

func _update_context_rows() -> void:
	var is_collecting := _selected_pickup != MissionCatalog.PICKUP_NONE
	if _lang_row != null:
		_lang_row.visible = is_collecting
		_set_option_button_enabled(_lang_button, is_collecting)

	var chaser_allowed := MissionCatalog.chaser_allowed(_selected_mission)
	var chaser_forced_off := MissionCatalog.chaser_forced_off(_selected_mission)
	# Only show trouble row when user has an actual choice
	var user_can_toggle := chaser_allowed and not chaser_forced_off
	_trouble_row.visible = user_can_toggle
	# Silently enforce the only valid value when there's no choice
	if chaser_forced_off or not chaser_allowed:
		_chaser_enabled = false
	_trouble_button.text = tr("trouble_chaser") if _chaser_enabled else tr("trouble_no_chaser")

	_set_option_button_enabled(_chaser_speed_button, _chaser_enabled)
	_chaser_speed_row.visible = _chaser_enabled
	var speed_level := MissionCatalog.CHASER_TUNING_LEVELS[temp_chaser_speed_idx]
	_chaser_speed_button.text = tr(Config.CHASER_LEVEL_KEYS[speed_level]) if _chaser_enabled else tr("trouble_no_chaser")

	_chaser_preview.modulate.a = 1.0 if _chaser_enabled else 0.28

func _set_option_button_enabled(button: Button, enabled: bool) -> void:
	if button == null:
		return
	button.disabled = not enabled
	button.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE

func _apply_responsive_layout() -> void:
	var available_width := _available_setup_width()
	var viewport_height: float = get_viewport_rect().size.y
	var short_screen: bool = viewport_height < 820.0

	if _home_vbox != null:
		_home_vbox.custom_minimum_size = Vector2(available_width, viewport_height)
		_home_vbox.add_theme_constant_override("separation", _home_spacing())

	if _top_spacer != null:
		_top_spacer.custom_minimum_size.y = clampf(viewport_height * 0.0075, 3.0, 8.0)

	if _title_row != null:
		var simulated_logo_width: float = clampf(available_width * (0.52 if short_screen else 0.58), 480.0, 930.0)
		var simulated_logo_height: float = clampf(simulated_logo_width * 0.214, 102.0, 198.0)
		_title_row.custom_minimum_size.y = simulated_logo_height

		if _title_label != null:
			_title_label.add_theme_font_size_override("font_size", int(simulated_logo_height * 0.40))

		var preview_size := simulated_logo_height * 0.45
		if _player_preview != null:
			_player_preview.custom_minimum_size = Vector2(preview_size, preview_size)
		if _chaser_preview != null:
			_chaser_preview.custom_minimum_size = Vector2(preview_size, preview_size)

	if _title_cards_spacer != null:
		_title_cards_spacer.custom_minimum_size.y = 16.0 if short_screen else 24.0

	if _cards_settings_spacer != null:
		_cards_settings_spacer.custom_minimum_size.y = 20.0 if short_screen else 30.0

	var visible_cards := _pickup_card_buttons(true)
	if not visible_cards.is_empty() and _pickup_row.visible:
		var count: int = visible_cards.size()
		var columns: int = 4 if available_width >= 760.0 else 2

		var mission_gap: int = 48
		if available_width < 1200.0:
			mission_gap = 34
		if available_width < 900.0:
			mission_gap = 24

		var gaps := float(mission_gap * maxi(0, columns - 1))
		var card_width := floorf((available_width - gaps) / float(columns))
		card_width = clampf(card_width, 160.0, 390.0)
		var card_height := clampf(viewport_height * (0.355 if short_screen else 0.335), 260.0, 340.0)

		_pickup_row.add_theme_constant_override("separation", mission_gap)

		for card in visible_cards:
			card.custom_minimum_size = Vector2(card_width, card_height)
			card.pivot_offset = Vector2(card_width * 0.5, card_height * 0.5)

			var icon_size: int = 46 if card_width < 220.0 else (52 if card_width < 270.0 else 58)
			var title_size: int = 24 if card_width < 220.0 else (28 if card_width < 270.0 else 31)
			var subtitle_size: int = 17 if card_width < 250.0 else 19
			card.call("configure_compact", icon_size, title_size, subtitle_size)

	# Responsive action button size
	var action_btn_width: float = clampf(available_width * 0.22, 260.0, 380.0)
	var action_btn_height: float = 62.0 if short_screen else 68.0
	var action_font_size: int = 26 if short_screen else 30
	if _start_button != null:
		_start_button.custom_minimum_size = Vector2(action_btn_width, action_btn_height)
		_start_button.add_theme_font_size_override("font_size", action_font_size)

	# Responsive selector sizes — match main menu
	var selector_width: float = clampf(available_width * 0.32, 380.0, 500.0)
	var selector_height: float = 58.0 if short_screen else 66.0
	var selector_font_size: int = 28 if short_screen else 31

	for btn in [_trouble_button, _chaser_speed_button, _lang_button]:
		if btn != null:
			btn.custom_minimum_size = Vector2(selector_width, selector_height)
			btn.add_theme_font_size_override("font_size", selector_font_size)

func _available_setup_width() -> float:
	var viewport_size := get_viewport_rect().size
	var controls_mode := Config.ControlsMode.OFF
	if Config != null:
		controls_mode = Config.on_screen_controls
	var content_rect := UIHelpers.get_content_rect(viewport_size, controls_mode)
	return clampf(content_rect.size.x * 0.985, 760.0, 1640.0)

func _home_spacing() -> int:
	var height: float = get_viewport_rect().size.y
	if height < 650.0:
		return 8
	if height < 820.0:
		return 12
	return 20

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
	UIHelpers.go_to_scene_with_loading(get_tree(), Scenes.GAME)

func _on_back_pressed() -> void:
	# Persist current selections so they're restored on return
	Config.learning_language = Config.LANG_CODES[temp_lang_idx]
	Config.difficulty = temp_diff_idx
	Config.selected_mission_id = _selected_mission
	Config.training_type = MissionCatalog.training_for_pickup(_selected_pickup)
	Config.chaser_enabled = _chaser_enabled
	Config.chaser_level = MissionCatalog.CHASER_TUNING_LEVELS[temp_chaser_speed_idx] if _chaser_enabled else Config.ChaserLevel.OFF
	Config.save_settings()
	get_tree().change_scene_to_file(Scenes.HOME)

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
	var active_lang_btn = _lang_button if FocusNavigator.is_focusable(_lang_button) else null
	# Order: cards → start button → lang → trouble → chaser speed
	if not pickup_buttons.is_empty() and _pickup_row.visible:
		FocusNavigator.configure_row(pickup_buttons, null, _start_button)
	if _start_button != null:
		FocusNavigator.configure_single(_start_button, _selected_pickup_button() if _pickup_row.visible else null, active_lang_btn if active_lang_btn != null else _first_chaser_button())
	var lang_top: Control = _start_button
	if active_lang_btn != null:
		FocusNavigator.configure_single(_lang_button, lang_top, _first_chaser_button())
	if FocusNavigator.is_focusable(_trouble_button):
		var trouble_top = active_lang_btn if active_lang_btn != null else _start_button
		FocusNavigator.configure_single(_trouble_button, trouble_top, _next_after_trouble_button())
	if FocusNavigator.is_focusable(_chaser_speed_button):
		FocusNavigator.configure_single(_chaser_speed_button, _previous_before_speed_button(), null)

func _first_chaser_button() -> Button:
	if FocusNavigator.is_focusable(_trouble_button):
		return _trouble_button
	if FocusNavigator.is_focusable(_chaser_speed_button):
		return _chaser_speed_button
	return null

func _next_after_trouble_button() -> Button:
	if FocusNavigator.is_focusable(_chaser_speed_button):
		return _chaser_speed_button
	return null

func _previous_before_speed_button() -> Button:
	if FocusNavigator.is_focusable(_trouble_button):
		return _trouble_button
	if FocusNavigator.is_focusable(_lang_button):
		return _lang_button
	return _selected_pickup_button()

func _pickup_card_buttons(only_focusable: bool = false) -> Array[Button]:
	var buttons: Array[Button] = []
	for pickup_id in PICKUP_CARD_ORDER:
		var button := _pickup_cards.get(pickup_id, null) as Button
		if button == null:
			continue
		if only_focusable and not FocusNavigator.is_focusable(button):
			continue
		buttons.append(button)
	return buttons

func _selected_pickup_button() -> Button:
	var selected := _pickup_cards.get(_selected_pickup, null) as Button
	if FocusNavigator.is_focusable(selected):
		return selected
	var buttons := _pickup_card_buttons(true)
	return buttons[0] if not buttons.is_empty() else null
