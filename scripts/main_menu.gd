extends Control

const ModeCardScene := preload("res://scenes/ui/mode_card.tscn")
const MissionCatalog := preload("res://scripts/mission_catalog.gd")
const LogoTexture := preload("res://images/lm_horizontal.png")

const JOIN_GREEN := Color("#2FAE66")
const MISSION_CARD_GAP := 42

@onready var center_container: CenterContainer = $CenterContainer

var _home_vbox: VBoxContainer = null
var _join_vbox: VBoxContainer = null
var _top_spacer: Control = null
var _logo: TextureRect = null
var _logo_cards_spacer: Control = null
var _mission_row: GridContainer = null
var _mission_settings_spacer: Control = null
var _join_card: Button = null
var _join_card_focused: bool = false
var _theme_button: Button = null
var _theme_left: Label = null
var _theme_right: Label = null
var _theme_preview: CharacterPreview = null
var _maze_size_button: Button = null
var _maze_size_left: Label = null
var _maze_size_right: Label = null
var _start_multiplayer_button: Button = null
var _settings_button: Button = null
var _help_button: Button = null
var _theme_preview_container: Control = null
var _secondary_overlay: Control = null
var _secondary_row: HBoxContainer = null
var _host_list_scroll: ScrollContainer = null
var _host_list_vbox: VBoxContainer = null
var _join_status_label: Label = null
var _join_back_button: Button = null

var _mission_cards: Dictionary = {}
var _mission_order: Array[String] = []
var _selected_mission: String = MissionCatalog.DEFAULT_MISSION
var _themes: Array[String] = []
var _theme_idx: int = 0
var _theme_preview_loader: ThemeLoader = null
var _last_theme_idx: int = -1
var _maze_size_idx: int = 0
var _hosts: Array = []
var _host_cards: Array[Button] = []
var _selected_host_index: int = -1
var _mission_columns: int = 4

var _quit_dialog: CanvasLayer = null
var _quit_no_button: Button = null
var _input_locked: bool = true

func _ready() -> void:
	Input.warp_mouse(Vector2(-1, -1))
	_initialize_state()
	_build_layout()
	_update_home()
	_apply_dpad_layout()
	_apply_responsive_layout()
	_configure_home_focus()

	NetworkManager.discovery_updated.connect(_on_discovery_updated)
	NetworkManager.host_discovered.connect(_on_host_discovered)
	if Config != null and not Config.on_screen_controls_changed.is_connected(_on_controls_changed):
		Config.on_screen_controls_changed.connect(_on_controls_changed)

	var err: int = NetworkManager.start_discovery()
	if err != OK:
		_hosts.clear()
	_update_join_button()

	if Config.show_join_list_on_home:
		var status_override: String = Config.join_status_override
		Config.show_join_list_on_home = false
		Config.join_status_override = ""
		call_deferred("_show_join_list", true, status_override)

	var initial_focus := _selected_mission_card()
	if initial_focus != null:
		initial_focus.call_deferred("grab_focus")
	get_tree().create_timer(0.2).timeout.connect(func(): _input_locked = false)

func _exit_tree() -> void:
	NetworkManager.stop_discovery()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_apply_dpad_layout()
		_apply_responsive_layout()
		_configure_home_focus()

func _initialize_state() -> void:
	_selected_mission = Config.selected_mission_id
	if not MissionCatalog.mission_ids().has(_selected_mission):
		_selected_mission = Config.mission_id
	if not MissionCatalog.mission_ids().has(_selected_mission):
		_selected_mission = MissionCatalog.DEFAULT_MISSION

	_themes = ThemeLoader.get_available_themes()
	_theme_idx = _themes.find(Config.theme_dir_name)
	if _theme_idx < 0:
		_theme_idx = 0
	_maze_size_idx = clampi(Config.difficulty, 0, max(0, Config.DIFF_KEYS.size() - 1))

