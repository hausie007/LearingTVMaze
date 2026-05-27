extends Control

const DEFAULT_GAME_PORT: int = 42020
const MissionCatalog := preload("res://scripts/mission_catalog.gd")
const LogoTexture := preload("res://images/lm_paper_horizontal.png")
const JoinSetupLayoutBuilder := preload("res://scripts/ui/join_setup_layout_builder.gd")
const JoinCardHelper := preload("res://scripts/ui/join_card_helper.gd")
const HostCardBuilder := preload("res://scripts/ui/host_card_builder.gd")
const PulseAnimator := preload("res://scripts/ui/pulse_animator.gd")
const SlotStyler := preload("res://scripts/ui/slot_styler.gd")

const NO_HOST_HINT_DELAY_SEC := 3.5
const MP_GREEN := UIColors.MP_GREEN
const MP_GREEN_BORDER := UIColors.MP_GREEN_BORDER
const SLOT_EMPTY_COLOR := UIColors.SLOT_EMPTY_COLOR
const SLOT_EMPTY_BG := UIColors.SLOT_EMPTY_BG
const MP_RED := UIColors.MP_RED
const MP_RED_BORDER := UIColors.MP_RED_BORDER
const JOIN_GREEN := UIColors.JOIN_GREEN
const REMOTE_GOAL_HAPTIC_MS := 500
const REMOTE_GOAL_FONT_SIZE := 36
const REMOTE_GOAL_MIN_WIDTH := 440.0
const REMOTE_GOAL_MAX_WIDTH := 720.0

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
var _controller_size_row: HBoxContainer = null
var _controller_size_button: Button = null
var _controller_size_left: Label = null
var _controller_size_right: Label = null
var _char_row: HBoxContainer = null
var _char_button: Button = null
var _char_left: Label = null
var _char_right: Label = null
var _char_preview: CharacterPreview = null
var _settings_vbox: VBoxContainer = null
var _join_card_container: MarginContainer = null
var _join_card_panel: PanelContainer = null
var _join_card_normal: StyleBoxFlat = null
var _join_card_focus: StyleBoxFlat = null
var _join_card_tween: Tween = null
var _pulse_tween: Tween = null
var _pause_dialog: PauseDialog = null
var _gameplay_char_preview: CharacterPreview = null
var _gameplay_badge: Control = null
var _gameplay_badge_data: Dictionary = {}
var _gameplay_badge_slot: Control = null
var _gameplay_badge_container: MarginContainer = null
var _gameplay_result_node: Control = null

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
var _current_remote_goal_text: String = ""
var _current_remote_role_tag: String = ""

# ── Game Switcher UI (multi-game support) ───────────────────────────────────
# Arrows flank the green join card: [‹]  [card]  [›]
var _game_switcher_label: Label = null   # "Game N of M" shown below the card
var _game_prev_button: Button = null     # ‹ left of card
var _game_next_button: Button = null     # › right of card
var _game_unavailable_label: Label = null
var _discovery_hint_label: Label = null
var _setup_hint_label: Label = null
var _scan_empty_timer: Timer = null



func _ready() -> void:
	Input.warp_mouse(Vector2(-1, -1))
	_localize_ui()
	if network_debug_label != null:
		network_debug_label.visible = false
	_build_discovery_helpers()
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
	if NetworkManager.has_signal("remote_result_updated"):
		NetworkManager.remote_result_updated.connect(_on_remote_result_updated)
	if NetworkManager.has_signal("remote_trap_status_updated"):
		NetworkManager.remote_trap_status_updated.connect(_on_remote_trap_status_updated)
	if Config != null and not Config.on_screen_controls_changed.is_connected(_on_controls_changed):
		Config.on_screen_controls_changed.connect(_on_controls_changed)
	if Config != null and not Config.controller_size_changed.is_connected(_on_controller_size_changed):
		Config.controller_size_changed.connect(_on_controller_size_changed)

	# Centralized OLED idle guard transition
	IdleManager.idle_tier_2.connect(_on_idle_tier2_global)

	_pause_dialog = PauseDialog.new()
	_pause_dialog.confirmed.connect(func(): _pause_dialog.hide_dialog(); _leave_session())
	_pause_dialog.cancelled.connect(func(): _pause_dialog.hide_dialog(); _apply_remote_dpad_confusion_visual())
	add_child(_pause_dialog)

	_scan_empty_timer = Timer.new()
	_scan_empty_timer.wait_time = NO_HOST_HINT_DELAY_SEC
	_scan_empty_timer.one_shot = true
	_scan_empty_timer.timeout.connect(_on_scan_empty_timeout)
	add_child(_scan_empty_timer)

	var pending_host: Dictionary = NetworkManager.consume_pending_join_host()
	if pending_host.is_empty():
		get_tree().call_deferred("change_scene_to_file", Scenes.HOME)
		return
	_selected_host = pending_host.duplicate(true)
	_hosts = [_selected_host.duplicate(true)]
	_selected_host_index = 0
	_selected_host_available = true
	_start_discovery_scan(false)
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
			if event.is_action_pressed("ui_accept") and _game_started and _pause_dialog != null and not _pause_dialog.visible:
				_send_use_trap()
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
		_apply_remote_dpad_confusion_visual()
	else:
		_pause_dialog.show_dialog()
		_set_remote_dpad_confusion_visual(false)

