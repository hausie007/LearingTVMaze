extends Control

const DEFAULT_GAME_PORT: int = 42020
const MissionCatalog := preload("res://scripts/mission_catalog.gd")
const CharacterCatalog := preload("res://scripts/multiplayer/character_catalog.gd")

const MP_GREEN := Color("#2D9B58")
const MP_GREEN_BORDER := Color("#3DC878")
const SLOT_EMPTY_COLOR := Color(1, 1, 1, 0.18)
const SLOT_EMPTY_BG := Color(0.15, 0.17, 0.22, 0.6)

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
var _title_row: HBoxContainer = null
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
var _pulse_tween: Tween = null

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
var _saved_local_dpad_visible: bool = true
var _local_dpad_node: CanvasLayer = null
var _leaving: bool = false
var _joined: bool = false
var _last_host_cfg: Dictionary = {}

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

	var pending_host: Dictionary = NetworkManager.consume_pending_join_host()
	if pending_host.is_empty():
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
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
			_leave_session()
			return

	if not event.is_action_pressed("ui_cancel"):
		return
	if viewport != null: viewport.set_input_as_handled()
	if join_setup_panel.visible:
		_leave_session()
	else:
		_go_back_to_main_menu()

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
	if _char_button != null and not _char_button.disabled:
		_char_button.call_deferred("grab_focus")
	elif _join_button != null:
		_join_button.call_deferred("grab_focus")

func _build_setup_layout() -> void:
	for child in join_setup_center.get_children():
		join_setup_center.remove_child(child)
		child.queue_free()

	_main_vbox = VBoxContainer.new()
	_main_vbox.name = "SetupVBox"
	_main_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	_main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main_vbox.add_theme_constant_override("separation", 10)
	join_setup_center.add_child(_main_vbox)

	# Top spacer
	_top_spacer = Control.new()
	_top_spacer.custom_minimum_size = Vector2(0, 8)
	_main_vbox.add_child(_top_spacer)

	# Title row: [Title]
	_title_row = HBoxContainer.new()
	_title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_title_row.add_theme_constant_override("separation", 20)
	_main_vbox.add_child(_title_row)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 52)
	_title_label.add_theme_color_override("font_color", UIColors.YELLOW)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_row.add_child(_title_label)

	# Spacer
	var sp1 := Control.new()
	sp1.custom_minimum_size = Vector2(0, 4)
	_main_vbox.add_child(sp1)

	# Breadcrumb 1
	_breadcrumb1 = _build_breadcrumb_row()
	_main_vbox.add_child(_breadcrumb1)

	# Breadcrumb 2
	_breadcrumb2 = _build_breadcrumb_row()
	_main_vbox.add_child(_breadcrumb2)

	# Spacer
	var sp2 := Control.new()
	sp2.custom_minimum_size = Vector2(0, 16)
	_main_vbox.add_child(sp2)

	# Settings block (Character & Controller) ABOVE player slots
	var settings_vbox := VBoxContainer.new()
	settings_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	settings_vbox.add_theme_constant_override("separation", 12)
	_main_vbox.add_child(settings_vbox)

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
	settings_vbox.add_child(_char_row)

	# Controller layout row
	var ctrl_data := _create_selector_row("mp_join_remote_layout")
	_controller_row = ctrl_data["row"] as HBoxContainer
	_controller_left = ctrl_data["left"] as Label
	_controller_button = ctrl_data["button"] as Button
	_controller_right = ctrl_data["right"] as Label
	_controller_button.pressed.connect(func(): _cycle_controller_layout(1))
	_setup_cycling(_controller_button, _cycle_controller_layout)
	_setup_arrow_visibility(_controller_button, _controller_left, _controller_right)
	settings_vbox.add_child(_controller_row)

	# Spacer
	var sp3 := Control.new()
	sp3.custom_minimum_size = Vector2(0, 24)
	_main_vbox.add_child(sp3)

	# Player slots
	_slots_row = HBoxContainer.new()
	_slots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_slots_row.add_theme_constant_override("separation", 32)
	_slots_row.custom_minimum_size = Vector2(0, 160)
	_main_vbox.add_child(_slots_row)

	# Join button + error
	var join_row := VBoxContainer.new()
	join_row.alignment = BoxContainer.ALIGNMENT_CENTER
	join_row.add_theme_constant_override("separation", 8)
	_main_vbox.add_child(join_row)

	_join_error_label = Label.new()
	_join_error_label.add_theme_font_size_override("font_size", 24)
	_join_error_label.add_theme_color_override("font_color", Color(1, 0.45, 0.45, 1))
	_join_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_join_error_label.text = ""
	join_row.add_child(_join_error_label)

	var join_btn_row := HBoxContainer.new()
	join_btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	join_row.add_child(join_btn_row)

	_join_button = Button.new()
	_join_button.text = tr("mp_join_game")
	_join_button.custom_minimum_size = Vector2(320, 68)
	_join_button.add_theme_font_size_override("font_size", 30)
	UIHelpers.apply_style_to_button(_join_button, MP_GREEN)
	var mp_normal := UIHelpers.create_rounded_stylebox(UIColors.BG_DARK, MP_GREEN_BORDER, 12, 2)
	_join_button.add_theme_stylebox_override("normal", mp_normal)
	_join_button.pressed.connect(_on_join_pressed)
	join_btn_row.add_child(_join_button)



	# Spacer
	var sp4 := Control.new()
	sp4.custom_minimum_size = Vector2(0, 8)
	_main_vbox.add_child(sp4)

	# Instruction panel
	_instruction_panel = PanelContainer.new()
	var panel_style := UIHelpers.create_rounded_stylebox(
		Color(UIColors.BG_DARK.r, UIColors.BG_DARK.g, UIColors.BG_DARK.b, 0.85),
		Color(1, 1, 1, 0.12), 14, 1
	)
	panel_style.content_margin_left = 36
	panel_style.content_margin_right = 36
	panel_style.content_margin_top = 20
	panel_style.content_margin_bottom = 20
	_instruction_panel.add_theme_stylebox_override("panel", panel_style)
	_instruction_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_instruction_panel.custom_minimum_size = Vector2(800, 0)
	_main_vbox.add_child(_instruction_panel)

	_instruction_label = Label.new()
	_instruction_label.add_theme_font_size_override("font_size", 28)
	_instruction_label.add_theme_color_override("font_color", Color(1, 0.92, 0.6))
	_instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instruction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_instruction_panel.add_child(_instruction_label)

