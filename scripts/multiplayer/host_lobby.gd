extends Control

@onready var center_container: CenterContainer = $CenterContainer
@onready var title_label: Label = %TitleLabel
@onready var config_label: Label = %ConfigLabel
@onready var status_label: Label = %StatusLabel
@onready var network_debug_label: Label = %NetworkDebugLabel
@onready var players_list: ItemList = %PlayersList
@onready var start_now_button: Button = %StartNowButton
@onready var buttons_row: HBoxContainer = $CenterContainer/MainVBox/Buttons

var _collector_button: Button = null
var _random_collector_button: Button = null
var _rotate_roles_button: Button = null
var _selected_collector_idx: int = 0
var _last_lobby_state: Dictionary = {}

func _ready() -> void:
	Input.warp_mouse(Vector2(-1, -1))
	_localize_ui()
	if network_debug_label != null:
		network_debug_label.visible = false

	_build_role_controls()
	UIHelpers.apply_style_to_button(start_now_button, UIColors.BLUE)

	start_now_button.pressed.connect(_on_start_now_pressed)

	NetworkManager.lobby_updated.connect(_on_lobby_updated)
	NetworkManager.game_started.connect(_on_game_started)
	NetworkManager.peer_disconnected.connect(_on_peer_disconnected)
	NetworkManager.debug_status_changed.connect(_on_network_debug_changed)
	if Config != null and not Config.on_screen_controls_changed.is_connected(_on_controls_changed):
		Config.on_screen_controls_changed.connect(_on_controls_changed)

	_apply_dpad_layout()
	_on_lobby_updated({
		"config": NetworkManager.host_config,
		"players": NetworkManager.players,
	})
	start_now_button.call_deferred("grab_focus")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		var viewport: Viewport = get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
		NetworkManager.leave_session()
		get_tree().change_scene_to_file("res://scenes/multiplayer/multiplayer_menu.tscn")

func _localize_ui() -> void:
	title_label.text = tr("mp_host_lobby_title")
	status_label.text = tr("mp_host_lobby_waiting")
	start_now_button.text = tr("mp_host_start_now")

func _build_role_controls() -> void:
	if buttons_row == null:
		return

	_collector_button = Button.new()
	_collector_button.custom_minimum_size = Vector2(330, 96)
	_collector_button.add_theme_font_size_override("font_size", 28)
	_collector_button.pressed.connect(func(): _cycle_collector(1))
	UIHelpers.apply_style_to_button(_collector_button, UIColors.YELLOW)
	buttons_row.add_child(_collector_button)
	buttons_row.move_child(_collector_button, 0)

	_random_collector_button = Button.new()
	_random_collector_button.custom_minimum_size = Vector2(260, 96)
	_random_collector_button.add_theme_font_size_override("font_size", 28)
	_random_collector_button.text = tr("mp_role_random_collector")
	_random_collector_button.pressed.connect(Callable(NetworkManager, "randomize_collector"))
	UIHelpers.apply_style_to_button(_random_collector_button, UIColors.YELLOW)
	buttons_row.add_child(_random_collector_button)
	buttons_row.move_child(_random_collector_button, 1)

	_rotate_roles_button = Button.new()
	_rotate_roles_button.custom_minimum_size = Vector2(280, 96)
	_rotate_roles_button.add_theme_font_size_override("font_size", 28)
	_rotate_roles_button.pressed.connect(_toggle_rotate_roles)
	UIHelpers.apply_style_to_button(_rotate_roles_button, UIColors.YELLOW)
	buttons_row.add_child(_rotate_roles_button)
	buttons_row.move_child(_rotate_roles_button, 2)

func _apply_dpad_layout() -> void:
	if center_container != null and Config != null:
		UIHelpers.apply_dpad_layout(center_container, Config.on_screen_controls)

func _on_controls_changed(_new_mode: int) -> void:
	_apply_dpad_layout()

func _on_lobby_updated(state: Dictionary) -> void:
	_last_lobby_state = state.duplicate(true)
	var cfg: Dictionary = state.get("config", {}) as Dictionary
	var player_map: Dictionary = state.get("players", {}) as Dictionary
	var max_players: int = int(cfg.get("max_players", 2))

	config_label.text = "%s | %s | %s: %s | %s: %s | %s: %d" % [
		String(cfg.get("game_style_title", tr("mp_style_path"))),
		String(cfg.get("training_type_title", tr("mode_words"))),
		tr("mp_host_difficulty"),
		tr(String(cfg.get("difficulty_key", "diff_easy"))),
		tr("mp_host_theme"),
		String(cfg.get("theme_title", "")),
		tr("mp_host_max_players"),
		max_players,
	]

	players_list.clear()
	for key in player_map.keys():
		var peer_id: int = int(key)
		var info: Dictionary = player_map[key] as Dictionary
		var char_id: String = String(info.get("character_id", ""))
		var is_host: bool = bool(info.get("is_host", false))
		var role: String = tr("mp_host_player")
		if is_host:
			role = tr("mp_host_player_host")
		var char_name: String = CharacterCatalog.display_name_for_id(char_id)
		if _is_roleless_next_symbol_config(cfg):
			players_list.add_item("%s %d | %s" % [role, peer_id, char_name])
		else:
			var assigned_role: String = String(info.get("role", NetworkManager.ROLE_COLLECTOR))
			players_list.add_item("%s %d | %s | %s" % [role, peer_id, char_name, _role_title(assigned_role)])

	status_label.text = "%s %d/%d" % [tr("mp_host_lobby_players"), player_map.size(), max_players]
	_update_role_controls(cfg, player_map)