func _exit_tree() -> void:
	if _local_dpad_node != null and _local_dpad_node.has_method("set_controls_reversed_visual"):
		_local_dpad_node.call("set_controls_reversed_visual", false)
	_reset_global_dpad_accent()
	_restore_local_dpad()

	if NetworkManager.host_discovered.is_connected(_on_host_discovered):
		NetworkManager.host_discovered.disconnect(_on_host_discovered)
	if NetworkManager.discovery_updated.is_connected(_on_discovery_updated):
		NetworkManager.discovery_updated.disconnect(_on_discovery_updated)
	if NetworkManager.lobby_updated.is_connected(_on_lobby_updated):
		NetworkManager.lobby_updated.disconnect(_on_lobby_updated)
	if NetworkManager.join_accepted.is_connected(_on_join_accepted):
		NetworkManager.join_accepted.disconnect(_on_join_accepted)
	if NetworkManager.join_rejected.is_connected(_on_join_rejected):
		NetworkManager.join_rejected.disconnect(_on_join_rejected)
	if NetworkManager.game_started.is_connected(_on_game_started):
		NetworkManager.game_started.disconnect(_on_game_started)
	if NetworkManager.debug_status_changed.is_connected(_on_network_debug_changed):
		NetworkManager.debug_status_changed.disconnect(_on_network_debug_changed)
	if NetworkManager.chaser_countdown_updated.is_connected(_on_chaser_countdown_updated):
		NetworkManager.chaser_countdown_updated.disconnect(_on_chaser_countdown_updated)
	if NetworkManager.chaser_released.is_connected(_on_chaser_released):
		NetworkManager.chaser_released.disconnect(_on_chaser_released)
	if NetworkManager.remote_goal_updated.is_connected(_on_remote_goal_updated):
		NetworkManager.remote_goal_updated.disconnect(_on_remote_goal_updated)
	if NetworkManager.remote_result_updated.is_connected(_on_remote_result_updated):
		NetworkManager.remote_result_updated.disconnect(_on_remote_result_updated)
	if NetworkManager.remote_trap_status_updated.is_connected(_on_remote_trap_status_updated):
		NetworkManager.remote_trap_status_updated.disconnect(_on_remote_trap_status_updated)
	if Config != null:
		if Config.on_screen_controls_changed.is_connected(_on_controls_changed):
			Config.on_screen_controls_changed.disconnect(_on_controls_changed)
		if Config.controller_size_changed.is_connected(_on_controller_size_changed):
			Config.controller_size_changed.disconnect(_on_controller_size_changed)

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

func _on_controller_size_changed(_new_size: int) -> void:
	_apply_dpad_layout()
	_apply_responsive_layout()

func _localize_ui() -> void:
	discovery_title_label.text = tr("mp_join_discovery_title")
	discovery_status_label.text = tr("mp_join_discovery_scanning")
	if _discovery_hint_label != null:
		_discovery_hint_label.text = tr("mp_same_network_hint")
	if _setup_hint_label != null:
		_setup_hint_label.text = tr("mp_same_network_hint")

func _build_discovery_helpers() -> void:
	if discovery_panel == null or discovery_status_label == null:
		return
	var discovery_vbox := discovery_status_label.get_parent() as VBoxContainer
	if discovery_vbox == null:
		return

	_discovery_hint_label = Label.new()
	_discovery_hint_label.name = "DiscoverySameNetworkHintLabel"
	_discovery_hint_label.visible = false
	_discovery_hint_label.text = tr("mp_same_network_hint")
	_discovery_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_discovery_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_discovery_hint_label.custom_minimum_size = Vector2(760, 0)
	_discovery_hint_label.add_theme_font_size_override("font_size", 24)
	_discovery_hint_label.add_theme_color_override("font_color", UIColors.TEXT_SECONDARY)
	UIHelpers.apply_medium(_discovery_hint_label)
	discovery_vbox.add_child(_discovery_hint_label)
	discovery_vbox.move_child(_discovery_hint_label, discovery_status_label.get_index() + 1)

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
	_refresh_controller_size()
	_apply_responsive_layout()
	_configure_navigation()
	if _join_button != null and not _join_button.disabled:
		_join_button.call_deferred("grab_focus")
	elif _char_button != null and not _char_button.disabled:
		_char_button.call_deferred("grab_focus")

	# OLED: join screen is static while waiting — keep wake-lock OFF.
	DisplayServer.screen_set_keep_on(false)


func _on_idle_tier2_global() -> void:
	IdleManager.reset()
	_leave_session()

