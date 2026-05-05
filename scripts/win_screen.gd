## win_screen.gd
## ---------------------------------------------------------------------------
## Overlay UI for both the "You Win!" screen and "Gotcha!" (chaser caught)
## screen.  Handles button creation, mode switch buttons, and auto-countdown.
##
## Emits signals so GameManager can respond without tight coupling.
## ---------------------------------------------------------------------------
class_name WinScreen
extends CanvasLayer


# ── Signals ──────────────────────────────────────────────────────────────────

signal next_round_pressed
signal harder_pressed
signal home_pressed
signal play_together_pressed
signal play_alone_pressed
signal swap_roles_pressed

## Emitted when the screen becomes visible (GameManager should pause the tree).
signal screen_shown
## Emitted when the screen is hidden (GameManager should unpause the tree).
signal screen_hidden


# ── UI References ────────────────────────────────────────────────────────────

var _container: Control = null
var _left_previews: HBoxContainer = null
var _right_previews: HBoxContainer = null
var _win_label: Label = null
var _recap_label: Label = null
var _next_button: Button = null
var _harder_button: Button = null
var _timer_label: Label = null
var _suggestion_container: VBoxContainer = null
var _swap_roles_enabled: bool = false
var _is_multiplayer: bool = false
var _learning_recap: Dictionary = {}
var _recap_played: bool = false

## Countdown state.
var _timer_remaining: float = 0.0
var _timer_paused: bool = false
var _is_active: bool = false

# OLED burn-in protection: secondary idle guard that activates once the
# auto-countdown is cancelled by player input.
var _oled_guard: OledIdleGuard = null
var _oled_pulse_tween: Tween = null

# ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()

	_oled_guard = OledIdleGuard.new()
	_oled_guard.name = "WinScreenOledGuard"
	add_child(_oled_guard)
	# Tier 1 (60 s): dim the panel and pulse the Next Round button
	_oled_guard.idle_tier_1.connect(_on_oled_tier1)
	# Tier 2 (3 min): go home
	_oled_guard.idle_tier_2.connect(_on_oled_tier2)
	# Reset: undim immediately on any input
	_oled_guard.idle_reset.connect(_on_oled_reset)


func _process(delta: float) -> void:
	if _is_active and not _timer_paused and _timer_remaining > 0.0:
		_timer_remaining -= delta
		if _timer_label:
			_timer_label.text = str(ceili(_timer_remaining))
		if _timer_remaining <= 0.0:
			_timer_remaining = 0.0
			_timer_paused = true
			_stop_recap_tts()
			next_round_pressed.emit()


func _input(event: InputEvent) -> void:
	# Any action interaction during the active screen pauses the auto-countdown.
	if _is_active and not _timer_paused:
		if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") or \
		   event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right") or \
		   event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
			_timer_paused = true
			if _timer_label:
				_timer_label.text = ""
			# Countdown cancelled by player — start secondary OLED idle guard
			if _oled_guard:
				_oled_guard.start(60.0, 180.0)

	# Always consume ui_cancel when active to prevent focus loss or global pause.
	if _is_active and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()


# ── Public API ───────────────────────────────────────────────────────────────

## Check if the win/gotcha screen is currently visible.
func is_active() -> bool:
	return _is_active

func set_swap_roles_enabled(enabled: bool) -> void:
	_swap_roles_enabled = enabled

func set_is_multiplayer(is_mp: bool) -> void:
	_is_multiplayer = is_mp

func set_learning_recap(recap: Dictionary) -> void:
	_learning_recap = recap.duplicate(true) if not recap.is_empty() else {}
	_recap_played = false
	_update_recap_label()