func _build_breadcrumb_row() -> Button:
	var btn := Button.new()
	btn.flat = true
	btn.custom_minimum_size = Vector2(0, 48)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var normal_style := UIHelpers.create_rounded_stylebox(
		Color(UIColors.BG_DARK.r, UIColors.BG_DARK.g, UIColors.BG_DARK.b, 0.6),
		Color(1, 1, 1, 0.08), 10, 1
	)
	normal_style.content_margin_left = 24
	normal_style.content_margin_right = 24
	for state_name in ["normal", "focus", "hover", "pressed"]:
		btn.add_theme_stylebox_override(state_name, normal_style)
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	hbox.add_theme_constant_override("separation", 12)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.add_child(hbox)
	var chevron := Label.new()
	chevron.text = "▾"
	chevron.add_theme_font_size_override("font_size", 26)
	chevron.add_theme_color_override("font_color", UIColors.YELLOW)
	chevron.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chevron.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chevron.custom_minimum_size = Vector2(28, 0)
	hbox.add_child(chevron)
	var summary := Label.new()
	summary.name = "SummaryText"
	summary.add_theme_font_size_override("font_size", 28)
	summary.add_theme_color_override("font_color", UIColors.TEXT_SECONDARY)
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(summary)
	btn.set_meta("summary", summary)
	btn.set_meta("chevron", chevron)
	return btn