func _build_layout() -> void:
	for child in center_container.get_children():
		center_container.remove_child(child)
		child.queue_free()
	if _secondary_overlay != null:
		_secondary_overlay.queue_free()
		_secondary_overlay = null
	_mission_cards.clear()
	_join_card = null

	_home_vbox = VBoxContainer.new()
	_home_vbox.name = "MissionHome"
	_home_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	_home_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_home_vbox.custom_minimum_size = Vector2(1500, 0)
	_home_vbox.add_theme_constant_override("separation", 18)
	center_container.add_child(_home_vbox)

	_top_spacer = Control.new()
	_top_spacer.name = "HomeTopSpacer"
	_top_spacer.custom_minimum_size = Vector2(0, 60)
	_home_vbox.add_child(_top_spacer)

	_logo = TextureRect.new()
	_logo.name = "AppLogo"
	_logo.texture = LogoTexture
	_logo.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.clip_contents = false
	_logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_home_vbox.add_child(_logo)

	_logo_cards_spacer = Control.new()
	_logo_cards_spacer.name = "LogoCardsSpacer"
	_logo_cards_spacer.custom_minimum_size = Vector2(0, 18)
	_home_vbox.add_child(_logo_cards_spacer)

	_mission_row = GridContainer.new()
	_mission_row.name = "MissionRow"
	_mission_row.columns = _mission_columns
	_mission_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mission_row.add_theme_constant_override("h_separation", MISSION_CARD_GAP)
	_mission_row.add_theme_constant_override("v_separation", 18)
	_home_vbox.add_child(_mission_row)

	_mission_order = MissionCatalog.mission_ids()
	for i in range(_mission_order.size()):
		if i == 2:
			_create_join_card()
		var mission_id := _mission_order[i]
		var card := _create_mission_card(mission_id)
		_mission_row.add_child(card)
		_mission_cards[mission_id] = card
	if _join_card == null:
		_create_join_card()

	_mission_settings_spacer = Control.new()
	_mission_settings_spacer.name = "MissionSettingsSpacer"
	_mission_settings_spacer.custom_minimum_size = Vector2(0, 22)
	_home_vbox.add_child(_mission_settings_spacer)

	var settings_block := HBoxContainer.new()
	settings_block.name = "HomeSettingsBlock"
	settings_block.alignment = BoxContainer.ALIGNMENT_CENTER
	settings_block.add_theme_constant_override("separation", 22)
	_home_vbox.add_child(settings_block)

	var selector_vbox := VBoxContainer.new()
	selector_vbox.name = "SelectorRows"
	selector_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	selector_vbox.add_theme_constant_override("separation", 12)
	settings_block.add_child(selector_vbox)

	var theme_row := _create_home_selector_row("setting_theme")
	selector_vbox.add_child(theme_row)
	_theme_left = theme_row.get_meta("left") as Label
	_theme_button = theme_row.get_meta("button") as Button
	_theme_right = theme_row.get_meta("right") as Label
	_theme_button.pressed.connect(func(): _cycle_theme(1))
	_setup_cycling(_theme_button, _cycle_theme)
	_setup_arrow_visibility(_theme_button, _theme_left, _theme_right)

	var maze_size_row := _create_home_selector_row("setting_diff")
	selector_vbox.add_child(maze_size_row)
	_maze_size_left = maze_size_row.get_meta("left") as Label
	_maze_size_button = maze_size_row.get_meta("button") as Button
	_maze_size_right = maze_size_row.get_meta("right") as Label
	_maze_size_button.pressed.connect(func(): _cycle_maze_size(1))
	_setup_cycling(_maze_size_button, _cycle_maze_size)
	_setup_arrow_visibility(_maze_size_button, _maze_size_left, _maze_size_right)

	_theme_preview_container = Control.new()
	_theme_preview_container.name = "ThemePreviewContainer"
	settings_block.add_child(_theme_preview_container)

	_theme_preview = CharacterPreview.new()
	_theme_preview.name = "ThemePlayerPreview"
	_theme_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_theme_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_theme_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_theme_preview_container.add_child(_theme_preview)

	_build_secondary_overlay()
	_build_join_list()

func _create_mission_card(mission_id: String) -> Button:
	var card := ModeCardScene.instantiate() as Button
	card.custom_minimum_size = Vector2(300, 230)
	card.pivot_offset = Vector2(150, 115)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.call("configure_compact", 48, 28, 17)
	card.pressed.connect(_open_solo_setup.bind(mission_id))
	card.focus_entered.connect(_select_mission.bind(mission_id))
	return card

func _create_join_card() -> void:
	_join_card = ModeCardScene.instantiate() as Button
	_join_card.name = "JoinGameCard"
	_join_card.visible = false
	_join_card.custom_minimum_size = Vector2(300, 230)
	_join_card.pivot_offset = Vector2(150, 115)
	_join_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mission_row.add_child(_join_card)
	_join_card.call("configure_compact", 48, 28, 17)
	_join_card.call(
		"set_custom_palette",
		JOIN_GREEN.darkened(0.06),
		JOIN_GREEN.lightened(0.16),
		UIColors.BLUE,
		Color.WHITE,
		UIColors.YELLOW,
		Color.WHITE,
		Color(1, 1, 1, 0.86)
	)
	_join_card.call("setup", "!", tr("mp_join_game"), tr("mp_join_discovery_found"))
	_join_card.pressed.connect(func(): _show_join_list())
	_join_card.focus_entered.connect(_on_join_card_focus_entered)
	_join_card.focus_exited.connect(_on_join_card_focus_exited)

