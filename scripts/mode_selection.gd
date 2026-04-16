class_name ModeSelection
extends Control

@onready var maze_card: Button = %MazeCard
@onready var numbers_card: Button = %NumbersCard
@onready var letters_card: Button = %LettersCard
@onready var words_card: Button = %WordsCard
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
var themes: Array[String] = []
var _theme_preview_loader: ThemeLoader = null
var _last_theme_idx: int = -1

## Original values stored on enter so we can restore on cancel.
var _original_learning_language: String = ""
var _original_theme_dir_name: String = ""

func _ready() -> void:
	# Warp mouse off-screen
	Input.warp_mouse(Vector2(-1, -1))
	
	if Config:
		_original_learning_language = Config.learning_language
		_original_theme_dir_name = Config.theme_dir_name
		
		temp_lang_idx = Config.LANG_CODES.find(Config.learning_language)
		if temp_lang_idx < 0: temp_lang_idx = 0
		
		themes = ThemeLoader.get_available_themes()
		temp_theme_idx = themes.find(Config.theme_dir_name)
		if temp_theme_idx < 0: temp_theme_idx = 0
		
		temp_diff_idx = Config.difficulty
	
	# Connect cards
	numbers_card.pressed.connect(func(): _start_game(Config.GameMode.NUMBERS))
	letters_card.pressed.connect(func(): _start_game(Config.GameMode.LETTERS))
	words_card.pressed.connect(func(): _start_game(Config.GameMode.WORDS))
	maze_card.pressed.connect(func(): _start_game(Config.GameMode.NORMAL))
	
	# Explicit Focus Routing for bullet-proof D-pad navigation
	var cards: Array[Button] = [numbers_card, words_card, letters_card]
	if is_layout_rtl():
		cards.reverse()
		
	for i in range(cards.size()):
		var c = cards[i]
		var prev = cards[(i - 1 + cards.size()) % cards.size()]
		var next = cards[(i + 1) % cards.size()]
		c.focus_neighbor_left = c.get_path_to(prev)
		c.focus_neighbor_right = c.get_path_to(next)
		c.focus_neighbor_bottom = c.get_path_to(maze_card)
	
	maze_card.focus_neighbor_top = maze_card.get_path_to(words_card)
	maze_card.focus_neighbor_left = maze_card.get_path_to(maze_card)
	maze_card.focus_neighbor_right = maze_card.get_path_to(maze_card)
	maze_card.focus_neighbor_bottom = maze_card.get_path_to(diff_btn)

	lang_btn.pressed.connect(func(): _cycle_lang(1))
	theme_btn.pressed.connect(func(): _cycle_theme(1))
	diff_btn.pressed.connect(func(): _cycle_diff(1))
	
	# D-pad for cycling
	_setup_cycling(lang_btn, _cycle_lang)
	_setup_cycling(theme_btn, _cycle_theme)
	_setup_cycling(diff_btn, _cycle_diff)
	
	# Show arrows only on focus
	_setup_arrow_visibility(lang_btn, lang_left, lang_right)
	_setup_arrow_visibility(theme_btn, theme_left, theme_right)
	_setup_arrow_visibility(diff_btn, diff_left, diff_right)
	
	_localize_ui()
	_update_labels()
	
	# Apply styles for non-card buttons
	UIHelpers.apply_style_to_button(lang_btn, UIColors.YELLOW)
	UIHelpers.apply_style_to_button(theme_btn, UIColors.YELLOW)
	UIHelpers.apply_style_to_button(diff_btn, UIColors.YELLOW)
	
	# Responsive D-pad layout 
	UIHelpers.apply_dpad_layout($CenterContainer, Config.on_screen_controls)
	
	# Initial focus on Words Card in the middle
	words_card.call_deferred("grab_focus")

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
	title_lbl.text = tr("choose_adventure")
	
	# Setup cards with placeholders
	numbers_card.setup("123", tr("mode_numbers"), tr("desc_numbers"))
	letters_card.setup("ABC", tr("mode_letters"), tr("desc_letters"))
	words_card.setup("W", tr("mode_words"), tr("desc_words"))
	maze_card.setup("", tr("mode_normal"), "")
	
	lang_title_lbl.text = tr("setting_learning_lang")
	theme_title_lbl.text = tr("setting_theme")
	diff_title_lbl.text = tr("setting_diff")

func _cycle_lang(dir: int) -> void:
	temp_lang_idx = (temp_lang_idx + dir + Config.LANG_CODES.size()) % Config.LANG_CODES.size()
	_update_labels()

func _cycle_theme(dir: int) -> void:
	if themes.size() == 0: return
	temp_theme_idx = (temp_theme_idx + dir + themes.size()) % themes.size()
	_update_labels()

func _cycle_diff(dir: int) -> void:
	if Config.DIFF_KEYS.size() == 0: return
	temp_diff_idx = (temp_diff_idx + dir + Config.DIFF_KEYS.size()) % Config.DIFF_KEYS.size()
	_update_labels()

func _update_labels() -> void:
	# Language
	var ui_idx: int = Config.LANG_CODES.find(Config.ui_language)
	if ui_idx < 0: ui_idx = 0
	lang_btn.text = Config.get_lang_display_name(temp_lang_idx, true, ui_idx)
	
	# Difficulty
	if temp_diff_idx < Config.DIFF_KEYS.size():
		diff_btn.text = tr(Config.DIFF_KEYS[temp_diff_idx])
	
	# Theme
	if temp_theme_idx < themes.size():
		if temp_theme_idx != _last_theme_idx:
			_last_theme_idx = temp_theme_idx
			_theme_preview_loader = ThemeLoader.get_cached(themes[temp_theme_idx])
			
		theme_btn.text = _theme_preview_loader.get_display_title(themes[temp_theme_idx])
		
		if _player_preview:
			_player_preview.set_character(_theme_preview_loader.player_frames, _theme_preview_loader.player_fps)
			
		if _chaser_preview:
			if Config.chaser_level > 0:
				_chaser_preview.modulate.a = 1.0
				_chaser_preview.set_character(_theme_preview_loader.chaser_frames, _theme_preview_loader.chaser_fps)
			else:
				_chaser_preview.modulate.a = 0.0

func _start_game(mode: int) -> void:
	Config.game_mode = mode
	# Commit temp selections to Config only when the user starts a game
	Config.learning_language = Config.LANG_CODES[temp_lang_idx]
	Config.theme_dir_name = themes[temp_theme_idx] if temp_theme_idx < themes.size() else _original_theme_dir_name
	Config.difficulty = temp_diff_idx
	Config.save_settings()
	UIHelpers.go_to_scene_with_loading(get_tree(), "res://scenes/main.tscn")

func _on_back_pressed() -> void:
	# Restore original values — user cancelled, so don't persist cycling changes
	Config.learning_language = _original_learning_language
	Config.theme_dir_name = _original_theme_dir_name
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()
