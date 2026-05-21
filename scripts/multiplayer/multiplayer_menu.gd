extends Control

const MissionCatalog := preload("res://scripts/mission_catalog.gd")
const HostCardBuilder := preload("res://scripts/ui/host_card_builder.gd")

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
	if NetworkManager.discovery_updated.is_connected(_on_discovery_updated):
		NetworkManager.discovery_updated.disconnect(_on_discovery_updated)
	if NetworkManager.host_discovered.is_connected(_on_host_discovered):
		NetworkManager.host_discovered.disconnect(_on_host_discovered)
	if Config != null and Config.on_screen_controls_changed.is_connected(_on_controls_changed):
		Config.on_screen_controls_changed.disconnect(_on_controls_changed)

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
	join_games_title.text = tr("mp_join_games")
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
	Config.prepare_setup_session(Config.selected_mission_id, Config.theme_dir_name, true)
	NetworkManager.stop_discovery()
	get_tree().change_scene_to_file(Scenes.HOST_SETUP)

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
	var button: Button = HostCardBuilder.create_card(host, index, true)
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
	get_tree().change_scene_to_file(Scenes.JOIN_FLOW)

func _go_back() -> void:
	NetworkManager.stop_discovery()
	get_tree().change_scene_to_file(Scenes.HOME)

func _host_mission_title(host: Dictionary) -> String:
	return HostCardBuilder.get_host_mission_title(host)

func _host_pickup_title(host: Dictionary) -> String:
	return HostCardBuilder.get_host_pickup_title(host)

func _host_role_summary(host: Dictionary) -> String:
	return HostCardBuilder.get_host_role_summary(host)