## Show the "You Win!" screen.
func show_win() -> void:
	_is_active = true
	_timer_remaining = 10.0
	_timer_paused = false
	_recap_played = false
	_set_winner_character("")

	_win_label.text = tr("you_win")
	_next_button.text = tr("next_round")
	_update_recap_label()

	if _harder_button:
		_harder_button.visible = Config.difficulty < 6
		_harder_button.text = tr("challenge_pp")

	if _container and is_instance_valid(Config):
		UIHelpers.apply_dpad_layout(_container, Config.on_screen_controls)

	_build_mode_switch_buttons()

	_container.visible = true
	_next_button.grab_focus()
	screen_shown.emit()
	_play_learning_recap_once()


## Show the "Gotcha!" screen when the chaser catches the player.
func show_gotcha(chaser_id: String = "") -> void:
	_stop_recap_tts()
	_learning_recap.clear()
	_update_recap_label()
	_is_active = true
	_timer_remaining = 10.0
	_timer_paused = false
	if chaser_id.is_empty() and is_instance_valid(Config) and not Config.theme_dir_name.is_empty():
		chaser_id = Config.theme_dir_name + ":chaser"
	_set_winner_character(chaser_id)

	_win_label.text = tr("gotcha")
	_next_button.text = tr("try_again")

	# Show "Easier" if possible (button handler checks text to decide direction)
	if _harder_button:
		_harder_button.visible = Config.difficulty > 0
		_harder_button.text = tr("challenge_mm")

	if _container and is_instance_valid(Config):
		UIHelpers.apply_dpad_layout(_container, Config.on_screen_controls)

	_build_mode_switch_buttons()

	_container.visible = true
	_next_button.grab_focus()
	screen_shown.emit()

func show_race_win(winner_character_id: String) -> void:
	show_win()
	_win_label.text = tr("race_i_won")
	_set_winner_character(winner_character_id)

func show_race_gotcha(winner_character_id: String) -> void:
	show_gotcha()
	_win_label.text = tr("race_i_won")
	_set_winner_character(winner_character_id)

func show_coop_win(character_ids: Array[String]) -> void:
	show_win()
	_win_label.text = tr("mp_you_won_together")
	
	_clear_previews()
	if character_ids.is_empty():
		return
		
	var base_size := 124
	var scale_factor := 1.0
	if character_ids.size() >= 4:
		scale_factor = 0.8
	var preview_size := int(base_size * scale_factor)
	
	for i in range(character_ids.size()):
		var cid := character_ids[i]
		var p := create_preview_instance(cid, preview_size)
		if p != null:
			# Distribute evenly between left and right boxes
			if i < character_ids.size() / 2.0:
				_left_previews.add_child(p)
			else:
				_right_previews.add_child(p)

static func build_title_header(title_text: String, character_ids: Array[String], preview_size: int = 124, title_font_size: int = 90) -> HBoxContainer:
	var title_hbox := HBoxContainer.new()
	title_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	title_hbox.add_theme_constant_override("separation", 24)

	var left_previews := HBoxContainer.new()
	left_previews.alignment = BoxContainer.ALIGNMENT_CENTER
	left_previews.add_theme_constant_override("separation", 8)
	title_hbox.add_child(left_previews)

	var title_label := Label.new()
	title_label.text = title_text
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", title_font_size)
	title_label.add_theme_color_override("font_color", UIColors.TEXT_PRIMARY)
	UIHelpers.apply_semibold(title_label)
	title_hbox.add_child(title_label)

	var right_previews := HBoxContainer.new()
	right_previews.alignment = BoxContainer.ALIGNMENT_CENTER
	right_previews.add_theme_constant_override("separation", 8)
	title_hbox.add_child(right_previews)

	for i in range(character_ids.size()):
		var preview := create_preview_instance(character_ids[i], preview_size)
		if preview != null:
			if i < character_ids.size() / 2.0:
				left_previews.add_child(preview)
			else:
				right_previews.add_child(preview)

	return title_hbox


