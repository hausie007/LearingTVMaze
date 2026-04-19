class_name ModeSelection
extends Control

const ModeCardScene := preload("res://scenes/ui/mode_card.tscn")

const CHASER_SPEED_LEVELS: Array[int] = [
	GameConfig.ChaserLevel.SLOW,
	GameConfig.ChaserLevel.MEDIUM,
	GameConfig.ChaserLevel.FAST,
	GameConfig.ChaserLevel.TURBO,
]

enum Step {
	SETUP,
	VARIANT,
}

@onready var style_path_card: Button = %NumbersCard
@onready var style_next_card: Button = %WordsCard
@onready var style_race_card: Button = %LettersCard
@onready var calm_card: Button = %MazeCard
@onready var main_vbox: VBoxContainer = $CenterContainer/MainVBox
@onready var style_row: HBoxContainer = %NumbersCard.get_parent()
@onready var variant_row: HBoxContainer = %MazeCard.get_parent()
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
var temp_theme_idx: int = 0
var temp_diff_idx: int = 0
var temp_chaser_speed_idx: int = 1
var themes: Array[String] = []

var _selected_style: String = Config.STYLE_PATH
var _selected_training: String = Config.TRAINING_WORDS
var _chaser_enabled: bool = false

var _theme_preview_loader: ThemeLoader = null
var _last_theme_idx: int = -1
var _step: int = Step.SETUP
var _chaser_card: Button = null
var _training_row: HBoxContainer = null
var _training_cards: Dictionary = {}
var _training_order: Array[String] = []
var _chaser_speed_row: HBoxContainer = null
var _chaser_speed_title: Label = null
var _chaser_speed_button: Button = null
var _chaser_speed_left: Label = null
var _chaser_speed_right: Label = null
var _start_button: Button = null

var _original_learning_language: String = ""
var _original_theme_dir_name: String = ""
var _original_game_style: String = ""
var _original_training_type: String = ""
var _original_chaser_enabled: bool = false
var _original_chaser_level: int = 0

func _ready() -> void:
	Input.warp_mouse(Vector2(-1, -1))
	_cache_original_config()
	_initialize_temp_state()
	_prepare_static_layout()
	_build_dynamic_rows()
	_connect_cards()
	_setup_config_controls()
	_localize_ui()
	_update_labels()
	UIHelpers.apply_dpad_layout($CenterContainer, Config.on_screen_controls)
	_configure_dpad_navigation()
	_show_step(Step.SETUP)

func _prepare_static_layout() -> void:
	var center: CenterContainer = $CenterContainer
	center.anchor_top = 0.0
	center.anchor_bottom = 0.0
	center.offset_top = 20.0
	center.offset_bottom = 930.0

	main_vbox.custom_minimum_size = Vector2(1500, 0)
	main_vbox.add_theme_constant_override("separation", 28)
	footer_vbox.add_theme_constant_override("separation", 26)
	style_row.add_theme_constant_override("separation", 42)
	variant_row.add_theme_constant_override("separation", 34)
	title_lbl.add_theme_font_size_override("font_size", 44)
	if _player_preview != null:
		_player_preview.custom_minimum_size = Vector2(48, 48)
	if _chaser_preview != null:
		_chaser_preview.custom_minimum_size = Vector2(48, 48)
	_configure_card(style_path_card, Vector2(390, 255), Vector2(195, 127.5), 58, 34, 20)
	_configure_card(style_next_card, Vector2(390, 255), Vector2(195, 127.5), 58, 34, 20)
	_configure_card(style_race_card, Vector2(390, 255), Vector2(195, 127.5), 58, 34, 20)
	_config_grid_for_setup_page()

func _config_grid_for_setup_page() -> void:
	if config_grid == null:
		return
	config_grid.columns = 4
	config_grid.add_theme_constant_override("h_separation", 8)
	config_grid.add_theme_constant_override("v_separation", 8)

func _configure_card(
	card: Button,
	size: Vector2,
	pivot: Vector2,
	icon_size: int,
	title_size: int,
	subtitle_size: int,
	preview_size: Vector2 = Vector2(72, 72),
) -> void:
	card.custom_minimum_size = size
	card.pivot_offset = pivot
	card.call("configure_compact", icon_size, title_size, subtitle_size, preview_size)

func _cache_original_config() -> void:
	_original_learning_language = Config.learning_language
	_original_theme_dir_name = Config.theme_dir_name
	_original_game_style = Config.game_style
	_original_training_type = Config.training_type
	_original_chaser_enabled = Config.chaser_enabled
	_original_chaser_level = Config.chaser_level