func _update_role_controls(cfg: Dictionary, player_map: Dictionary) -> void:
	var chaser_enabled := bool(cfg.get("chaser_enabled", false)) and not _is_roleless_or_race_config(cfg)
	if _collector_button != null:
		_collector_button.visible = chaser_enabled
	if _random_collector_button != null:
		_random_collector_button.visible = chaser_enabled
	if _rotate_roles_button != null:
		_rotate_roles_button.visible = chaser_enabled
		_rotate_roles_button.text = "%s: %s" % [
			tr("mp_role_rotate_roles"),
			tr("on") if bool(cfg.get("rotate_roles_after_round", false)) else tr("off"),
		]
	if not chaser_enabled or _collector_button == null:
		return

	var peer_ids := _ordered_peer_ids(player_map)
	if peer_ids.is_empty():
		_collector_button.text = tr("mp_role_collector")
		return

	var collector_peer_id := int(cfg.get("collector_peer_id", peer_ids[0]))
	var collector_idx := peer_ids.find(collector_peer_id)
	if collector_idx < 0:
		collector_idx = 0
	_selected_collector_idx = collector_idx
	_collector_button.text = "%s: %s" % [
		tr("mp_role_collector"),
		_player_label(player_map, peer_ids[collector_idx]),
	]

func _cycle_collector(dir: int) -> void:
	var player_map: Dictionary = _last_lobby_state.get("players", {}) as Dictionary
	var peer_ids := _ordered_peer_ids(player_map)
	if peer_ids.is_empty():
		return
	_selected_collector_idx = (_selected_collector_idx + dir + peer_ids.size()) % peer_ids.size()
	NetworkManager.set_collector_peer_id(peer_ids[_selected_collector_idx])

func _toggle_rotate_roles() -> void:
	var cfg: Dictionary = _last_lobby_state.get("config", {}) as Dictionary
	NetworkManager.set_rotate_roles_after_round(not bool(cfg.get("rotate_roles_after_round", false)))

func _ordered_peer_ids(player_map: Dictionary) -> Array[int]:
	var peer_ids: Array[int] = []
	for key in player_map.keys():
		peer_ids.append(int(key))
	peer_ids.sort()
	if peer_ids.has(NetworkManager.HOST_PEER_ID):
		peer_ids.erase(NetworkManager.HOST_PEER_ID)
		peer_ids.push_front(NetworkManager.HOST_PEER_ID)
	return peer_ids

func _player_label(player_map: Dictionary, peer_id: int) -> String:
	if not player_map.has(peer_id):
		return str(peer_id)
	var info := player_map[peer_id] as Dictionary
	return "%d %s" % [peer_id, CharacterCatalog.display_name_for_id(String(info.get("character_id", "")))]

func _role_title(role: String) -> String:
	match role:
		NetworkManager.ROLE_CHASER:
			return tr("mp_role_chaser")
		NetworkManager.ROLE_RACER:
			return tr("mp_role_racer")
		_:
			return tr("mp_role_collector")

func _is_roleless_next_symbol_config(cfg: Dictionary) -> bool:
	return String(cfg.get("game_style", NetworkManager.STYLE_PATH)) == NetworkManager.STYLE_NEXT_SYMBOL and not bool(cfg.get("chaser_enabled", false))

func _is_roleless_or_race_config(cfg: Dictionary) -> bool:
	var style := String(cfg.get("game_style", NetworkManager.STYLE_PATH))
	return style == NetworkManager.STYLE_RACE or (style == NetworkManager.STYLE_NEXT_SYMBOL and not bool(cfg.get("chaser_enabled", false)))

func _on_peer_disconnected(_peer_id: int) -> void:
	_on_lobby_updated({
		"config": NetworkManager.host_config,
		"players": NetworkManager.players,
	})

func _on_start_now_pressed() -> void:
	NetworkManager.start_now()

func _on_game_started(_session: Dictionary) -> void:
	get_tree().change_scene_to_file("res://scenes/multiplayer/multiplayer_game.tscn")

func _on_network_debug_changed(scope: String, message: String) -> void:
	if network_debug_label == null:
		return
	network_debug_label.text = "Network [%s]: %s" % [scope, message]
