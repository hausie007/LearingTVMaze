## top_menu.gd
## ---------------------------------------------------------------------------
## Top-level main menu — the entry point after the splash screen.
##
## Four navigation cards:
##   1. Play Now     — instant solo game with safe defaults
##   2. Your Adventure — custom setup wizard (Scenes.WIZARD)
##   3. Replay         — repeats the last started game/session
##   4. Join Game      — appears when a host is discovered on the network
##
## Settings and Help corner buttons live here (moved from the wizard).
## ---------------------------------------------------------------------------
extends Control

const MissionCatalog := preload("res://scripts/mission_catalog.gd")
const LogoTexture := preload("res://images/lm_paper_horizontal.png")
const ModeCardScene := preload("res://scenes/ui/mode_card.tscn")

# Card IDs
const CARD_PLAY_NOW := "play_now"
const CARD_YOUR_ADVENTURE := "your_adventure"
const CARD_REPLAY := "replay"
const CARD_PLAY_TOGETHER := "play_together"
const CARD_JOIN_GAME := "join_game"

@onready var center_container: CenterContainer = $CenterContainer

# ── Layout nodes ────────────────────────────────────────────────────────────
var _main_vbox: VBoxContainer = null
var _top_spacer: Control = null
var _logo: TextureRect = null
var _logo_card_spacer: Control = null
var _card_row: HBoxContainer = null
var _cards: Dictionary = {}  # id → ModeCard (Button)

var _corner_overlay: Control = null
var _settings_button: Button = null
var _help_button: Button = null

var _quit_dialog: CanvasLayer = null
var _quit_no_button: Button = null

# ── State ────────────────────────────────────────────────────────────────────
var _input_locked: bool = true
var _hosts: Array = []
var _oled_guard: OledIdleGuard = null


# ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	Input.warp_mouse(Vector2(-1, -1))
	_build_layout()
	_apply_dpad_layout()
	_apply_responsive_layout()
	_configure_navigation()

	NetworkManager.discovery_updated.connect(_on_discovery_updated)
	if Config != null and not Config.on_screen_controls_changed.is_connected(_on_controls_changed):
		Config.on_screen_controls_changed.connect(_on_controls_changed)

	# Start background discovery so we can show the join card when a host appears
	var err := NetworkManager.start_discovery()
	if err != OK:
		_hosts.clear()
	_update_join_card_visibility()
	_update_replay_card_state()

	# Focus the Play Now card
	var play_now_card: Button = _cards.get(CARD_PLAY_NOW, null) as Button
	if play_now_card != null:
		play_now_card.grab_focus()

	get_tree().create_timer(0.2).timeout.connect(func(): _input_locked = false)

	# OLED: home screen is a menu — release the wake lock.
	DisplayServer.screen_set_keep_on(false)

	# OLED idle guard: dim after 5 min, reload scene after 10 min.
	_oled_guard = OledIdleGuard.new()
	_oled_guard.name = "TopMenuOledGuard"
	add_child(_oled_guard)
	_oled_guard.idle_tier_1.connect(_on_oled_tier1)
	_oled_guard.idle_tier_2.connect(_on_oled_tier2)
	_oled_guard.idle_reset.connect(_on_oled_reset)
	_oled_guard.start(300.0, 600.0)


func _exit_tree() -> void:
	NetworkManager.stop_discovery()


# ── OLED Idle Callbacks ───────────────────────────────────────────────────────

func _on_oled_tier1() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.25, 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if DPad and DPad.visible:
		DPad.dim(0.05, 4.0)

func _on_oled_tier2() -> void:
	get_tree().reload_current_scene()

func _on_oled_reset() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if DPad:
		DPad.undim(0.3)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_apply_dpad_layout()
		_apply_responsive_layout()
		_configure_navigation()

func _on_controls_changed(_new_mode: int) -> void:
	_apply_dpad_layout()
	_apply_responsive_layout()
	_configure_navigation()


# ── Layout Building ──────────────────────────────────────────────────────────

