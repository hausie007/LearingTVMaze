extends Control

const DEFAULT_GAME_PORT: int = 42020

@onready var discovery_panel: Control = %DiscoveryPanel
@onready var discovery_title_label: Label = %DiscoveryTitleLabel
@onready var discovery_status_label: Label = %DiscoveryStatusLabel
@onready var network_debug_label: Label = %NetworkDebugLabel
@onready var host_list_scroll: ScrollContainer = %HostListScroll
@onready var host_list_vbox: VBoxContainer = %HostListVBox

@onready var join_setup_panel: Control = %JoinSetupPanel
@onready var join_setup_center_container: CenterContainer = $"JoinSetupPanel/CenterContainer"
@onready var join_title_label: Label = %JoinTitleLabel
@onready var host_info_label: Label = %HostInfoLabel
@onready var theme_label: Label = %ThemeLabel
@onready var theme_value_label: Label = %ThemeValueLabel
@onready var character_label: Label = %CharacterLabel
@onready var character_button: Button = %CharacterButton
@onready var character_left_arrow: Label = %CharacterLeftArrow
@onready var character_right_arrow: Label = %CharacterRightArrow
@onready var character_preview: CharacterPreview = %CharacterPlayerAnchor
@onready var taken_avatars_label: Label = %TakenAvatarsLabel
@onready var taken_avatars_container: HBoxContainer = %TakenAvatarsContainer
@onready var join_error_label: Label = %JoinErrorLabel
@onready var join_game_button: Button = %JoinGameButton

@onready var controller_panel: Control = %ControllerPanel
@onready var character_icon: CharacterPreview = %CharacterIcon
@onready var controller_title_label: Label = %ControllerTitleLabel
@onready var remote_layout_label: Label = %RemoteLayoutLabel
@onready var remote_layout_button: Button = %RemoteLayoutButton
@onready var remote_layout_left_arrow: Label = %RemoteLayoutLeftArrow
@onready var remote_layout_right_arrow: Label = %RemoteLayoutRightArrow

var _hosts: Array = []
var _host_cards: Array[Button] = []
var _selected_host_index: int = -1
var _selected_host: Dictionary = {}
var _character_catalog: Array[Dictionary] = []
var _taken_character_ids: Array[String] = []
var _selected_character_idx: int = 0
var _selected_character_id: String = ""
var _selected_character_palette: Dictionary = {}
var _selected_host_available: bool = false
var _saved_local_dpad_visible: bool = true
var _local_dpad_node: CanvasLayer = null
var _leaving_controller: bool = false

func _ready() -> void:
	Input.warp_mouse(Vector2(-1, -1))
	_localize_ui()
	if network_debug_label != null:
		network_debug_label.visible = false
	_cache_local_dpad()

	join_game_button.pressed.connect(_on_join_game_pressed)

	UIHelpers.apply_style_to_button(join_game_button, UIColors.BLUE)
	UIHelpers.apply_style_to_button(character_button, UIColors.YELLOW)
	UIHelpers.apply_style_to_button(remote_layout_button, UIColors.YELLOW)

	_setup_cycling_button(character_button, func(dir): _cycle_character(dir))
	_setup_cycling_button(remote_layout_button, func(dir): _cycle_remote_layout(dir))

	NetworkManager.host_discovered.connect(_on_host_discovered)
	NetworkManager.discovery_updated.connect(_on_discovery_updated)
	NetworkManager.lobby_updated.connect(_on_lobby_updated)
	NetworkManager.join_accepted.connect(_on_join_accepted)
	NetworkManager.join_rejected.connect(_on_join_rejected)
	NetworkManager.game_started.connect(_on_game_started)
	NetworkManager.debug_status_changed.connect(_on_network_debug_changed)
	if Config != null and not Config.on_screen_controls_changed.is_connected(_on_controls_changed):
		Config.on_screen_controls_changed.connect(_on_controls_changed)

	_character_catalog = CharacterCatalog.build_catalog()
	var pending_host: Dictionary = NetworkManager.consume_pending_join_host()
	if pending_host.is_empty():
		get_tree().change_scene_to_file("res://scenes/multiplayer/multiplayer_menu.tscn")
		return

	_selected_host = pending_host.duplicate(true)
	_hosts = [_selected_host.duplicate(true)]
	_selected_host_index = 0
	_selected_host_available = true
	NetworkManager.start_discovery()
	_enter_join_setup_mode()

