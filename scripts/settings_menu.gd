extends Control

var temp_mode: int
var temp_diff: int
var temp_theme_idx: int
var temp_lang_idx: int
var temp_voice: bool
var temp_chaser_level: int
var temp_perf: bool
var themes: Array[String] = []

# Mode/diff/lang keys for tr()
const MODE_KEYS = ["mode_normal", "mode_numbers", "mode_letters", "mode_words"]
const DIFF_KEYS = ["diff_very_easy", "diff_easy", "diff_medium", "diff_hard", "diff_very_hard", "diff_insane", "diff_unbelievable"]
const LANG_KEYS = ["lang_auto", "lang_english", "lang_czech", "lang_german", "lang_spanish", "lang_french", "lang_portuguese", "lang_vietnamese", "lang_turkish", "lang_italian", "lang_polish", "lang_swedish", "lang_norwegian", "lang_dutch", "lang_ukrainian", "lang_finnish", "lang_danish", "lang_hungarian", "lang_romanian", "lang_greek"]
const LANG_CODES = ["auto", "en", "cs", "de", "es", "fr", "pt", "vi", "tr", "it", "pl", "sv", "nb", "nl", "uk", "fi", "da", "hu", "ro", "el"]
const CHASER_LEVEL_KEYS = ["chaser_off", "chaser_slow", "chaser_medium", "chaser_fast", "chaser_turbo"]
var _is_saving: bool = false
var _tts_warning_label: Label = null

## Original language stored on enter so we can preview without mutating Config.
var _original_language: String = ""

# Animated Theme Preview
var _theme_preview_loader: ThemeLoader = null
var _theme_icon_rect: TextureRect = null
var _anim_time: float = 0.0
var _last_theme_idx: int = -1

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_save_pressed()

func _ready() -> void:
	# Warp mouse off-screen to prevent phantom hover highlights on TV
	Input.warp_mouse(Vector2(-1, -1))
	
	# Load current config state into temp variables
	if Config:
		TTS.refresh_cache() # Ensure we have latest OS voice state
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
		temp_chaser_level = Config.chaser_level
		temp_perf = Config.performance_mode
		_original_language = Config.language
		# Listen for async TTS completion
		if not TTS.status_changed.is_connected(_update_labels):
			TTS.status_changed.connect(_update_labels)
		
	# Wire up buttons
	_setup_cycling_button(%ModeButton, func(dir): _cycle_mode(dir))
	_setup_cycling_button(%DiffButton, func(dir): _cycle_diff(dir))
	_setup_cycling_button(%LangButton, func(dir): _cycle_lang(dir))
	_setup_cycling_button(%ThemeButton, func(dir): _cycle_theme(dir))
	_setup_cycling_button(%VoiceButton, func(dir): _cycle_voice(dir))
	_setup_cycling_button(%ChaserButton, func(dir): _cycle_chaser(dir))
	_setup_cycling_button(%PerfButton, func(dir): _cycle_perf(dir))
	
	# Add animated character preview next to the theme arrow
	# We attach it to the arrow (which is a Label, not a Container)
	# so it's taken out of the HBox flow and doesn't break the layout centering.
	var theme_arrow = get_node_or_null("%ThemeRightArrow")
	if theme_arrow:
		_theme_icon_rect = TextureRect.new()
		_theme_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_theme_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_theme_icon_rect.custom_minimum_size = Vector2(80, 80)
		theme_arrow.add_child(_theme_icon_rect)
		_theme_icon_rect.position = Vector2(50, -15) # Offset to the right
	
	_update_labels()
	_update_static_labels()
	
	# Focus first interactive element for TV
	if has_node("%ModeButton"):
		%ModeButton.call_deferred("grab_focus")


func _process(delta: float) -> void:
	if _theme_icon_rect and _theme_preview_loader:
		_anim_time += delta
		var frames = _theme_preview_loader.player_frames
		if frames and frames.size() > 1:
			var fps = _theme_preview_loader.player_fps
			var idx = int(_anim_time * fps) % frames.size()
			_theme_icon_rect.texture = frames[idx]
		else:
			_theme_icon_rect.texture = _theme_preview_loader.player_texture