func _build_setup_layout() -> void:
	var nodes := JoinSetupLayoutBuilder.build(self)
	_main_vbox = nodes["main_vbox"]
	_gameplay_char_preview = nodes["gameplay_char_preview"]
	_top_spacer = nodes["top_spacer"]
	_logo = nodes["logo"]
	_breadcrumb1 = nodes["breadcrumb1"]
	_breadcrumb2 = nodes["breadcrumb2"]
	_title_label = nodes["title_label"]
	_game_prev_button = nodes["game_prev_button"]
	_game_next_button = nodes["game_next_button"]
	_join_card_container = nodes["join_card_container"]
	_join_card_panel = nodes["join_card_panel"]
	_slots_row = nodes["slots_row"]
	_join_button = nodes["join_button"]
	_game_switcher_label = nodes["game_switcher_label"]
	_join_error_label = nodes["join_error_label"]
	_game_unavailable_label = nodes["game_unavailable_label"]
	_settings_vbox = nodes["settings_vbox"]
	_char_row = nodes["char_row"]
	_char_left = nodes["char_left"]
	_char_button = nodes["char_button"]
	_char_right = nodes["char_right"]
	_char_preview = nodes["char_preview"]
	_controller_row = nodes["controller_row"]
	_controller_left = nodes["controller_left"]
	_controller_button = nodes["controller_button"]
	_controller_right = nodes["controller_right"]
	_controller_size_row = nodes["controller_size_row"]
	_controller_size_left = nodes["controller_size_left"]
	_controller_size_button = nodes["controller_size_button"]
	_controller_size_right = nodes["controller_size_right"]
	_join_card_normal = nodes["join_card_normal"]
	_join_card_focus = nodes["join_card_focus"]
	_build_setup_hint_helpers()

func _build_setup_hint_helpers() -> void:
	if _main_vbox == null or _join_error_label == null:
		return

	_setup_hint_label = Label.new()
	_setup_hint_label.name = "SetupSameNetworkHintLabel"
	_setup_hint_label.visible = false
	_setup_hint_label.text = tr("mp_same_network_hint")
	_setup_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_setup_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_setup_hint_label.custom_minimum_size = Vector2(760, 0)
	_setup_hint_label.add_theme_font_size_override("font_size", 22)
	_setup_hint_label.add_theme_color_override("font_color", UIColors.TEXT_SECONDARY)
	UIHelpers.apply_medium(_setup_hint_label)
	_main_vbox.add_child(_setup_hint_label)
	_main_vbox.move_child(_setup_hint_label, _join_error_label.get_index() + 1)

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

func _cycle_controller_size(dir: int) -> void:
	if Config == null or Config.CONTROLLER_SIZE_KEYS.is_empty(): return
	Config.controller_size = (Config.controller_size + dir + Config.CONTROLLER_SIZE_KEYS.size()) % Config.CONTROLLER_SIZE_KEYS.size()
	Config.save_settings()
	_refresh_controller_size()
	_apply_dpad_layout()
	_apply_responsive_layout()

func _refresh_controller_layout() -> void:
	if Config == null or _controller_button == null: return
	if Config.on_screen_controls >= 0 and Config.on_screen_controls < Config.CONTROLS_KEYS.size():
		_controller_button.text = tr(Config.CONTROLS_KEYS[Config.on_screen_controls])

func _refresh_controller_size() -> void:
	if Config == null or _controller_size_button == null: return
	if Config.controller_size >= 0 and Config.controller_size < Config.CONTROLLER_SIZE_KEYS.size():
		_controller_size_button.text = tr(Config.CONTROLLER_SIZE_KEYS[Config.controller_size])

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
	_refresh_client_presence()
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
	_refresh_client_presence()
	_set_setup_hint_visible(true)
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
	_set_setup_hint_visible(false)
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
	if not _hosts.is_empty():
		if _scan_empty_timer != null:
			_scan_empty_timer.stop()
		_set_discovery_hint_visible(false)
		_set_setup_hint_visible(false)

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
			_refresh_client_presence()
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
		_refresh_client_presence()
		_update_join_action_state()
		return

	# Discovery panel (pre-selection): rebuild host card list.
	_rebuild_host_cards()
	if _hosts.is_empty():
		if _scan_empty_timer != null and not _scan_empty_timer.is_stopped():
			discovery_status_label.text = tr("mp_join_discovery_scanning")
			_set_discovery_hint_visible(false)
		else:
			discovery_status_label.text = tr("mp_join_discovery_none")
			_set_discovery_hint_visible(true)
	else:
		discovery_status_label.text = tr("mp_join_discovery_found")
		_set_discovery_hint_visible(false)
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
		_set_setup_hint_visible(true)
		_refresh_client_presence()
		return
	_join_pending = true
	_set_setup_hint_visible(false)
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
	_transition_to_joined(character_id)

func _on_join_rejected(reason: String) -> void:
	_join_pending = false
	# Suppress network callbacks that fire as a side-effect of a voluntary unjoin.
	if _unjoining: return
	if reason == "mp_kicked_by_host":
		_unjoin("mp_kicked_by_host")
		return
	if _should_return_to_discovery(reason):
		_show_no_games_state()
		if _join_error_label != null:
			_join_error_label.visible = true
			_join_error_label.text = _localized_join_reason(reason)
		call_deferred("_restart_discovery_after_join_rejection")
		return
	if _join_error_label != null: _join_error_label.text = _localized_join_reason(reason)

