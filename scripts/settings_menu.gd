extends Control

var temp_mode: int
var temp_diff: int
var temp_theme_idx: int
var temp_lang_idx: int
var temp_voice: bool
var themes: Array[String] = []

# Mode/diff/lang keys for tr()
const MODE_KEYS = ["mode_normal", "mode_numbers", "mode_letters", "mode_words"]
const DIFF_KEYS = ["diff_very_easy", "diff_easy", "diff_medium", "diff_hard"]
const LANG_KEYS = ["lang_auto", "lang_english", "lang_czech", "lang_german", "lang_spanish", "lang_french", "lang_portuguese", "lang_indonesian", "lang_vietnamese", "lang_turkish", "lang_italian", "lang_polish"]
const LANG_CODES = ["auto", "en", "cs", "de", "es", "fr", "pt", "id", "vi", "tr", "it", "pl"]
var _is_saving: bool = false
var _tts_warning_label: Label = null

func _ready() -> void:
	# Load current config state into temp variables
	if Config:
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
	
	if has_node("%SaveButton"):
		%SaveButton.pressed.connect(_on_save_pressed)
	
	_update_labels()
	_update_static_labels()
	
	# Focus first interactive element for TV
	if has_node("%ModeButton"):
		%ModeButton.grab_focus()

func _create_tts_warning() -> void:
	if _tts_warning_label: return
	
	# Add as a child of the button so it doesn't affect the parent container layout
	var voice_btn = get_node_or_null("%VoiceButton")
	if voice_btn:
		_tts_warning_label = Label.new()
		_tts_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_tts_warning_label.add_theme_font_size_override("font_size", 24) # Tiny bit bigger
		_tts_warning_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tts_warning_label.visible = false
		
		voice_btn.add_child(_tts_warning_label)
		
		# Overlay it beneath the button using anchors
		_tts_warning_label.anchors_preset = Control.PRESET_CENTER_BOTTOM
		_tts_warning_label.anchor_left = 0.0
		_tts_warning_label.anchor_right = 1.0
		_tts_warning_label.anchor_top = 1.0
		_tts_warning_label.anchor_bottom = 1.0
		_tts_warning_label.grow_vertical = Control.GROW_DIRECTION_BOTH
		_tts_warning_label.offset_top = 25 # More below, not touching the button!

func _input(event: InputEvent) -> void:
	if _is_saving: return
	
	if event.is_action_pressed("ui_cancel"):
		# Set handled BEFORE calling save, to stop bubbling
		get_viewport().set_input_as_handled()
		_on_save_pressed()