func _build_secondary_overlay() -> void:
	_secondary_overlay = Control.new()
	_secondary_overlay.name = "SecondaryActions"
	_secondary_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_secondary_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_secondary_overlay)

	_start_multiplayer_button = _create_corner_button(tr("home_start_multiplayer"), UIColors.BLUE)
	_start_multiplayer_button.pressed.connect(_open_host_setup)
	_secondary_overlay.add_child(_start_multiplayer_button)

	_secondary_row = HBoxContainer.new()
	_secondary_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_secondary_row.add_theme_constant_override("separation", 12)
	_secondary_overlay.add_child(_secondary_row)

	_settings_button = _create_tertiary_button(tr("settings"))
	_settings_button.pressed.connect(_on_settings_pressed)
	_secondary_row.add_child(_settings_button)

	_help_button = _create_tertiary_button(tr("help"))
	_help_button.pressed.connect(_on_help_pressed)
	_secondary_row.add_child(_help_button)

func _build_join_list() -> void:
	_join_vbox = VBoxContainer.new()
	_join_vbox.name = "JoinList"
	_join_vbox.visible = false
	_join_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_join_vbox.custom_minimum_size = Vector2(1180, 0)
	_join_vbox.add_theme_constant_override("separation", 18)
	center_container.add_child(_join_vbox)

	var title := Label.new()
	title.text = tr("home_join_multiplayer")
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", UIColors.YELLOW)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_join_vbox.add_child(title)

	_join_status_label = Label.new()
	_join_status_label.text = tr("mp_join_discovery_scanning")
	_join_status_label.add_theme_font_size_override("font_size", 27)
	_join_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_join_vbox.add_child(_join_status_label)

	_host_list_scroll = ScrollContainer.new()
	_host_list_scroll.custom_minimum_size = Vector2(1100, 520)
	_host_list_scroll.horizontal_scroll_mode = 0
	_host_list_scroll.vertical_scroll_mode = 1
	_join_vbox.add_child(_host_list_scroll)

	_host_list_vbox = VBoxContainer.new()
	_host_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_host_list_vbox.add_theme_constant_override("separation", 16)
	_host_list_scroll.add_child(_host_list_vbox)

	_join_back_button = _create_secondary_button(tr("mp_back"))
	_join_back_button.pressed.connect(_show_home)
	_join_vbox.add_child(_join_back_button)

func _create_secondary_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(230, 62)
	button.add_theme_font_size_override("font_size", 27)
	UIHelpers.apply_style_to_button(button, UIColors.YELLOW)
	return button

func _create_tertiary_button(text: String) -> Button:
	return _create_corner_button(text)

func _create_corner_button(text: String, color: Color = UIColors.YELLOW) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(260, 58)
	button.add_theme_font_size_override("font_size", 24)
	UIHelpers.apply_style_to_button(button, color)
	return button

