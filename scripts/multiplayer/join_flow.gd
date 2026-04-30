extends Control

const DEFAULT_GAME_PORT: int = 42020
const MissionCatalog := preload("res://scripts/mission_catalog.gd")
const LogoTexture := preload("res://images/lm_horizontal.png")

const MP_GREEN := PlayerSlotPanel.MP_GREEN
const MP_GREEN_BORDER := PlayerSlotPanel.MP_GREEN_BORDER
const SLOT_EMPTY_COLOR := PlayerSlotPanel.SLOT_EMPTY_COLOR
const SLOT_EMPTY_BG := PlayerSlotPanel.SLOT_EMPTY_BG
const MP_RED        := Color("#C84848")
const MP_RED_BORDER := Color("#E05050")
const JOIN_GREEN    := Color(0.18, 0.62, 0.34)

# ── Scene nodes ─────────────────────────────────────────────────────────────
@onready var discovery_panel: Control = %DiscoveryPanel
@onready var discovery_title_label: Label = %DiscoveryTitleLabel
@onready var discovery_status_label: Label = %DiscoveryStatusLabel
@onready var network_debug_label: Label = %NetworkDebugLabel
@onready var host_list_scroll: ScrollContainer = %HostListScroll
@onready var host_list_vbox: VBoxContainer = %HostListVBox
@onready var join_setup_panel: Control = %JoinSetupPanel
@onready var join_setup_center: CenterContainer = $"JoinSetupPanel/CenterContainer"
@onready var chaser_overlay: Control = %ChaserOverlay
@onready var chaser_ready_label: Label = get_node_or_null("%ChaserReadyLabel")
@onready var chaser_countdown_label: Label = get_node_or_null("%ChaserCountdownLabel")

# ── Code-built layout ──────────────────────────────────────────────────────
var _main_vbox: VBoxContainer = null
var _top_spacer: Control = null
var _logo: TextureRect = null
var _title_label: Label = null
var _breadcrumb1: Button = null
var _breadcrumb2: Button = null
var _slots_row: HBoxContainer = null
var _slot_nodes: Array[Dictionary] = []
var _join_button: Button = null
var _join_error_label: Label = null
var _controller_row: HBoxContainer = null
var _controller_button: Button = null
var _controller_left: Label = null
var _controller_right: Label = null
var _char_row: HBoxContainer = null
var _char_button: Button = null
var _char_left: Label = null
var _char_right: Label = null
var _char_preview: CharacterPreview = null
var _instruction_panel: PanelContainer = null
var _instruction_label: Label = null
var _settings_vbox: VBoxContainer = null
var _join_card_container: MarginContainer = null
var _join_card_panel: PanelContainer = null
var _join_card_normal: StyleBoxFlat = null
var _join_card_focus: StyleBoxFlat = null
var _join_card_tween: Tween = null
var _pulse_tween: Tween = null
var _pause_dialog: PauseDialog = null
var _gameplay_banner: PanelContainer = null
var _gameplay_banner_label: Label = null
var _gameplay_char_preview: CharacterPreview = null
var _current_goal_text: String = ""
var _is_chaser_waiting: bool = false

# ── State ───────────────────────────────────────────────────────────────────
var _hosts: Array = []
var _host_cards: Array[Button] = []
var _selected_host_index: int = -1
var _selected_host: Dictionary = {}
var _character_catalog: Array[Dictionary] = []
var _taken_character_ids: Array[String] = []
var _selected_character_idx: int = -1
var _selected_character_id: String = ""
var _selected_character_palette: Dictionary = {}
var _selected_host_available: bool = false
var _my_role: String = ""
var _saved_local_dpad_visible: bool = true
var _local_dpad_node: CanvasLayer = null
var _leaving: bool = false
var _joined: bool = false
var _join_pending: bool = false  # true between join press and accept/reject
var _game_started: bool = false
var _unjoining: bool = false
var _last_host_cfg: Dictionary = {}

# ── Game Switcher UI (multi-game support) ───────────────────────────────────
# Arrows flank the green join card: [‹]  [card]  [›]
var _game_switcher_label: Label = null   # "Game N of M" shown below the card
var _game_prev_button: Button = null     # ‹ left of card
var _game_next_button: Button = null     # › right of card
var _game_unavailable_label: Label = null

# OLED burn-in protection for the idle join-setup screen.
var _oled_guard: OledIdleGuard = null

func _ready() -> void:
	Input.warp_mouse(Vector2(-1, -1))
	_localize_ui()
	if network_debug_label != null:
		network_debug_label.visible = false
	_cache_local_dpad()
	_character_catalog = CharacterCatalog.build_catalog()

	NetworkManager.host_discovered.connect(_on_host_discovered)
	NetworkManager.discovery_updated.connect(_on_discovery_updated)
	NetworkManager.lobby_updated.connect(_on_lobby_updated)
	NetworkManager.join_accepted.connect(_on_join_accepted)
	NetworkManager.join_rejected.connect(_on_join_rejected)
	NetworkManager.game_started.connect(_on_game_started)
	NetworkManager.debug_status_changed.connect(_on_network_debug_changed)
	if NetworkManager.has_signal("chaser_countdown_updated"):
		NetworkManager.chaser_countdown_updated.connect(_on_chaser_countdown_updated)
	if NetworkManager.has_signal("chaser_released"):
		NetworkManager.chaser_released.connect(_on_chaser_released)
	if NetworkManager.has_signal("remote_goal_updated"):
		NetworkManager.remote_goal_updated.connect(_on_remote_goal_updated)
	if Config != null and not Config.on_screen_controls_changed.is_connected(_on_controls_changed):
		Config.on_screen_controls_changed.connect(_on_controls_changed)

	_pause_dialog = PauseDialog.new()
	_pause_dialog.confirmed.connect(func(): _pause_dialog.hide_dialog(); _leave_session())
	_pause_dialog.cancelled.connect(func(): _pause_dialog.hide_dialog())
	add_child(_pause_dialog)

	var pending_host: Dictionary = NetworkManager.consume_pending_join_host()
	if pending_host.is_empty():
		get_tree().change_scene_to_file(Scenes.HOME)
		return
	_selected_host = pending_host.duplicate(true)
	_hosts = [_selected_host.duplicate(true)]
	_selected_host_index = 0
	_selected_host_available = true
	NetworkManager.start_discovery()
	_enter_join_setup_mode()

func _unhandled_input(event: InputEvent) -> void:
	var viewport: Viewport = get_viewport()
	# Post-join: forward d-pad to host (unless a selector button has focus)
	if _joined and join_setup_panel.visible:
		var focus_owner: Control = viewport.gui_get_focus_owner() if viewport != null else null
		var on_selector := focus_owner == _controller_button
		if not on_selector:
			if event.is_action("ui_up"):
				_send_controller_direction(Vector2i.UP, event.is_pressed())
				if viewport != null: viewport.set_input_as_handled()
				return
			if event.is_action("ui_down"):
				_send_controller_direction(Vector2i.DOWN, event.is_pressed())
				if viewport != null: viewport.set_input_as_handled()
				return
			if event.is_action("ui_left"):
				_send_controller_direction(Vector2i.LEFT, event.is_pressed())
				if viewport != null: viewport.set_input_as_handled()
				return
			if event.is_action("ui_right"):
				_send_controller_direction(Vector2i.RIGHT, event.is_pressed())
				if viewport != null: viewport.set_input_as_handled()
				return
		if event.is_action_pressed("ui_cancel"):
			if viewport != null: viewport.set_input_as_handled()
			if _game_started:
				_toggle_pause()
			else:
				_unjoin()
			return

	if not event.is_action_pressed("ui_cancel"):
		return
	if viewport != null: viewport.set_input_as_handled()
	if _joined:
		if _game_started:
			_toggle_pause()
		else:
			_unjoin()
	else:
		_leave_session()

func _toggle_pause() -> void:
	if _pause_dialog == null:
		return
	if _pause_dialog.visible:
		_pause_dialog.hide_dialog()
	else:
		_pause_dialog.show_dialog()

func _exit_tree() -> void:
	_reset_global_dpad_accent()
	_restore_local_dpad()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_apply_dpad_layout()
		_apply_responsive_layout()
		_configure_navigation()