func _build_layout() -> void:
	for child in center_container.get_children():
		center_container.remove_child(child)
		child.queue_free()

	_main_vbox = VBoxContainer.new()
	_main_vbox.name = "TopMenuVBox"
	_main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main_vbox.custom_minimum_size = Vector2(1500, 0)
	_main_vbox.add_theme_constant_override("separation", 12)
	center_container.add_child(_main_vbox)

	# Top spacer
	_top_spacer = Control.new()
	_top_spacer.name = "TopSpacer"
	_top_spacer.custom_minimum_size = Vector2(0, 16)
	_main_vbox.add_child(_top_spacer)

	# Logo
	_logo = TextureRect.new()
	_logo.name = "AppLogo"
	_logo.texture = LogoTexture
	_logo.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.clip_contents = false
	_logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_main_vbox.add_child(_logo)

	_logo_card_spacer = Control.new()
	_logo_card_spacer.name = "LogoCardSpacer"
	_logo_card_spacer.custom_minimum_size = Vector2(0, 24)
	_main_vbox.add_child(_logo_card_spacer)

	# Card row
	_card_row = HBoxContainer.new()
	_card_row.name = "CardRow"
	_card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_card_row.add_theme_constant_override("separation", 48)
	_main_vbox.add_child(_card_row)

	_build_cards()
	_build_corner_buttons()


func _build_cards() -> void:
	var card_data := _build_card_data()
	for data in card_data:
		var card_id := String(data.get("id", ""))
		var card: Button = ModeCardScene.instantiate() as Button
		card.call("setup",
			String(data.get("icon", "")),
			String(data.get("title", "")),
			String(data.get("subtitle", ""))
		)
		card.pressed.connect(_on_card_pressed.bind(card_id))
		_card_row.add_child(card)
		_cards[card_id] = card

	# Apply palettes
	_apply_card_styles()
	_update_hidden_play_together_card()


func _build_card_data() -> Array[Dictionary]:
	var data: Array[Dictionary] = []

	# Play Now — gold
	data.append({
		"id": CARD_PLAY_NOW,
		"icon": "res://images/icons/i_play_now.png",
		"title": tr("menu_play_now"),
		"subtitle": tr("menu_play_now_desc"),
	})

	# Your Adventure — blue
	data.append({
		"id": CARD_YOUR_ADVENTURE,
		"icon": "res://images/icons/i_your_adventure.png",
		"title": tr("menu_your_adventure"),
		"subtitle": tr("menu_your_adventure_desc"),
	})

	# Replay — repeats the last played configuration
	data.append({
		"id": CARD_REPLAY,
		"icon": "res://images/icons/i_replay.png",
		"title": tr("menu_replay"),
		"subtitle": tr("menu_replay_desc"),
	})

	# Play Together — currently hidden, kept ready for the multiplayer entry point
	data.append({
		"id": CARD_PLAY_TOGETHER,
		"icon": "res://images/icons/i_play_together.png",
		"title": tr("start_together"),
		"subtitle": tr("menu_play_together_desc"),
	})

	# Join Game — teal (dynamic, shown/hidden based on discovery)
	data.append({
		"id": CARD_JOIN_GAME,
		"icon": "res://images/icons/i_join_game.png",
		"title": tr("menu_join_game"),
		"subtitle": tr("menu_join_searching"),
	})

	return data


func _apply_card_styles() -> void:
	# Play Now — warm yellow / gold palette
	var play_now: Button = _cards.get(CARD_PLAY_NOW, null) as Button
	if play_now != null:
		play_now.call("set_custom_palette",
			UIColors.CARD_YELLOW_DARK, UIColors.CARD_BORDER_SOFT,
			UIColors.UI_YELLOW, UIColors.HEADING_YELLOW,
			UIColors.HEADING_YELLOW, UIColors.TEXT_PRIMARY, UIColors.TEXT_SECONDARY
		)

	# Your Adventure — blue (default selected style from mode_card handles this)

	# Replay — same warm red family as Race to the Middle.
	var replay: Button = _cards.get(CARD_REPLAY, null) as Button
	if replay != null:
		replay.call("set_custom_palette",
			UIColors.CARD_ORANGE_RED_DARK, UIColors.CARD_BORDER_SOFT,
			UIColors.UI_ORANGE_RED, UIColors.SELECTED_BORDER,
			UIColors.RED_ACCENT, UIColors.TEXT_PRIMARY, UIColors.TEXT_SECONDARY
		)

	# Play Together — green co-op palette
	var play_together: Button = _cards.get(CARD_PLAY_TOGETHER, null) as Button
	if play_together != null:
		play_together.call("set_custom_palette",
			UIColors.CARD_GREEN_DARK, UIColors.CARD_BORDER_SOFT,
			UIColors.UI_GREEN, UIColors.GREEN_ACCENT,
			UIColors.GREEN_ACCENT, UIColors.TEXT_PRIMARY, UIColors.TEXT_SECONDARY
		)

	# Join Game — blue palette (uses same semantic blue as adventure)
	var join_game: Button = _cards.get(CARD_JOIN_GAME, null) as Button
	if join_game != null:
		join_game.call("set_custom_palette",
			UIColors.CARD_BLUE_DARK, UIColors.CARD_BORDER_SOFT,
			UIColors.UI_BLUE, UIColors.BLUE_ACCENT,
			UIColors.BLUE_ACCENT, UIColors.TEXT_PRIMARY, UIColors.TEXT_SECONDARY
		)


