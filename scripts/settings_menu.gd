class_name SettingsMenu
extends Control

var temp_ui_lang_idx: int
var temp_learning_lang_idx: int
var temp_diff: int
var temp_theme_idx: int
var temp_voice: bool
var temp_chaser_level: int
var temp_perf: bool
var temp_controls: int
var themes: Array[String] = []
@onready var player_preview: CharacterPreview = %ThemePlayerAnchor
var _is_saving: bool = false
var _tts_warning_label: Label = null

## Original language stored on enter so we can restore on cancel.
var _original_ui_language: String = ""
var _original_learning_language: String = ""

## Original controls state so we can restore on cancel (controls are live-previewed).
var _original_controls: int = 0

# Animated Theme Previews
var _theme_preview_loader: ThemeLoader = null
var _last_theme_idx: int = -1

func _ready() -> void:
	# Warp mouse off-screen to prevent phantom hover highlights on TV
	Input.warp_mouse(Vector2(-1, -1))
	
	if Config:
		TTS.refresh_cache()
		temp_diff = Config.difficulty
		themes = ThemeLoader.get_available_themes()
		
		temp_theme_idx = themes.find(Config.theme_dir_name)
		if temp_theme_idx < 0:
			temp_theme_idx = 0
		
		temp_ui_lang_idx = Config.LANG_CODES.find(Config.ui_language)
		if temp_ui_lang_idx < 0: temp_ui_lang_idx = 0
		
		temp_learning_lang_idx = Config.LANG_CODES.find(Config.learning_language)
		if temp_learning_lang_idx < 0: temp_learning_lang_idx = 0
			
		temp_voice = Config.voice_hints
		temp_chaser_level = Config.chaser_level
		temp_perf = Config.performance_mode
		temp_controls = Config.on_screen_controls
		_original_controls = Config.on_screen_controls
		_original_ui_language = Config.ui_language
		_original_learning_language = Config.learning_language
		# Listen for async TTS completion
		if not TTS.status_changed.is_connected(_update_labels):
			TTS.status_changed.connect(_update_labels)
			
	# Apply D-Pad layout shift using shared utility
	UIHelpers.apply_dpad_layout($CenterContainer, temp_controls)
	_apply_title_colors()
	# Wire up buttons with consistent brand styling
	_setup_cycling_button(%UILangButton, func(dir): _cycle_ui_lang(dir))
	_setup_cycling_button(%DiffButton, func(dir): _cycle_diff(dir))
	_setup_cycling_button(%LearningLangButton, func(dir): _cycle_learning_lang(dir))
	_setup_cycling_button(%ThemeButton, func(dir): _cycle_theme(dir))
	_setup_cycling_button(%VoiceButton, func(dir): _cycle_voice(dir))
	_setup_cycling_button(%ChaserButton, func(dir): _cycle_chaser(dir))
	_setup_cycling_button(%PerfButton, func(dir): _cycle_perf(dir))
	var ctrl_btn = get_node_or_null("%ControlsButton")
	if ctrl_btn:
		_setup_cycling_button(ctrl_btn, func(dir): _cycle_controls(dir))
	
	_update_labels()
	_update_static_labels()
	
	# Focus first interactive element for TV
	if has_node("%DiffButton"):
		%DiffButton.call_deferred("grab_focus")

func _get_preview_language(is_learning: bool = false) -> String:
	var idx = temp_learning_lang_idx if is_learning else temp_ui_lang_idx
	if idx < Config.LANG_CODES.size():
		var code: String = Config.LANG_CODES[idx]
		if code == "auto":
			return Config.get_auto_detected_language()
		if code in Config.SUPPORTED_LANGS:
			return code
	return "en"

func _on_tts_init_warmup() -> void:
	if TTS.tts_ready:
		_trigger_warmup_ui()

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

func _unhandled_input(event: InputEvent) -> void:
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
		if event.is_pressed():
			if event.is_action("ui_left"):
				cycle_func.call(-1)
				get_viewport().set_input_as_handled()
			elif event.is_action("ui_right"):
				cycle_func.call(1)
				get_viewport().set_input_as_handled()
	)
	
	var focus_color: Color = UIColors.YELLOW
		
	if left_arrow: left_arrow.add_theme_color_override("font_color", focus_color)
	if right_arrow: right_arrow.add_theme_color_override("font_color", focus_color)
		
	UIHelpers.apply_style_to_button(btn, focus_color)