func _unhandled_input(event: InputEvent) -> void:
	var viewport: Viewport = get_viewport()
	if controller_panel.visible:
		if event.is_action("ui_up"):
			_send_controller_direction(Vector2i.UP, event.is_pressed())
			if viewport != null:
				viewport.set_input_as_handled()
			return
		if event.is_action("ui_down"):
			_send_controller_direction(Vector2i.DOWN, event.is_pressed())
			if viewport != null:
				viewport.set_input_as_handled()
			return
		if event.is_action("ui_left"):
			_send_controller_direction(Vector2i.LEFT, event.is_pressed())
			if viewport != null:
				viewport.set_input_as_handled()
			return
		if event.is_action("ui_right"):
			_send_controller_direction(Vector2i.RIGHT, event.is_pressed())
			if viewport != null:
				viewport.set_input_as_handled()
			return
		if event.is_action_pressed("ui_cancel"):
			if viewport != null:
				viewport.set_input_as_handled()
			_on_controller_leave_pressed()
			return

	if not event.is_action_pressed("ui_cancel"):
		return

	if viewport != null:
		viewport.set_input_as_handled()

	if controller_panel.visible:
		_on_controller_leave_pressed()
	elif join_setup_panel.visible:
		_return_to_discovery()
	else:
		_go_back_to_multiplayer_menu()

func _exit_tree() -> void:
	_reset_global_dpad_accent()
	_restore_local_dpad()

func _localize_ui() -> void:
	discovery_title_label.text = tr("mp_join_discovery_title")
	discovery_status_label.text = tr("mp_join_discovery_scanning")

	join_title_label.text = tr("mp_join_setup_title")
	theme_label.text = tr("mp_join_theme")
	character_label.text = tr("mp_join_character")
	remote_layout_label.text = tr("mp_join_remote_layout")
	taken_avatars_label.text = "Taken avatars:"
	join_game_button.text = tr("mp_join_game")
	join_error_label.text = ""

	controller_title_label.text = tr("mp_controller_title")

func _apply_join_setup_layout() -> void:
	if join_setup_center_container != null and Config != null:
		UIHelpers.apply_dpad_layout(join_setup_center_container, Config.on_screen_controls)

func _on_controls_changed(_new_mode: int) -> void:
	_apply_join_setup_layout()
	_refresh_remote_controller_layout()
	if controller_panel.visible:
		_show_local_dpad_for_setup()
		_position_controller_avatar()

func _setup_cycling_button(btn: Button, cycle_func: Callable) -> void:
	if btn == null:
		return

	var left_arrow: Label = character_left_arrow if btn == character_button else remote_layout_left_arrow if btn == remote_layout_button else null
	var right_arrow: Label = character_right_arrow if btn == character_button else remote_layout_right_arrow if btn == remote_layout_button else null

	if left_arrow:
		left_arrow.modulate.a = 0.0
	if right_arrow:
		right_arrow.modulate.a = 0.0

	btn.focus_entered.connect(func():
		if is_instance_valid(left_arrow):
			left_arrow.modulate.a = 1.0
		if is_instance_valid(right_arrow):
			right_arrow.modulate.a = 1.0
	)
	btn.focus_exited.connect(func():
		if is_instance_valid(left_arrow):
			left_arrow.modulate.a = 0.0
		if is_instance_valid(right_arrow):
			right_arrow.modulate.a = 0.0
	)
	btn.pressed.connect(func(): cycle_func.call(1))
	btn.gui_input.connect(func(event: InputEvent):
		if event.is_pressed():
			var viewport: Viewport = get_viewport()
			if event.is_action("ui_left"):
				cycle_func.call(-1)
				if viewport != null:
					viewport.set_input_as_handled()
			elif event.is_action("ui_right"):
				cycle_func.call(1)
				if viewport != null:
					viewport.set_input_as_handled()
	)

func _enter_discovery_mode(status_override: String = "") -> void:
	discovery_panel.visible = true
	join_setup_panel.visible = false
	controller_panel.visible = false
	join_error_label.text = ""
	_hosts.clear()
	_host_cards.clear()
	_selected_host.clear()
	_selected_host_index = -1
	discovery_status_label.text = status_override if not status_override.is_empty() else tr("mp_join_discovery_scanning")

	var err: int = NetworkManager.start_discovery()
	var status_text: String = status_override
	if err != OK:
		status_text = "%s: %d" % [tr("mp_join_discovery_error"), err]
		discovery_status_label.text = status_text

	_rebuild_host_cards()
	if _selected_host.is_empty():
		_focus_first_host_card(status_text)
	else:
		_sync_selected_host_from_list()
		if _selected_host_index >= 0:
			_focus_host_card(_selected_host_index)
		else:
			_focus_first_host_card()

