extends Control

var temp_mode: int
var temp_diff: int
var temp_theme_idx: int
var temp_lang_idx: int
var temp_voice: bool
var themes: Array[String] = []

# Mode/diff/lang keys for Locale.t()
const MODE_KEYS = ["mode_normal", "mode_numbers", "mode_letters", "mode_words"]
const DIFF_KEYS = ["diff_very_easy", "diff_easy", "diff_medium", "diff_hard"]
const LANG_KEYS = ["lang_auto", "lang_english", "lang_czech"]
const LANG_CODES = ["auto", "en", "cs"]

func _ready() -> void:
	# Load current config state into temp variables
	temp_mode = Config.game_mode
	temp_diff = Config.difficulty
	themes = Config.get_available_themes()
	
	temp_theme_idx = themes.find(Config.theme_dir_name)
	if temp_theme_idx < 0:
		temp_theme_idx = 0
	
	temp_lang_idx = LANG_CODES.find(Config.language)
	if temp_lang_idx < 0:
		temp_lang_idx = 0
		
	temp_voice = Config.voice_hints
		
	# Wire up buttons
	_setup_cycling_button(%ModeButton, func(dir): _cycle_mode(dir))
	_setup_cycling_button(%DiffButton, func(dir): _cycle_diff(dir))
	_setup_cycling_button(%LangButton, func(dir): _cycle_lang(dir))
	_setup_cycling_button(%ThemeButton, func(dir): _cycle_theme(dir))
	_setup_cycling_button(%VoiceButton, func(dir): _cycle_voice(dir))
	
	%SaveButton.pressed.connect(_on_save_pressed)
	
	_update_labels()
	_update_static_labels()
	
	# Focus first interactive element for TV
	%ModeButton.grab_focus()

func _setup_cycling_button(btn: Button, cycle_func: Callable) -> void:
	# Find relative arrows based on button name
	var base_name = btn.name.replace("Button", "")
	var left_arrow: Label = get_node_or_null("%%%sLeftArrow" % base_name)
	var right_arrow: Label = get_node_or_null("%%%sRightArrow" % base_name)
	
	if left_arrow: left_arrow.modulate.a = 0.0
	if right_arrow: right_arrow.modulate.a = 0.0
	
	# Show arrows when focused
	btn.focus_entered.connect(func():
		if left_arrow: left_arrow.modulate.a = 1.0
		if right_arrow: right_arrow.modulate.a = 1.0
	)
	
	# Hide arrows when focus is lost
	btn.focus_exited.connect(func():
		if left_arrow: left_arrow.modulate.a = 0.0
		if right_arrow: right_arrow.modulate.a = 0.0
	)
	
	# Cycle on click
	btn.pressed.connect(func(): cycle_func.call(1))
	
	# Cycle on D-pad Left/Right
	btn.gui_input.connect(func(event: InputEvent):
		if event is InputEventKey or event is InputEventJoypadButton:
			if event.is_pressed():
				if event.is_action("ui_left"):
					cycle_func.call(-1)
					get_viewport().set_input_as_handled()
				elif event.is_action("ui_right"):
					cycle_func.call(1)
					get_viewport().set_input_as_handled()
	)

func _cycle_mode(dir: int) -> void:
	temp_mode = (temp_mode + dir + MODE_KEYS.size()) % MODE_KEYS.size()
	_update_labels()

func _cycle_diff(dir: int) -> void:
	temp_diff = (temp_diff + dir + DIFF_KEYS.size()) % DIFF_KEYS.size()
	_update_labels()

func _cycle_lang(dir: int) -> void:
	temp_lang_idx = (temp_lang_idx + dir + LANG_KEYS.size()) % LANG_KEYS.size()
	# Temporarily set the language so Locale.t() previews the new language
	Config.language = LANG_CODES[temp_lang_idx]
	_update_labels()
	_update_static_labels()

func _cycle_theme(dir: int) -> void:
	temp_theme_idx = (temp_theme_idx + dir + themes.size()) % themes.size()
	_update_labels()

func _cycle_voice(_dir: int) -> void:
	temp_voice = !temp_voice
	_update_labels()

func _update_labels() -> void:
	%ModeButton.text = Locale.t(MODE_KEYS[temp_mode])
	%DiffButton.text = Locale.t(DIFF_KEYS[temp_diff])
	
	# For "Auto", show the detected language in parentheses
	var lang_text := Locale.t(LANG_KEYS[temp_lang_idx])
	if temp_lang_idx == 0:
		# Show which language auto resolves to
		var detected := Config.get_effective_language()
		var det_key := "lang_english" if detected == "en" else "lang_czech"
		lang_text += " (%s)" % Locale.t(det_key)
	%LangButton.text = lang_text
	
	%ThemeButton.text = themes[temp_theme_idx].capitalize()
	%VoiceButton.text = Locale.t("on") if temp_voice else Locale.t("off")

func _update_static_labels() -> void:
	# Update row titles and other static text to current language
	%Title.text = Locale.t("settings_title")
	%ModeTitle.text = Locale.t("setting_mode")
	%DiffTitle.text = Locale.t("setting_diff")
	%LangTitle.text = Locale.t("setting_lang")
	%ThemeTitle.text = Locale.t("setting_theme")
	%VoiceTitle.text = Locale.t("setting_voice")
	%SaveButton.text = Locale.t("save_return")

func _on_save_pressed() -> void:
	# Save temp variables back to singleton
	Config.game_mode = temp_mode
	Config.difficulty = temp_diff
	Config.language = LANG_CODES[temp_lang_idx]
	Config.theme_dir_name = themes[temp_theme_idx]
	Config.voice_hints = temp_voice
	Config.save_settings()
	
	# Return to Main Menu
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