func _build_corner_buttons() -> void:
	_corner_overlay = Control.new()
	_corner_overlay.name = "CornerButtons"
	_corner_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_corner_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_corner_overlay)

	_settings_button = _create_corner_button(tr("settings"))
	_settings_button.pressed.connect(func():
		NetworkManager.stop_discovery()
		get_tree().change_scene_to_file(Scenes.SETTINGS)
	)
	_corner_overlay.add_child(_settings_button)

	_help_button = _create_corner_button(tr("help"))
	_help_button.pressed.connect(func():
		NetworkManager.stop_discovery()
		get_tree().change_scene_to_file(Scenes.HELP)
	)
	_corner_overlay.add_child(_help_button)


func _create_corner_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(220, 52)
	button.add_theme_font_size_override("font_size", 22)
	UIHelpers.apply_style_to_button(button, UIColors.YELLOW)
	return button


# ── Card Actions ─────────────────────────────────────────────────────────────

func _on_card_pressed(card_id: String) -> void:
	if _input_locked:
		return
	match card_id:
		CARD_PLAY_NOW:
			_start_play_now()
		CARD_YOUR_ADVENTURE:
			_navigate_to_wizard(false)
		CARD_REPLAY:
			_start_replay()
		CARD_PLAY_TOGETHER:
			_navigate_to_wizard(true)
		CARD_JOIN_GAME:
			_navigate_to_join_flow()


func _start_play_now() -> void:
	# Safe defaults: solo, numbers trail, small maze, no chaser
	Config.configure_single_player_session(
		MissionCatalog.STYLE_PATH,
		MissionCatalog.TRAINING_NUMBERS,
		false,
		Config.ChaserLevel.OFF,
		MissionCatalog.MISSION_FOLLOW_TRAIL,
	)
	Config.difficulty = 0  # Very Small maze
	Config.remember_last_single_player_session()
	Config.save_settings()
	NetworkManager.stop_discovery()
	DisplayServer.screen_set_keep_on(true)
	UIHelpers.go_to_scene_with_loading(get_tree(), Scenes.GAME)

func _start_replay() -> void:
	if not Config.has_replayable_last_game():
		_update_replay_card_state()
		return

	NetworkManager.stop_discovery()
	var replay_kind := String(Config.last_played_game.get("kind", ""))
	if replay_kind == Config.LAST_SESSION_SINGLE_PLAYER:
		if not Config.apply_last_single_player_session():
			_update_replay_card_state()
			return
		Config.remember_last_single_player_session()
		Config.save_settings()
		DisplayServer.screen_set_keep_on(true)
		UIHelpers.go_to_scene_with_loading(get_tree(), Scenes.GAME)
	elif replay_kind == Config.LAST_SESSION_MULTIPLAYER_HOST:
		var host_config := Config.get_last_multiplayer_host_config()
		if host_config.is_empty():
			_update_replay_card_state()
			return
		_apply_replay_host_config_to_settings(host_config)
		Config.save_settings()
		NetworkManager.configure_host(host_config)
		var err := NetworkManager.start_host()
		if err != OK:
			push_error("Failed to replay hosted game: %d" % err)
			_update_replay_card_state()
			return
		get_tree().change_scene_to_file(Scenes.HOST_LOBBY)

