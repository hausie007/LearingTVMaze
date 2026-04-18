extends Control

@onready var main_vbox: VBoxContainer = %MainVBox
@onready var center_container: CenterContainer = %CenterContainer
@onready var title_label: Label = %TitleLabel
@onready var host_button: Button = %HostButton
@onready var join_games_title: Label = %JoinGamesTitle
@onready var join_games_status: Label = %JoinGamesStatus
@onready var host_list_scroll: ScrollContainer = %HostListScroll
@onready var host_list_vbox: VBoxContainer = %HostListVBox

var _hosts: Array = []
var _host_cards: Array[Button] = []
var _selected_host_index: int = -1

func _ready() -> void:
	Input.warp_mouse(Vector2(-1, -1))
	_localize_ui()

	UIHelpers.apply_style_to_button(host_button, UIColors.BLUE)
	host_button.pressed.connect(_on_host_pressed)

	NetworkManager.discovery_updated.connect(_on_discovery_updated)
	NetworkManager.host_discovered.connect(_on_host_discovered)
	if Config != null and not Config.on_screen_controls_changed.is_connected(_on_controls_changed):
		Config.on_screen_controls_changed.connect(_on_controls_changed)

	if host_list_scroll != null:
		host_list_scroll.vertical_scroll_mode = 1
		host_list_scroll.horizontal_scroll_mode = 0

	_apply_layout()

	var err: int = NetworkManager.start_discovery()
	if err != OK:
		join_games_status.text = "%s: %d" % [tr("mp_join_discovery_error"), err]
	else:
		join_games_status.text = tr("mp_join_discovery_scanning")

	_rebuild_host_cards()
	host_button.call_deferred("grab_focus")

func _exit_tree() -> void:
	NetworkManager.stop_discovery()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return

	var viewport: Viewport = get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()
	_go_back()

func _localize_ui() -> void:
	title_label.text = tr("mp_multiplayer_title")
	host_button.text = tr("mp_host_new_game")
	join_games_title.text = "Join games"
	join_games_status.text = tr("mp_join_discovery_scanning")

func _apply_layout() -> void:
	if main_vbox == null:
		return
	if Config == null:
		return
	if center_container != null:
		UIHelpers.apply_dpad_layout(center_container, Config.on_screen_controls)

func _on_controls_changed(_new_mode: int) -> void:
	_apply_layout()

func _on_host_pressed() -> void:
	NetworkManager.stop_discovery()
	get_tree().change_scene_to_file("res://scenes/multiplayer/host_setup.tscn")

func _on_discovery_updated(hosts: Array) -> void:
	_hosts = hosts.duplicate(true)
	_rebuild_host_cards()

	if _hosts.is_empty():
		join_games_status.text = tr("mp_join_discovery_none")
	else:
		join_games_status.text = tr("mp_join_discovery_found")
		if _selected_host_index >= 0 and _selected_host_index < _host_cards.size():
			_focus_host_card(_selected_host_index)
		else:
			_focus_first_host_card()

func _on_host_discovered(_info: Dictionary) -> void:
	# Full refresh comes through discovery_updated.
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
	var style_title: String = String(host.get("game_style_title", ""))
	var training_title: String = String(host.get("training_type_title", ""))
	var chaser_text: String = tr("mp_roles_chaser_on") if bool(host.get("chaser_enabled", false)) else tr("mp_roles_chaser_off")
	var player_count: int = int(host.get("player_count", 1))
	var max_players: int = int(host.get("max_players", 2))

	var title: Label = Label.new()
	title.text = host_name
	title.add_theme_font_size_override("font_size", 34)
	text_box.add_child(title)

	var subtitle: Label = Label.new()
	subtitle.text = "%s | %d/%d | %s" % [host_ip, player_count, max_players, theme_title]
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.modulate = Color(1, 1, 1, 0.8)
	text_box.add_child(subtitle)

	var footer: Label = Label.new()
	footer.text = "%s | %s | %s | %s" % [
		style_title,
		training_title,
		chaser_text,
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
		if host_list_scroll != null:
			host_list_scroll.ensure_control_visible(button)
	)
	return button

func _focus_first_host_card() -> void:
	if _host_cards.is_empty():
		join_games_status.text = tr("mp_join_discovery_none")
		return

	_host_cards[0].call_deferred("grab_focus")

func _focus_host_card(index: int) -> void:
	if index < 0 or index >= _host_cards.size():
		return
	_host_cards[index].call_deferred("grab_focus")

func _select_host_index(index: int) -> void:
	if index < 0 or index >= _hosts.size():
		return

	_selected_host_index = index
	NetworkManager.set_pending_join_host((_hosts[index] as Dictionary).duplicate(true))
	NetworkManager.stop_discovery()
	get_tree().change_scene_to_file("res://scenes/multiplayer/join_flow.tscn")

func _go_back() -> void:
	NetworkManager.stop_discovery()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