func _on_game_started(_session: Dictionary) -> void:
	_game_started = true
	# Game started — restore the wake lock and stop the idle guard.
	DisplayServer.screen_set_keep_on(true)
	modulate.a = 1.0  # Restore opacity in case tier-1 had dimmed us
	if _main_vbox != null: _main_vbox.visible = false
	
	if _gameplay_char_preview != null:
		_gameplay_char_preview.visible = false
		
	var players := _session.get("players", {}) as Dictionary
	var my_id := multiplayer.get_unique_id()
	var my_info := players.get(my_id, players.get(str(my_id), {})) as Dictionary
	var session_role := String(my_info.get("role", ""))
	if not session_role.is_empty():
		_my_role = session_role
		
	var session_config := _session.get("config", _last_host_cfg) as Dictionary
	_last_host_cfg = session_config.duplicate(true)
	var role_tag := _role_tag_for_session(session_role, session_config)
	_current_remote_role_tag = role_tag
	_current_remote_goal_text = _initial_remote_goal_for_session(session_role, session_config, players.size())
	my_info["role"] = role_tag
	if not _selected_character_palette.is_empty():
		my_info["color"] = _selected_character_palette.get("accent", UIColors.BLUE)

	# Resolve initial trap availability
	var style := String(session_config.get("game_style", NetworkManager.STYLE_PATH))
	var mission_id := String(session_config.get("mission_id", ""))
	var chaser_enabled := bool(session_config.get("chaser_enabled", false)) and style != NetworkManager.STYLE_RACE
	var traps_enabled := bool(session_config.get("traps_enabled", false)) and Config.traps_allowed_for_session(style, chaser_enabled, mission_id)
	my_info["trap_available"] = traps_enabled
	my_info["trap_texture"] = _remote_trap_texture()
		
	# Construct the player badge
	if _gameplay_badge_container != null:
		_gameplay_badge_container.queue_free()
		_gameplay_badge_container = null
		_gameplay_badge_slot = null
		_gameplay_badge = null
	
	if _gameplay_result_node != null:
		_gameplay_result_node.queue_free()
		_gameplay_result_node = null
	
	# Pass my_info to build the chip. We use scale_mult=2.0 to make it large on the phone screen
	_gameplay_badge_data = my_info.duplicate(true)
	_gameplay_badge = UIHelpers.build_player_chip(my_info, 1, 2.0)
	
	# Position the badge almost in the top corner, opposite the D-Pad horizontally
	var margin_container := MarginContainer.new()
	margin_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gameplay_badge_container = margin_container
	
	var alignment := MarginContainer.new()
	alignment.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gameplay_badge_slot = alignment
	
	var _is_rtl := Config.on_screen_controls == Config.ControlsMode.RIGHT_HANDED
	if _is_rtl:
		# D-Pad is on the right, put badge on the left
		alignment.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	else:
		# D-Pad is on the left, put badge on the right
		alignment.size_flags_horizontal = Control.SIZE_SHRINK_END
	
	# Position almost in the top corner
	alignment.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	
	# Add generous padding so it's not glued to the edge
	var horizontal_pad = int(get_viewport_rect().size.x * 0.1)
	alignment.add_theme_constant_override("margin_left", horizontal_pad if not _is_rtl else 40)
	alignment.add_theme_constant_override("margin_right", horizontal_pad if _is_rtl else 40)
	alignment.add_theme_constant_override("margin_top", 40)
	
	var vbox := VBoxContainer.new()
	vbox.name = "BadgeVBox"
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 20)
	alignment.add_child(vbox)
	
	vbox.add_child(_gameplay_badge)
	
	var goal_label := Label.new()
	goal_label.name = "RemoteGoalLabel"
	goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	goal_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal_label.custom_minimum_size = Vector2(_remote_goal_label_width(), 0)
	
	# Stylize the goal label
	goal_label.add_theme_font_override("font", UIHelpers.get_font_at_weight(UIHelpers.WEIGHT_SEMIBOLD))
	goal_label.add_theme_font_size_override("font_size", REMOTE_GOAL_FONT_SIZE)
	goal_label.add_theme_color_override("font_color", UIColors.TEXT_SECONDARY)
	
	# Semi-transparent background panel overlay (glassmorphism look)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(UIColors.BG_PANEL, 0.85)
	bg_style.corner_radius_top_left = 16
	bg_style.corner_radius_top_right = 16
	bg_style.corner_radius_bottom_right = 16
	bg_style.corner_radius_bottom_left = 16
	bg_style.set_content_margin_all(20)
	bg_style.border_width_left = 2
	bg_style.border_width_top = 2
	bg_style.border_width_right = 2
	bg_style.border_width_bottom = 2
	bg_style.border_color = Color(UIColors.SELECTED_BORDER, 0.4)
	goal_label.add_theme_stylebox_override("normal", bg_style)
	
	goal_label.text = tr(_current_remote_goal_text) if not _current_remote_goal_text.is_empty() else ""
	goal_label.visible = not _current_remote_goal_text.is_empty()
	
	vbox.add_child(goal_label)
	
	margin_container.add_child(alignment)
	join_setup_panel.add_child(margin_container)