func _create_home_selector_row(label_key: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size = Vector2(0, 68)

	var label := Label.new()
	label.text = tr(label_key)
	label.custom_minimum_size = Vector2(245, 0)
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", UIColors.TEXT_SUBTITLE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

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

	row.set_meta("left", left)
	row.set_meta("button", button)
	row.set_meta("right", right)
	return row

func _create_arrow_label() -> Label:
	var label := Label.new()
	label.custom_minimum_size = Vector2(36, 0)
	label.add_theme_color_override("font_color", UIColors.YELLOW)
	label.add_theme_font_size_override("font_size", 38)
	label.text = "<"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label

func _update_home() -> void:
	_update_theme_preview()
	_update_mission_cards()
	_update_maze_size_button()
	_update_join_button()
	_apply_responsive_layout()
	_configure_home_focus()

func _update_theme_preview() -> void:
	if _themes.is_empty():
		return
	if _theme_idx != _last_theme_idx:
		_last_theme_idx = _theme_idx
		_theme_preview_loader = ThemeLoader.get_cached(_themes[_theme_idx])

	if _theme_preview_loader != null:
		_theme_button.text = _theme_preview_loader.get_display_title(_themes[_theme_idx])
		if _theme_preview != null:
			_theme_preview.set_character(_theme_preview_loader.player_frames, _theme_preview_loader.player_fps)

func _update_mission_cards() -> void:
	for mission_id in _mission_order:
		var card := _mission_cards.get(mission_id, null) as Button
		if card == null:
			continue
		var data := MissionCatalog.mission_data(mission_id)
		card.call(
			"setup",
			String(data.get("icon", "?")),
			tr(String(data.get("title_key", ""))),
			tr(String(data.get("subtitle_key", "")))
		)
		card.call("set_selected", not _join_card_focused and _selected_mission == mission_id)

func _select_mission(mission_id: String) -> void:
	if _selected_mission == mission_id:
		return
	_selected_mission = mission_id
	Config.selected_mission_id = mission_id
	_update_mission_cards()
	_configure_home_focus()

func _on_join_card_focus_entered() -> void:
	_join_card_focused = true
	_update_mission_cards()

func _on_join_card_focus_exited() -> void:
	_join_card_focused = false
	_update_mission_cards()

func _cycle_theme(dir: int) -> void:
	if _themes.is_empty():
		return
	_theme_idx = (_theme_idx + dir + _themes.size()) % _themes.size()
	Config.theme_dir_name = _themes[_theme_idx]
	Config.selected_theme_dir = Config.theme_dir_name
	Config.save_settings()
	_update_theme_preview()

func _cycle_maze_size(dir: int) -> void:
	if Config.DIFF_KEYS.is_empty():
		return
	_maze_size_idx = (_maze_size_idx + dir + Config.DIFF_KEYS.size()) % Config.DIFF_KEYS.size()
	Config.difficulty = _maze_size_idx
	Config.save_settings()
	_update_maze_size_button()

func _update_maze_size_button() -> void:
	if _maze_size_button == null:
		return
	_maze_size_idx = clampi(_maze_size_idx, 0, max(0, Config.DIFF_KEYS.size() - 1))
	if _maze_size_idx < Config.DIFF_KEYS.size():
		_maze_size_button.text = tr(Config.DIFF_KEYS[_maze_size_idx])

func _open_solo_setup(mission_id: String) -> void:
	_select_mission(mission_id)
	Config.prepare_setup_session(_selected_mission, Config.theme_dir_name, false)
	NetworkManager.stop_discovery()
	get_tree().change_scene_to_file("res://scenes/mode_selection.tscn")

func _open_host_setup() -> void:
	Config.prepare_setup_session(_selected_mission, Config.theme_dir_name, true)
	NetworkManager.stop_discovery()
	get_tree().change_scene_to_file("res://scenes/multiplayer/host_setup.tscn")

func _on_settings_pressed() -> void:
	NetworkManager.stop_discovery()
	get_tree().change_scene_to_file("res://scenes/settings_menu.tscn")

func _on_help_pressed() -> void:
	NetworkManager.stop_discovery()
	get_tree().change_scene_to_file("res://scenes/help_menu.tscn")

func _on_discovery_updated(hosts: Array) -> void:
	_hosts = hosts.duplicate(true)
	_update_join_button()
	if _join_vbox != null and _join_vbox.visible:
		_rebuild_host_cards()

func _on_host_discovered(_info: Dictionary) -> void:
	pass

func _update_join_button() -> void:
	if _join_card == null:
		return
	var has_hosts := not _hosts.is_empty()
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	_join_card.visible = has_hosts
	_join_card.disabled = not has_hosts
	_join_card.mouse_filter = Control.MOUSE_FILTER_STOP if has_hosts else Control.MOUSE_FILTER_IGNORE
	_join_card.focus_mode = Control.FOCUS_ALL if has_hosts else Control.FOCUS_NONE
	_join_card.call("setup", "!", tr("mp_join_game"), tr("mp_join_discovery_found"))
	if not has_hosts:
		_join_card_focused = false
	_update_mission_cards()
	if not has_hosts and focus_owner == _join_card:
		var fallback := _mission_cards.get(MissionCatalog.MISSION_FIND_NEXT, _selected_mission_card()) as Button
		if fallback != null:
			fallback.call_deferred("grab_focus")
	_apply_responsive_layout()
	_configure_home_focus()

func _show_join_list(force: bool = false, status_override: String = "") -> void:
	if _hosts.is_empty() and not force:
		return
	_home_vbox.visible = false
	if _secondary_overlay != null:
		_secondary_overlay.visible = false
	_join_vbox.visible = true
	_rebuild_host_cards()
	if not status_override.is_empty():
		_join_status_label.text = status_override
	_configure_join_focus()
	if not _host_cards.is_empty():
		_host_cards[0].call_deferred("grab_focus")
	else:
		_join_back_button.call_deferred("grab_focus")

func _show_home() -> void:
	_join_vbox.visible = false
	if _secondary_overlay != null:
		_secondary_overlay.visible = true
	_home_vbox.visible = true
	_update_home()
	var mission_card := _selected_mission_card()
	if mission_card != null:
		mission_card.call_deferred("grab_focus")

func _rebuild_host_cards() -> void:
	if _host_list_vbox == null:
		return
	for child in _host_list_vbox.get_children():
		child.queue_free()
	_host_cards.clear()

	if _hosts.is_empty():
		_join_status_label.text = tr("mp_join_discovery_none")
		_apply_responsive_layout()
		_configure_join_focus()
		if _join_vbox != null and _join_vbox.visible:
			_join_back_button.call_deferred("grab_focus")
		return

	_join_status_label.text = tr("mp_join_discovery_found")
	for i in range(_hosts.size()):
		var host := _hosts[i] as Dictionary
		var card := _create_host_card(host, i)
		_host_list_vbox.add_child(card)
		_host_cards.append(card)
	_apply_responsive_layout()
	_configure_join_focus()

func _create_host_card(host: Dictionary, index: int) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(_join_card_width(), 136)
	button.text = ""
	button.focus_mode = Control.FOCUS_ALL
	UIHelpers.apply_style_to_button(button, UIColors.BLUE)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 12)
	button.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	margin.add_child(row)

	var icon := CharacterPreview.new()
	icon.custom_minimum_size = Vector2(104, 104)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var host_character_id := String(host.get("character_id", ""))
	var icon_data: Dictionary = CharacterCatalog.get_preview_data_by_id(host_character_id)
	var icon_frames: Array[Texture2D] = []
	for item in icon_data.get("frames", []):
		if item is Texture2D:
			icon_frames.append(item)
	if not icon_frames.is_empty():
		icon.set_character(icon_frames, float(icon_data.get("fps", 1.0)))
	row.add_child(icon)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 6)
	row.add_child(text_box)

	var host_name := String(host.get("host_name", "Host"))
	var host_ip := String(host.get("ip", ""))
	var theme_title := String(host.get("theme_title", host.get("theme_dir", "")))
	var player_count := int(host.get("player_count", 1))
	var max_players := int(host.get("max_players", 2))

	var title := Label.new()
	title.text = host_name
	title.add_theme_font_size_override("font_size", 34)
	text_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "%s | %d/%d | %s" % [host_ip, player_count, max_players, theme_title]
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.modulate = Color(1, 1, 1, 0.8)
	text_box.add_child(subtitle)

	var footer := Label.new()
	footer.text = "%s | %s | %s | %s" % [
		_host_mission_title(host),
		_host_pickup_title(host),
		_host_role_summary(host),
		CharacterCatalog.display_name_for_id(host_character_id),
	]
	footer.add_theme_font_size_override("font_size", 24)
	footer.modulate = Color(0.92, 0.75, 0.2, 1)
	text_box.add_child(footer)

	button.pressed.connect(func():
		_select_host_index(index)
	)
	button.focus_entered.connect(func():
		_selected_host_index = index
		if _host_list_scroll != null:
			_host_list_scroll.ensure_control_visible(button)
	)
	return button