func _initialize_temp_state() -> void:
	temp_lang_idx = Config.LANG_CODES.find(Config.learning_language)
	if temp_lang_idx < 0:
		temp_lang_idx = 0

	themes = ThemeLoader.get_available_themes()
	temp_theme_idx = themes.find(Config.theme_dir_name)
	if temp_theme_idx < 0:
		temp_theme_idx = 0

	temp_diff_idx = Config.difficulty
	_selected_style = Config.game_style if [Config.STYLE_PATH, Config.STYLE_NEXT_SYMBOL, Config.STYLE_RACE].has(Config.game_style) else Config.STYLE_PATH
	_selected_training = Config.training_type
	if not [Config.TRAINING_NUMBERS, Config.TRAINING_LETTERS, Config.TRAINING_WORDS].has(_selected_training):
		_selected_training = Config.TRAINING_WORDS

	_chaser_enabled = Config.chaser_enabled and Config.chaser_level != Config.ChaserLevel.OFF
	var speed_idx := CHASER_SPEED_LEVELS.find(Config.chaser_level)
	temp_chaser_speed_idx = speed_idx if speed_idx >= 0 else 1

func _build_dynamic_rows() -> void:
	if calm_card != null:
		_configure_card(calm_card, Vector2(390, 210), Vector2(195, 105), 52, 32, 20)

	_chaser_card = ModeCardScene.instantiate() as Button
	_chaser_card.name = "ChaserVariantCard"
	_configure_card(_chaser_card, Vector2(390, 210), Vector2(195, 105), 52, 32, 20, Vector2(88, 88))
	variant_row.add_child(_chaser_card)

	_chaser_speed_row = HBoxContainer.new()
	_chaser_speed_row.name = "ChaserSpeedRow"
	_chaser_speed_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_chaser_speed_row.add_theme_constant_override("separation", 10)
	footer_vbox.add_child(_chaser_speed_row)
	footer_vbox.move_child(_chaser_speed_row, 0)

	_chaser_speed_title = Label.new()
	_chaser_speed_title.add_theme_font_size_override("font_size", 24)
	_chaser_speed_title.add_theme_color_override("font_color", UIColors.TEXT_SUBTITLE)
	_chaser_speed_title.custom_minimum_size = Vector2(260, 0)
	_chaser_speed_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_chaser_speed_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_chaser_speed_row.add_child(_chaser_speed_title)

	_chaser_speed_left = _create_arrow_label()
	_chaser_speed_row.add_child(_chaser_speed_left)

	_chaser_speed_button = Button.new()
	_chaser_speed_button.custom_minimum_size = Vector2(250, 54)
	_chaser_speed_button.add_theme_font_size_override("font_size", 28)
	_chaser_speed_row.add_child(_chaser_speed_button)

	_chaser_speed_right = _create_arrow_label()
	_chaser_speed_right.text = ">"
	_chaser_speed_row.add_child(_chaser_speed_right)

	_training_row = HBoxContainer.new()
	_training_row.name = "TrainingCardRow"
	_training_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_training_row.add_theme_constant_override("separation", 34)
	footer_vbox.add_child(_training_row)
	footer_vbox.move_child(_training_row, 0)

	_add_training_card(_training_row, Config.TRAINING_NUMBERS, "123")
	_add_training_card(_training_row, Config.TRAINING_LETTERS, "ABC")
	_add_training_card(_training_row, Config.TRAINING_WORDS, "W")

	_start_button = Button.new()
	_start_button.name = "StartButton"
	_start_button.custom_minimum_size = Vector2(620, 54)
	_start_button.add_theme_font_size_override("font_size", 27)
	_start_button.pressed.connect(_on_play_pressed)
	footer_vbox.add_child(_start_button)

func _create_arrow_label() -> Label:
	var label := Label.new()
	label.custom_minimum_size = Vector2(40, 0)
	label.add_theme_color_override("font_color", UIColors.YELLOW)
	label.add_theme_font_size_override("font_size", 40)
	label.text = "<"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label

func _add_training_card(parent: HBoxContainer, training: String, icon_text: String) -> void:
	var card := ModeCardScene.instantiate() as Button
	_configure_card(card, Vector2(330, 200), Vector2(165, 100), 50, 32, 19)
	card.pressed.connect(func(): _select_training(training))
	card.focus_entered.connect(func(): _select_training(training))
	parent.add_child(card)
	_training_order.append(training)
	_training_cards[training] = {
		"card": card,
		"icon": icon_text,
	}

