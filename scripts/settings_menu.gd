class_name SettingsMenu
extends Control

var temp_ui_lang_idx: int
var temp_learning_lang_idx: int
var temp_voice: int   ## Config.VoiceMode
var temp_perf: bool
var temp_controls: int
var temp_controller_size: int
var temp_screensaver: int
var _is_saving: bool = false
var _tts_warning_label: Label = null
var _release_section: VBoxContainer = null
var _version_label: Label = null
var _release_actions_row: HBoxContainer = null
var _privacy_button: Button = null
var _rate_button: Button = null

const SCREENSAVER_TIMEOUTS: Array[int] = [0, 60, 300, 600, 1200]
const SCREENSAVER_KEYS: Array[String] = ["off", "screensaver_1m", "screensaver_5m", "screensaver_10m", "screensaver_20m"]

## Original language stored on enter so we can restore on cancel.
var _original_ui_language: String = ""
var _original_learning_language: String = ""

## Original controls state so we can restore on cancel (controls are live-previewed).
var _original_controls: int = 0
var _original_controller_size: int = 0

var _original_voice_mode: int = 0
var _original_performance_mode: bool = false

func _ready() -> void:
	# Warp mouse off-screen to prevent phantom hover highlights on TV
	Input.warp_mouse(Vector2(-1, -1))
	
	if Config:
		TTS.refresh_cache()
		
		temp_ui_lang_idx = Config.LANG_CODES.find(Config.ui_language)
		if temp_ui_lang_idx < 0: temp_ui_lang_idx = 0
		
		temp_learning_lang_idx = Config.LANG_CODES.find(Config.learning_language)
		if temp_learning_lang_idx < 0: temp_learning_lang_idx = 0
			
		temp_voice = Config.voice_mode
		temp_perf = Config.performance_mode
		temp_screensaver = Config.screensaver_timeout
		temp_controls = Config.on_screen_controls
		temp_controller_size = Config.controller_size
		_original_controls = Config.on_screen_controls
		_original_controller_size = Config.controller_size
		_original_ui_language = Config.ui_language
		_original_learning_language = Config.learning_language
		_original_voice_mode = Config.voice_mode
		_original_performance_mode = Config.performance_mode
		# Listen for async TTS completion
		if not TTS.status_changed.is_connected(_update_labels):
			TTS.status_changed.connect(_update_labels)
			
	# Apply D-Pad layout shift using shared utility
	UIHelpers.apply_dpad_layout($CenterContainer, temp_controls)
	_apply_title_colors()
	# Wire up buttons with consistent brand styling
	_setup_cycling_button(%UILangButton, func(dir): _cycle_ui_lang(dir))
	_setup_cycling_button(%LearningLangButton, func(dir): _cycle_learning_lang(dir))
	_setup_cycling_button(%VoiceButton, func(dir): _cycle_voice(dir))
	_setup_cycling_button(%PerfButton, func(dir): _cycle_perf(dir))
	_setup_cycling_button(%ScreensaverButton, func(dir): _cycle_screensaver(dir))
	var ctrl_btn = get_node_or_null("%ControlsButton")
	if ctrl_btn:
		_setup_cycling_button(ctrl_btn, func(dir): _cycle_controls(dir))
	var size_btn = get_node_or_null("%ControllerSizeButton")
	if size_btn:
		_setup_cycling_button(size_btn, func(dir): _cycle_controller_size(dir))
	_build_release_section()
	
	_update_labels()
	_update_static_labels()
	_apply_release_layout()
	_configure_navigation()
	
	# Focus first interactive element for TV
	if has_node("%PerfButton"):
		%PerfButton.call_deferred("grab_focus")

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_apply_release_layout()
		_configure_navigation()

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
		# Set handled BEFORE calling cancel, to stop bubbling
		get_viewport().set_input_as_handled()
		_on_cancel_pressed()

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
	
	var focus_color: Color = UIColors.FOCUS_GOLD
		
	if left_arrow: left_arrow.add_theme_color_override("font_color", focus_color)
	if right_arrow: right_arrow.add_theme_color_override("font_color", focus_color)
		
	CyclingSelector._apply_field_style(btn)
	UIHelpers.apply_semibold(btn)


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
	_apply_release_layout()
	if Config and temp_ui_lang_idx < Config.LANG_CODES.size():
		Config.ui_language = Config.LANG_CODES[temp_ui_lang_idx]
		Config.save_settings()
	_configure_navigation()