func _on_controls_changed(_new_mode: int) -> void:
	_apply_dpad_layout()
	_apply_responsive_layout()
	_configure_navigation()
	if _joined:
		_show_local_dpad_for_setup()

func _localize_ui() -> void:
	discovery_title_label.text = tr("mp_join_discovery_title")
	discovery_status_label.text = tr("mp_join_discovery_scanning")

# ── Layout Building ─────────────────────────────────────────────────────────

func _enter_join_setup_mode() -> void:
	discovery_panel.visible = false
	join_setup_panel.visible = true
	_joined = false
	_build_setup_layout()
	_show_local_dpad_for_setup()
	_apply_dpad_layout()
	_populate_from_host()
	_update_character_selector()
	_refresh_controller_layout()
	_apply_responsive_layout()
	_configure_navigation()
	if _join_button != null and not _join_button.disabled:
		_join_button.call_deferred("grab_focus")
	elif _char_button != null and not _char_button.disabled:
		_char_button.call_deferred("grab_focus")

	# OLED: join screen is static while waiting — keep wake-lock OFF.
	DisplayServer.screen_set_keep_on(false)

	# Lazy-create the idle guard (could be called multiple times from unjoin).
	if _oled_guard == null:
		_oled_guard = OledIdleGuard.new()
		_oled_guard.name = "JoinFlowOledGuard"
		add_child(_oled_guard)
		_oled_guard.idle_tier_1.connect(func(): _on_join_oled_tier1())
		_oled_guard.idle_tier_2.connect(func(): _on_join_oled_tier2())
		_oled_guard.idle_reset.connect(func(): _on_join_oled_reset())
	_oled_guard.reset()
	_oled_guard.start(180.0, 300.0)


## Called after 3 min of join-screen idle — dim the overlay and D-pad.
func _on_join_oled_tier1() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.30, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if DPad and DPad.visible:
		DPad.dim(0.05, 3.0)


## Called after 5 min of join-screen idle — leave and go home.
func _on_join_oled_tier2() -> void:
	_leave_session()


## Called on any input — restore brightness.
func _on_join_oled_reset() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if DPad:
		DPad.undim(0.3)