func _on_chaser_countdown_updated(remaining: int) -> void:
	if _gameplay_badge == null: return
	
	var lbl := _gameplay_badge.find_child("ChaserCountdownLabel", true, false) as Label
	if lbl != null:
		if remaining > 0:
			lbl.text = tr("hud_chaser_in") % remaining
			lbl.visible = true
		else:
			lbl.text = ""
			lbl.visible = false

func _on_chaser_released() -> void:
	_vibrate_remote_goal_change()
	if _gameplay_badge != null:
		var lbl := _gameplay_badge.find_child("ChaserCountdownLabel", true, false) as Label
		if lbl != null:
			lbl.text = ""
			lbl.visible = false

func _on_remote_goal_updated(goal_text: String, role_tag: String = "") -> void:
	# Clean up any leftover win/gotcha result overlay from the previous round
	if _gameplay_result_node != null:
		_gameplay_result_node.queue_free()
		_gameplay_result_node = null

	# Ensure the gameplay badge container is visible again
	if _gameplay_badge_container != null:
		_gameplay_badge_container.visible = true

	# Defensively reset any stuck D-Pad confusion visual from the previous round
	if _gameplay_badge_data != null and _gameplay_badge_data.has("confusion_moves"):
		if int(_gameplay_badge_data.get("confusion_moves", 0)) > 0:
			_gameplay_badge_data["confusion_moves"] = 0
			_gameplay_badge_data["is_confused"] = false
			_apply_remote_dpad_confusion_visual()

	var changed := goal_text != _current_remote_goal_text
	changed = changed or role_tag != _current_remote_role_tag
	_current_remote_role_tag = role_tag
	_refresh_gameplay_badge_role(role_tag)
	_current_remote_goal_text = goal_text
	if _gameplay_badge_slot != null:
		var vbox = _gameplay_badge_slot.get_node_or_null("BadgeVBox")
		if vbox != null:
			var goal_label = vbox.get_node_or_null("RemoteGoalLabel") as Label
			if goal_label != null:
				goal_label.text = tr(goal_text) if not goal_text.is_empty() else ""
				goal_label.visible = not goal_text.is_empty()
				_apply_remote_goal_label_layout(goal_label)
	if changed:
		_vibrate_remote_goal_change()

func _on_remote_result_updated(title_text: String, character_ids: Array[String]) -> void:
	# Clean up any existing result container first
	if _gameplay_result_node != null:
		_gameplay_result_node.queue_free()
		_gameplay_result_node = null
		
	# Hide the gameplay badge container so the screen is clean for result display
	if _gameplay_badge_container != null:
		_gameplay_badge_container.visible = false
		
	# Create a premium rounded banner container for the result
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = UIColors.BG_PANEL
	style.corner_radius_top_left = 32
	style.corner_radius_top_right = 32
	style.corner_radius_bottom_right = 32
	style.corner_radius_bottom_left = 32
	style.border_width_left = 6
	style.border_width_top = 6
	style.border_width_right = 6
	style.border_width_bottom = 6
	style.border_color = UIColors.SELECTED_BORDER
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 16
	style.content_margin_left = 60
	style.content_margin_right = 60
	style.content_margin_top = 40
	style.content_margin_bottom = 40
	panel.add_theme_stylebox_override("panel", style)
	
	# Make it large and gorgeous
	var header := WinScreen.build_title_header(tr(title_text), character_ids, 180, 130)
	panel.add_child(header)
	
	_gameplay_result_node = panel
	join_setup_center.add_child(panel)
	
	_vibrate_remote_goal_change()

func _on_remote_trap_status_updated(trap_available: bool, confusion_moves: int) -> void:
	_gameplay_badge_data["trap_available"] = trap_available
	_gameplay_badge_data["trap_texture"] = _remote_trap_texture()
	_gameplay_badge_data["confusion_moves"] = confusion_moves
	_gameplay_badge_data["is_confused"] = confusion_moves > 0
	_apply_remote_dpad_confusion_visual()
	_refresh_gameplay_badge_role(_current_remote_role_tag)

func _apply_remote_dpad_confusion_visual() -> void:
	var enabled := int(_gameplay_badge_data.get("confusion_moves", 0)) > 0
	if _pause_dialog != null and _pause_dialog.visible:
		enabled = false
	_set_remote_dpad_confusion_visual(enabled)

func _set_remote_dpad_confusion_visual(enabled: bool) -> void:
	if _local_dpad_node != null and _local_dpad_node.has_method("set_controls_reversed_visual"):
		_local_dpad_node.call("set_controls_reversed_visual", enabled)

func _on_network_debug_changed(scope: String, message: String) -> void:
	if network_debug_label == null: return
	network_debug_label.text = "Network [%s]: %s" % [scope, message]

func _transition_to_joined(character_id: String) -> void:
	_joined = true
	if _join_button != null: _join_button.visible = false
	if _join_error_label != null: _join_error_label.visible = false
	if _settings_vbox != null: _settings_vbox.visible = false
	_apply_character_preview(character_id, _char_preview)
	_cache_character_palette(character_id)
	_apply_selected_avatar_to_global_dpad()
	_show_local_dpad_for_setup()
	_configure_navigation()
	NetworkManager.stop_discovery()
	NetworkManager.stop_client_presence()
	if _scan_empty_timer != null:
		_scan_empty_timer.stop()
	_set_setup_hint_visible(false)