func _select_host_index(index: int) -> void:
	if index < 0 or index >= _hosts.size():
		return
	_selected_host_index = index
	NetworkManager.set_pending_join_host((_hosts[index] as Dictionary).duplicate(true))
	NetworkManager.stop_discovery()
	get_tree().change_scene_to_file("res://scenes/multiplayer/join_flow.tscn")

func _host_mission_title(host: Dictionary) -> String:
	return String(host.get("mission_title", host.get("game_style_title", tr("mission_follow_trail"))))

func _host_pickup_title(host: Dictionary) -> String:
	var training := String(host.get("training_type", NetworkManager.TRAINING_WORDS))
	if training == NetworkManager.TRAINING_NONE:
		return tr("pickup_none")
	var title := String(host.get("training_type_title", ""))
	if not title.is_empty():
		return title
	return tr(MissionCatalog.pickup_title_key(MissionCatalog.pickup_for_training(training)))

func _host_role_summary(host: Dictionary) -> String:
	var mission_id := String(host.get("mission_id", MissionCatalog.MISSION_FOLLOW_TRAIL))
	var chaser_enabled := bool(host.get("chaser_enabled", false))
	return tr(String(host.get("role_summary_key", MissionCatalog.role_summary_key(mission_id, chaser_enabled))))

func _apply_dpad_layout() -> void:
	if center_container != null and Config != null:
		UIHelpers.apply_dpad_layout(center_container, Config.on_screen_controls)