func _create_selector_row(label_key: String) -> Dictionary:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 0)
	row.custom_minimum_size = Vector2(0, 68)
	var label := Label.new()
	label.custom_minimum_size = Vector2(245, 0)
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", UIColors.TEXT_SUBTITLE)
	label.text = tr(label_key)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(12, 0)
	row.add_child(gap)
	var left := _create_arrow_label()
	row.add_child(left)
	var button := Button.new()
	button.custom_minimum_size = Vector2(430, 64)
	button.add_theme_font_size_override("font_size", 30)
	UIHelpers.apply_style_to_button(button, UIColors.YELLOW)
	row.add_child(button)
	var right := _create_arrow_label()
	right.text = ">"
	row.add_child(right)
	var extras := HBoxContainer.new()
	extras.custom_minimum_size = Vector2(80, 0)
	extras.add_theme_constant_override("separation", 8)
	extras.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_child(extras)
	return {"row": row, "left": left, "button": button, "right": right, "extras": extras}

func _create_arrow_label() -> Label:
	var label := Label.new()
	label.custom_minimum_size = Vector2(36, 0)
	label.add_theme_color_override("font_color", UIColors.YELLOW)
	label.add_theme_font_size_override("font_size", 38)
	label.text = "<"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label

func _setup_cycling(btn: Button, cycle_func: Callable) -> void:
	if btn == null: return
	btn.gui_input.connect(func(event: InputEvent):
		if event.is_pressed():
			var vp: Viewport = get_viewport()
			if event.is_action("ui_left"):
				cycle_func.call(-1)
				if vp != null: vp.set_input_as_handled()
			elif event.is_action("ui_right"):
				cycle_func.call(1)
				if vp != null: vp.set_input_as_handled()
	)

func _setup_arrow_visibility(btn: Button, left: Label, right: Label) -> void:
	if btn == null or left == null or right == null: return
	left.modulate.a = 0.0
	right.modulate.a = 0.0
	btn.focus_entered.connect(func():
		left.modulate.a = 1.0
		right.modulate.a = 1.0
	)
	btn.focus_exited.connect(func():
		left.modulate.a = 0.0
		right.modulate.a = 0.0
	)

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
		var target_id := Config.theme_dir_name + ":player"
		for i in range(_character_catalog.size()):
			var cat_id := String(_character_catalog[i].get("id", ""))
			if cat_id == target_id and not _taken_character_ids.has(cat_id):
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
	if not host_available and _join_error_label != null:
		_join_error_label.text = tr("mp_join_host_unavailable")

# ── Network Callbacks ───────────────────────────────────────────────────────

func _on_host_discovered(_info: Dictionary) -> void:
	pass

func _on_discovery_updated(hosts: Array) -> void:
	_hosts = hosts.duplicate(true)
	if join_setup_panel.visible and not _selected_host.is_empty():
		_selected_host_available = _sync_selected_host_from_list()
		_populate_from_host()
		_update_character_selector()
		return
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
	if _join_error_label != null: _join_error_label.text = tr("mp_join_connecting")

func _on_join_accepted(peer_id: int, state: Dictionary) -> void:
	var character_id: String = _selected_character_id
	var players: Dictionary = state.get("players", {}) as Dictionary
	if players.has(peer_id):
		character_id = String((players[peer_id] as Dictionary).get("character_id", character_id))
	elif players.has(str(peer_id)):
		character_id = String((players[str(peer_id)] as Dictionary).get("character_id", character_id))
	_transition_to_joined(character_id)

func _on_join_rejected(reason: String) -> void:
	if _should_return_to_discovery(reason):
		_leave_session()
		return
	if _join_error_label != null: _join_error_label.text = reason

func _on_game_started(_session: Dictionary) -> void:
	# Controller stays on this screen. Game is visible on host only.
	pass

func _on_chaser_countdown_updated(remaining: int) -> void:
	if chaser_ready_label == null or chaser_countdown_label == null: return
	if chaser_overlay != null: chaser_overlay.visible = true
	chaser_ready_label.visible = true
	chaser_countdown_label.visible = true
	if remaining > 0: chaser_countdown_label.text = str(remaining)