# ── Layout / Navigation / Helpers ───────────────────────────────────────────

func _apply_dpad_layout() -> void:
	if join_setup_center != null and Config != null:
		UIHelpers.apply_dpad_layout(join_setup_center, Config.on_screen_controls)

func _configure_navigation() -> void:
	# Chain follows the visual top-to-bottom order on the setup screen.
	var focusable: Array[Button] = []
	if _join_button != null and _join_button.visible and not _join_button.disabled:
		focusable.append(_join_button)
	if _char_button != null and not _char_button.disabled and _char_button.visible:
		focusable.append(_char_button)
	if _controller_button != null and _controller_button.visible:
		focusable.append(_controller_button)
	if _controller_size_button != null and _controller_size_button.visible:
		focusable.append(_controller_size_button)
	
	FocusNavigator.configure_vertical_chain(focusable)

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
		var logo_width: float = clampf(available_width * (0.24 if short_screen else 0.30), 200.0, 500.0)
		var logo_height: float = clampf(logo_width * 0.214, 40.0, 107.0)
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
	for btn in [_char_button, _controller_button, _controller_size_button]:
		if btn != null:
			btn.custom_minimum_size = Vector2(sel_w, sel_h)
			btn.add_theme_font_size_override("font_size", sel_fs)

	# Join button
	if _join_button != null:
		var jw := clampf(available_width * 0.22, 260.0, 380.0)
		_join_button.custom_minimum_size = Vector2(jw, 62.0 if short_screen else 68.0)
		_join_button.add_theme_font_size_override("font_size", 26 if short_screen else 30)

	if _setup_hint_label != null:
		_setup_hint_label.custom_minimum_size.x = clampf(available_width * 0.7, 520.0, 860.0)
		_setup_hint_label.add_theme_font_size_override("font_size", 20 if short_screen else 22)
	_apply_remote_goal_label_layout()
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

func _role_tag_for_session(role: String, session_config: Dictionary) -> String:
	var game_style := String(session_config.get("game_style", NetworkManager.STYLE_PATH))
	var mission_id := String(session_config.get("mission_id", ""))
	var chaser_enabled := bool(session_config.get("chaser_enabled", false))
	var training_type := String(session_config.get("training_type", NetworkManager.TRAINING_WORDS))
	if game_style == NetworkManager.STYLE_RACE:
		return NetworkManager.ROLE_RACER
	if game_style == NetworkManager.STYLE_PATH and not chaser_enabled and training_type == NetworkManager.TRAINING_NONE:
		return NetworkManager.ROLE_RACER
	if game_style == NetworkManager.STYLE_NEXT_SYMBOL and not chaser_enabled:
		return NetworkManager.ROLE_COLLECTOR
	if role == NetworkManager.ROLE_CHASER:
		return NetworkManager.ROLE_CHASER
	if mission_id == MissionCatalog.MISSION_FIND_EXIT:
		return "exit"
	return role

func _initial_remote_goal_for_session(role: String, session_config: Dictionary, player_count: int) -> String:
	var game_style := String(session_config.get("game_style", NetworkManager.STYLE_PATH))
	var mission_id := String(session_config.get("mission_id", MissionCatalog.mission_from_config(
		game_style,
		String(session_config.get("training_type", NetworkManager.TRAINING_WORDS))
	)))
	var training_type := String(session_config.get("training_type", NetworkManager.TRAINING_WORDS))
	var chaser_enabled := bool(session_config.get("chaser_enabled", false)) and game_style != NetworkManager.STYLE_RACE

	if game_style == NetworkManager.STYLE_RACE:
		return "mp_goal_maze_race_first"
	if role == NetworkManager.ROLE_CHASER:
		return "mp_goal_chaser_catch"
	if game_style == NetworkManager.STYLE_PATH and not chaser_enabled and training_type == NetworkManager.TRAINING_NONE:
		return "mp_goal_maze_race_first"
	if mission_id == MissionCatalog.MISSION_FIND_EXIT:
		return "mp_goal_find_exit"
	if chaser_enabled:
		match training_type:
			NetworkManager.TRAINING_NUMBERS: return "mp_goal_collect_numbers_chaser"
			NetworkManager.TRAINING_WORDS: return "mp_goal_collect_words_chaser"
			_: return "mp_goal_collect_letters_chaser"
	if player_count > 1:
		match training_type:
			NetworkManager.TRAINING_NUMBERS: return "mp_goal_collect_together_numbers"
			NetworkManager.TRAINING_WORDS: return "mp_goal_collect_together_words"
			_: return "mp_goal_collect_together_letters"
	match training_type:
		NetworkManager.TRAINING_NUMBERS: return "mp_goal_collect_numbers"
		NetworkManager.TRAINING_WORDS: return "mp_goal_collect_words"
		_: return "mp_goal_collect_letters"