func _connect_cards() -> void:
	style_path_card.pressed.connect(func(): _select_style(Config.STYLE_PATH))
	style_next_card.pressed.connect(func(): _select_style(Config.STYLE_NEXT_SYMBOL))
	style_race_card.pressed.connect(func(): _select_style(Config.STYLE_RACE))
	calm_card.pressed.connect(func(): _select_chaser(false))
	_chaser_card.pressed.connect(func(): _select_chaser(true))

	style_path_card.focus_entered.connect(func(): _select_style(Config.STYLE_PATH))
	style_next_card.focus_entered.connect(func(): _select_style(Config.STYLE_NEXT_SYMBOL))
	style_race_card.focus_entered.connect(func(): _select_style(Config.STYLE_RACE))

func _setup_config_controls() -> void:
	lang_btn.pressed.connect(func(): _cycle_lang(1))
	theme_btn.pressed.connect(func(): _cycle_theme(1))
	diff_btn.pressed.connect(func(): _cycle_diff(1))
	_chaser_speed_button.pressed.connect(func(): _cycle_chaser_speed(1))

	_setup_cycling(lang_btn, _cycle_lang)
	_setup_cycling(theme_btn, _cycle_theme)
	_setup_cycling(diff_btn, _cycle_diff)
	_setup_cycling(_chaser_speed_button, _cycle_chaser_speed)

	_setup_arrow_visibility(lang_btn, lang_left, lang_right)
	_setup_arrow_visibility(theme_btn, theme_left, theme_right)
	_setup_arrow_visibility(diff_btn, diff_left, diff_right)
	_setup_arrow_visibility(_chaser_speed_button, _chaser_speed_left, _chaser_speed_right)

	UIHelpers.apply_style_to_button(lang_btn, UIColors.YELLOW)
	UIHelpers.apply_style_to_button(theme_btn, UIColors.YELLOW)
	UIHelpers.apply_style_to_button(diff_btn, UIColors.YELLOW)
	UIHelpers.apply_style_to_button(_chaser_speed_button, UIColors.YELLOW)
	UIHelpers.apply_style_to_button(_start_button, UIColors.BLUE)
	_configure_option_control_size(diff_title_lbl, diff_left, diff_btn, diff_right)
	_configure_option_control_size(lang_title_lbl, lang_left, lang_btn, lang_right)
	_configure_option_control_size(theme_title_lbl, theme_left, theme_btn, theme_right)

func _configure_option_control_size(title: Label, left: Label, btn: Button, right: Label) -> void:
	title.add_theme_font_size_override("font_size", 20)
	title.custom_minimum_size = Vector2(190, 0)
	left.add_theme_font_size_override("font_size", 28)
	left.custom_minimum_size = Vector2(26, 0)
	btn.custom_minimum_size = Vector2(230, 42)
	btn.add_theme_font_size_override("font_size", 22)
	right.add_theme_font_size_override("font_size", 28)
	right.custom_minimum_size = Vector2(26, 0)

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

func _setup_arrow_visibility(btn: Button, left: Label, right: Label) -> void:
	left.modulate.a = 0.0
	right.modulate.a = 0.0
	btn.focus_entered.connect(func(): left.modulate.a = 1.0; right.modulate.a = 1.0)
	btn.focus_exited.connect(func(): left.modulate.a = 0.0; right.modulate.a = 0.0)

func _localize_ui() -> void:
	title_lbl.text = tr("menu_play_alone")
	lang_title_lbl.text = tr("setting_learning_lang")
	theme_title_lbl.text = tr("setting_theme")
	diff_title_lbl.text = tr("setting_diff")
	_chaser_speed_title.text = tr("setting_chaser_speed")
	_start_button.text = tr("play")

func _cycle_lang(dir: int) -> void:
	temp_lang_idx = (temp_lang_idx + dir + Config.LANG_CODES.size()) % Config.LANG_CODES.size()
	_update_labels()

func _cycle_theme(dir: int) -> void:
	if themes.is_empty():
		return
	temp_theme_idx = (temp_theme_idx + dir + themes.size()) % themes.size()
	_update_labels()

func _cycle_diff(dir: int) -> void:
	if Config.DIFF_KEYS.is_empty():
		return
	temp_diff_idx = (temp_diff_idx + dir + Config.DIFF_KEYS.size()) % Config.DIFF_KEYS.size()
	_update_labels()

func _cycle_chaser_speed(dir: int) -> void:
	temp_chaser_speed_idx = (temp_chaser_speed_idx + dir + CHASER_SPEED_LEVELS.size()) % CHASER_SPEED_LEVELS.size()
	_update_labels()

func _select_style(style: String) -> void:
	_selected_style = style
	_update_labels()
	_configure_dpad_navigation()

func _select_chaser(enabled: bool) -> void:
	_chaser_enabled = enabled
	_update_labels()
	_start_game()