func _on_chaser_released() -> void:
	if chaser_ready_label == null or chaser_countdown_label == null: return
	chaser_countdown_label.text = "GO!"
	chaser_ready_label.visible = true
	chaser_countdown_label.visible = true
	if OS.has_feature("mobile"): Input.vibrate_handheld(500)
	var timer := get_tree().create_timer(1.0)
	timer.connect("timeout", func():
		if is_instance_valid(chaser_ready_label): chaser_ready_label.visible = false
		if is_instance_valid(chaser_countdown_label): chaser_countdown_label.visible = false
		if is_instance_valid(chaser_overlay): chaser_overlay.visible = false
	)

func _on_remote_goal_updated(goal_text: String) -> void:
	if _instruction_label != null:
		_instruction_label.text = goal_text

func _on_network_debug_changed(scope: String, message: String) -> void:
	if network_debug_label == null: return
	network_debug_label.text = "Network [%s]: %s" % [scope, message]

func _transition_to_joined(character_id: String) -> void:
	_joined = true
	if _join_button != null: _join_button.visible = false
	if _join_error_label != null: _join_error_label.visible = false
	if _char_button != null:
		_char_button.disabled = true
		_char_button.focus_mode = Control.FOCUS_NONE
	if _instruction_label != null:
		_instruction_label.text = "Waiting for host to start the game."
	_apply_character_preview(character_id, _char_preview)
	_cache_character_palette(character_id)
	_apply_selected_avatar_to_global_dpad()
	_show_local_dpad_for_setup()
	_configure_navigation()
	NetworkManager.stop_discovery()
	if _controller_button != null:
		_controller_button.call_deferred("grab_focus")

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

	if _title_row != null:
		var sim_w: float = clampf(available_width * (0.52 if short_screen else 0.58), 480.0, 930.0)
		var sim_h: float = clampf(sim_w * 0.214, 80.0, 160.0)
		_title_row.custom_minimum_size.y = sim_h
		if _title_label != null:
			_title_label.add_theme_font_size_override("font_size", int(sim_h * 0.32))

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
	if Config != null: controls_mode = Config.on_screen_controls
	var content_rect := UIHelpers.get_content_rect(viewport_size, controls_mode)
	return clampf(content_rect.size.x * 0.985, 760.0, 1640.0)

# ── Helpers ─────────────────────────────────────────────────────────────────

func _apply_character_preview(character_id: String, preview: CharacterPreview) -> void:
	if preview == null: return
	var preview_data: Dictionary = CharacterCatalog.get_preview_data_by_id(character_id)
	var frames_data: Array = preview_data.get("frames", [])
	var frames: Array[Texture2D] = []
	for item in frames_data:
		if item is Texture2D: frames.append(item)
	var fps: float = float(preview_data.get("fps", 1.0))
	if not frames.is_empty():
		preview.set_character(frames, fps)
	else:
		var fallback: Texture2D = CharacterCatalog.get_texture_by_id(character_id)
		if fallback != null:
			preview.set_character([fallback], 1.0)
		else:
			preview.clear()

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
	if not _joined or not join_setup_panel.visible: return
	match action:
		&"ui_up": _send_controller_direction(Vector2i.UP, pressed)
		&"ui_down": _send_controller_direction(Vector2i.DOWN, pressed)
		&"ui_left": _send_controller_direction(Vector2i.LEFT, pressed)
		&"ui_right": _send_controller_direction(Vector2i.RIGHT, pressed)
		&"ui_cancel":
			if pressed: _leave_session()

func _leave_session() -> void:
	if _leaving: return
	_leaving = true
	_reset_global_dpad_accent()
	_restore_local_dpad()
	NetworkManager.leave_session()
	Config.show_join_list_on_home = true
	Config.join_status_override = ""
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _go_back_to_main_menu() -> void:
	_reset_global_dpad_accent()
	_restore_local_dpad()
	NetworkManager.leave_session()
	Config.show_join_list_on_home = true
	Config.join_status_override = ""
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _update_taken_character_ids_from_selected_host() -> void:
	_taken_character_ids.clear()
	var raw_taken: Variant = _selected_host.get("taken_characters", [])
	if raw_taken is Array:
		for item in (raw_taken as Array):
			var character_id: String = String(item)
			if not character_id.is_empty() and not _taken_character_ids.has(character_id):
				_taken_character_ids.append(character_id)