func _trigger_warmup() -> void:
	# Only warm up if voice hints are currently toggled ON in the UI
	if temp_voice:
		var lang_name := ""
		var preview_lang := _get_preview_language()
		if temp_lang_idx == 0: # Auto case
			var detected := Config.get_auto_detected_language()
			var det_idx := LANG_CODES.find(detected)
			if det_idx > 0 and det_idx < LANG_KEYS.size():
				lang_name = tr("lang_auto") + " - " + tr(LANG_KEYS[det_idx]).to_lower()
			else:
				lang_name = tr("lang_auto")
		else:
			lang_name = tr(LANG_KEYS[temp_lang_idx])
		
		if not lang_name.is_empty():
			TTS.warm_up(preview_lang, lang_name)


## Return the effective language for the currently selected temp_lang_idx.
## Does NOT mutate Config.language.
func _get_preview_language() -> String:
	if temp_lang_idx < LANG_CODES.size():
		var code: String = LANG_CODES[temp_lang_idx]
		if code == "auto":
			return Config.get_auto_detected_language()
		if code in Config.SUPPORTED_LANGS:
			return code
	return "en"


func _on_tts_init_warmup() -> void:
	if TTS.tts_ready:
		_trigger_warmup()


func _create_tts_warning() -> void:
	if _tts_warning_label: return
	
	# Add as a child of the button so it doesn't affect the parent container layout
	var voice_btn = get_node_or_null("%VoiceButton")
	if voice_btn:
		_tts_warning_label = Label.new()
		_tts_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_tts_warning_label.add_theme_font_size_override("font_size", 22) # Slightly more "natural" size
		_tts_warning_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tts_warning_label.visible = false
		
		# Set semi-transparent color for a "hint" look
		_tts_warning_label.modulate.a = 0.8
		
		voice_btn.add_child(_tts_warning_label)
		
		# Overlay it beneath the button using anchors
		_tts_warning_label.anchors_preset = Control.PRESET_CENTER_BOTTOM
		_tts_warning_label.anchor_left = 0.0
		_tts_warning_label.anchor_right = 1.0
		_tts_warning_label.anchor_top = 1.0
		_tts_warning_label.anchor_bottom = 1.0
		_tts_warning_label.grow_vertical = Control.GROW_DIRECTION_BOTH
		_tts_warning_label.offset_top = 30 # Balanced for compact layout

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
	
	var focus_color: Color = UIColors.BLUE # Blue for game modifiers
	if btn.name in ["ThemeButton", "LangButton", "VoiceButton", "PerfButton"]:
		focus_color = UIColors.YELLOW # Yellow for app modifiers
		
	UIHelpers.apply_style_to_button(btn, focus_color)


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
	# Preview the language via TranslationServer without mutating Config.language
	if temp_lang_idx < LANG_CODES.size():
		var preview_lang := _get_preview_language()
		TranslationServer.set_locale(preview_lang)
		_trigger_warmup()
	_update_labels()
	_update_static_labels()

func _cycle_theme(dir: int) -> void:
	if themes.size() == 0: return
	temp_theme_idx = (temp_theme_idx + dir + themes.size()) % themes.size()
	_update_labels()

func _cycle_voice(_dir: int) -> void:
	temp_voice = !temp_voice
	_update_labels()
	if temp_voice:
		_trigger_warmup()

func _cycle_chaser(dir: int) -> void:
	if CHASER_LEVEL_KEYS.size() == 0: return
	temp_chaser_level = (temp_chaser_level + dir + CHASER_LEVEL_KEYS.size()) % CHASER_LEVEL_KEYS.size()
	_update_labels()