func _build_setup_layout() -> void:
	for child in join_setup_center.get_children():
		join_setup_center.remove_child(child)
		child.queue_free()

	_main_vbox = VBoxContainer.new()
	_main_vbox.name = "SetupVBox"
	_main_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	_main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main_vbox.add_theme_constant_override("separation", 6)
	join_setup_center.add_child(_main_vbox)

	_gameplay_char_preview = CharacterPreview.new()
	_gameplay_char_preview.visible = false
	_gameplay_char_preview.custom_minimum_size = Vector2(256, 256)
	join_setup_center.add_child(_gameplay_char_preview)
	
	_gameplay_banner = PanelContainer.new()
	_gameplay_banner.visible = false
	var banner_style := UIHelpers.create_rounded_stylebox(Color(0.12, 0.13, 0.18, 0.95), UIColors.YELLOW, 12, 2)
	banner_style.content_margin_left = 32; banner_style.content_margin_right = 32
	banner_style.content_margin_top = 24; banner_style.content_margin_bottom = 24
	_gameplay_banner.add_theme_stylebox_override("panel", banner_style)
	
	var banner_margin := MarginContainer.new()
	banner_margin.add_theme_constant_override("margin_left", 48)
	banner_margin.add_theme_constant_override("margin_right", 48)
	banner_margin.add_theme_constant_override("margin_top", 32)
	_gameplay_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	banner_margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	banner_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gameplay_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_gameplay_banner_label = Label.new()
	_gameplay_banner_label.add_theme_font_size_override("font_size", 36)
	_gameplay_banner_label.add_theme_color_override("font_color", UIColors.YELLOW)
	_gameplay_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gameplay_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_gameplay_banner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_gameplay_banner.add_child(_gameplay_banner_label)
	banner_margin.add_child(_gameplay_banner)
	join_setup_panel.add_child(banner_margin)

	# Top spacer
	_top_spacer = Control.new()
	_top_spacer.custom_minimum_size = Vector2(0, 4)
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


	# Logo -> Breadcrumbs spacer
	var sp1 := Control.new()
	sp1.custom_minimum_size = Vector2(0, 8)
	_main_vbox.add_child(sp1)

	# Breadcrumb 1
	_breadcrumb1 = _build_breadcrumb_row()
	_main_vbox.add_child(_breadcrumb1)

	# Breadcrumb 2
	_breadcrumb2 = _build_breadcrumb_row()
	_main_vbox.add_child(_breadcrumb2)

	# Breadcrumbs -> Title spacer
	var logo_title_spacer := Control.new()
	logo_title_spacer.custom_minimum_size = Vector2(0, 4)
	_main_vbox.add_child(logo_title_spacer)

	# Title
	_title_label = Label.new()
	_title_label.text = tr("mp_join_title")
	_title_label.add_theme_font_size_override("font_size", 30)
	_title_label.add_theme_color_override("font_color", UIColors.YELLOW)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_main_vbox.add_child(_title_label)

	# Title -> Join Card spacer
	var sp2 := Control.new()
	sp2.custom_minimum_size = Vector2(0, 8)
	_main_vbox.add_child(sp2)

	# ── Join Card row: [‹]  [card]  [›] ────────────────────────────────────
	var card_center := HBoxContainer.new()
	card_center.alignment = BoxContainer.ALIGNMENT_CENTER
	card_center.add_theme_constant_override("separation", 40)
	_main_vbox.add_child(card_center)

	# Prev arrow — always in the HBox (uses modulate to hide, not visible,
	# so the card stays centered at all times).
	_game_prev_button = Button.new()
	_game_prev_button.text = "‹"
	_game_prev_button.add_theme_font_size_override("font_size", 48)
	_game_prev_button.add_theme_color_override("font_color", Color.WHITE)
	_game_prev_button.focus_mode = Control.FOCUS_NONE
	_game_prev_button.custom_minimum_size = Vector2(56, 0)
	_game_prev_button.modulate.a = 0.0
	_game_prev_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_game_prev_button.pressed.connect(func(): _cycle_game(-1))
	var prev_style := StyleBoxEmpty.new()
	_game_prev_button.add_theme_stylebox_override("normal", prev_style)
	_game_prev_button.add_theme_stylebox_override("hover", prev_style)
	_game_prev_button.add_theme_stylebox_override("pressed", prev_style)
	_game_prev_button.add_theme_stylebox_override("focus", prev_style)
	card_center.add_child(_game_prev_button)

	_join_card_container = MarginContainer.new()
	card_center.add_child(_join_card_container)

	# Next arrow — same approach as prev (opacity, not visibility).
	_game_next_button = Button.new()
	_game_next_button.text = "›"
	_game_next_button.add_theme_font_size_override("font_size", 48)
	_game_next_button.add_theme_color_override("font_color", Color.WHITE)
	_game_next_button.focus_mode = Control.FOCUS_NONE
	_game_next_button.custom_minimum_size = Vector2(56, 0)
	_game_next_button.modulate.a = 0.0
	_game_next_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_game_next_button.pressed.connect(func(): _cycle_game(1))
	var next_style := StyleBoxEmpty.new()
	_game_next_button.add_theme_stylebox_override("normal", next_style)
	_game_next_button.add_theme_stylebox_override("hover", next_style)
	_game_next_button.add_theme_stylebox_override("pressed", next_style)
	_game_next_button.add_theme_stylebox_override("focus", next_style)
	card_center.add_child(_game_next_button)

	_join_card_panel = PanelContainer.new()
	_join_card_normal = UIHelpers.create_rounded_stylebox(JOIN_GREEN.darkened(0.06), JOIN_GREEN.lightened(0.16), 15, 2)
	_join_card_normal.content_margin_left = 32; _join_card_normal.content_margin_right = 32
	_join_card_normal.content_margin_top = 16; _join_card_normal.content_margin_bottom = 16
	_join_card_panel.add_theme_stylebox_override("panel", _join_card_normal)
	
	_join_card_focus = UIHelpers.create_rounded_stylebox(JOIN_GREEN.darkened(0.02), Color.WHITE, 15, 6)
	_join_card_focus.content_margin_left = 32; _join_card_focus.content_margin_right = 32
	_join_card_focus.content_margin_top = 16; _join_card_focus.content_margin_bottom = 16
	_join_card_focus.shadow_color = Color(0, 0, 0, 0.25)
	_join_card_focus.shadow_size = 10
	
	_join_card_container.add_child(_join_card_panel)

	var card_vbox := VBoxContainer.new()
	card_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card_vbox.add_theme_constant_override("separation", 4)
	_join_card_panel.add_child(card_vbox)

	var card_title := Label.new()
	card_title.text = tr("mp_join_game")
	card_title.add_theme_font_size_override("font_size", 36)
	card_title.add_theme_color_override("font_color", Color.WHITE)
	card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_vbox.add_child(card_title)

	var sp_card := Control.new()
	sp_card.custom_minimum_size = Vector2(0, 12)
	card_vbox.add_child(sp_card)

	# ── Player slots (inside the card) ──────────────────────────────────────
	_slots_row = HBoxContainer.new()
	_slots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_slots_row.add_theme_constant_override("separation", 32)
	_slots_row.custom_minimum_size = Vector2(0, 140)
	card_vbox.add_child(_slots_row)

	# ── The clickable button overlay (also handles left/right to cycle games) ─
	_join_button = Button.new()
	_join_button.name = "JoinCardButton"
	_join_button.focus_mode = Control.FOCUS_ALL
	_join_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	var empty_style := StyleBoxEmpty.new()
	
	_join_button.add_theme_stylebox_override("normal", empty_style)
	_join_button.add_theme_stylebox_override("hover", empty_style)
	_join_button.add_theme_stylebox_override("pressed", empty_style)
	_join_button.add_theme_stylebox_override("focus", empty_style)
	
	_join_button.pressed.connect(_on_join_pressed)
	_join_button.focus_entered.connect(func(): _apply_card_zoom(true))
	_join_button.focus_exited.connect(func(): _apply_card_zoom(false))
	_join_button.mouse_entered.connect(_join_button.grab_focus)
	# Left/right on the focused card cycles through available games.
	_join_button.gui_input.connect(_on_join_button_gui_input)
	
	_join_card_container.add_child(_join_button)

	# Small spacer so the counter clears the card's drop shadow.
	var counter_spacer := Control.new()
	counter_spacer.custom_minimum_size = Vector2(0, 6)
	_main_vbox.add_child(counter_spacer)

	# ── "Game N of M" counter label (always reserves height via min size) ──
	_game_switcher_label = Label.new()
	_game_switcher_label.add_theme_font_size_override("font_size", 20)
	_game_switcher_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	_game_switcher_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_switcher_label.custom_minimum_size = Vector2(0, 20)
	_game_switcher_label.text = ""
	_main_vbox.add_child(_game_switcher_label)

	# ── Single status label (unavailable, no-games, error — one at a time) ──
	# Using _join_error_label for all status messages; _game_unavailable_label
	# points to the same node so existing call-sites work unchanged.
	_join_error_label = Label.new()
	_join_error_label.add_theme_font_size_override("font_size", 22)
	_join_error_label.add_theme_color_override("font_color", Color(1, 0.45, 0.45, 1))
	_join_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_join_error_label.custom_minimum_size = Vector2(0, 24)
	_join_error_label.text = ""
	_main_vbox.add_child(_join_error_label)
	_game_unavailable_label = _join_error_label  # alias — same node

	# Card -> Settings spacer
	var sp3 := Control.new()
	sp3.custom_minimum_size = Vector2(0, 8)
	_main_vbox.add_child(sp3)

	# ── Settings block (Character & Controller) ──────────────────────────────
	_settings_vbox = VBoxContainer.new()
	_settings_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_settings_vbox.add_theme_constant_override("separation", 8)
	_main_vbox.add_child(_settings_vbox)

	# Character row
	var char_data := _create_selector_row("mp_join_character")
	_char_row = char_data["row"] as HBoxContainer
	_char_left = char_data["left"] as Label
	_char_button = char_data["button"] as Button
	_char_right = char_data["right"] as Label
	_char_button.pressed.connect(func(): _cycle_character(1))
	_setup_cycling(_char_button, _cycle_character)
	_setup_arrow_visibility(_char_button, _char_left, _char_right)
	_char_preview = CharacterPreview.new()
	_char_preview.custom_minimum_size = Vector2(56, 56)
	_char_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_char_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var char_extras := char_data["extras"] as HBoxContainer
	char_extras.add_child(_char_preview)
	_settings_vbox.add_child(_char_row)

	# Controller layout row
	var ctrl_data := _create_selector_row("mp_join_remote_layout")
	_controller_row = ctrl_data["row"] as HBoxContainer
	_controller_left = ctrl_data["left"] as Label
	_controller_button = ctrl_data["button"] as Button
	_controller_right = ctrl_data["right"] as Label
	_controller_button.pressed.connect(func(): _cycle_controller_layout(1))
	_setup_cycling(_controller_button, _cycle_controller_layout)
	_setup_arrow_visibility(_controller_button, _controller_left, _controller_right)
	_settings_vbox.add_child(_controller_row)

	# Settings -> Panel spacer
	var sp5 := Control.new()
	sp5.custom_minimum_size = Vector2(0, 8)
	_main_vbox.add_child(sp5)

	# ── Instruction panel (goal text only) ──────────────────────────────────
	_instruction_panel = PanelContainer.new()
	var panel_style := UIHelpers.create_rounded_stylebox(
		Color(UIColors.BG_DARK.r, UIColors.BG_DARK.g, UIColors.BG_DARK.b, 0.85),
		Color(1, 1, 1, 0.12), 14, 1
	)
	panel_style.content_margin_left = 36
	panel_style.content_margin_right = 36
	panel_style.content_margin_top = 16
	panel_style.content_margin_bottom = 16
	_instruction_panel.add_theme_stylebox_override("panel", panel_style)
	_instruction_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_instruction_panel.custom_minimum_size = Vector2(800, 0)
	_main_vbox.add_child(_instruction_panel)

	_instruction_label = Label.new()
	_instruction_label.add_theme_font_size_override("font_size", 26)
	_instruction_label.add_theme_color_override("font_color", Color(1, 0.92, 0.6))
	_instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instruction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_instruction_panel.add_child(_instruction_label)

func _build_breadcrumb_row() -> Button:
	return BreadcrumbRow.create()

func _create_selector_row(label_key: String) -> Dictionary:
	return CyclingSelector.create_row_dict(label_key)

func _create_arrow_label() -> Label:
	return CyclingSelector.create_arrow_label()

func _setup_cycling(btn: Button, cycle_func: Callable) -> void:
	CyclingSelector.setup_cycling(btn, cycle_func)

func _setup_arrow_visibility(btn: Button, left: Label, right: Label) -> void:
	CyclingSelector.setup_arrow_visibility(btn, left, right)

# ── Character & Controller Cycling ──────────────────────────────────────────

func _update_character_selector() -> void:
	if _character_catalog.is_empty():
		if _char_button != null:
			_char_button.text = ""
			_char_button.disabled = true
		_selected_character_id = ""
		_selected_character_palette = AvatarAccent.safe_palette()
		_apply_selected_avatar_to_global_dpad()
		if _char_preview != null: _char_preview.clear()
		_update_join_action_state()
		return
	if _selected_character_idx < 0 or _selected_character_idx >= _character_catalog.size():
		var host_theme := String(_last_host_cfg.get("theme_dir", ""))
		if host_theme.is_empty():
			host_theme = Config.theme_dir_name
		var prefix := host_theme + ":"
		for i in range(_character_catalog.size()):
			var cat_id := String(_character_catalog[i].get("id", ""))
			if cat_id.begins_with(prefix) and not _taken_character_ids.has(cat_id):
				_selected_character_idx = i
				break
		if _selected_character_idx < 0:
			_selected_character_idx = _find_next_enabled_character(-1, 1)
	if _selected_character_idx >= 0:
		var current_id: String = String(_character_catalog[_selected_character_idx].get("id", ""))
		if _taken_character_ids.has(current_id):
			_selected_character_idx = _find_next_enabled_character(_selected_character_idx, 1)
	if _selected_character_idx < 0:
		if _char_button != null:
			_char_button.text = tr("mp_join_error_character_taken")
			_char_button.disabled = true
		_selected_character_id = ""
		if _char_preview != null: _char_preview.clear()
		_selected_character_palette = AvatarAccent.safe_palette()
		_apply_selected_avatar_to_global_dpad()
		_update_join_action_state()
		return
	var entry: Dictionary = _character_catalog[_selected_character_idx]
	_selected_character_id = String(entry.get("id", ""))
	if _char_button != null:
		_char_button.text = String(entry.get("display_name", ""))
		_char_button.disabled = false
	_apply_character_preview(_selected_character_id, _char_preview)
	_cache_character_palette(_selected_character_id)
	_apply_selected_avatar_to_global_dpad()
	_update_join_action_state()