func _select_training(training: String) -> void:
	_selected_training = training
	_update_labels()
	_configure_dpad_navigation()

func _on_play_pressed() -> void:
	if not [Config.STYLE_PATH, Config.STYLE_NEXT_SYMBOL, Config.STYLE_RACE].has(_selected_style):
		return
	if _selected_style == Config.STYLE_RACE:
		_chaser_enabled = false
		_start_game()
		return
	_show_step(Step.VARIANT)

func _update_labels() -> void:
	_update_theme_preview()
	_update_style_cards()
	_update_variant_cards()
	_update_training_cards()

	var ui_idx: int = Config.LANG_CODES.find(Config.ui_language)
	if ui_idx < 0:
		ui_idx = 0
	lang_btn.text = Config.get_lang_display_name(temp_lang_idx, true, ui_idx)

	if temp_diff_idx < Config.DIFF_KEYS.size():
		diff_btn.text = tr(Config.DIFF_KEYS[temp_diff_idx])

	if temp_theme_idx < themes.size() and _theme_preview_loader != null:
		theme_btn.text = _theme_preview_loader.get_display_title(themes[temp_theme_idx])

	var speed_level := CHASER_SPEED_LEVELS[temp_chaser_speed_idx]
	_chaser_speed_button.text = tr(Config.CHASER_LEVEL_KEYS[speed_level])
	if _start_button != null:
		var style_ready := [Config.STYLE_PATH, Config.STYLE_NEXT_SYMBOL, Config.STYLE_RACE].has(_selected_style)
		_start_button.text = tr("play") if style_ready else tr("style_coming_soon")
	_apply_step_visibility()

func _update_style_cards() -> void:
	style_path_card.setup(">", _selected_title("style_path", Config.STYLE_PATH), tr("desc_maze"))
	style_next_card.setup("1", tr("style_next_symbol"), tr("hud_target_now"))
	style_race_card.setup(">>", tr("style_race"), tr("role_racer"))
	_apply_card_selection(style_path_card, _selected_style == Config.STYLE_PATH)
	_apply_card_selection(style_next_card, _selected_style == Config.STYLE_NEXT_SYMBOL)
	_apply_card_selection(style_race_card, _selected_style == Config.STYLE_RACE)

func _update_variant_cards() -> void:
	calm_card.setup("🙂", _selected_title("play_calm", "calm"), "")
	calm_card.call("clear_character_preview")
	_apply_card_selection(calm_card, false)

	_chaser_card.setup("", _selected_title("play_with_chaser", "chaser"), "")
	_apply_card_selection(_chaser_card, false)
	if _theme_preview_loader != null:
		var frames := _theme_preview_loader.chaser_frames.duplicate()
		if frames.is_empty() and _theme_preview_loader.chaser_texture != null:
			frames.append(_theme_preview_loader.chaser_texture)
		if not frames.is_empty():
			_chaser_card.call("set_character_preview", frames, _theme_preview_loader.chaser_fps)
		else:
			_chaser_card.call("clear_character_preview")
			_chaser_card.call("setup", "!", _selected_title("play_with_chaser", "chaser"), "")

func _update_training_cards() -> void:
	_setup_training_card(Config.TRAINING_NUMBERS, "training_numbers", "desc_numbers")
	_setup_training_card(Config.TRAINING_WORDS, "training_words", "desc_words")
	_setup_training_card(Config.TRAINING_LETTERS, "training_letters", "desc_letters")

func _setup_training_card(training: String, title_key: String, desc_key: String) -> void:
	var data := _training_cards.get(training, {}) as Dictionary
	var card := data.get("card", null) as Button
	if card == null:
		return
	card.call("clear_character_preview")
	card.call("setup", String(data.get("icon", "")), _selected_title(title_key, training), tr(desc_key))
	_apply_card_selection(card, _selected_training == training)

func _selected_title(title_key: String, value: String) -> String:
	return tr(title_key)

func _apply_card_selection(card: Button, selected: bool) -> void:
	if card == null:
		return
	card.call("set_selected", selected)

func _show_step(step: int) -> void:
	if step == Step.VARIANT and _selected_style == Config.STYLE_RACE:
		_start_game()
		return
	_step = step
	_apply_step_visibility()
	_configure_dpad_navigation()
	match _step:
		Step.SETUP:
			title_lbl.text = tr("menu_play_alone")
			style_path_card.call_deferred("grab_focus")
		Step.VARIANT:
			title_lbl.text = tr("setup_choose_variant")
			calm_card.call_deferred("grab_focus")