func _on_controls_changed(_new_mode: int) -> void:
	_apply_dpad_layout()
	_apply_responsive_layout()
	_configure_home_focus()
	_configure_join_focus()

func _apply_responsive_layout() -> void:
	var available_width: float = _available_home_width()
	var viewport_height: float = get_viewport_rect().size.y
	var short_screen: bool = viewport_height < 820.0
	if _home_vbox != null:
		_home_vbox.custom_minimum_size.x = available_width
		_home_vbox.custom_minimum_size.y = viewport_height
		_home_vbox.add_theme_constant_override("separation", _home_spacing())
	if _join_vbox != null:
		_join_vbox.custom_minimum_size.x = minf(available_width, 1180.0)
	if _top_spacer != null:
		_top_spacer.custom_minimum_size.y = clampf(viewport_height * 0.0075, 3.0, 8.0)
	if _logo != null:
		var logo_width: float = clampf(available_width * (0.52 if short_screen else 0.58), 480.0, 930.0)
		var logo_height: float = clampf(logo_width * 0.214, 102.0, 198.0)
		_logo.custom_minimum_size = Vector2(logo_width, logo_height)
	if _logo_cards_spacer != null:
		_logo_cards_spacer.custom_minimum_size.y = 16.0 if short_screen else 24.0
	if _mission_row != null:
		var cards: Array[Button] = _primary_card_buttons()
		var count: int = cards.size()
		_mission_columns = _mission_column_count(count, available_width)
		_mission_row.columns = _mission_columns
		_mission_row.add_theme_constant_override("h_separation", _mission_gap())
		_mission_row.add_theme_constant_override("v_separation", 14 if short_screen else 18)
		if count > 0:
			var columns: int = mini(count, _mission_columns)
			var gaps: float = float(_mission_gap() * maxi(0, columns - 1))
			var card_width: float = floorf((available_width - gaps) / float(columns))
			var max_card_width: float = 350.0 if _join_card_visible() else 390.0
			var min_card_width: float = 138.0 if _join_card_visible() and available_width < 900.0 else 160.0
			card_width = clampf(card_width, min_card_width, max_card_width)
			var card_height: float = clampf(viewport_height * (0.355 if short_screen else 0.335), 260.0, 340.0)
			var icon_size: int = 46 if card_width < 220.0 else (52 if card_width < 270.0 else 58)
			var title_size: int = 24 if card_width < 220.0 else (28 if card_width < 270.0 else 31)
			var subtitle_size: int = 17 if card_width < 250.0 else 19
			for card in cards:
				card.custom_minimum_size = Vector2(card_width, card_height)
				card.pivot_offset = Vector2(card_width * 0.5, card_height * 0.5)
				card.call("configure_compact", icon_size, title_size, subtitle_size)
	if _mission_settings_spacer != null:
		_mission_settings_spacer.custom_minimum_size.y = 56.0 if short_screen else 74.0
	var selector_width: float = clampf(available_width * 0.32, 380.0, 500.0)
	var selector_height: float = 58.0 if short_screen else 66.0
	var selector_font_size: int = 28 if short_screen else 31

	if _theme_button != null:
		_theme_button.custom_minimum_size = Vector2(selector_width, selector_height)
		_theme_button.add_theme_font_size_override("font_size", selector_font_size)
		_maze_size_button.custom_minimum_size = Vector2(selector_width, selector_height)
		_maze_size_button.add_theme_font_size_override("font_size", selector_font_size)

	if _theme_preview_container != null:
		var preview_size: float = 94.0 if short_screen else 124.0
		_theme_preview_container.custom_minimum_size = Vector2(preview_size, preview_size)
		_theme_preview_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		if _theme_preview != null:
			_theme_preview.custom_minimum_size = Vector2(preview_size, preview_size)

	if _start_multiplayer_button != null:
		_start_multiplayer_button.custom_minimum_size = Vector2(selector_width, selector_height)
		_start_multiplayer_button.add_theme_font_size_override("font_size", selector_font_size)
		if _settings_button != null:
			_settings_button.custom_minimum_size = Vector2(selector_width, selector_height)
			_settings_button.add_theme_font_size_override("font_size", selector_font_size)
		if _help_button != null:
			_help_button.custom_minimum_size = Vector2(selector_width, selector_height)
			_help_button.add_theme_font_size_override("font_size", selector_font_size)
	if _secondary_row != null:
		_position_secondary_row()
	if _host_list_scroll != null:
		_host_list_scroll.custom_minimum_size.x = minf(available_width, 1100.0)
		for card in _host_cards:
			if card != null:
				card.custom_minimum_size.x = _join_card_width()