func _cycle_character(dir: int) -> void:
	if _character_catalog.is_empty() or _joined: return
	_selected_character_idx = _find_next_enabled_character(_selected_character_idx, dir)
	_update_character_selector()

func _cycle_controller_layout(dir: int) -> void:
	if Config == null or Config.CONTROLS_KEYS.is_empty(): return
	Config.on_screen_controls = (Config.on_screen_controls + dir + Config.CONTROLS_KEYS.size()) % Config.CONTROLS_KEYS.size()
	Config.save_settings()
	_refresh_controller_layout()
	_apply_dpad_layout()

func _refresh_controller_layout() -> void:
	if Config == null or _controller_button == null: return
	if Config.on_screen_controls >= 0 and Config.on_screen_controls < Config.CONTROLS_KEYS.size():
		_controller_button.text = tr(Config.CONTROLS_KEYS[Config.on_screen_controls])

func _find_next_enabled_character(start_idx: int, dir: int) -> int:
	if _character_catalog.is_empty(): return -1
	var next_idx: int = start_idx
	for _i in range(_character_catalog.size()):
		next_idx = (next_idx + dir + _character_catalog.size()) % _character_catalog.size()
		var character_id: String = String(_character_catalog[next_idx].get("id", ""))
		if not _taken_character_ids.has(character_id):
			return next_idx
	return -1

func _update_join_action_state() -> void:
	if _join_button == null: return
	if _joined:
		_join_button.visible = false
		return
	var host_available: bool = _is_selected_host_available()
	var character_available: bool = not _selected_character_id.is_empty() and not _taken_character_ids.has(_selected_character_id)
	_join_button.disabled = not (host_available and character_available)
	# Only write the host-unavailable message if the status label is empty
	# (don't overwrite "Connecting…", "No games", or "Game unavailable" notices).
	if not host_available and _join_error_label != null and not _unjoining:
		if _join_error_label.text.is_empty():
			_join_error_label.text = tr("mp_join_host_unavailable")

# ── Game Switcher (multi-game support) ──────────────────────────────────────

func _cycle_game(dir: int) -> void:
	if _hosts.is_empty() or _joined: return
	_selected_host_index = (_selected_host_index + dir + _hosts.size()) % _hosts.size()
	_selected_host = (_hosts[_selected_host_index] as Dictionary).duplicate(true)
	_selected_host_available = true
	if _game_unavailable_label != null:
		_game_unavailable_label.text = ""
	_populate_from_host()
	_update_character_selector()
	_update_game_switcher()
	_update_join_action_state()

func _update_game_switcher() -> void:
	var count := _hosts.size()
	var show_arrows := count > 1 and not _joined
	var arrow_alpha := 1.0 if show_arrows else 0.0
	var arrow_filter := Control.MOUSE_FILTER_STOP if show_arrows else Control.MOUSE_FILTER_IGNORE
	if _game_prev_button != null:
		_game_prev_button.modulate.a = arrow_alpha
		_game_prev_button.mouse_filter = arrow_filter
	if _game_next_button != null:
		_game_next_button.modulate.a = arrow_alpha
		_game_next_button.mouse_filter = arrow_filter
	if _game_switcher_label != null:
		if show_arrows:
			var idx := clampi(_selected_host_index, 0, count - 1) + 1
			_game_switcher_label.text = tr("mp_join_game_counter") % [idx, count]
		else:
			_game_switcher_label.text = ""

func _show_no_games_state() -> void:
	_selected_host = {}
	_selected_host_available = false
	if _join_card_panel != null:
		_join_card_panel.modulate = Color(1, 1, 1, 0.3)
	if _join_button != null:
		_join_button.disabled = true
	if _game_unavailable_label != null:
		_game_unavailable_label.text = tr("mp_join_no_games")
	# Hide arrows (opacity) and clear counter text.
	if _game_prev_button != null:
		_game_prev_button.modulate.a = 0.0
		_game_prev_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _game_next_button != null:
		_game_next_button.modulate.a = 0.0
		_game_next_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _game_switcher_label != null:
		_game_switcher_label.text = ""
	# Suppress secondary error so only one message shows at a time.
	if _join_error_label != null:
		_join_error_label.text = ""

func _restore_from_no_games_state() -> void:
	if _join_card_panel != null:
		_join_card_panel.modulate = Color(1, 1, 1, 1)
	if _game_unavailable_label != null:
		_game_unavailable_label.text = ""