## Build the "Play Together" / "Play Alone" / "Swap Roles" buttons.
func _build_mode_switch_buttons() -> void:
	for child in _suggestion_container.get_children():
		child.queue_free()

	if _swap_roles_enabled:
		_add_suggestion_button(tr("mp_role_swap_roles"), func(): swap_roles_pressed.emit(), UIColors.YELLOW)

	if _is_multiplayer:
		# MP mode → offer "Play Alone" in blue
		_add_suggestion_button(tr("play_alone"), func(): play_alone_pressed.emit(), UIColors.BLUE)
	else:
		# SP mode → offer "Play Together" in green
		_add_suggestion_button(tr("play_together"), func(): play_together_pressed.emit(), UIColors.GREEN, "res://images/icons/i_2players_crop.png")


func _update_recap_label() -> void:
	if _recap_label == null:
		return
	var recap_text := String(_learning_recap.get("text", "")).strip_edges()
	_recap_label.text = recap_text
	_recap_label.visible = _is_active and not recap_text.is_empty()


func _play_learning_recap_once() -> void:
	if _recap_played:
		return
	_recap_played = true
	if not _is_active or not Config.voice_hints:
		return
	var segments := _learning_recap.get("tts_segments", []) as Array
	if segments == null or segments.is_empty():
		return
	TTS.speak_segments(segments)


func _stop_recap_tts() -> void:
	TTS.stop()


func _emit_next_round() -> void:
	_stop_recap_tts()
	next_round_pressed.emit()


func _emit_harder() -> void:
	_stop_recap_tts()
	harder_pressed.emit()


func _emit_home() -> void:
	_stop_recap_tts()
	home_pressed.emit()


## Hide the screen and reset state.
func hide_screen() -> void:
	_stop_recap_tts()
	_is_active = false
	if _container:
		_container.visible = false
		_container.modulate.a = 1.0
	_update_recap_label()
	# Stop and reset the OLED guard
	if _oled_guard:
		_oled_guard.stop()
	# Clean up coop character previews added dynamically.
	_clear_previews()
	screen_hidden.emit()


# ── OLED Idle Callbacks ───────────────────────────────────────────────────────