## Say the language just chosen, so a parent who cannot read the menu still
## hears which one they picked. The name is said in the language of the menu,
## not in the language being named, so it resolves against the UI pack.
func _trigger_warmup_ui() -> void:
	if temp_voice == Config.VoiceMode.OFF:
		return
	var lang_name = _get_lang_display_name(temp_ui_lang_idx, false)
	Speech.warm_up(_get_preview_language(false))
	Speech.speak_ui(lang_name, _get_preview_language(false))

func _trigger_warmup_learning() -> void:
	if temp_voice == Config.VoiceMode.OFF:
		return
	var lang_name = _get_lang_display_name(temp_learning_lang_idx, true)
	Speech.warm_up(_get_preview_language(true))
	Speech.speak_ui(lang_name, _get_preview_language(true))

func _get_lang_display_name(idx: int, is_learning: bool = false) -> String:
	return Config.get_lang_display_name(idx, is_learning, temp_ui_lang_idx)

func _cycle_learning_lang(dir: int) -> void:
	if Config.LANG_KEYS.size() == 0: return
	temp_learning_lang_idx = (temp_learning_lang_idx + dir + Config.LANG_KEYS.size()) % Config.LANG_KEYS.size()
	if Config and temp_learning_lang_idx < Config.LANG_CODES.size():
		var lang: String = Config.LANG_CODES[temp_learning_lang_idx]
		Config.adopt_learning_language(lang, _get_lang_display_name(temp_learning_lang_idx, true))
		Config.save_settings()
	_update_labels()

## Off / Device voice / Studio voice, skipping whichever is unavailable.
## Studio voice only appears once the learning language has a complete pack;
## the device voice only when the OS actually has the voices installed. Both
## are checked separately, because a Czech pack works on a device with no
## Czech voice at all — which is the case it exists for.
func _cycle_voice(dir: int) -> void:
	var choices := _voice_choices()
	if choices.is_empty():
		return
	var at := choices.find(temp_voice)
	if at == -1:
		at = 0
		dir = 0
	temp_voice = choices[(at + dir + choices.size()) % choices.size()]
	_update_labels()
	if temp_voice == Config.VoiceMode.DEVICE_TTS:
		_trigger_warmup_ui()
	if Config:
		Config.voice_mode = temp_voice
		Config.save_settings()

## Which modes the player can actually reach right now.
func _voice_choices() -> Array[int]:
	# int() rather than the enum values directly: a named enum is its own type
	# to the static checker, and will not append to an Array[int].
	# All three, always. Hiding a mode because this language has no pack meant
	# the row changed length as the parent scrolled through languages, and the
	# setting is a preference anyway: studio falls back to the device voice per
	# item, and the device voice falls back to silence, both without asking.
	return [int(Config.VoiceMode.OFF), int(Config.VoiceMode.DEVICE_TTS),
			int(Config.VoiceMode.STUDIO_PREFERRED)]

func _device_voices_available() -> bool:
	return TTS.is_available(_get_preview_language(false)) \
		and TTS.is_available(_get_preview_language(true))

func _voice_mode_label(mode: int) -> String:
	match mode:
		Config.VoiceMode.OFF: return tr("voice_off")
		Config.VoiceMode.STUDIO_PREFERRED: return tr("voice_studio")
		_: return tr("voice_device")