func _on_join_button_gui_input(event: InputEvent) -> void:
	# Allow left/right D-pad / keyboard to cycle between available games.
	if _joined or _hosts.size() <= 1: return
	if event.is_action_pressed("ui_left"):
		_cycle_game(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_cycle_game(1)
		get_viewport().set_input_as_handled()

# ── Network Callbacks ───────────────────────────────────────────────────────


func _on_host_discovered(_info: Dictionary) -> void:
	pass

func _on_discovery_updated(hosts: Array) -> void:
	_hosts = hosts.duplicate(true)
	_update_game_switcher()

	if join_setup_panel.visible and not _joined and not _join_pending:
		# We are on the pre-join setup panel — try to keep the same game.
		var was_available := _selected_host_available

		# Recovery from "no games" state: auto-select first game.
		if _selected_host.is_empty() and not _hosts.is_empty():
			_selected_host_index = 0
			_selected_host = (_hosts[0] as Dictionary).duplicate(true)
			_selected_host_available = true
			_restore_from_no_games_state()
			_populate_from_host()
			_update_character_selector()
			_update_game_switcher()
			_update_join_action_state()
			return

		_selected_host_available = _sync_selected_host_from_list()

		if not _selected_host_available:
			# The currently-shown game disappeared.
			if not _hosts.is_empty():
				# Auto-switch to first available.
				_selected_host_index = 0
				_selected_host = (_hosts[0] as Dictionary).duplicate(true)
				_selected_host_available = true
				_populate_from_host()
				_update_character_selector()
				# Show brief notice.
				if _game_unavailable_label != null:
					_game_unavailable_label.text = tr("mp_join_game_unavailable")
					get_tree().create_timer(3.0).timeout.connect(
						func(): if is_instance_valid(_game_unavailable_label): _game_unavailable_label.text = ""
					)
				_update_game_switcher()
			else:
				_show_no_games_state()
		else:
			# Game still present — refresh player count and taken chars.
			_populate_from_host()
			_update_character_selector()
			# Dismiss any stale unavailable notice.
			if not was_available and _game_unavailable_label != null:
				_game_unavailable_label.text = ""
		_update_join_action_state()
		return

	# Discovery panel (pre-selection): rebuild host card list.
	_rebuild_host_cards()
	if _hosts.is_empty():
		discovery_status_label.text = tr("mp_join_discovery_none")
	else:
		discovery_status_label.text = tr("mp_join_discovery_found")
		if discovery_panel.visible:
			if _selected_host_index >= 0 and _selected_host_index < _host_cards.size():
				_focus_host_card(_selected_host_index)
			else:
				_focus_first_host_card()

func _on_lobby_updated(state: Dictionary) -> void:
	if not join_setup_panel.visible: return
	var cfg: Dictionary = state.get("config", {}) as Dictionary
	var players: Dictionary = state.get("players", {}) as Dictionary
	
	var my_id := multiplayer.get_unique_id()
	var my_info := players.get(my_id, players.get(str(my_id), {})) as Dictionary
	var session_role := String(my_info.get("role", ""))
	if not session_role.is_empty():
		_my_role = session_role
		
	if not cfg.is_empty():
		_last_host_cfg = cfg.duplicate(true)
		_update_breadcrumbs(cfg)
		_update_instruction_text(cfg)
	_update_player_slots(_last_host_cfg, players)
	_taken_character_ids.clear()
	for info in players.values():
		var p: Dictionary = info as Dictionary
		_taken_character_ids.append(String(p.get("character_id", "")))
	if not _joined:
		if not _selected_character_id.is_empty() and _taken_character_ids.has(_selected_character_id):
			_selected_character_idx = _find_next_enabled_character(_selected_character_idx, 1)
			_update_character_selector()
		else:
			_update_join_action_state()

func _on_join_pressed() -> void:
	if _join_error_label != null: _join_error_label.text = ""
	if _selected_character_id.is_empty():
		if _join_error_label != null: _join_error_label.text = tr("mp_join_error_character")
		return
	if not _is_selected_host_available():
		_leave_session()
		return
	if _taken_character_ids.has(_selected_character_id):
		if _join_error_label != null: _join_error_label.text = tr("mp_join_error_character_taken")
		return
	var host_ip: String = String(_selected_host.get("ip", ""))
	var host_port: int = int(_selected_host.get("port", DEFAULT_GAME_PORT))
	var err: int = NetworkManager.join_host(host_ip, host_port, _selected_character_id)
	if err != OK:
		if _join_error_label != null:
			_join_error_label.text = "%s: %d" % [tr("mp_join_error_connect"), err]
		return
	_join_pending = true
	if _join_error_label != null: _join_error_label.text = tr("mp_join_connecting")

func _on_join_accepted(peer_id: int, state: Dictionary) -> void:
	_join_pending = false
	var character_id: String = _selected_character_id
	var players: Dictionary = state.get("players", {}) as Dictionary
	var my_info: Dictionary = {}
	if players.has(peer_id):
		my_info = players[peer_id] as Dictionary
		character_id = String(my_info.get("character_id", character_id))
	elif players.has(str(peer_id)):
		my_info = players[str(peer_id)] as Dictionary
		character_id = String(my_info.get("character_id", character_id))
	_my_role = String(my_info.get("role", ""))
	_update_instruction_text(_last_host_cfg)
	_transition_to_joined(character_id)

func _on_join_rejected(reason: String) -> void:
	_join_pending = false
	# Suppress network callbacks that fire as a side-effect of a voluntary unjoin.
	if _unjoining: return
	if _should_return_to_discovery(reason):
		_leave_session()
		return
	if _join_error_label != null: _join_error_label.text = reason

func _on_game_started(_session: Dictionary) -> void:
	_game_started = true
	# Game started — restore the wake lock and stop the idle guard.
	DisplayServer.screen_set_keep_on(true)
	if _oled_guard:
		_oled_guard.stop()
	modulate.a = 1.0  # Restore opacity in case tier-1 had dimmed us
	if _main_vbox != null: _main_vbox.visible = false

	if _instruction_panel != null: _instruction_panel.visible = false
	
	if _gameplay_char_preview != null:
		_gameplay_char_preview.visible = true
		_apply_character_preview(_selected_character_id, _gameplay_char_preview)
		
	var players := _session.get("players", {}) as Dictionary
	var my_id := multiplayer.get_unique_id()
	var my_info := players.get(my_id, players.get(str(my_id), {})) as Dictionary
	var session_role := String(my_info.get("role", ""))
	if not session_role.is_empty():
		_my_role = session_role
		
	var session_config := _session.get("config", _last_host_cfg) as Dictionary
	_update_instruction_text(session_config)
		
	if _gameplay_banner != null:
		_gameplay_banner.visible = true

func _on_chaser_countdown_updated(remaining: int) -> void:
	if _gameplay_banner_label == null: return
	_is_chaser_waiting = true
	if remaining > 3:
		_gameplay_banner_label.text = tr("mp_chaser_waiting_steps") % remaining
		_gameplay_banner_label.add_theme_font_size_override("font_size", 36)
		_gameplay_banner_label.add_theme_color_override("font_color", UIColors.YELLOW)
	elif remaining > 0:
		_gameplay_banner_label.text = tr("mp_chaser_get_ready_steps") % remaining
		_gameplay_banner_label.add_theme_font_size_override("font_size", 48)
		_gameplay_banner_label.add_theme_color_override("font_color", UIColors.YELLOW)

func _on_chaser_released() -> void:
	_is_chaser_waiting = false
	if OS.has_feature("mobile"): Input.vibrate_handheld(500)
	if _gameplay_banner_label != null:
		_gameplay_banner_label.text = "GO!"
		_gameplay_banner_label.add_theme_font_size_override("font_size", 64)
		_gameplay_banner_label.add_theme_color_override("font_color", UIColors.YELLOW)
		
	var timer := get_tree().create_timer(1.5)
	timer.connect("timeout", func():
		if is_instance_valid(_gameplay_banner_label):
			_gameplay_banner_label.text = _current_goal_text
			_gameplay_banner_label.add_theme_font_size_override("font_size", 36)
			_gameplay_banner_label.add_theme_color_override("font_color", UIColors.YELLOW)
	)

func _on_remote_goal_updated(goal_text: String) -> void:
	_current_goal_text = goal_text
	if not _joined:
		if _instruction_label != null:
			_instruction_label.text = goal_text
	else:
		if _my_role != NetworkManager.ROLE_CHASER:
			_is_chaser_waiting = false
			
		if _gameplay_banner_label != null and not _is_chaser_waiting:
			_gameplay_banner_label.text = goal_text

func _on_network_debug_changed(scope: String, message: String) -> void:
	if network_debug_label == null: return
	network_debug_label.text = "Network [%s]: %s" % [scope, message]

func _transition_to_joined(character_id: String) -> void:
	_joined = true
	if _join_button != null: _join_button.visible = false
	if _join_error_label != null: _join_error_label.visible = false
	if _settings_vbox != null: _settings_vbox.visible = false
	if _instruction_label != null:
		_instruction_label.text = tr("mp_waiting_for_host")
	_apply_character_preview(character_id, _char_preview)
	_cache_character_palette(character_id)
	_apply_selected_avatar_to_global_dpad()
	_show_local_dpad_for_setup()
	_configure_navigation()
	NetworkManager.stop_discovery()

# ── Layout / Navigation / Helpers ───────────────────────────────────────────

func _apply_dpad_layout() -> void:
	if join_setup_center != null and Config != null:
		UIHelpers.apply_dpad_layout(join_setup_center, Config.on_screen_controls)

func _configure_navigation() -> void:
	# Chain: char_button → controller_button → join_button
	var focusable: Array[Button] = []
	if _char_button != null and not _char_button.disabled and _char_button.visible:
		focusable.append(_char_button)
	if _controller_button != null and _controller_button.visible:
		focusable.append(_controller_button)
	if _join_button != null and _join_button.visible and not _join_button.disabled:
		focusable.append(_join_button)
	for i in range(focusable.size()):
		var btn := focusable[i]
		btn.focus_neighbor_left = btn.get_path_to(btn)
		btn.focus_neighbor_right = btn.get_path_to(btn)
		if i > 0:
			btn.focus_neighbor_top = btn.get_path_to(focusable[i - 1])
		if i < focusable.size() - 1:
			btn.focus_neighbor_bottom = btn.get_path_to(focusable[i + 1])

func _apply_responsive_layout() -> void:
	var available_width := _available_width()
	var viewport_height: float = get_viewport_rect().size.y
	var short_screen: bool = viewport_height < 820.0

	if _main_vbox != null:
		_main_vbox.custom_minimum_size = Vector2(available_width, viewport_height)
		_main_vbox.add_theme_constant_override("separation", 8 if short_screen else 12)

	if _top_spacer != null:
		_top_spacer.custom_minimum_size.y = clampf(viewport_height * 0.005, 2.0, 8.0)

	if _logo != null:
		var logo_width: float = clampf(available_width * (0.42 if short_screen else 0.48), 380.0, 780.0)
		var logo_height: float = clampf(logo_width * 0.214, 80.0, 166.0)
		_logo.custom_minimum_size = Vector2(logo_width, logo_height)

	if _title_label != null:
		_title_label.add_theme_font_size_override("font_size", 30 if short_screen else 36)

	# Breadcrumbs
	var bread_font := 26 if short_screen else 30
	var bread_h := 42.0 if short_screen else 50.0
	for bread in [_breadcrumb1, _breadcrumb2]:
		if bread == null: continue
		bread.custom_minimum_size = Vector2(clampf(available_width * 0.8, 600.0, 1200.0), bread_h)
		var s := bread.get_meta("summary") as Label
		if s != null: s.add_theme_font_size_override("font_size", bread_font)
		var c := bread.get_meta("chevron") as Label
		if c != null: c.add_theme_font_size_override("font_size", bread_font - 2)

	# Slots
	var slot_size: float = 100.0 if short_screen else 120.0
	var frame_size: float = slot_size * 0.9
	var preview_size: float = frame_size * 0.78
	for slot in _slot_nodes:
		(slot["vbox"] as Control).custom_minimum_size = Vector2(slot_size + 20, slot_size + 40)
		(slot["frame"] as PanelContainer).custom_minimum_size = Vector2(frame_size, frame_size)
		(slot["preview"] as CharacterPreview).custom_minimum_size = Vector2(preview_size, preview_size)
		(slot["label"] as Label).add_theme_font_size_override("font_size", 20 if short_screen else 22)
	if _slots_row != null:
		_slots_row.add_theme_constant_override("separation", 28 if short_screen else 36)
		_slots_row.custom_minimum_size.y = slot_size + 62

	# Selectors
	var sel_w := clampf(available_width * 0.32, 380.0, 500.0)
	var sel_h: float = 58.0 if short_screen else 66.0
	var sel_fs: int = 28 if short_screen else 31
	for btn in [_char_button, _controller_button]:
		if btn != null:
			btn.custom_minimum_size = Vector2(sel_w, sel_h)
			btn.add_theme_font_size_override("font_size", sel_fs)

	# Join button
	if _join_button != null:
		var jw := clampf(available_width * 0.22, 260.0, 380.0)
		_join_button.custom_minimum_size = Vector2(jw, 62.0 if short_screen else 68.0)
		_join_button.add_theme_font_size_override("font_size", 26 if short_screen else 30)

	# Instruction panel
	if _instruction_panel != null:
		_instruction_panel.custom_minimum_size.x = clampf(available_width * 0.7, 600.0, 1100.0)
		if _instruction_label != null:
			_instruction_label.add_theme_font_size_override("font_size", 24 if short_screen else 28)



func _available_width() -> float:
	var viewport_size := get_viewport_rect().size
	var controls_mode := Config.ControlsMode.OFF
	if Config != null: controls_mode = Config.on_screen_controls as Config.ControlsMode
	var content_rect := UIHelpers.get_content_rect(viewport_size, controls_mode)
	return clampf(content_rect.size.x * 0.985, 760.0, 1640.0)

# ── Helpers ─────────────────────────────────────────────────────────────────

func _apply_character_preview(character_id: String, preview: CharacterPreview) -> void:
	PlayerSlotPanel.apply_character_preview(character_id, preview)

func _cache_character_palette(character_id: String) -> void:
	if character_id.is_empty():
		_selected_character_palette = AvatarAccent.safe_palette()
		return
	_selected_character_palette = AvatarAccent.palette_from_character_id(character_id)
	if _selected_character_palette.is_empty():
		_selected_character_palette = AvatarAccent.safe_palette()

func _apply_selected_avatar_to_global_dpad() -> void:
	if _local_dpad_node == null: return
	if _local_dpad_node.has_method("set_accent_palette"):
		_local_dpad_node.call("set_accent_palette", _selected_character_palette)

func _reset_global_dpad_accent() -> void:
	if _local_dpad_node == null: return
	if _local_dpad_node.has_method("reset_accent_palette"):
		_local_dpad_node.call("reset_accent_palette")

func _send_controller_direction(direction: Vector2i, pressed: bool) -> void:
	NetworkManager.send_dpad(direction, pressed)

func _cache_local_dpad() -> void:
	_local_dpad_node = get_node_or_null("/root/DPad") as CanvasLayer
	if _local_dpad_node != null:
		_saved_local_dpad_visible = _local_dpad_node.visible
		var action_callable: Callable = Callable(self, "_on_local_dpad_action")
		if _local_dpad_node.has_signal("action_changed") and not _local_dpad_node.is_connected("action_changed", action_callable):
			_local_dpad_node.connect("action_changed", action_callable)

func _restore_local_dpad() -> void:
	if _local_dpad_node != null:
		if Config != null:
			_local_dpad_node.visible = Config.on_screen_controls != Config.ControlsMode.OFF
		else:
			_local_dpad_node.visible = _saved_local_dpad_visible

func _show_local_dpad_for_setup() -> void:
	if _local_dpad_node == null: return
	var off_mode: int = Config.ControlsMode.OFF if Config != null else 0
	var controls_mode: int = Config.on_screen_controls if Config != null else off_mode
	_local_dpad_node.visible = controls_mode != off_mode

func _on_local_dpad_action(action: StringName, pressed: bool) -> void:
	if not join_setup_panel.visible: return
	# ui_cancel is intentionally NOT handled here in any branch — TouchScreenButton
	# also injects it through the input system, so _unhandled_input handles it.
	# Handling it here too would double-fire the back action.
	if not _joined:
		return
	match action:
		&"ui_up": _send_controller_direction(Vector2i.UP, pressed)
		&"ui_down": _send_controller_direction(Vector2i.DOWN, pressed)
		&"ui_left": _send_controller_direction(Vector2i.LEFT, pressed)
		&"ui_right": _send_controller_direction(Vector2i.RIGHT, pressed)

## Disconnect from the current session and restore the pre-join UI so the
## player can reconfigure and join again without going back to the home screen.
func _unjoin() -> void:
	if _leaving or _unjoining: return
	_unjoining = true
	NetworkManager.leave_session()
	NetworkManager.start_discovery()
	_joined = false
	_game_started = false
	# Hide gameplay-only overlays
	if _gameplay_banner != null: _gameplay_banner.visible = false
	if _gameplay_char_preview != null: _gameplay_char_preview.visible = false
	# Restore pre-join UI elements
	if _main_vbox != null: _main_vbox.visible = true
	if _instruction_panel != null: _instruction_panel.visible = true
	if _join_button != null: _join_button.visible = true
	if _settings_vbox != null: _settings_vbox.visible = true
	# Show a neutral, localized "disconnected" message briefly.
	# _unjoining stays true for the same 3 s so _update_join_action_state()
	# cannot overwrite the message with "host unavailable" during that window.
	if _join_error_label != null:
		_join_error_label.visible = true
		_join_error_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6, 1.0))
		_join_error_label.text = tr("mp_join_disconnected")
	var lbl_ref := _join_error_label
	get_tree().create_timer(3.0).timeout.connect(func():
		_unjoining = false
		if is_instance_valid(lbl_ref) and lbl_ref.text == tr("mp_join_disconnected"):
			lbl_ref.text = ""
		if is_instance_valid(lbl_ref):
			lbl_ref.add_theme_color_override("font_color", Color(1, 0.45, 0.45, 1))
	)
	_update_instruction_text(_last_host_cfg)
	_update_join_action_state()
	_configure_navigation()
	# Focus the join card button and zoom the card unconditionally so the user
	# can press it again as soon as the host is re-discovered (even if the button
	# starts out disabled while discovery is still scanning).
	if _join_button != null:
		_join_button.call_deferred("grab_focus")
		_apply_card_zoom(true)