func _refresh_gameplay_badge_role(role_tag: String) -> void:
	if _gameplay_badge == null:
		return
	var countdown_text := ""
	var countdown_visible := false
	var old_countdown := _gameplay_badge.find_child("ChaserCountdownLabel", true, false) as Label
	if old_countdown != null:
		countdown_text = old_countdown.text
		countdown_visible = old_countdown.visible
	_gameplay_badge_data["role"] = role_tag
	if not _selected_character_palette.is_empty():
		_gameplay_badge_data["color"] = _selected_character_palette.get("accent", UIColors.BLUE)
	_gameplay_badge_data["trap_texture"] = _remote_trap_texture()
	var new_badge := UIHelpers.build_player_chip(_gameplay_badge_data, 1, 2.0)
	_replace_gameplay_badge_control(new_badge)
	var new_countdown := _gameplay_badge.find_child("ChaserCountdownLabel", true, false) as Label
	if new_countdown != null:
		new_countdown.text = countdown_text
		new_countdown.visible = countdown_visible

func _replace_gameplay_badge_control(new_control: Control) -> void:
	if _gameplay_badge_slot == null:
		return
	var vbox = _gameplay_badge_slot.get_node_or_null("BadgeVBox")
	if vbox != null:
		if _gameplay_badge != null and _gameplay_badge.get_parent() == vbox:
			vbox.remove_child(_gameplay_badge)
			_gameplay_badge.queue_free()
		vbox.add_child(new_control)
		vbox.move_child(new_control, 0)
	_gameplay_badge = new_control

func _apply_remote_goal_label_layout(goal_label: Label = null) -> void:
	if goal_label == null:
		goal_label = _remote_goal_label()
	if goal_label == null:
		return
	goal_label.custom_minimum_size = Vector2(_remote_goal_label_width(), 0)
	goal_label.add_theme_font_size_override("font_size", REMOTE_GOAL_FONT_SIZE)

func _remote_goal_label() -> Label:
	if _gameplay_badge_slot == null:
		return null
	var vbox = _gameplay_badge_slot.get_node_or_null("BadgeVBox")
	if vbox == null:
		return null
	return vbox.get_node_or_null("RemoteGoalLabel") as Label

func _remote_goal_label_width() -> float:
	return clampf(get_viewport_rect().size.x * 0.36, REMOTE_GOAL_MIN_WIDTH, REMOTE_GOAL_MAX_WIDTH)

func _vibrate_remote_goal_change() -> void:
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(REMOTE_GOAL_HAPTIC_MS)

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

func _send_use_trap() -> void:
	if not _joined or not _game_started:
		return
	if _pause_dialog != null and _pause_dialog.visible:
		return
	NetworkManager.send_use_trap()

func _remote_trap_texture() -> Texture2D:
	var theme_dir := String(_last_host_cfg.get("theme_dir", Config.theme_dir_name if Config != null else "default"))
	if theme_dir.is_empty():
		theme_dir = "default"
	var loader := ThemeLoader.get_cached(theme_dir)
	return loader.trap_texture if loader != null else null

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
		&"ui_accept":
			if pressed:
				_send_use_trap()

## Disconnect from the current session and restore the pre-join UI so the
## player can reconfigure and join again without going back to the home screen.
func _unjoin(message_key: String = "mp_join_disconnected") -> void:
	if _leaving or _unjoining: return
	_unjoining = true
	NetworkManager.leave_session()
	_start_discovery_scan(false)
	_joined = false
	_game_started = false
	_refresh_client_presence()
	# Hide gameplay-only overlays
	if _gameplay_char_preview != null: _gameplay_char_preview.visible = false
	if _gameplay_badge_container != null:
		_gameplay_badge_container.queue_free()
		_gameplay_badge_container = null
		_gameplay_badge_slot = null
		_gameplay_badge = null
	if _gameplay_result_node != null:
		_gameplay_result_node.queue_free()
		_gameplay_result_node = null
	if _local_dpad_node != null and _local_dpad_node.has_method("set_controls_reversed_visual"):
		_local_dpad_node.call("set_controls_reversed_visual", false)
	# Restore pre-join UI elements
	if _main_vbox != null: _main_vbox.visible = true
	if _join_button != null: _join_button.visible = true
	if _settings_vbox != null: _settings_vbox.visible = true
	# Show a neutral, localized "disconnected" message briefly.
	# _unjoining stays true for the same 3 s so _update_join_action_state()
	# cannot overwrite the message with "host unavailable" during that window.
	if _join_error_label != null:
		_join_error_label.visible = true
		if message_key == "mp_kicked_by_host":
			_join_error_label.add_theme_color_override("font_color", Color(1, 0.45, 0.45, 1))
		else:
			_join_error_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6, 1.0))
		_join_error_label.text = tr(message_key)
	var lbl_ref := _join_error_label
	get_tree().create_timer(3.0).timeout.connect(func():
		_unjoining = false
		if is_instance_valid(lbl_ref) and lbl_ref.text == tr(message_key):
			lbl_ref.text = ""
		if is_instance_valid(lbl_ref):
			lbl_ref.add_theme_color_override("font_color", Color(1, 0.45, 0.45, 1))
	)
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
	return reason in ["mp_join_host_unavailable", "mp_join_error_connect", "mp_join_disconnected", "mp_join_game_started", "mp_join_lobby_full"]