func _enter_join_setup_mode() -> void:
	discovery_panel.visible = false
	join_setup_panel.visible = true
	controller_panel.visible = false
	join_error_label.text = ""
	_show_local_dpad_for_setup()
	_apply_join_setup_layout()
	_populate_join_setup_from_selected_host()
	_update_character_selector()
	_update_taken_avatars()
	_refresh_remote_controller_layout()
	if character_button.disabled:
		join_game_button.call_deferred("grab_focus")
	else:
		character_button.call_deferred("grab_focus")

func _enter_controller_mode(character_id: String) -> void:
	discovery_panel.visible = false
	join_setup_panel.visible = false
	controller_panel.visible = true
	_leaving_controller = false
	_refresh_remote_controller_layout()

	_apply_character_preview(character_id, character_icon)
	_cache_character_palette(character_id)
	_apply_selected_avatar_to_global_dpad()
	_show_local_dpad_for_setup()
	_position_controller_avatar()
	NetworkManager.stop_discovery()

func _populate_join_setup_from_selected_host() -> void:
	if _selected_host.is_empty():
		return

	var host_name: String = String(_selected_host.get("host_name", "Host"))
	var host_ip: String = String(_selected_host.get("ip", ""))
	var max_players: int = int(_selected_host.get("max_players", 2))
	var player_count: int = int(_selected_host.get("player_count", 1))

	host_info_label.text = "%s (%s) %d/%d" % [host_name, host_ip, player_count, max_players]
	theme_value_label.text = String(_selected_host.get("theme_title", _selected_host.get("theme_dir", "")))
	_update_taken_character_ids_from_selected_host()
	if character_button:
		character_button.text = ""
	_update_join_action_state()

func _update_character_selector() -> void:
	if _character_catalog.is_empty():
		character_button.text = ""
		character_button.disabled = true
		join_game_button.disabled = true
		character_preview.clear()
		_selected_character_palette = AvatarAccent.safe_palette()
		_apply_selected_avatar_to_global_dpad()
		return

	if _selected_character_idx < 0 or _selected_character_idx >= _character_catalog.size():
		_selected_character_idx = _find_next_enabled_character(-1, 1)

	if _selected_character_idx >= 0:
		var current_character_id: String = String(_character_catalog[_selected_character_idx].get("id", ""))
		if _taken_character_ids.has(current_character_id):
			_selected_character_idx = _find_next_enabled_character(_selected_character_idx, 1)

	if _selected_character_idx < 0:
		character_button.text = tr("mp_join_error_character_taken")
		character_button.disabled = true
		join_game_button.disabled = true
		_selected_character_id = ""
		character_preview.clear()
		_selected_character_palette = AvatarAccent.safe_palette()
		_apply_selected_avatar_to_global_dpad()
		return

	var entry: Dictionary = _character_catalog[_selected_character_idx]
	_selected_character_id = String(entry.get("id", ""))
	character_button.text = String(entry.get("display_name", ""))
	character_button.disabled = false

	_apply_character_preview(_selected_character_id, character_preview)
	_cache_character_palette(_selected_character_id)
	_apply_selected_avatar_to_global_dpad()

	_update_join_action_state()

func _on_host_discovered(_info: Dictionary) -> void:
	# Full refresh is handled by discovery_updated.
	pass