func _leave_session() -> void:
	if _leaving: return
	_leaving = true
	_reset_global_dpad_accent()
	_restore_local_dpad()
	NetworkManager.leave_session()
	Config.show_join_list_on_home = true
	Config.join_status_override = ""
	get_tree().change_scene_to_file(Scenes.HOME)


func _update_taken_character_ids_from_selected_host() -> void:
	_taken_character_ids.clear()
	var raw_taken: Variant = _selected_host.get("taken_characters", [])
	if raw_taken is Array:
		for item in (raw_taken as Array):
			var character_id: String = String(item)
			if not character_id.is_empty() and not _taken_character_ids.has(character_id):
				_taken_character_ids.append(character_id)

func _host_key(host: Dictionary) -> String:
	# Prefer session_id (unique per hosting session) over ip:port.
	var sid := String(host.get("session_id", ""))
	if not sid.is_empty():
		return sid
	return "%s:%d" % [String(host.get("ip", "")), int(host.get("port", DEFAULT_GAME_PORT))]

func _selected_host_key() -> String:
	if _selected_host.is_empty(): return ""
	return _host_key(_selected_host)

func _sync_selected_host_from_list() -> bool:
	var hk: String = _selected_host_key()
	if hk.is_empty(): return false
	for i in range(_hosts.size()):
		var host: Dictionary = _hosts[i] as Dictionary
		if _host_key(host) == hk:
			_selected_host_index = i
			_selected_host = host.duplicate(true)
			return true
	return false

