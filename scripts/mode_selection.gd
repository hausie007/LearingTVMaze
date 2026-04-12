extends Control

@onready var maze_card: Button = %MazeCard
@onready var numbers_card: Button = %NumbersCard
@onready var letters_card: Button = %LettersCard
@onready var words_card: Button = %WordsCard
@onready var lang_btn: Button = %LangButton
@onready var theme_btn: Button = %ThemeButton

@onready var title_lbl: Label = %TitleLabel
@onready var lang_title_lbl: Label = %LangTitleLabel
@onready var theme_title_lbl: Label = %ThemeTitleLabel

@onready var lang_left: Label = %LangLeftArrow
@onready var lang_right: Label = %LangRightArrow
@onready var theme_left: Label = %ThemeLeftArrow
@onready var theme_right: Label = %ThemeRightArrow

@onready var _player_preview: CharacterPreview = %PlayerAnchor
@onready var _chaser_preview: CharacterPreview = %ChaserAnchor

const LANG_KEYS = ["lang_auto", "lang_english", "lang_czech", "lang_german", "lang_spanish", "lang_french", "lang_portuguese", "lang_vietnamese", "lang_turkish", "lang_italian", "lang_polish", "lang_swedish", "lang_norwegian", "lang_dutch", "lang_ukrainian", "lang_finnish", "lang_danish", "lang_hungarian", "lang_romanian", "lang_greek"]
const LANG_CODES = ["auto", "en", "cs", "de", "es", "fr", "pt", "vi", "tr", "it", "pl", "sv", "nb", "nl", "uk", "fi", "da", "hu", "ro", "el"]

var temp_lang_idx: int = 0
var temp_theme_idx: int = 0
var themes: Array[String] = []
var _theme_preview_loader: ThemeLoader = null
var _last_theme_idx: int = -1

func _ready() -> void:
	# Warp mouse off-screen
	Input.warp_mouse(Vector2(-1, -1))
	
	if Config:
		temp_lang_idx = LANG_CODES.find(Config.learning_language)
		if temp_lang_idx < 0: temp_lang_idx = 0
		
		themes = ThemeLoader.get_available_themes()
		temp_theme_idx = themes.find(Config.theme_dir_name)
		if temp_theme_idx < 0: temp_theme_idx = 0
	
	# Connect cards
	numbers_card.pressed.connect(func(): _start_game(Config.GameMode.NUMBERS))
	letters_card.pressed.connect(func(): _start_game(Config.GameMode.LETTERS))
	words_card.pressed.connect(func(): _start_game(Config.GameMode.WORDS))
	maze_card.pressed.connect(func(): _start_game(Config.GameMode.NORMAL))
	
	lang_btn.pressed.connect(func(): _cycle_lang(1))
	theme_btn.pressed.connect(func(): _cycle_theme(1))
	
	# D-pad for cycling
	_setup_cycling(lang_btn, _cycle_lang)
	_setup_cycling(theme_btn, _cycle_theme)
	
	# Show arrows only on focus
	_setup_arrow_visibility(lang_btn, lang_left, lang_right)
	_setup_arrow_visibility(theme_btn, theme_left, theme_right)
	
	_localize_ui()
	_update_labels()
	
	# Apply styles for non-card buttons
	UIHelpers.apply_style_to_button(lang_btn, UIColors.YELLOW)
	UIHelpers.apply_style_to_button(theme_btn, UIColors.YELLOW)
	
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

func _cycle_lang(dir: int) -> void:
	temp_lang_idx = (temp_lang_idx + dir + LANG_CODES.size()) % LANG_CODES.size()
	Config.learning_language = LANG_CODES[temp_lang_idx]
	_update_labels()

func _cycle_theme(dir: int) -> void:
	if themes.size() == 0: return
	temp_theme_idx = (temp_theme_idx + dir + themes.size()) % themes.size()
	Config.theme_dir_name = themes[temp_theme_idx]
	_update_labels()

func _update_labels() -> void:
	# Language
	if temp_lang_idx == 0:
		var ui_lang = Config.get_effective_ui_language()
		var ui_idx = LANG_CODES.find(ui_lang)
		var ui_name = tr(LANG_KEYS[ui_idx])
		lang_btn.text = tr("lang_auto") + " (" + ui_name + ")"
	else:
		lang_btn.text = tr(LANG_KEYS[temp_lang_idx])
	
	# Theme
	if temp_theme_idx < themes.size():
		if temp_theme_idx != _last_theme_idx:
			_last_theme_idx = temp_theme_idx
			_theme_preview_loader = ThemeLoader.new()
			_theme_preview_loader.load_theme(themes[temp_theme_idx])
			
		var display_title: String = themes[temp_theme_idx].capitalize()
		if _theme_preview_loader and _theme_preview_loader.manifest.has("title"):
			var manifest_title = _theme_preview_loader.manifest["title"]
			if manifest_title is String and not manifest_title.is_empty():
				display_title = manifest_title
		theme_btn.text = display_title
		
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
	Config.save_settings()
	UIHelpers.go_to_scene_with_loading(get_tree(), "res://scenes/main.tscn")

func _on_back_pressed() -> void:
	Config.save_settings()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()