func _cycle_ui_lang(dir: int) -> void:
	if Config.LANG_KEYS.size() == 0: return
	temp_ui_lang_idx = (temp_ui_lang_idx + dir + Config.LANG_KEYS.size()) % Config.LANG_KEYS.size()
	var preview_lang := _get_preview_language(false)
	TranslationServer.set_locale(preview_lang)
	# Re-apply D-pad layout immediately to update anchors if RTL status changed
	UIHelpers.apply_dpad_layout($CenterContainer, temp_controls)
	_trigger_warmup_ui()
	_update_labels()
	_update_static_labels()

func _cycle_diff(dir: int) -> void:
	if Config.DIFF_KEYS.size() == 0: return
	temp_diff = (temp_diff + dir + Config.DIFF_KEYS.size()) % Config.DIFF_KEYS.size()
	_update_labels()

func _trigger_warmup_ui() -> void:
	if temp_voice:
		var lang_name = _get_lang_display_name(temp_ui_lang_idx, false)
		TTS.warm_up(_get_preview_language(false), lang_name)

func _trigger_warmup_learning() -> void:
	if temp_voice:
		var lang_name = _get_lang_display_name(temp_learning_lang_idx, true)
		TTS.warm_up(_get_preview_language(true), lang_name)

func _get_lang_display_name(idx: int, is_learning: bool = false) -> String:
	return Config.get_lang_display_name(idx, is_learning, temp_ui_lang_idx)

func _cycle_learning_lang(dir: int) -> void:
	if Config.LANG_KEYS.size() == 0: return
	temp_learning_lang_idx = (temp_learning_lang_idx + dir + Config.LANG_KEYS.size()) % Config.LANG_KEYS.size()
	_update_labels()

func _cycle_theme(dir: int) -> void:
	if themes.size() == 0: return
	temp_theme_idx = (temp_theme_idx + dir + themes.size()) % themes.size()
	_update_labels()

func _cycle_voice(_dir: int) -> void:
	temp_voice = !temp_voice
	_update_labels()
	if temp_voice:
		_trigger_warmup_ui()

func _cycle_chaser(dir: int) -> void:
	if Config.CHASER_LEVEL_KEYS.size() == 0: return
	temp_chaser_level = (temp_chaser_level + dir + Config.CHASER_LEVEL_KEYS.size()) % Config.CHASER_LEVEL_KEYS.size()
	_update_labels()

func _cycle_perf(_dir: int) -> void:
	temp_perf = !temp_perf
	_update_labels()

func _cycle_controls(dir: int) -> void:
	if Config.CONTROLS_KEYS.size() == 0: return
	temp_controls = (temp_controls + dir + Config.CONTROLS_KEYS.size()) % Config.CONTROLS_KEYS.size()
	# Immediately update Config so the d-pad previews live
	if Config: 
		Config.on_screen_controls = temp_controls
		UIHelpers.apply_dpad_layout($CenterContainer, temp_controls)
	_update_labels()