func _apply_replay_host_config_to_settings(host_config: Dictionary) -> void:
	Config.difficulty = clampi(int(host_config.get("difficulty", Config.difficulty)), 0, Config.DIFFICULTY_SIZES.size() - 1)
	Config.theme_dir_name = String(host_config.get("theme_dir", Config.theme_dir_name))
	Config.game_style = String(host_config.get("game_style", Config.game_style))
	Config.training_type = String(host_config.get("training_type", Config.training_type))
	Config.mission_id = String(host_config.get("mission_id", Config.mission_id))
	Config.chaser_enabled = bool(host_config.get("chaser_enabled", false))
	Config.chaser_level = clampi(int(host_config.get("chaser_level", Config.chaser_level)), Config.ChaserLevel.OFF, Config.ChaserLevel.TURBO) as Config.ChaserLevel
	Config.game_mode = Config.game_mode_for_training(Config.training_type) as Config.GameMode
	Config.player_role = Config.ROLE_RACER if Config.game_style == Config.STYLE_RACE else Config.ROLE_COLLECTOR
	Config.traps_enabled = bool(host_config.get("traps_enabled", false)) and Config.traps_allowed_for_session(Config.game_style, Config.chaser_enabled, Config.mission_id)


func _navigate_to_wizard(multiplayer_host: bool) -> void:
	Config.is_multiplayer_host = multiplayer_host
	NetworkManager.stop_discovery()
	get_tree().change_scene_to_file(Scenes.WIZARD)


func _navigate_to_join_flow() -> void:
	if _hosts.is_empty():
		return
	NetworkManager.set_pending_join_host((_hosts[0] as Dictionary).duplicate(true))
	NetworkManager.stop_discovery()
	get_tree().change_scene_to_file(Scenes.JOIN_FLOW)


# ── Discovery ────────────────────────────────────────────────────────────────

func _on_discovery_updated(hosts: Array) -> void:
	_hosts = hosts.duplicate(true)
	_update_join_card_visibility()


func _update_join_card_visibility() -> void:
	var join_card: Button = _cards.get(CARD_JOIN_GAME, null) as Button
	if join_card == null:
		return

	var has_hosts := not _hosts.is_empty()
	var focus_owner: Control = get_viewport().gui_get_focus_owner() if get_viewport() != null else null
	var was_showing := join_card.visible

	join_card.visible = has_hosts
	join_card.disabled = not has_hosts
	join_card.mouse_filter = Control.MOUSE_FILTER_STOP if has_hosts else Control.MOUSE_FILTER_IGNORE
	join_card.focus_mode = Control.FOCUS_ALL if has_hosts else Control.FOCUS_NONE

	if not has_hosts and focus_owner == join_card:
		var play_now: Button = _cards.get(CARD_PLAY_NOW, null) as Button
		if play_now != null:
			play_now.grab_focus()

	if was_showing != has_hosts:
		_apply_responsive_layout()
		_configure_navigation()

func _update_replay_card_state() -> void:
	var replay_card: Button = _cards.get(CARD_REPLAY, null) as Button
	if replay_card == null:
		return

	var can_replay := Config.has_replayable_last_game()
	var focus_owner: Control = get_viewport().gui_get_focus_owner() if get_viewport() != null else null
	replay_card.disabled = not can_replay
	replay_card.focus_mode = Control.FOCUS_ALL if can_replay else Control.FOCUS_NONE
	replay_card.mouse_filter = Control.MOUSE_FILTER_STOP if can_replay else Control.MOUSE_FILTER_IGNORE
	replay_card.modulate = Color.WHITE if can_replay else Color(1.0, 1.0, 1.0, 0.42)
	if not can_replay and focus_owner == replay_card:
		var play_now: Button = _cards.get(CARD_PLAY_NOW, null) as Button
		if play_now != null:
			play_now.grab_focus()
	_configure_navigation()

func _update_hidden_play_together_card() -> void:
	var play_together: Button = _cards.get(CARD_PLAY_TOGETHER, null) as Button
	if play_together == null:
		return
	play_together.visible = false
	play_together.disabled = true
	play_together.focus_mode = Control.FOCUS_NONE
	play_together.mouse_filter = Control.MOUSE_FILTER_IGNORE


# ── Navigation ───────────────────────────────────────────────────────────────