func _cycle_perf(_dir: int) -> void:
	temp_perf = !temp_perf
	_update_labels()
	if Config:
		Config.performance_mode = temp_perf
		Config.save_settings()

func _cycle_screensaver(dir: int) -> void:
	var idx = SCREENSAVER_TIMEOUTS.find(temp_screensaver)
	if idx < 0: idx = 2
	idx = (idx + dir + SCREENSAVER_TIMEOUTS.size()) % SCREENSAVER_TIMEOUTS.size()
	temp_screensaver = SCREENSAVER_TIMEOUTS[idx]
	if Config:
		Config.screensaver_timeout = temp_screensaver
		Config.save_settings()
	_update_labels()

func _cycle_controls(dir: int) -> void:
	if Config.CONTROLS_KEYS.size() == 0: return
	temp_controls = (temp_controls + dir + Config.CONTROLS_KEYS.size()) % Config.CONTROLS_KEYS.size()
	# Immediately update Config so the d-pad previews live
	if Config: 
		Config.on_screen_controls = temp_controls
		UIHelpers.apply_dpad_layout($CenterContainer, temp_controls)
		Config.save_settings()
	_update_labels()
	_apply_release_layout()
	_configure_navigation()

func _cycle_controller_size(dir: int) -> void:
	if Config.CONTROLLER_SIZE_KEYS.size() == 0: return
	temp_controller_size = (temp_controller_size + dir + Config.CONTROLLER_SIZE_KEYS.size()) % Config.CONTROLLER_SIZE_KEYS.size()
	if Config:
		Config.controller_size = temp_controller_size
		UIHelpers.apply_dpad_layout($CenterContainer, temp_controls)
		Config.save_settings()
	_update_labels()
	_apply_release_layout()
	_configure_navigation()

func _update_labels() -> void:
	if has_node("%UILangButton"):
		var ui_code := Config.LANG_CODES[temp_ui_lang_idx]
		var flag_code := ui_code
		if flag_code == "auto":
			flag_code = Config.get_auto_detected_language()
		var ui_text := _get_lang_display_name(temp_ui_lang_idx, false)
		UIHelpers.apply_flag_to_button(%UILangButton, flag_code, ui_text)

	if has_node("%LearningLangButton"):
		var learn_code := Config.LANG_CODES[temp_learning_lang_idx]
		var flag_code := learn_code
		if flag_code == "auto":
			var ui_code := Config.LANG_CODES[temp_ui_lang_idx]
			if ui_code == "auto":
				flag_code = Config.get_auto_detected_language()
			else:
				flag_code = ui_code
		var learn_text := _get_lang_display_name(temp_learning_lang_idx, true)
		UIHelpers.apply_flag_to_button(%LearningLangButton, flag_code, learn_text)
	
	if has_node("%VoiceButton"):
		if not _tts_warning_label: _create_tts_warning()
		
		var has_studio := Speech.has_pack(_get_preview_language(true))

		if not TTS.tts_ready and not has_studio:
			%VoiceButton.text = _voice_mode_label(temp_voice)
			%VoiceButton.disabled = true
			%VoiceButton.modulate.a = 0.5
			if _tts_warning_label:
				_tts_warning_label.visible = true
				_tts_warning_label.text = tr("checking_tts")
				_tts_warning_label.add_theme_color_override("font_color", UIColors.TTS_PENDING)
		else:
			var ui_available := TTS.is_available(_get_preview_language(false))
			var learning_available := TTS.is_available(_get_preview_language(true))
			var device_ok := ui_available and learning_available

			# The row is usable whenever there is more than one thing to choose,
			# and a complete pack is enough on its own. The old rule disabled it
			# unless the OS had both voices, which would have hidden Studio
			# voice on exactly the devices that need it most.
			var choices := _voice_choices()
			if not choices.has(temp_voice):
				temp_voice = Config.VoiceMode.OFF
			%VoiceButton.text = _voice_mode_label(temp_voice)
			%VoiceButton.disabled = choices.size() < 2
			%VoiceButton.modulate.a = 1.0 if choices.size() > 1 else 0.4

			if _tts_warning_label:
				# Studio coverage and device availability are reported
				# separately; only the device voice depends on the OS.
				if has_studio and not device_ok:
					_tts_warning_label.visible = true
					_tts_warning_label.text = tr("voice_studio_only")
					_tts_warning_label.add_theme_color_override("font_color", UIColors.TTS_OK)
				elif not device_ok:
					_tts_warning_label.visible = true
					if not ui_available and not learning_available:
						_tts_warning_label.text = tr("tts_missing")
					elif not ui_available:
						_tts_warning_label.text = tr("tts_missing") + " (UI)"
					else:
						_tts_warning_label.text = tr("tts_missing") + " (Learn)"
					_tts_warning_label.add_theme_color_override("font_color", UIColors.TTS_ERROR)
				else:
					_tts_warning_label.visible = false
					_tts_warning_label.text = tr("tts_ready")
					_tts_warning_label.add_theme_color_override("font_color", UIColors.TTS_OK)

	if has_node("%PerfButton"):
		%PerfButton.text = tr("quality_high") if not temp_perf else tr("quality_standard")

	if has_node("%ScreensaverButton"):
		var idx = SCREENSAVER_TIMEOUTS.find(temp_screensaver)
		if idx >= 0 and idx < SCREENSAVER_KEYS.size():
			%ScreensaverButton.text = tr(SCREENSAVER_KEYS[idx])

	if has_node("%ControlsButton") and temp_controls >= 0 and temp_controls < Config.CONTROLS_KEYS.size():
		%ControlsButton.text = tr(Config.CONTROLS_KEYS[temp_controls])

	if has_node("%ControllerSizeButton") and temp_controller_size >= 0 and temp_controller_size < Config.CONTROLLER_SIZE_KEYS.size():
		%ControllerSizeButton.text = tr(Config.CONTROLLER_SIZE_KEYS[temp_controller_size])