## Called after 60 s of idle on the win screen (countdown already cancelled).
## Dims the overlay and starts a gentle brightness pulse on the Next Round button.
func _on_oled_tier1() -> void:
	if not _is_active:
		return
	# Fade the container slightly
	var tw := create_tween()
	tw.tween_property(_container, "modulate:a", 0.50, 2.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if DPad and DPad.visible:
		DPad.dim(0.05, 2.5)
	# Pulse the Next Round button brightness in a loop
	if _next_button:
		if _oled_pulse_tween and _oled_pulse_tween.is_valid():
			_oled_pulse_tween.kill()
		_oled_pulse_tween = create_tween().set_loops()
		_oled_pulse_tween.tween_property(_next_button, "modulate:v", 0.55, 1.2).set_trans(Tween.TRANS_SINE)
		_oled_pulse_tween.tween_property(_next_button, "modulate:v", 1.0, 1.2).set_trans(Tween.TRANS_SINE)


## Called on any input — restore full brightness of the win/gotcha overlay.
func _on_oled_reset() -> void:
	if not _is_active:
		return
	# Kill the pulse and restore button
	if _oled_pulse_tween and _oled_pulse_tween.is_valid():
		_oled_pulse_tween.kill()
		_oled_pulse_tween = null
	if _next_button:
		_next_button.modulate.v = 1.0
	# Fade the container back to full opacity
	var tw := create_tween()
	tw.tween_property(_container, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if DPad:
		DPad.undim(0.25)


## Called after 3 min of idle on the win/gotcha screen — nobody is watching,
## so just go back to the home screen rather than auto-starting a new round.
func _on_oled_tier2() -> void:
	if not _is_active:
		return
	hide_screen()
	get_tree().change_scene_to_file(Scenes.HOME)


# ── UI Construction ──────────────────────────────────────────────────────────

func _build_ui() -> void:
	_container = CenterContainer.new()
	_container.anchors_preset = Control.PRESET_FULL_RECT
	_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_container)

	var main_panel := PanelContainer.new()
	main_panel.anchors_preset = Control.PRESET_CENTER
	main_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_panel.custom_minimum_size.x = 800

	var main_style := StyleBoxFlat.new()
	main_style.bg_color = UIColors.CARD_NEUTRAL
	main_style.corner_radius_top_left = 32
	main_style.corner_radius_top_right = 32
	main_style.corner_radius_bottom_right = 32
	main_style.corner_radius_bottom_left = 32
	main_style.border_width_left = 6
	main_style.border_width_top = 6
	main_style.border_width_right = 6
	main_style.border_width_bottom = 6
	main_style.border_color = UIColors.SELECTED_BORDER
	main_style.shadow_color = UIColors.SELECTED_SHADOW
	main_style.shadow_size = 12
	main_style.content_margin_left = 60
	main_style.content_margin_right = 60
	main_style.content_margin_top = 40
	main_style.content_margin_bottom = 40
	main_panel.add_theme_stylebox_override("panel", main_style)
	_container.add_child(main_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	main_panel.add_child(vbox)

	# Header row (Previews + Title + Previews)
	var title_hbox := build_title_header(tr("you_win"), [], 124, 90)
	vbox.add_child(title_hbox)

	_left_previews = title_hbox.get_child(0) as HBoxContainer
	_win_label = title_hbox.get_child(1) as Label
	_right_previews = title_hbox.get_child(2) as HBoxContainer

	_recap_label = Label.new()
	_recap_label.visible = false
	_recap_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_recap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_recap_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_recap_label.custom_minimum_size.x = 720
	_recap_label.add_theme_font_size_override("font_size", 28)
	_recap_label.add_theme_color_override("font_color", UIColors.TEXT_SECONDARY)
	UIHelpers.apply_medium(_recap_label)
	vbox.add_child(_recap_label)

	var button_vbox := VBoxContainer.new()
	button_vbox.add_theme_constant_override("separation", 15)
	vbox.add_child(button_vbox)

	# Next Round + Timer
	var next_hbox := HBoxContainer.new()
	next_hbox.add_theme_constant_override("separation", 20)
	next_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	button_vbox.add_child(next_hbox)

	var next_spacer_l := Control.new()
	next_spacer_l.custom_minimum_size.x = 80
	next_hbox.add_child(next_spacer_l)

	_next_button = _create_styled_button(tr("next_round"), 650, 90, UIColors.YELLOW)
	_next_button.pressed.connect(_emit_next_round)
	next_hbox.add_child(_next_button)

	_timer_label = Label.new()
	_timer_label.text = "10"
	_timer_label.custom_minimum_size.x = 80
	_timer_label.add_theme_font_size_override("font_size", 36)
	_timer_label.add_theme_color_override("font_color", UIColors.TIMER_DIM)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	next_hbox.add_child(_timer_label)

	# Harder / Easier
	var harder_hbox := HBoxContainer.new()
	harder_hbox.add_theme_constant_override("separation", 20)
	harder_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	button_vbox.add_child(harder_hbox)

	var h_spacer_l := Control.new()
	h_spacer_l.custom_minimum_size.x = 80
	harder_hbox.add_child(h_spacer_l)

	_harder_button = _create_styled_button(tr("challenge_pp"), 650, 90, UIColors.YELLOW)
	_harder_button.pressed.connect(_emit_harder)
	harder_hbox.add_child(_harder_button)

	var h_spacer_r := Control.new()
	h_spacer_r.custom_minimum_size.x = 80
	harder_hbox.add_child(h_spacer_r)

	# Mode Switch Buttons (Play Together / Play Alone / Swap Roles)
	_suggestion_container = VBoxContainer.new()
	_suggestion_container.add_theme_constant_override("separation", 12)
	button_vbox.add_child(_suggestion_container)

	# Padding before Main Menu
	var padding := Control.new()
	padding.custom_minimum_size.y = 20
	button_vbox.add_child(padding)

	# Home Button
	var home_hbox := HBoxContainer.new()
	home_hbox.add_theme_constant_override("separation", 20)
	home_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	button_vbox.add_child(home_hbox)

	var home_spacer_l := Control.new()
	home_spacer_l.custom_minimum_size.x = 80
	home_hbox.add_child(home_spacer_l)

	var home_btn: Button = _create_styled_button(tr("main_menu"), 650, 90, UIColors.YELLOW)
	home_btn.pressed.connect(_emit_home)
	home_hbox.add_child(home_btn)

	var home_spacer_r := Control.new()
	home_spacer_r.custom_minimum_size.x = 80
	home_hbox.add_child(home_spacer_r)

	_container.visible = false


# ── Shared Button Style ──────────────────────────────────────────────────────

func _create_styled_button(btn_text: String, w: int, h: int, f_color: Color = UIColors.YELLOW) -> Button:
	return UIHelpers.create_styled_button(btn_text, w, h, f_color)

func _add_suggestion_button(text: String, callback: Callable, color: Color = UIColors.YELLOW, icon_path: String = "") -> void:
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_suggestion_container.add_child(hbox)

	var btn: Button = _create_styled_button(text, 650, 90, color)
	btn.pressed.connect(func():
		_stop_recap_tts()
		callback.call()
	)
	
	if not icon_path.is_empty():
		btn.text = "" # Hide native text to use custom layout
		var btn_hbox := HBoxContainer.new()
		btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		btn_hbox.add_theme_constant_override("separation", 16)
		btn_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		btn_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(btn_hbox)
		
		var lbl := Label.new()
		lbl.text = text
		lbl.add_theme_font_size_override("font_size", 42)
		lbl.add_theme_color_override("font_color", UIColors.TEXT_PRIMARY)
		UIHelpers.apply_semibold(lbl)
		
		var tex := TextureRect.new()
		tex.texture = load(icon_path)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.custom_minimum_size = Vector2(40, 40)
		tex.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		# Place icon before text to make it clear it's a mode switch
		btn_hbox.add_child(tex)
		btn_hbox.add_child(lbl)

	hbox.add_child(btn)

func _clear_previews() -> void:
	if _left_previews != null:
		for child in _left_previews.get_children():
			child.queue_free()
	if _right_previews != null:
		for child in _right_previews.get_children():
			child.queue_free()

static func create_preview_instance(cid: String, size: int) -> Control:
	if cid.is_empty():
		return null
	var p := CharacterPreview.new()
	p.custom_minimum_size = Vector2(size, size)
	p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var preview_data := CharacterCatalog.get_preview_data_by_id(cid)
	var frames: Array[Texture2D] = []
	if preview_data.has("frames"):
		for item in (preview_data.get("frames", []) as Array):
			var texture := item as Texture2D
			if texture != null:
				frames.append(texture)
	if frames.is_empty():
		var fallback := CharacterCatalog.get_texture_by_id(cid)
		if fallback != null:
			frames.append(fallback)
	if frames.is_empty():
		return null
	p.set_character(frames, float(preview_data.get("fps", 1.0)))
	return p

func _set_winner_character(character_id: String) -> void:
	_clear_previews()
	if character_id.is_empty():
		# If empty but we are in solo game, we still want to show the player icon
		# as decoration instead of the old star emojis.
		if is_instance_valid(Config) and not Config.theme_dir_name.is_empty():
			var default_char_id := Config.theme_dir_name + ":player"
			var p1 := create_preview_instance(default_char_id, 124)
			var p2 := create_preview_instance(default_char_id, 124)
			if p1 != null: _left_previews.add_child(p1)
			if p2 != null: _right_previews.add_child(p2)
		return
		
	var p1 := create_preview_instance(character_id, 124)
	var p2 := create_preview_instance(character_id, 124)
	if p1 != null: _left_previews.add_child(p1)
	if p2 != null: _right_previews.add_child(p2)