func _configure_navigation() -> void:
	var visible_cards: Array[Button] = []
	for id in _card_order():
		var card: Button = _cards.get(id, null) as Button
		if card != null and card.visible and not card.disabled and card.focus_mode != Control.FOCUS_NONE:
			visible_cards.append(card)

	if visible_cards.is_empty():
		return

	var is_rtl := is_layout_rtl()

	# Horizontal navigation wraps within visible cards
	for i in range(visible_cards.size()):
		var card := visible_cards[i]
		var left_idx := (i + 1) % visible_cards.size() if is_rtl else (i - 1 + visible_cards.size()) % visible_cards.size()
		var right_idx := (i - 1 + visible_cards.size()) % visible_cards.size() if is_rtl else (i + 1) % visible_cards.size()
		card.focus_neighbor_left = card.get_path_to(visible_cards[left_idx])
		card.focus_neighbor_right = card.get_path_to(visible_cards[right_idx])
		# Top: lock to self (no row above)
		card.focus_neighbor_top = card.get_path_to(card)
		# Bottom: go to Settings button
		if _settings_button != null:
			card.focus_neighbor_bottom = card.get_path_to(_settings_button)

	# Corner buttons
	if _settings_button != null and _help_button != null:
		_settings_button.focus_neighbor_right = _settings_button.get_path_to(_help_button)
		_help_button.focus_neighbor_left = _help_button.get_path_to(_settings_button)
		_settings_button.focus_neighbor_left = _settings_button.get_path_to(_settings_button)
		_help_button.focus_neighbor_right = _help_button.get_path_to(_help_button)
		# Top: go to the first visible card (or Play Now if available)
		var top_card: Button = visible_cards[0] if not visible_cards.is_empty() else null
		if top_card != null:
			_settings_button.focus_neighbor_top = _settings_button.get_path_to(top_card)
			_help_button.focus_neighbor_top = _help_button.get_path_to(top_card)
		# Bottom: lock to self
		_settings_button.focus_neighbor_bottom = _settings_button.get_path_to(_settings_button)
		_help_button.focus_neighbor_bottom = _help_button.get_path_to(_help_button)


# ── Responsive Layout ────────────────────────────────────────────────────────

func _apply_responsive_layout() -> void:
	var viewport_size := get_viewport_rect().size
	var available_width := _available_width()
	var short_screen: bool = viewport_size.y < 820.0

	if _main_vbox != null:
		_main_vbox.custom_minimum_size = Vector2(available_width, viewport_size.y)
		_main_vbox.add_theme_constant_override("separation", _spacing())

	if _top_spacer != null:
		_top_spacer.custom_minimum_size.y = clampf(viewport_size.y * 0.005, 2.0, 8.0)

	if _logo != null:
		var logo_width := clampf(available_width * (0.42 if short_screen else 0.48), 380.0, 780.0)
		_logo.custom_minimum_size = Vector2(logo_width, logo_width * 0.214)

	if _logo_card_spacer != null:
		_logo_card_spacer.custom_minimum_size.y = 12.0 if short_screen else 24.0

	# Card sizing
	_apply_card_sizing(available_width, viewport_size.y, short_screen)

	_position_corner_buttons()

	if _main_vbox != null:
		_main_vbox.size = Vector2.ZERO


func _apply_card_sizing(available_width: float, viewport_height: float, short_screen: bool) -> void:
	var visible_cards: Array[Button] = []
	for id in _card_order():
		var card: Button = _cards.get(id, null) as Button
		if card != null and card.visible:
			visible_cards.append(card)
	if visible_cards.is_empty():
		return

	var count := visible_cards.size()
	var columns: int = count if available_width >= 760.0 else mini(count, 2)
	var space_per_card := available_width / float(columns)
	var gap: int = 48 if space_per_card >= 260.0 else (34 if space_per_card >= 200.0 else 24)
	var gaps := float(gap * maxi(0, columns - 1))
	var card_width := clampf(floorf((available_width - gaps) / float(columns)), 140.0, 390.0)
	var card_height := clampf(viewport_height * (0.34 if short_screen else 0.32), 240.0, 340.0)
	var icon_size: int = 46 if card_width < 220.0 else (52 if card_width < 270.0 else 58)
	var title_size: int = 24 if card_width < 220.0 else (28 if card_width < 270.0 else 31)
	var subtitle_size: int = 17 if card_width < 250.0 else 19

	if _card_row != null:
		_card_row.add_theme_constant_override("separation", gap)

	for card in visible_cards:
		card.custom_minimum_size = Vector2(card_width, card_height)
		card.size = Vector2.ZERO
		card.pivot_offset = Vector2(card_width * 0.5, card_height * 0.5)
		card.call("configure_compact", icon_size, title_size, subtitle_size)

	# Lock card row width so layout doesn't shift when join card appears/disappears
	if _card_row != null:
		_card_row.custom_minimum_size.x = available_width
		_card_row.size = Vector2.ZERO