func _rebuild_host_cards() -> void:
	if host_list_vbox == null:
		return

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
	var icon_data: Dictionary = CharacterCatalog.get_preview_data_by_id(host_character_id)
	var icon_frames: Array[Texture2D] = []
	for item in icon_data.get("frames", []):
		if item is Texture2D:
			icon_frames.append(item)
	if not icon_frames.is_empty():
		icon.set_character(icon_frames, float(icon_data.get("fps", 1.0)))
	else:
		var fallback: Texture2D = CharacterCatalog.get_texture_by_id(host_character_id)
		if fallback != null:
			icon.set_character([fallback], 1.0)
	row.add_child(icon)

	var text_box: VBoxContainer = VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 6)
	row.add_child(text_box)

	var host_name: String = String(host.get("host_name", "Host"))
	var host_ip: String = String(host.get("ip", ""))
	var theme_title: String = String(host.get("theme_title", host.get("theme_dir", "")))
	var player_count: int = int(host.get("player_count", 1))
	var max_players: int = int(host.get("max_players", 2))

	var title: Label = Label.new()
	title.text = "%s" % host_name
	title.add_theme_font_size_override("font_size", 34)
	text_box.add_child(title)

	var subtitle: Label = Label.new()
	subtitle.text = "%s | %d/%d | %s" % [host_ip, player_count, max_players, theme_title]
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.modulate = Color(1, 1, 1, 0.8)
	text_box.add_child(subtitle)

	var footer: Label = Label.new()
	footer.text = CharacterCatalog.display_name_for_id(host_character_id)
	footer.add_theme_font_size_override("font_size", 24)
	footer.modulate = Color(0.92, 0.75, 0.2, 1)
	text_box.add_child(footer)

	button.pressed.connect(func():
		_select_host_index(index)
	)
	button.focus_entered.connect(func():
		_selected_host_index = index
		if host_list_scroll:
			host_list_scroll.ensure_control_visible(button)
	)
	return button

func _focus_first_host_card(status_if_empty: String = "") -> void:
	if _host_cards.is_empty():
		if status_if_empty.is_empty():
			discovery_status_label.text = tr("mp_join_discovery_none")
		else:
			discovery_status_label.text = status_if_empty
		return

	_host_cards[0].call_deferred("grab_focus")

func _select_host_index(index: int) -> void:
	if index < 0 or index >= _hosts.size():
		return

	_selected_host_index = index
	_selected_host = (_hosts[index] as Dictionary).duplicate(true)
	_enter_join_setup_mode()

func _go_back_to_multiplayer_menu() -> void:
	_reset_global_dpad_accent()
	_restore_local_dpad()
	NetworkManager.leave_session()
	get_tree().change_scene_to_file("res://scenes/multiplayer/multiplayer_menu.tscn")

func _return_to_discovery(status_override: String = "") -> void:
	_reset_global_dpad_accent()
	_selected_host.clear()
	_selected_host_index = -1
	_selected_host_available = false
	_selected_character_idx = 0
	_selected_character_id = ""
	_taken_character_ids.clear()
	NetworkManager.leave_session()
	get_tree().change_scene_to_file("res://scenes/multiplayer/multiplayer_menu.tscn")

func _find_next_enabled_character(start_idx: int, dir: int) -> int:
	if _character_catalog.is_empty():
		return -1

	var next_idx: int = start_idx
	for _i in range(_character_catalog.size()):
		next_idx = (next_idx + dir + _character_catalog.size()) % _character_catalog.size()
		var character_id: String = String(_character_catalog[next_idx].get("id", ""))
		if not _taken_character_ids.has(character_id):
			return next_idx

	return -1

func _on_discovery_updated(hosts: Array) -> void:
	_hosts = hosts.duplicate(true)

	if join_setup_panel.visible and not _selected_host.is_empty():
		_selected_host_available = _sync_selected_host_from_list()
		_populate_join_setup_from_selected_host()
		_update_character_selector()
		_update_taken_avatars()
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

func _on_join_game_pressed() -> void:
	join_error_label.text = ""
	if _selected_character_id.is_empty():
		join_error_label.text = tr("mp_join_error_character")
		return

	if not _is_selected_host_available():
		_return_to_discovery(tr("mp_join_host_unavailable"))
		return

	if _taken_character_ids.has(_selected_character_id):
		join_error_label.text = tr("mp_join_error_character_taken")
		return

	var host_ip: String = String(_selected_host.get("ip", ""))
	var host_port: int = int(_selected_host.get("port", DEFAULT_GAME_PORT))
	var err: int = NetworkManager.join_host(host_ip, host_port, _selected_character_id)
	if err != OK:
		join_error_label.text = "%s: %d" % [tr("mp_join_error_connect"), err]
		return

	join_error_label.text = tr("mp_join_connecting")

func _on_join_accepted(peer_id: int, state: Dictionary) -> void:
	var character_id: String = _selected_character_id
	var players: Dictionary = state.get("players", {}) as Dictionary
	if players.has(peer_id):
		character_id = String((players[peer_id] as Dictionary).get("character_id", character_id))
	elif players.has(str(peer_id)):
		character_id = String((players[str(peer_id)] as Dictionary).get("character_id", character_id))

	_enter_controller_mode(character_id)