func _update_labels() -> void:
	# ALWAYS update previews first so that _theme_preview_loader gets initialized with the right theme
	# BEFORE we use it to pull the manifest title for ThemeButton.
	_update_previews()

	if has_node("%UILangButton"):
		%UILangButton.text = _get_lang_display_name(temp_ui_lang_idx, false)
	
	if has_node("%DiffButton") and temp_diff < Config.DIFF_KEYS.size():
		%DiffButton.text = tr(Config.DIFF_KEYS[temp_diff])

	if has_node("%LearningLangButton"):
		%LearningLangButton.text = _get_lang_display_name(temp_learning_lang_idx, true)
	
	if has_node("%ChaserButton") and temp_chaser_level < Config.CHASER_LEVEL_KEYS.size():
		%ChaserButton.text = tr(Config.CHASER_LEVEL_KEYS[temp_chaser_level])
		
	if has_node("%ThemeButton") and temp_theme_idx < themes.size():
		var display_title: String = _theme_preview_loader.get_display_title(themes[temp_theme_idx]) if _theme_preview_loader else themes[temp_theme_idx].capitalize()
		%ThemeButton.text = display_title
	
	if has_node("%VoiceButton"):
		if not _tts_warning_label: _create_tts_warning()
		
		if not TTS.tts_ready:
			%VoiceButton.text = tr("on") if temp_voice else tr("off")
			%VoiceButton.disabled = true
			%VoiceButton.modulate.a = 0.5
			if _tts_warning_label:
				_tts_warning_label.visible = true
				_tts_warning_label.text = tr("checking_tts")
				_tts_warning_label.add_theme_color_override("font_color", UIColors.TTS_PENDING)
		else:
			var ui_lang_code = Config.LANG_CODES[temp_ui_lang_idx]
			var learning_lang_code = Config.LANG_CODES[temp_learning_lang_idx]
			var ui_available = TTS.is_available(ui_lang_code)
			var learning_available = TTS.is_available(learning_lang_code)
			var is_available = ui_available and learning_available
			var effective_voice_state = temp_voice and is_available
			
			%VoiceButton.text = tr("on") if effective_voice_state else tr("off")
			%VoiceButton.disabled = not is_available
			%VoiceButton.modulate.a = 1.0 if is_available else 0.4
			
			if _tts_warning_label:
				_tts_warning_label.visible = not is_available
				if not is_available:
					if not ui_available and not learning_available:
						_tts_warning_label.text = tr("tts_missing")
					elif not ui_available:
						_tts_warning_label.text = tr("tts_missing") + " (UI)"
					else:
						_tts_warning_label.text = tr("tts_missing") + " (Learn)"
					_tts_warning_label.add_theme_color_override("font_color", UIColors.TTS_ERROR)
				else:
					_tts_warning_label.text = tr("tts_ready")
					_tts_warning_label.add_theme_color_override("font_color", UIColors.TTS_OK)

	if has_node("%PerfButton"):
		%PerfButton.text = tr("quality_high") if not temp_perf else tr("quality_standard")

	if has_node("%ControlsButton") and temp_controls >= 0 and temp_controls < Config.CONTROLS_KEYS.size():
		%ControlsButton.text = tr(Config.CONTROLS_KEYS[temp_controls])

func _update_previews() -> void:
	if themes.size() == 0: return
	
	if temp_theme_idx != _last_theme_idx:
		_last_theme_idx = temp_theme_idx
		_theme_preview_loader = ThemeLoader.get_cached(themes[temp_theme_idx])
	
	var player_preview: CharacterPreview = get_node_or_null("%ThemePlayerAnchor") as CharacterPreview
	if player_preview:
		player_preview.set_character(_theme_preview_loader.player_frames, _theme_preview_loader.player_fps)

func _update_static_labels() -> void:
	if has_node("%Title"): 
		%Title.text = tr("settings_title")
		%Title.add_theme_color_override("font_color", UIColors.YELLOW)
	if has_node("%UILangTitle"): %UILangTitle.text = tr("setting_ui_lang")
	if has_node("%DiffTitle"): %DiffTitle.text = tr("setting_diff")
	if has_node("%LearningLangTitle"): %LearningLangTitle.text = tr("setting_learning_lang")
	if has_node("%ThemeTitle"): %ThemeTitle.text = tr("setting_theme")
	if has_node("%VoiceTitle"): %VoiceTitle.text = tr("setting_voice")
	if has_node("%ChaserTitle"): %ChaserTitle.text = tr("setting_chaser")
	if has_node("%PerfTitle"): %PerfTitle.text = tr("setting_quality")
	if has_node("%ControlsTitle"): %ControlsTitle.text = tr("setting_controls")
	
func _apply_title_colors() -> void:
	var titles = ["%UILangTitle", "%DiffTitle", "%LearningLangTitle", "%ThemeTitle", "%VoiceTitle", "%ChaserTitle", "%PerfTitle", "%ControlsTitle"]
	for t in titles:
		if has_node(t):
			get_node(t).add_theme_color_override("font_color", UIColors.TEXT_SECONDARY)

func _on_save_pressed() -> void:
	if _is_saving: return
	_is_saving = true
	if Config:
		Config.difficulty = temp_diff
		if temp_ui_lang_idx < Config.LANG_CODES.size(): Config.ui_language = Config.LANG_CODES[temp_ui_lang_idx]
		if temp_learning_lang_idx < Config.LANG_CODES.size(): Config.learning_language = Config.LANG_CODES[temp_learning_lang_idx]
		if temp_theme_idx < themes.size(): Config.theme_dir_name = themes[temp_theme_idx]
		Config.voice_hints = temp_voice
		Config.chaser_level = temp_chaser_level
		Config.performance_mode = temp_perf
		Config.on_screen_controls = temp_controls
		Config.save_settings()
		TranslationServer.set_locale(Config.get_effective_ui_language())
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _exit_tree() -> void:
	if not _is_saving and Config:
		Config.on_screen_controls = _original_controls