func _card_order() -> Array[String]:
	return [CARD_PLAY_NOW, CARD_YOUR_ADVENTURE, CARD_REPLAY, CARD_PLAY_TOGETHER, CARD_JOIN_GAME]


func _position_corner_buttons() -> void:
	var viewport_size := get_viewport_rect().size
	var controls_mode: int = Config.on_screen_controls if Config != null else Config.ControlsMode.OFF
	var eff_mode := controls_mode
	if is_layout_rtl():
		if eff_mode == Config.ControlsMode.LEFT_HANDED:
			eff_mode = Config.ControlsMode.RIGHT_HANDED
		elif eff_mode == Config.ControlsMode.RIGHT_HANDED:
			eff_mode = Config.ControlsMode.LEFT_HANDED
	var content_rect := UIHelpers.get_content_rect(viewport_size, eff_mode)
	var margin: float = 24.0
	if _settings_button != null:
		var s := _settings_button.custom_minimum_size
		_settings_button.size = s
		_settings_button.position = Vector2(content_rect.position.x + margin, viewport_size.y - s.y - margin)
	if _help_button != null:
		var s := _help_button.custom_minimum_size
		_help_button.size = s
		_help_button.position = Vector2(content_rect.end.x - s.x - margin, viewport_size.y - s.y - margin)


func _apply_dpad_layout() -> void:
	if center_container != null and Config != null:
		UIHelpers.apply_dpad_layout(center_container, Config.on_screen_controls)


func _available_width() -> float:
	var viewport_size := get_viewport_rect().size
	var controls_mode := Config.ControlsMode.OFF
	if Config != null:
		controls_mode = Config.on_screen_controls as Config.ControlsMode
	var content_rect := UIHelpers.get_content_rect(viewport_size, controls_mode)
	return clampf(content_rect.size.x * 0.985, 760.0, 1640.0)


func _spacing() -> int:
	var h := get_viewport_rect().size.y
	if h < 650.0: return 6
	if h < 820.0: return 10
	return 14


# ── Input ─────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if _input_locked: return
	if not event.is_action_pressed("ui_cancel"): return

	if _quit_dialog and _quit_dialog.visible:
		_hide_quit_dialog()
	else:
		_show_quit_dialog()
	get_viewport().set_input_as_handled()


# ── Quit Dialog ───────────────────────────────────────────────────────────────

func _show_quit_dialog() -> void:
	if _quit_dialog == null:
		_create_quit_dialog()
	_quit_dialog.visible = true
	if _quit_no_button:
		_quit_no_button.grab_focus()

func _hide_quit_dialog() -> void:
	if _quit_dialog != null:
		_quit_dialog.visible = false
	var play_now: Button = _cards.get(CARD_PLAY_NOW, null) as Button
	if play_now != null:
		play_now.grab_focus()

func _create_quit_dialog() -> void:
	_quit_dialog = CanvasLayer.new()
	_quit_dialog.layer = 100
	add_child(_quit_dialog)

	var overlay := ColorRect.new()
	overlay.color = UIColors.OVERLAY
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_quit_dialog.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	var style := UIHelpers.create_rounded_stylebox(UIColors.BG_DARK, UIColors.BLUE, 20, 4)
	style.content_margin_left = 60
	style.content_margin_right = 60
	style.content_margin_top = 40
	style.content_margin_bottom = 40
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 40)
	panel.add_child(vbox)

	var label := Label.new()
	label.text = tr("quit_confirm")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 48)
	vbox.add_child(label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 50)
	vbox.add_child(row)

	var yes_button := UIHelpers.create_styled_button(tr("yes"), 250, 100, UIColors.BLUE, 36)
	yes_button.pressed.connect(func(): get_tree().quit())
	row.add_child(yes_button)

	_quit_no_button = UIHelpers.create_styled_button(tr("no"), 250, 100, UIColors.YELLOW, 36)
	_quit_no_button.pressed.connect(_hide_quit_dialog)
	row.add_child(_quit_no_button)