func _on_join_rejected(reason: String) -> void:
	if _should_return_to_discovery(reason):
		_return_to_discovery(reason)
		return

	if join_setup_panel.visible:
		join_error_label.text = reason
	else:
		discovery_status_label.text = reason

func _on_lobby_updated(state: Dictionary) -> void:
	if not join_setup_panel.visible:
		return

	var cfg: Dictionary = state.get("config", {}) as Dictionary
	if not cfg.is_empty():
		theme_value_label.text = String(cfg.get("theme_title", cfg.get("theme_dir", theme_value_label.text)))

	var players: Dictionary = state.get("players", {}) as Dictionary
	_taken_character_ids.clear()
	for info in players.values():
		var p: Dictionary = info as Dictionary
		_taken_character_ids.append(String(p.get("character_id", "")))
	_update_taken_avatars()

	if not _selected_character_id.is_empty() and _taken_character_ids.has(_selected_character_id):
		_selected_character_idx = _find_next_enabled_character(_selected_character_idx, 1)
		_update_character_selector()
	else:
		_update_join_action_state()

func _on_game_started(_session: Dictionary) -> void:
	# Controller stays on this screen in Phase 1.
	pass

func _on_network_debug_changed(scope: String, message: String) -> void:
	if network_debug_label == null:
		return
	network_debug_label.text = "Network [%s]: %s" % [scope, message]

func _cycle_character(dir: int) -> void:
	if _character_catalog.is_empty():
		return

	_selected_character_idx = _find_next_enabled_character(_selected_character_idx, dir)
	_update_character_selector()

func _cycle_remote_layout(dir: int) -> void:
	if Config == null or Config.CONTROLS_KEYS.is_empty():
		return

	Config.on_screen_controls = (Config.on_screen_controls + dir + Config.CONTROLS_KEYS.size()) % Config.CONTROLS_KEYS.size()
	Config.save_settings()
	_refresh_remote_controller_layout()
	if join_setup_panel.visible:
		_apply_join_setup_layout()

func _cache_character_palette(character_id: String) -> void:
	if character_id.is_empty():
		_selected_character_palette = AvatarAccent.safe_palette()
		return

	_selected_character_palette = AvatarAccent.palette_from_character_id(character_id)
	if _selected_character_palette.is_empty():
		_selected_character_palette = AvatarAccent.safe_palette()

func _apply_selected_avatar_to_global_dpad() -> void:
	if _local_dpad_node == null:
		return
	if _local_dpad_node.has_method("set_accent_palette"):
		_local_dpad_node.call("set_accent_palette", _selected_character_palette)

func _reset_global_dpad_accent() -> void:
	if _local_dpad_node == null:
		return
	if _local_dpad_node.has_method("reset_accent_palette"):
		_local_dpad_node.call("reset_accent_palette")

func _update_taken_character_ids_from_selected_host() -> void:
	_taken_character_ids.clear()
	var raw_taken: Variant = _selected_host.get("taken_characters", [])
	if raw_taken is Array:
		var taken_items: Array = raw_taken as Array
		for item in taken_items:
			var character_id: String = String(item)
			if not character_id.is_empty() and not _taken_character_ids.has(character_id):
				_taken_character_ids.append(character_id)

func _update_taken_avatars() -> void:
	if taken_avatars_container == null:
		return

	for child in taken_avatars_container.get_children():
		var node: Node = child as Node
		if node != null:
			node.queue_free()

	for raw_character_id in _taken_character_ids:
		var character_id: String = String(raw_character_id)
		var preview: CharacterPreview = CharacterPreview.new()
		preview.custom_minimum_size = Vector2(86, 86)
		preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_apply_character_preview(character_id, preview)
		taken_avatars_container.add_child(preview)

func _apply_character_preview(character_id: String, preview: CharacterPreview) -> void:
	if preview == null:
		return

	var preview_data: Dictionary = CharacterCatalog.get_preview_data_by_id(character_id)
	var frames_data: Array = preview_data.get("frames", [])
	var frames: Array[Texture2D] = []
	for item in frames_data:
		if item is Texture2D:
			frames.append(item)
	var fps: float = float(preview_data.get("fps", 1.0))
	if not frames.is_empty():
		preview.set_character(frames, fps)
	else:
		var fallback: Texture2D = CharacterCatalog.get_texture_by_id(character_id)
		if fallback != null:
			preview.set_character([fallback], 1.0)
		else:
			preview.clear()