func _apply_step_visibility() -> void:
	if style_row != null:
		style_row.visible = _step == Step.SETUP
	if variant_row != null:
		variant_row.visible = _step == Step.VARIANT
	if _training_row != null:
		_training_row.visible = _step == Step.SETUP
	if config_grid != null:
		config_grid.visible = _step == Step.SETUP
	if _chaser_speed_row != null:
		_chaser_speed_row.visible = _step == Step.VARIANT
	if _start_button != null:
		_start_button.visible = _step == Step.SETUP

func _update_theme_preview() -> void:
	if themes.is_empty():
		return
	if temp_theme_idx != _last_theme_idx:
		_last_theme_idx = temp_theme_idx
		_theme_preview_loader = ThemeLoader.get_cached(themes[temp_theme_idx])

	if _player_preview != null and _theme_preview_loader != null:
		_player_preview.set_character(_theme_preview_loader.player_frames, _theme_preview_loader.player_fps)

	if _chaser_preview != null and _theme_preview_loader != null:
		_chaser_preview.modulate.a = 1.0 if _chaser_enabled else 0.35
		_chaser_preview.set_character(_theme_preview_loader.chaser_frames, _theme_preview_loader.chaser_fps)

func _start_game() -> void:
	if not [Config.STYLE_PATH, Config.STYLE_NEXT_SYMBOL, Config.STYLE_RACE].has(_selected_style):
		return
	if _selected_style == Config.STYLE_RACE:
		_chaser_enabled = false
	Config.learning_language = Config.LANG_CODES[temp_lang_idx]
	Config.theme_dir_name = themes[temp_theme_idx] if temp_theme_idx < themes.size() else _original_theme_dir_name
	Config.difficulty = temp_diff_idx
	Config.configure_single_player_session(
		_selected_style,
		_selected_training,
		_chaser_enabled,
		CHASER_SPEED_LEVELS[temp_chaser_speed_idx],
	)
	Config.save_settings()
	UIHelpers.go_to_scene_with_loading(get_tree(), "res://scenes/main.tscn")

func _on_back_pressed() -> void:
	Config.learning_language = _original_learning_language
	Config.theme_dir_name = _original_theme_dir_name
	Config.game_style = _original_game_style
	Config.training_type = _original_training_type
	Config.chaser_enabled = _original_chaser_enabled
	Config.chaser_level = _original_chaser_level
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _go_to_previous_step() -> void:
	match _step:
		Step.VARIANT:
			_show_step(Step.SETUP)
		_:
			_on_back_pressed()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_go_to_previous_step()

func _configure_dpad_navigation() -> void:
	var style_cards: Array[Button] = [style_path_card, style_next_card, style_race_card]
	var training_cards := _training_card_buttons()
	var selected_style := _selected_style_card()
	var selected_training := _selected_training_card()

	_configure_card_row_navigation(
		style_cards,
		null,
		selected_training
	)
	_configure_card_row_navigation(
		training_cards,
		selected_style,
		diff_btn
	)
	_configure_card_row_navigation(
		[calm_card, _chaser_card],
		null,
		_chaser_speed_button
	)

	_set_vertical_focus(diff_btn, selected_training, lang_btn)
	_set_vertical_focus(lang_btn, diff_btn, theme_btn)
	_set_vertical_focus(theme_btn, lang_btn, _start_button)
	_set_vertical_focus(_start_button, theme_btn, _start_button)
	_set_vertical_focus(_chaser_speed_button, calm_card, _chaser_speed_button)

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

func _valid_buttons(items: Array) -> Array[Button]:
	var result: Array[Button] = []
	for item in items:
		if item is Button and is_instance_valid(item):
			result.append(item)
	return result

func _training_card_buttons() -> Array[Button]:
	var cards: Array[Button] = []
	for training in _training_order:
		var data := _training_cards.get(training, {}) as Dictionary
		var card := data.get("card", null) as Button
		if card != null:
			cards.append(card)
	return cards

func _selected_style_card() -> Button:
	match _selected_style:
		Config.STYLE_NEXT_SYMBOL:
			return style_next_card
		Config.STYLE_RACE:
			return style_race_card
		_:
			return style_path_card

func _selected_training_card() -> Button:
	var data := _training_cards.get(_selected_training, {}) as Dictionary
	var card := data.get("card", null) as Button
	if card != null:
		return card
	var cards := _training_card_buttons()
	return cards[0] if not cards.is_empty() else null

func _set_vertical_focus(control: Control, top: Control, bottom: Control) -> void:
	if control == null:
		return
	if top != null:
		control.focus_neighbor_top = control.get_path_to(top)
	if bottom != null:
		control.focus_neighbor_bottom = control.get_path_to(bottom)