func _host_key(host: Dictionary) -> String:
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
	_update_title(_selected_host)
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

func _update_title(cfg: Dictionary) -> void:
	if _title_label == null: return
	var max_p := int(cfg.get("max_players", 2))
	_title_label.text = "%s (%d %s)" % [tr("start_together"), max_p, tr("badge_players_word")]

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
	if _instruction_label == null: return
	if _joined:
		_instruction_label.text = "Waiting for host to start the game."
		return

	var goal_key := String(cfg.get("mission_goal_key", ""))
	if goal_key.is_empty():
		var mission_id := String(cfg.get("mission_id", MissionCatalog.MISSION_FOLLOW_TRAIL))
		var pickup := MissionCatalog.pickup_for_training(String(cfg.get("training_type", "words")))
		var chaser := bool(cfg.get("chaser_enabled", false))
		goal_key = MissionCatalog.goal_key(mission_id, pickup, chaser, true)
	_instruction_label.text = tr(goal_key) if not goal_key.is_empty() else ""

# ── Player Slots ────────────────────────────────────────────────────────────

func _update_player_slots(cfg: Dictionary, player_map: Dictionary) -> void:
	var max_players := int(cfg.get("max_players", _last_host_cfg.get("max_players", 2)))
	if _slot_nodes.size() != max_players:
		_clear_slots()
		for i in range(max_players):
			_create_slot(i)
	var peer_ids := _ordered_peer_ids(player_map)
	for i in range(max_players):
		var slot := _slot_nodes[i]
		if i < peer_ids.size():
			var peer_id: int = peer_ids[i]
			var info := player_map[peer_id] as Dictionary
			var char_id := String(info.get("character_id", ""))
			_apply_character_preview(char_id, slot["preview"] as CharacterPreview)
			(slot["preview"] as CharacterPreview).visible = true
			var is_host := bool(info.get("is_host", false))
			var lbl := slot["label"] as Label
			lbl.text = "Host" if is_host else CharacterCatalog.display_name_for_id(char_id)
			lbl.add_theme_color_override("font_color", UIColors.YELLOW if is_host else UIColors.TEXT_PRIMARY)
			var frame := slot["frame"] as PanelContainer
			_apply_filled_frame_style(frame)
			slot["is_filled"] = true
		else:
			(slot["preview"] as CharacterPreview).visible = false
			var lbl := slot["label"] as Label
			lbl.text = "Waiting..."
			lbl.add_theme_color_override("font_color", UIColors.TEXT_SUBTITLE)
			_apply_empty_frame_style(slot["frame"] as PanelContainer)
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
	label.text = "Waiting..."
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

func _apply_filled_frame_style(frame: PanelContainer) -> void:
	var style := UIHelpers.create_rounded_stylebox(
		Color(UIColors.BG_DARK.r, UIColors.BG_DARK.g, UIColors.BG_DARK.b, 0.9),
		MP_GREEN_BORDER, 12, 2)
	style.content_margin_left = 10; style.content_margin_right = 10
	style.content_margin_top = 10; style.content_margin_bottom = 10
	frame.add_theme_stylebox_override("panel", style)

func _apply_empty_frame_style(frame: PanelContainer) -> void:
	var style := UIHelpers.create_rounded_stylebox(SLOT_EMPTY_BG, SLOT_EMPTY_COLOR, 12, 2)
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

func _ordered_peer_ids(player_map: Dictionary) -> Array[int]:
	var peer_ids: Array[int] = []
	for key in player_map.keys():
		peer_ids.append(int(key))
	peer_ids.sort()
	if peer_ids.has(NetworkManager.HOST_PEER_ID):
		peer_ids.erase(NetworkManager.HOST_PEER_ID)
		peer_ids.push_front(NetworkManager.HOST_PEER_ID)
	return peer_ids