func _available_home_width() -> float:
	var viewport_size: Vector2 = get_viewport_rect().size
	var controls_mode: int = Config.ControlsMode.OFF
	if Config != null:
		controls_mode = Config.on_screen_controls
	var content_rect: Rect2 = UIHelpers.get_content_rect(viewport_size, controls_mode)
	return clampf(content_rect.size.x * 0.985, 760.0, 1640.0)

func _mission_gap() -> int:
	var width: float = _available_home_width()
	if width < 900.0:
		return 16 if _join_card_visible() else 24
	if width < 1200.0:
		return 34
	if _join_card_visible():
		return 38
	return 48

func _mission_column_count(card_count: int, available_width: float) -> int:
	if card_count <= 0:
		return 1
	if available_width >= 760.0:
		return card_count
	return mini(card_count, 2)

func _join_card_visible() -> bool:
	return _join_card != null and _join_card.visible

func _home_spacing() -> int:
	var height: float = get_viewport_rect().size.y
	if height < 650.0:
		return 8
	if height < 820.0:
		return 12
	return 20

func _position_secondary_row() -> void:
	if _secondary_row == null or _start_multiplayer_button == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var controls_mode: int = Config.on_screen_controls if Config != null else Config.ControlsMode.OFF
	var content_rect: Rect2 = UIHelpers.get_content_rect(viewport_size, controls_mode)
	var button_size: Vector2 = _start_multiplayer_button.custom_minimum_size
	var row_width: float = (_settings_button.custom_minimum_size.x + _help_button.custom_minimum_size.x + 12.0) if _settings_button != null and _help_button != null else 532.0
	var row_height: float = button_size.y
	var margin: float = 30.0

	_start_multiplayer_button.custom_minimum_size = button_size
	_start_multiplayer_button.size = button_size
	_start_multiplayer_button.anchor_left = 0.0
	_start_multiplayer_button.anchor_right = 0.0
	_start_multiplayer_button.anchor_top = 0.0
	_start_multiplayer_button.anchor_bottom = 0.0
	_start_multiplayer_button.position = Vector2(content_rect.position.x + margin, viewport_size.y - row_height - margin)

	_secondary_row.custom_minimum_size = Vector2(row_width, row_height)
	_secondary_row.size = Vector2(row_width, row_height)
	_secondary_row.anchor_left = 0.0
	_secondary_row.anchor_right = 0.0
	_secondary_row.anchor_top = 0.0
	_secondary_row.anchor_bottom = 0.0
	_secondary_row.position = Vector2(content_rect.end.x - row_width - margin, viewport_size.y - row_height - margin)

func _join_card_width() -> float:
	return minf(_available_home_width() - 60.0, 1040.0)

func _configure_home_focus() -> void:
	var cards: Array[Button] = _primary_card_buttons()
	_configure_grid_navigation(cards, _mission_columns, null, _theme_button)
	_configure_single_navigation(_theme_button, _selected_mission_card(), _maze_size_button)
	_configure_single_navigation(_maze_size_button, _theme_button, _settings_button)

	var bottom_buttons: Array[Button] = [_start_multiplayer_button, _settings_button, _help_button]
	_configure_row_navigation(bottom_buttons, _maze_size_button, null)

func _configure_join_focus() -> void:
	for i in range(_host_cards.size()):
		var card := _host_cards[i] as Button
		var top: Control = _join_back_button
		var bottom: Control = _join_back_button
		if i > 0:
			top = _host_cards[i - 1] as Button
		if i < _host_cards.size() - 1:
			bottom = _host_cards[i + 1] as Button
		_configure_single_navigation(card, top, bottom)
	var back_top: Control = _join_back_button
	var back_bottom: Control = _join_back_button
	if not _host_cards.is_empty():
		back_top = _host_cards[_host_cards.size() - 1] as Button
		back_bottom = _host_cards[0] as Button
	_configure_single_navigation(_join_back_button, back_top, back_bottom)