func _setup_cycling_button(btn: Button, cycle_func: Callable) -> void:
	if not btn: return
	
	# Find relative arrows based on button name
	var base_name = btn.name.replace("Button", "")
	var left_arrow = get_node_or_null("%%%sLeftArrow" % base_name)
	var right_arrow = get_node_or_null("%%%sRightArrow" % base_name)
	
	if left_arrow: left_arrow.modulate.a = 0.0
	if right_arrow: right_arrow.modulate.a = 0.0
	
	# Show arrows when focused
	btn.focus_entered.connect(func():
		if is_instance_valid(left_arrow): left_arrow.modulate.a = 1.0
		if is_instance_valid(right_arrow): right_arrow.modulate.a = 1.0
	)
	
	# Hide arrows when focus is lost
	btn.focus_exited.connect(func():
		if is_instance_valid(left_arrow): left_arrow.modulate.a = 0.0
		if is_instance_valid(right_arrow): right_arrow.modulate.a = 0.0
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
	if MODE_KEYS.size() == 0: return
	temp_mode = (temp_mode + dir + MODE_KEYS.size()) % MODE_KEYS.size()
	_update_labels()

func _cycle_diff(dir: int) -> void:
	if DIFF_KEYS.size() == 0: return
	temp_diff = (temp_diff + dir + DIFF_KEYS.size()) % DIFF_KEYS.size()
	_update_labels()

func _cycle_lang(dir: int) -> void:
	if LANG_KEYS.size() == 0: return
	temp_lang_idx = (temp_lang_idx + dir + LANG_KEYS.size()) % LANG_KEYS.size()
	# Temporarily set the language so tr() previews the new language
	if Config and temp_lang_idx < LANG_CODES.size():
		Config.language = LANG_CODES[temp_lang_idx]
		TranslationServer.set_locale(Config.get_effective_language())
	_update_labels()
	_update_static_labels()

func _cycle_theme(dir: int) -> void:
	if themes.size() == 0: return
	temp_theme_idx = (temp_theme_idx + dir + themes.size()) % themes.size()
	_update_labels()

func _cycle_voice(_dir: int) -> void:
	temp_voice = !temp_voice
	_update_labels()

func _update_labels() -> void:
	if has_node("%ModeButton") and temp_mode < MODE_KEYS.size():
		%ModeButton.text = tr(MODE_KEYS[temp_mode])
	if has_node("%DiffButton") and temp_diff < DIFF_KEYS.size():
		%DiffButton.text = tr(DIFF_KEYS[temp_diff])
	
	# For "Auto", show the detected language in parentheses
	var lang_text := ""
	if temp_lang_idx < LANG_KEYS.size():
		lang_text = tr(LANG_KEYS[temp_lang_idx])
		
	if temp_lang_idx == 0 and Config:
		# Show which language auto resolves to
		var detected := Config.get_effective_language()
		var det_idx := LANG_CODES.find(detected)
		if det_idx > 0 and det_idx < LANG_KEYS.size():
			lang_text += " (%s)" % tr(LANG_KEYS[det_idx])
			
	if has_node("%LangButton"):
		%LangButton.text = lang_text
	
	if has_node("%ThemeButton") and temp_theme_idx < themes.size():
		%ThemeButton.text = themes[temp_theme_idx].capitalize()
	
	if has_node("%VoiceButton"):
		%VoiceButton.text = tr("on") if temp_voice else tr("off")
		
		# Instant check using Config's background cache
		var current_lang_code = LANG_CODES[temp_lang_idx]
		var is_available = Config.is_tts_available(current_lang_code) if Config else false
		
		if not is_available:
			%VoiceButton.modulate = Color(1, 1, 1, 0.4) # Dimmed
			if not _tts_warning_label: _create_tts_warning()
			if _tts_warning_label: 
				_tts_warning_label.visible = true
				_tts_warning_label.text = tr("tts_missing")
				_tts_warning_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4)) # Soft red
		else:
			%VoiceButton.modulate = Color(1, 1, 1, 1.0) # Full
			if not _tts_warning_label: _create_tts_warning()
			if _tts_warning_label:
				_tts_warning_label.visible = true
				_tts_warning_label.text = tr("tts_ready")
				_tts_warning_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4)) # Green

func _update_static_labels() -> void:
	# Update row titles and other static text to current language
	if has_node("%Title"): %Title.text = tr("settings_title")
	if has_node("%ModeTitle"): %ModeTitle.text = tr("setting_mode")
	if has_node("%DiffTitle"): %DiffTitle.text = tr("setting_diff")
	if has_node("%LangTitle"): %LangTitle.text = tr("setting_lang")
	if has_node("%ThemeTitle"): %ThemeTitle.text = tr("setting_theme")
	if has_node("%VoiceTitle"): %VoiceTitle.text = tr("setting_voice")
	if has_node("%SaveButton"): %SaveButton.text = tr("save_return")

func _on_save_pressed() -> void:
	if _is_saving: return
	_is_saving = true
	
	# Save temp variables back to singleton
	if Config:
		Config.game_mode = temp_mode
		Config.difficulty = temp_diff
		if temp_lang_idx < LANG_CODES.size():
			Config.language = LANG_CODES[temp_lang_idx]
		if temp_theme_idx < themes.size():
			Config.theme_dir_name = themes[temp_theme_idx]
		Config.voice_hints = temp_voice
		Config.save_settings()
		TranslationServer.set_locale(Config.get_effective_language())
	
	# Return to Main Menu
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