func _cycle_perf(_dir: int) -> void:
	temp_perf = !temp_perf
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
		# Show which language auto resolves to system-wide
		var detected := Config.get_auto_detected_language()
		var det_idx := LANG_CODES.find(detected)
		if det_idx > 0 and det_idx < LANG_KEYS.size():
			lang_text += " (%s)" % tr(LANG_KEYS[det_idx])
			
	if has_node("%LangButton"):
		%LangButton.text = lang_text
	
	if has_node("%ChaserButton") and temp_chaser_level < CHASER_LEVEL_KEYS.size():
		%ChaserButton.text = tr(CHASER_LEVEL_KEYS[temp_chaser_level])
		
	if has_node("%ThemeButton") and temp_theme_idx < themes.size():
		# Update theme preview icon loader when theme changes
		if _theme_icon_rect and temp_theme_idx != _last_theme_idx:
			_last_theme_idx = temp_theme_idx
			_theme_preview_loader = ThemeLoader.new()
			# Always explicitly pass the theme name to force a clean load,
			# even for "default", to prevent it falling back to Config's active theme.
			_theme_preview_loader.load_theme(themes[temp_theme_idx])
			
		var display_title: String = themes[temp_theme_idx].capitalize()
		if _theme_preview_loader and _theme_preview_loader.manifest.has("title"):
			var manifest_title = _theme_preview_loader.manifest["title"]
			if manifest_title is String and not manifest_title.is_empty():
				display_title = manifest_title
				
		%ThemeButton.text = display_title
	
	if has_node("%VoiceButton"):
		# Ensure warning label exists
		if not _tts_warning_label: _create_tts_warning()
		
		# If scan isn't done yet, show "Checking..." in the info label
		if not TTS.tts_ready:
			%VoiceButton.text = tr("on") if temp_voice else tr("off")
			%VoiceButton.disabled = true
			%VoiceButton.modulate.a = 0.5
			if _tts_warning_label:
				_tts_warning_label.visible = true
				_tts_warning_label.text = tr("checking_tts")
				_tts_warning_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8)) # Neutral grey
			return

		# Instant check using TTS voice cache
		var current_lang_code = LANG_CODES[temp_lang_idx]
		var is_available = TTS.is_available(current_lang_code)
		
		# UI logic: if not available, force show as "off" but don't overwrite user's temp_voice preference
		var effective_voice_state = temp_voice and is_available
		%VoiceButton.text = tr("on") if effective_voice_state else tr("off")
		%VoiceButton.disabled = not is_available
		
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

	if has_node("%ChaserButton") and temp_chaser_level < CHASER_LEVEL_KEYS.size():
		%ChaserButton.text = tr(CHASER_LEVEL_KEYS[temp_chaser_level])

	if has_node("%PerfButton"):
		%PerfButton.text = tr("quality_high") if not temp_perf else tr("quality_standard")

func _update_static_labels() -> void:
	# Update row titles and other static text to current language
	if has_node("%Title"): 
		%Title.text = tr("settings_title")
		%Title.add_theme_color_override("font_color", UIColors.YELLOW) # Match Settings Button
	
	if has_node("%ModeTitle"): %ModeTitle.text = tr("setting_mode")
	if has_node("%DiffTitle"): %DiffTitle.text = tr("setting_diff")
	if has_node("%LangTitle"): %LangTitle.text = tr("setting_lang")
	if has_node("%ThemeTitle"): %ThemeTitle.text = tr("setting_theme")
	if has_node("%VoiceTitle"): %VoiceTitle.text = tr("setting_voice")
	if has_node("%ChaserTitle"): %ChaserTitle.text = tr("setting_chaser")
	if has_node("%PerfTitle"): %PerfTitle.text = tr("setting_quality")
	
	var titles = ["%ModeTitle", "%DiffTitle", "%LangTitle", "%ThemeTitle", "%VoiceTitle", "%ChaserTitle", "%PerfTitle"]
	for t in titles:
		if has_node(t):
			get_node(t).add_theme_color_override("font_color", UIColors.TEXT_SECONDARY)

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
		Config.chaser_level = temp_chaser_level
		Config.performance_mode = temp_perf
		Config.save_settings()
		TranslationServer.set_locale(Config.get_effective_language())
	
	# Return to Main Menu
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