func _restart_discovery_after_join_rejection() -> void:
	if _leaving or _joined or _game_started:
		return
	NetworkManager.leave_session()
	_start_discovery_scan(false)

func _localized_join_reason(reason: String) -> String:
	var localized := tr(reason)
	return reason if localized == reason and not reason.begins_with("mp_") else localized

# ── Discovery (kept for host card rebuilding) ──────────────────────────────

func _start_discovery_scan(reset_selection: bool = false) -> void:
	if reset_selection:
		_hosts.clear()
		_selected_host = {}
		_selected_host_index = -1
		_selected_host_available = false
		_rebuild_host_cards()
		_show_no_games_state()

	_set_discovery_hint_visible(false)
	_set_setup_hint_visible(false)
	var err: int = NetworkManager.start_discovery()
	if err != OK:
		if _scan_empty_timer != null:
			_scan_empty_timer.stop()
		if discovery_panel.visible and discovery_status_label != null:
			discovery_status_label.text = "%s: %d" % [tr("mp_join_discovery_error"), err]
			_set_discovery_hint_visible(true)
		if join_setup_panel.visible and _join_error_label != null:
			_join_error_label.visible = true
			_join_error_label.text = "%s: %d" % [tr("mp_join_discovery_error"), err]
			_set_setup_hint_visible(true)
		return

	if discovery_panel.visible and discovery_status_label != null:
		discovery_status_label.text = tr("mp_join_discovery_scanning")
	if join_setup_panel.visible and _join_error_label != null and _selected_host.is_empty():
		_join_error_label.visible = true
		_join_error_label.text = tr("mp_join_discovery_scanning")
	if _scan_empty_timer != null:
		_scan_empty_timer.start()
	_refresh_client_presence()

func _refresh_client_presence() -> void:
	if _leaving or _joined or _join_pending or _game_started:
		NetworkManager.stop_client_presence()
		return
	if _selected_host.is_empty():
		NetworkManager.start_client_presence()
	else:
		NetworkManager.start_client_presence(_selected_host)

func _on_scan_empty_timeout() -> void:
	if _hosts.is_empty() and discovery_panel.visible:
		discovery_status_label.text = tr("mp_join_discovery_none")
		_set_discovery_hint_visible(true)
	if _hosts.is_empty() and join_setup_panel.visible and not _joined and not _join_pending:
		_show_no_games_state()

func _set_discovery_hint_visible(visible: bool) -> void:
	if _discovery_hint_label != null:
		_discovery_hint_label.visible = visible
	_configure_discovery_navigation()

func _set_setup_hint_visible(visible: bool) -> void:
	if _setup_hint_label != null:
		_setup_hint_label.visible = visible
	_configure_navigation()

func _configure_discovery_navigation() -> void:
	var focusable: Array[Control] = []
	for card in _host_cards:
		if card != null and card.visible and not card.disabled:
			focusable.append(card)
	FocusNavigator.configure_vertical_chain(focusable)

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
	_configure_discovery_navigation()

func _create_host_card(host: Dictionary, index: int) -> Button:
	var button: Button = HostCardBuilder.create_card(host, index, false)
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
	_refresh_client_presence()

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
	label.add_theme_color_override("font_color", UIColors.TEXT_SECONDARY)
	slot_vbox.add_child(label)
	_slots_row.add_child(slot_vbox)
	_slot_nodes.append({"vbox": slot_vbox, "frame": frame, "preview": preview, "label": label, "is_filled": false})
	_apply_empty_frame_style(frame)

func _clear_slots() -> void:
	for slot in _slot_nodes:
		var vbox := slot["vbox"] as Control
		if is_instance_valid(vbox): vbox.queue_free()
	_slot_nodes.clear()
	_pulse_tween = PulseAnimator.stop_pulse(_pulse_tween)

func _apply_filled_frame_style(frame: PanelContainer, border_color: Color = MP_GREEN_BORDER) -> void:
	SlotStyler.apply_filled_style(frame, border_color)

func _apply_empty_frame_style(frame: PanelContainer) -> void:
	_apply_empty_frame_style_colored(frame, SLOT_EMPTY_COLOR)

func _apply_empty_frame_style_colored(frame: PanelContainer, border_color: Color) -> void:
	var bg := SLOT_EMPTY_BG if border_color == SLOT_EMPTY_COLOR else Color(UIColors.BG_DARK.r, UIColors.BG_DARK.g, UIColors.BG_DARK.b, 0.5)
	SlotStyler.apply_empty_style(frame, border_color, bg)

func _update_pulse_animation() -> void:
	_pulse_tween = PulseAnimator.stop_pulse(_pulse_tween)
	var empty_frames: Array[PanelContainer] = []
	for slot in _slot_nodes:
		if not slot["is_filled"]:
			empty_frames.append(slot["frame"] as PanelContainer)
	if empty_frames.is_empty(): return
	_pulse_tween = PulseAnimator.start_pulse(self, empty_frames)

func _apply_card_zoom(focused: bool) -> void:
	JoinCardHelper.apply_card_zoom(self, focused)

func _ordered_peer_ids(player_map: Dictionary) -> Array[int]:
	return PlayerSlotPanel.ordered_peer_ids(player_map)