func _update_static_labels() -> void:
	if has_node("%Title"): 
		%Title.text = tr("settings_title")
		%Title.add_theme_color_override("font_color", UIColors.HEADING_YELLOW)
		UIHelpers.apply_semibold(%Title)
	if has_node("%UILangTitle"):
		%UILangTitle.text = tr("setting_ui_lang")
		UIHelpers.apply_medium(%UILangTitle)
	if has_node("%LearningLangTitle"):
		%LearningLangTitle.text = tr("setting_learning_lang")
		UIHelpers.apply_medium(%LearningLangTitle)
	if has_node("%VoiceTitle"):
		%VoiceTitle.text = tr("setting_voice")
		UIHelpers.apply_medium(%VoiceTitle)
	if has_node("%PerfTitle"):
		%PerfTitle.text = tr("setting_quality")
		UIHelpers.apply_medium(%PerfTitle)
	if has_node("%ScreensaverTitle"):
		%ScreensaverTitle.text = tr("setting_screensaver")
		UIHelpers.apply_medium(%ScreensaverTitle)
	if has_node("%ControlsTitle"):
		%ControlsTitle.text = tr("setting_controls")
		UIHelpers.apply_medium(%ControlsTitle)
	if has_node("%ControllerSizeTitle"):
		%ControllerSizeTitle.text = tr("setting_controller_size")
		UIHelpers.apply_medium(%ControllerSizeTitle)
	if _version_label != null:
		_version_label.text = _release_version_text()
	if _privacy_button != null:
		_privacy_button.text = tr("privacy_policy")
	if _rate_button != null:
		_rate_button.text = tr("rate_game")
	
func _apply_title_colors() -> void:
	var titles = ["%UILangTitle", "%LearningLangTitle", "%VoiceTitle", "%PerfTitle", "%ScreensaverTitle", "%ControlsTitle", "%ControllerSizeTitle"]
	for t in titles:
		if has_node(t):
			get_node(t).add_theme_color_override("font_color", UIColors.TEXT_SECONDARY)