func _is_selected_host_available() -> bool:
	return _selected_host_available and not _selected_host_key().is_empty()

func _should_return_to_discovery(reason: String) -> bool:
	return reason in ["Host unavailable", "Could not connect to host", "Disconnected from host", "Game already started", "Lobby is full"]

# ── Discovery (kept for host card rebuilding) ──────────────────────────────

func _rebuild_host_cards() -> void:
	if host_list_vbox == null: return
	for child in host_list_vbox.get_children():
		child.queue_free()
	_host_cards.clear()
	for i in range(_hosts.size()):
		var host: Dictionary = _hosts[i] as Dictionary
		var card: Button = _create_host_card(host, i)
		host_list_vbox.add_child(card)
		_host_cards.append(card)

func _create_host_card(host: Dictionary, index: int) -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(1000, 136)
	button.text = ""
	button.focus_mode = Control.FOCUS_ALL
	UIHelpers.apply_style_to_button(button, UIColors.BLUE)
	var card_margin: MarginContainer = MarginContainer.new()
	card_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_margin.add_theme_constant_override("margin_left", 18)
	card_margin.add_theme_constant_override("margin_top", 12)
	card_margin.add_theme_constant_override("margin_right", 18)
	card_margin.add_theme_constant_override("margin_bottom", 12)
	button.add_child(card_margin)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	card_margin.add_child(row)
	var icon: CharacterPreview = CharacterPreview.new()
	icon.custom_minimum_size = Vector2(104, 104)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var host_character_id: String = String(host.get("character_id", ""))
	_apply_character_preview(host_character_id, icon)
	row.add_child(icon)
	var text_box: VBoxContainer = VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 6)
	row.add_child(text_box)
	var host_name: String = String(host.get("host_name", "Host"))
	var title: Label = Label.new()
	title.text = "%s" % host_name
	title.add_theme_font_size_override("font_size", 34)
	text_box.add_child(title)
	var host_ip: String = String(host.get("ip", ""))
	var player_count: int = int(host.get("player_count", 1))
	var max_players: int = int(host.get("max_players", 2))
	var theme_title: String = String(host.get("theme_title", host.get("theme_dir", "")))
	var subtitle: Label = Label.new()
	subtitle.text = "%s | %d/%d | %s" % [host_ip, player_count, max_players, theme_title]
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.modulate = Color(1, 1, 1, 0.8)
	text_box.add_child(subtitle)
	button.pressed.connect(func(): _select_host_index(index))
	button.focus_entered.connect(func():
		_selected_host_index = index
		if host_list_scroll: host_list_scroll.ensure_control_visible(button)
	)
	return button

func _focus_first_host_card(status_if_empty: String = "") -> void:
	if _host_cards.is_empty():
		discovery_status_label.text = status_if_empty if not status_if_empty.is_empty() else tr("mp_join_discovery_none")
		return
	_host_cards[0].call_deferred("grab_focus")

func _select_host_index(index: int) -> void:
	if index < 0 or index >= _hosts.size(): return
	_selected_host_index = index
	_selected_host = (_hosts[index] as Dictionary).duplicate(true)
	_enter_join_setup_mode()

func _focus_host_card(index: int) -> void:
	if index < 0 or index >= _host_cards.size(): return
	_host_cards[index].call_deferred("grab_focus")

# ── Data Population & Updates ───────────────────────────────────────────────

func _populate_from_host() -> void:
	if _selected_host.is_empty(): return
	var host_char_id := String(_selected_host.get("character_id", ""))
	_last_host_cfg = _selected_host.duplicate(true)
	_update_breadcrumbs(_selected_host)
	var initial_players := {
		NetworkManager.HOST_PEER_ID: {
			"character_id": host_char_id,
			"is_host": true
		}
	}
	_update_player_slots(_selected_host, initial_players)
	_update_instruction_text(_selected_host)
	_update_taken_character_ids_from_selected_host()

func _update_breadcrumbs(cfg: Dictionary) -> void:
	var mission_id := String(cfg.get("mission_id", MissionCatalog.MISSION_FOLLOW_TRAIL))
	var mission_title := String(cfg.get("mission_title", tr(MissionCatalog.mission_title_key(mission_id))))
	var theme_title := String(cfg.get("theme_title", ""))
	var diff_key := String(cfg.get("difficulty_key", "diff_easy"))
	var s1 := "%s  •  %s  •  %s" % [mission_title, theme_title, tr(diff_key)]
	var sl1 := _breadcrumb1.get_meta("summary") as Label
	if sl1 != null: sl1.text = s1

	var pickup_title := String(cfg.get("training_type_title", ""))
	var training := String(cfg.get("training_type", NetworkManager.TRAINING_WORDS))
	if training == NetworkManager.TRAINING_NONE:
		pickup_title = tr("pickup_none")
	elif pickup_title.is_empty():
		pickup_title = tr(MissionCatalog.pickup_title_key(MissionCatalog.pickup_for_training(training)))
	var chaser_enabled := bool(cfg.get("chaser_enabled", false))
	var action_text := tr("start_vs_chaser") if chaser_enabled else tr("start_together")
	var lang_text := ""
	if training != NetworkManager.TRAINING_NONE:
		var ui_idx := Config.LANG_CODES.find(Config.ui_language)
		if ui_idx < 0: ui_idx = 0
		var lang_idx := Config.LANG_CODES.find(Config.learning_language)
		if lang_idx < 0: lang_idx = 0
		lang_text = "  •  " + Config.get_lang_display_name(lang_idx, true, ui_idx)
	var chaser_on := bool(cfg.get("chaser_enabled", false))
	var player_options := MissionCatalog.max_players_options(mission_id, chaser_on)
	var players_tag := ""
	if player_options.size() <= 1:
		var n := int(player_options[0]) if not player_options.is_empty() else 2
		players_tag = "%d %s" % [n, tr("badge_players_word")]
	else:
		var mn := int(player_options[0])
		var mx := int(player_options[player_options.size() - 1])
		players_tag = "%d-%d %s" % [mn, mx, tr("badge_players_word")]
	var s2 := "%s%s  •  %s  •  🟢 %s" % [pickup_title, lang_text, action_text, players_tag]
	var sl2 := _breadcrumb2.get_meta("summary") as Label
	if sl2 != null: sl2.text = s2

func _update_instruction_text(cfg: Dictionary) -> void:
	var goal_key := String(cfg.get("mission_goal_key", ""))
	if goal_key.is_empty():
		var mission_id := String(cfg.get("mission_id", MissionCatalog.MISSION_FOLLOW_TRAIL))
		var pickup := MissionCatalog.pickup_for_training(String(cfg.get("training_type", "words")))
		var chaser := bool(cfg.get("chaser_enabled", false))
		goal_key = MissionCatalog.goal_key(mission_id, pickup, chaser, true)
	_current_goal_text = tr(goal_key) if not goal_key.is_empty() else ""
	
	var chaser_enabled := bool(cfg.get("chaser_enabled", false))
	var game_style := String(cfg.get("game_style", ""))
	var is_chaser_variant := chaser_enabled and (game_style == NetworkManager.STYLE_PATH or game_style == NetworkManager.STYLE_NEXT_SYMBOL)
	var display_text := _current_goal_text
	
	if is_chaser_variant and _my_role == NetworkManager.ROLE_CHASER:
		_is_chaser_waiting = true
		var chaser_level := int(cfg.get("chaser_level", 1))
		var difficulty := int(cfg.get("difficulty", 1))
		var initial_moves := 10
		match chaser_level:
			1: initial_moves = 10 + difficulty * 5
			2: initial_moves = 6 + difficulty * 3
			3: initial_moves = 3 + difficulty * 1
			4: initial_moves = 2
		display_text = tr("mp_chaser_waiting_steps") % initial_moves
	else:
		_is_chaser_waiting = false
	
	if _gameplay_banner_label != null: _gameplay_banner_label.text = display_text
	
	if _instruction_label == null: return
	if _joined:
		_instruction_label.text = tr("mp_waiting_for_host")
		return
	_instruction_label.text = display_text