func _configure_grid_navigation(buttons: Array, columns: int, top: Control, bottom: Control) -> void:
	var grid: Array[Button] = _valid_buttons(buttons)
	if grid.is_empty():
		return
	var cols: int = maxi(1, mini(columns, grid.size()))
	for i in range(grid.size()):
		var button := grid[i] as Button
		var row_start: int = int(floor(float(i) / float(cols))) * cols
		var row_end: int = mini(row_start + cols, grid.size())
		var row_size: int = row_end - row_start
		var row_index: int = i - row_start
		var left := grid[row_start + ((row_index - 1 + row_size) % row_size)] as Button
		var right := grid[row_start + ((row_index + 1) % row_size)] as Button
		button.focus_neighbor_left = button.get_path_to(left)
		button.focus_neighbor_right = button.get_path_to(right)
		var top_target: Control = top
		var previous_row_start: int = row_start - cols
		if previous_row_start >= 0:
			var previous_row_end: int = row_start
			top_target = grid[mini(previous_row_start + row_index, previous_row_end - 1)] as Button
		var bottom_target: Control = bottom
		var next_row_start: int = row_start + cols
		if next_row_start < grid.size():
			var next_row_end: int = mini(next_row_start + cols, grid.size())
			bottom_target = grid[mini(next_row_start + row_index, next_row_end - 1)] as Button
		if top_target != null:
			button.focus_neighbor_top = button.get_path_to(top_target)
		if bottom_target != null:
			button.focus_neighbor_bottom = button.get_path_to(bottom_target)

func _configure_row_navigation(buttons: Array, top: Control, bottom: Control) -> void:
	var row: Array[Button] = _valid_buttons(buttons)
	if row.is_empty():
		return
	for i in range(row.size()):
		var button := row[i] as Button
		var left := row[(i - 1 + row.size()) % row.size()] as Button
		var right := row[(i + 1) % row.size()] as Button
		button.focus_neighbor_left = button.get_path_to(left)
		button.focus_neighbor_right = button.get_path_to(right)
		if top != null:
			button.focus_neighbor_top = button.get_path_to(top)
		if bottom != null:
			button.focus_neighbor_bottom = button.get_path_to(bottom)

func _configure_single_navigation(button: Control, top: Control, bottom: Control) -> void:
	if button == null:
		return
	button.focus_neighbor_left = button.get_path_to(button)
	button.focus_neighbor_right = button.get_path_to(button)
	if top != null:
		button.focus_neighbor_top = button.get_path_to(top)
	if bottom != null:
		button.focus_neighbor_bottom = button.get_path_to(bottom)

func _valid_buttons(items: Array) -> Array[Button]:
	var result: Array[Button] = []
	for item in items:
		if item is Button and is_instance_valid(item):
			var button := item as Button
			if button.visible and not button.disabled and button.focus_mode != Control.FOCUS_NONE:
				result.append(button)
	return result

func _mission_card_buttons() -> Array[Button]:
	var cards: Array[Button] = []
	for mission_id in _mission_order:
		var card := _mission_cards.get(mission_id, null) as Button
		if card != null:
			cards.append(card)
	return cards

func _primary_card_buttons() -> Array[Button]:
	var cards: Array[Button] = []
	for i in range(_mission_order.size()):
		if i == 2 and _join_card_visible():
			cards.append(_join_card)
		var mission_id := _mission_order[i]
		var card := _mission_cards.get(mission_id, null) as Button
		if card != null:
			cards.append(card)
	return cards

func _selected_mission_card() -> Button:
	return _mission_cards.get(_selected_mission, _mission_cards.get(MissionCatalog.DEFAULT_MISSION, null)) as Button

func _setup_arrow_visibility(button: Button, left: Label, right: Label) -> void:
	left.modulate.a = 0.0
	right.modulate.a = 0.0
	button.focus_entered.connect(func():
		left.modulate.a = 1.0
		right.modulate.a = 1.0
	)
	button.focus_exited.connect(func():
		left.modulate.a = 0.0
		right.modulate.a = 0.0
	)

func _setup_cycling(button: Button, cycle_func: Callable) -> void:
	button.gui_input.connect(func(event: InputEvent):
		if event.is_pressed():
			if event.is_action("ui_left"):
				cycle_func.call(-1)
				get_viewport().set_input_as_handled()
			elif event.is_action("ui_right"):
				cycle_func.call(1)
				get_viewport().set_input_as_handled()
	)

func _unhandled_input(event: InputEvent) -> void:
	if _input_locked:
		return
	if not event.is_action_pressed("ui_cancel"):
		return

	if _quit_dialog and _quit_dialog.visible:
		_hide_quit_dialog()
	elif _join_vbox != null and _join_vbox.visible:
		_show_home()
	else:
		_show_quit_dialog()
	get_viewport().set_input_as_handled()

func _show_quit_dialog() -> void:
	if _quit_dialog == null:
		_create_quit_dialog()
	_quit_dialog.visible = true
	if _quit_no_button:
		_quit_no_button.grab_focus()

func _hide_quit_dialog() -> void:
	if _quit_dialog != null:
		_quit_dialog.visible = false
	var mission_card := _selected_mission_card()
	if mission_card != null:
		mission_card.grab_focus()

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