func _build_release_section() -> void:
	var main_vbox := get_node_or_null("CenterContainer/MainVBox") as VBoxContainer
	if main_vbox == null:
		return

	var release_spacer := Control.new()
	release_spacer.name = "ReleaseSectionSpacer"
	release_spacer.custom_minimum_size = Vector2(0, 10)
	main_vbox.add_child(release_spacer)

	_release_section = VBoxContainer.new()
	_release_section.name = "ReleaseSection"
	_release_section.alignment = BoxContainer.ALIGNMENT_CENTER
	_release_section.add_theme_constant_override("separation", 12)
	main_vbox.add_child(_release_section)

	_version_label = Label.new()
	_version_label.name = "VersionLabel"
	_version_label.text = _release_version_text()
	_version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_version_label.add_theme_font_size_override("font_size", 24)
	_version_label.add_theme_color_override("font_color", UIColors.TEXT_SECONDARY)
	UIHelpers.apply_medium(_version_label)
	_release_section.add_child(_version_label)

	_release_actions_row = HBoxContainer.new()
	_release_actions_row.name = "ReleaseActionsRow"
	_release_actions_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_release_actions_row.add_theme_constant_override("separation", 28)
	_release_section.add_child(_release_actions_row)

	_privacy_button = UIHelpers.create_styled_button(tr("privacy_policy"), 300, 64, UIColors.YELLOW, 26)
	_privacy_button.pressed.connect(_open_privacy_policy)
	_release_actions_row.add_child(_privacy_button)

	_rate_button = UIHelpers.create_styled_button(tr("rate_game"), 300, 64, UIColors.YELLOW, 26)
	_rate_button.pressed.connect(_open_rate_game)
	_release_actions_row.add_child(_rate_button)

func _apply_release_layout() -> void:
	if _release_section == null:
		return
	var viewport_size := get_viewport_rect().size
	var content_rect := UIHelpers.get_content_rect(viewport_size, temp_controls)
	var short_screen := viewport_size.y < 820.0
	var gap := clampi(int(content_rect.size.x * 0.025), 18, 28)
	var button_width := clampf((content_rect.size.x - float(gap)) * 0.5, 180.0, 300.0)
	var button_height := 56.0 if short_screen else 64.0
	var font_size := 24 if short_screen else 26
	var main_vbox := get_node_or_null("CenterContainer/MainVBox") as VBoxContainer
	if main_vbox != null:
		main_vbox.add_theme_constant_override("separation", 8 if short_screen else 16)
	if has_node("%Title"):
		%Title.add_theme_font_size_override("font_size", 44 if short_screen else 52)
	for row_path in ["%RowPerf", "%RowScreensaver", "%RowControls", "%RowControllerSize", "%RowUILang", "%RowLearningLang", "%RowVoice"]:
		var row := get_node_or_null(row_path) as HBoxContainer
		if row != null:
			row.add_theme_constant_override("separation", 48 if short_screen else 80)
	for title_path in ["%PerfTitle", "%ScreensaverTitle", "%ControlsTitle", "%ControllerSizeTitle", "%UILangTitle", "%LearningLangTitle", "%VoiceTitle"]:
		var title := get_node_or_null(title_path) as Label
		if title != null:
			title.add_theme_font_size_override("font_size", 30 if short_screen else 36)
	for button_path in ["%PerfButton", "%ScreensaverButton", "%ControlsButton", "%ControllerSizeButton", "%UILangButton", "%LearningLangButton", "%VoiceButton"]:
		var settings_button := get_node_or_null(button_path) as Button
		if settings_button != null:
			settings_button.custom_minimum_size.y = 58.0 if short_screen else 72.0
			settings_button.add_theme_font_size_override("font_size", 30 if short_screen else 36)
	if _release_actions_row != null:
		_release_actions_row.add_theme_constant_override("separation", gap)
	if _version_label != null:
		_version_label.add_theme_font_size_override("font_size", 22 if short_screen else 24)
	for button in [_privacy_button, _rate_button]:
		if button == null:
			continue
		button.custom_minimum_size = Vector2(button_width, button_height)
		UIHelpers.fit_button_font_size_to_width(button, button_width, font_size, 18, 44.0)