func _send_controller_direction(direction: Vector2i, pressed: bool) -> void:
	NetworkManager.send_dpad(direction, pressed)

func _refresh_remote_controller_layout() -> void:
	if Config == null:
		return
	if remote_layout_button != null and Config.on_screen_controls >= 0 and Config.on_screen_controls < Config.CONTROLS_KEYS.size():
		remote_layout_button.text = tr(Config.CONTROLS_KEYS[Config.on_screen_controls])

func _position_controller_avatar() -> void:
	if character_icon == null:
		return

	var avatar_size: Vector2 = Vector2(140, 140)
	var margin: float = 20.0
	var dpad_mode: int = 0
	if Config != null:
		dpad_mode = Config.on_screen_controls
	var place_left: bool = Config != null and dpad_mode == Config.ControlsMode.RIGHT_HANDED

	character_icon.anchor_top = 0.0
	character_icon.anchor_bottom = 0.0
	if place_left:
		character_icon.anchor_left = 0.0
		character_icon.anchor_right = 0.0
		character_icon.offset_left = margin
		character_icon.offset_right = margin + avatar_size.x
	else:
		character_icon.anchor_left = 1.0
		character_icon.anchor_right = 1.0
		character_icon.offset_left = -margin - avatar_size.x
		character_icon.offset_right = -margin
	character_icon.offset_top = margin
	character_icon.offset_bottom = margin + avatar_size.y

func _update_join_action_state() -> void:
	if join_game_button == null:
		return

	var host_available: bool = _is_selected_host_available()
	var character_available: bool = not _selected_character_id.is_empty() and not _taken_character_ids.has(_selected_character_id)
	join_game_button.disabled = not (host_available and character_available)
	if join_setup_panel.visible and not host_available:
		join_error_label.text = tr("mp_join_host_unavailable")

func _host_key(host: Dictionary) -> String:
	return "%s:%d" % [String(host.get("ip", "")), int(host.get("port", DEFAULT_GAME_PORT))]

func _selected_host_key() -> String:
	if _selected_host.is_empty():
		return ""
	return _host_key(_selected_host)

func _sync_selected_host_from_list() -> bool:
	var host_key: String = _selected_host_key()
	if host_key.is_empty():
		return false

	for i in range(_hosts.size()):
		var host: Dictionary = _hosts[i] as Dictionary
		if _host_key(host) == host_key:
			_selected_host_index = i
			_selected_host = host.duplicate(true)
			return true
	return false

func _focus_host_card(index: int) -> void:
	if index < 0 or index >= _host_cards.size():
		return
	_host_cards[index].call_deferred("grab_focus")

func _is_selected_host_available() -> bool:
	return _selected_host_available and not _selected_host_key().is_empty()

func _should_return_to_discovery(reason: String) -> bool:
	return reason == "Host unavailable" or reason == "Could not connect to host" or reason == "Disconnected from host" or reason == "Game already started" or reason == "Lobby is full"

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
	if _local_dpad_node == null:
		return
	var off_mode: int = Config.ControlsMode.OFF if Config != null else 0
	var controls_mode: int = Config.on_screen_controls if Config != null else off_mode
	_local_dpad_node.visible = controls_mode != off_mode

func _on_controller_leave_pressed() -> void:
	if _leaving_controller:
		return
	_leaving_controller = true
	_reset_global_dpad_accent()
	_restore_local_dpad()
	NetworkManager.leave_session()
	get_tree().change_scene_to_file("res://scenes/multiplayer/multiplayer_menu.tscn")

func _on_local_dpad_action(action: StringName, pressed: bool) -> void:
	if not controller_panel.visible:
		return

	match action:
		&"ui_up":
			_send_controller_direction(Vector2i.UP, pressed)
		&"ui_down":
			_send_controller_direction(Vector2i.DOWN, pressed)
		&"ui_left":
			_send_controller_direction(Vector2i.LEFT, pressed)
		&"ui_right":
			_send_controller_direction(Vector2i.RIGHT, pressed)
		&"ui_cancel":
			if pressed:
				_on_controller_leave_pressed()