# ── Player Slots ────────────────────────────────────────────────────────────

func _update_player_slots(cfg: Dictionary, player_map: Dictionary) -> void:
	var max_players := int(cfg.get("max_players", _last_host_cfg.get("max_players", 2)))
	if _slot_nodes.size() != max_players:
		_clear_slots()
		for i in range(max_players):
			_create_slot(i)
	var peer_ids := _ordered_peer_ids(player_map)
	var my_peer_id := multiplayer.get_unique_id() if multiplayer != null else -1
	var chaser_enabled := bool(cfg.get("chaser_enabled", false))
	var game_style := String(cfg.get("game_style", ""))
	var is_race := game_style == NetworkManager.STYLE_RACE
	for i in range(max_players):
		var slot := _slot_nodes[i]
		if i < peer_ids.size():
			var peer_id: int = peer_ids[i]
			var info := player_map[peer_id] as Dictionary
			var char_id := String(info.get("character_id", ""))
			_apply_character_preview(char_id, slot["preview"] as CharacterPreview)
			(slot["preview"] as CharacterPreview).visible = true
			var is_host := bool(info.get("is_host", false))
			var is_me := (peer_id == my_peer_id)
			# Determine role
			var role := String(info.get("role", ""))
			if role.is_empty():
				if is_race:
					role = NetworkManager.ROLE_RACER
				elif chaser_enabled and not is_host:
					role = NetworkManager.ROLE_CHASER
				else:
					role = NetworkManager.ROLE_COLLECTOR
			var role_color: Color = MP_RED if role == NetworkManager.ROLE_CHASER else MP_GREEN
			var role_border: Color = MP_RED_BORDER if role == NetworkManager.ROLE_CHASER else MP_GREEN_BORDER
			var role_name := tr("mp_role_" + role) if not role.is_empty() else ""
			var lbl := slot["label"] as Label
			var frame := slot["frame"] as PanelContainer
			# Label text
			if is_host and is_me:
				lbl.text = tr("mp_slot_host") + ": " + role_name
			elif is_host:
				lbl.text = tr("mp_slot_host") + ": " + role_name
			elif is_me:
				lbl.text = tr("mp_slot_you") + ": " + role_name
			else:
				lbl.text = role_name
			lbl.add_theme_color_override("font_color", Color.WHITE)
			# Frame border colour matches role
			_apply_filled_frame_style(frame, role_border)
			slot["is_filled"] = true
		else:
			# Empty slot — predict the role for this slot index and pre-color it
			var empty_role: String
			if is_race:
				empty_role = NetworkManager.ROLE_RACER
			elif chaser_enabled and i > 0:
				empty_role = NetworkManager.ROLE_CHASER
			else:
				empty_role = NetworkManager.ROLE_COLLECTOR
			var empty_role_color: Color = MP_RED if empty_role == NetworkManager.ROLE_CHASER else MP_GREEN
			var empty_border: Color = MP_RED_BORDER if empty_role == NetworkManager.ROLE_CHASER else MP_GREEN_BORDER
			var empty_role_name := tr("mp_role_" + empty_role)
			(slot["preview"] as CharacterPreview).visible = false
			var lbl := slot["label"] as Label
			if i == peer_ids.size() and not _joined:
				lbl.text = tr("mp_slot_join_as") % empty_role_name
			else:
				lbl.text = tr("mp_slot_waiting")
			lbl.add_theme_color_override("font_color", Color.WHITE)
			_apply_empty_frame_style_colored(slot["frame"] as PanelContainer, empty_border)
			slot["is_filled"] = false
	_update_pulse_animation()

func _create_slot(_index: int) -> void:
	var slot_vbox := VBoxContainer.new()
	slot_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	slot_vbox.add_theme_constant_override("separation", 8)
	slot_vbox.custom_minimum_size = Vector2(130, 150)
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(110, 110)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slot_vbox.add_child(frame)
	var preview := CharacterPreview.new()
	preview.custom_minimum_size = Vector2(90, 90)
	preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	preview.visible = false
	frame.add_child(preview)
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.text = tr("mp_slot_waiting")
	label.add_theme_color_override("font_color", UIColors.TEXT_SUBTITLE)
	slot_vbox.add_child(label)
	_slots_row.add_child(slot_vbox)
	_slot_nodes.append({"vbox": slot_vbox, "frame": frame, "preview": preview, "label": label, "is_filled": false})
	_apply_empty_frame_style(frame)

func _clear_slots() -> void:
	for slot in _slot_nodes:
		var vbox := slot["vbox"] as Control
		if is_instance_valid(vbox): vbox.queue_free()
	_slot_nodes.clear()
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
		_pulse_tween = null

func _apply_filled_frame_style(frame: PanelContainer, border_color: Color = MP_GREEN_BORDER) -> void:
	var style := UIHelpers.create_rounded_stylebox(
		Color(UIColors.BG_DARK.r, UIColors.BG_DARK.g, UIColors.BG_DARK.b, 0.9),
		border_color, 12, 2)
	style.content_margin_left = 10; style.content_margin_right = 10
	style.content_margin_top = 10; style.content_margin_bottom = 10
	frame.add_theme_stylebox_override("panel", style)

func _apply_empty_frame_style(frame: PanelContainer) -> void:
	_apply_empty_frame_style_colored(frame, SLOT_EMPTY_COLOR)

func _apply_empty_frame_style_colored(frame: PanelContainer, border_color: Color) -> void:
	var bg := SLOT_EMPTY_BG if border_color == SLOT_EMPTY_COLOR else Color(UIColors.BG_DARK.r, UIColors.BG_DARK.g, UIColors.BG_DARK.b, 0.5)
	var style := UIHelpers.create_rounded_stylebox(bg, border_color, 12, 2)
	style.content_margin_left = 10; style.content_margin_right = 10
	style.content_margin_top = 10; style.content_margin_bottom = 10
	style.draw_center = true
	frame.add_theme_stylebox_override("panel", style)

func _update_pulse_animation() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
		_pulse_tween = null
	var empty_frames: Array[PanelContainer] = []
	for slot in _slot_nodes:
		if not slot["is_filled"]:
			empty_frames.append(slot["frame"] as PanelContainer)
	if empty_frames.is_empty(): return
	_pulse_tween = create_tween()
	_pulse_tween.set_loops()
	for frame in empty_frames:
		frame.modulate = Color(1, 1, 1, 1)
	_pulse_tween.tween_method(func(alpha: float):
		for f in empty_frames:
			if is_instance_valid(f): f.modulate.a = alpha
	, 1.0, 0.45, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_method(func(alpha: float):
		for f in empty_frames:
			if is_instance_valid(f): f.modulate.a = alpha
	, 0.45, 1.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _apply_card_zoom(focused: bool) -> void:
	if _join_card_panel != null:
		_join_card_panel.add_theme_stylebox_override("panel", _join_card_focus if focused else _join_card_normal)
		
	if _join_card_container == null: return
	
	var pivot_size := _join_card_container.size
	if pivot_size.x <= 0 or pivot_size.y <= 0:
		pivot_size = _join_card_container.get_minimum_size()
	if pivot_size.x > 0 and pivot_size.y > 0:
		_join_card_container.pivot_offset = pivot_size * 0.5
		
	var target_scale := Vector2(1.16, 1.16) if focused else Vector2.ONE
	
	if _join_card_tween != null and _join_card_tween.is_valid():
		_join_card_tween.kill()
		
	_join_card_tween = create_tween()
	_join_card_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_join_card_tween.tween_property(_join_card_container, "scale", target_scale, 0.18)
	_join_card_container.z_index = 2 if focused else 0

func _ordered_peer_ids(player_map: Dictionary) -> Array[int]:
	return PlayerSlotPanel.ordered_peer_ids(player_map)