func _configure_navigation() -> void:
	var controls: Array[Control] = []
	for node_path in ["%PerfButton", "%ScreensaverButton", "%ControlsButton", "%ControllerSizeButton", "%UILangButton", "%LearningLangButton", "%VoiceButton"]:
		var ctrl := get_node_or_null(node_path) as Control
		if FocusNavigator.is_focusable(ctrl):
			controls.append(ctrl)
	FocusNavigator.configure_vertical_chain(controls)

	var release_buttons: Array[Button] = []
	if _privacy_button != null and _privacy_button.visible and not _privacy_button.disabled:
		release_buttons.append(_privacy_button)
	if _rate_button != null and _rate_button.visible and not _rate_button.disabled:
		release_buttons.append(_rate_button)
	if release_buttons.is_empty():
		return

	var top_control: Control = controls[controls.size() - 1] if not controls.is_empty() else release_buttons[0]
	if not controls.is_empty():
		top_control.focus_neighbor_bottom = top_control.get_path_to(release_buttons[0])
	FocusNavigator.configure_row(release_buttons, top_control, null, is_layout_rtl())
	for button in release_buttons:
		button.focus_neighbor_bottom = button.get_path_to(button)

func _open_privacy_policy() -> void:
	var err := OS.shell_open(Config.PRIVACY_POLICY_URL)
	if err != OK:
		push_warning("Could not open privacy policy URL: %d" % err)

func _open_rate_game() -> void:
	if OS.get_name() == "Android":
		var market_err := OS.shell_open("market://details?id=%s" % Config.ANDROID_PACKAGE_ID)
		if market_err == OK:
			return
	var err := OS.shell_open(Config.PLAY_STORE_URL)
	if err != OK:
		push_warning("Could not open Play Store URL: %d" % err)

func _release_version_text() -> String:
	var template := tr("game_version")
	var version_label := Config.get_release_version_label() if Config != null else ""
	if template.contains("%s"):
		return template % version_label
	return "%s %s" % [template, version_label]

func _on_save_pressed() -> void:
	if _is_saving: return
	_is_saving = true
	if Config:
		if temp_ui_lang_idx < Config.LANG_CODES.size(): Config.ui_language = Config.LANG_CODES[temp_ui_lang_idx]
		if temp_learning_lang_idx < Config.LANG_CODES.size(): Config.learning_language = Config.LANG_CODES[temp_learning_lang_idx]
		Config.voice_mode = temp_voice
		Config.performance_mode = temp_perf
		Config.screensaver_timeout = temp_screensaver
		Config.on_screen_controls = temp_controls
		Config.controller_size = temp_controller_size
		Config.save_settings()
		TranslationServer.set_locale(Config.get_effective_ui_language())
	get_tree().change_scene_to_file(Scenes.HOME)

func _on_cancel_pressed() -> void:
	if _is_saving: return
	_is_saving = true
	if Config:
		if temp_ui_lang_idx < Config.LANG_CODES.size(): Config.ui_language = Config.LANG_CODES[temp_ui_lang_idx]
		if temp_learning_lang_idx < Config.LANG_CODES.size(): Config.learning_language = Config.LANG_CODES[temp_learning_lang_idx]
		Config.voice_mode = temp_voice
		Config.performance_mode = temp_perf
		Config.screensaver_timeout = temp_screensaver
		Config.on_screen_controls = temp_controls
		Config.controller_size = temp_controller_size
		Config.save_settings()
		TranslationServer.set_locale(Config.get_effective_ui_language())
	get_tree().change_scene_to_file(Scenes.HOME)
