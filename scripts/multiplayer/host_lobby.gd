extends Control

@onready var center_container: CenterContainer = $CenterContainer
@onready var title_label: Label = %TitleLabel
@onready var config_label: Label = %ConfigLabel
@onready var status_label: Label = %StatusLabel
@onready var network_debug_label: Label = %NetworkDebugLabel
@onready var players_list: ItemList = %PlayersList
@onready var start_now_button: Button = %StartNowButton

func _ready() -> void:
	Input.warp_mouse(Vector2(-1, -1))
	_localize_ui()
	if network_debug_label != null:
		network_debug_label.visible = false

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

func _apply_dpad_layout() -> void:
	if center_container != null and Config != null:
		UIHelpers.apply_dpad_layout(center_container, Config.on_screen_controls)

func _on_controls_changed(_new_mode: int) -> void:
	_apply_dpad_layout()

func _on_lobby_updated(state: Dictionary) -> void:
	var cfg: Dictionary = state.get("config", {}) as Dictionary
	var player_map: Dictionary = state.get("players", {}) as Dictionary
	var max_players: int = int(cfg.get("max_players", 2))

	config_label.text = "%s: %s | %s: %s | %s: %d" % [
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
		players_list.add_item("%s %d | %s" % [role, peer_id, char_name])

	status_label.text = "%s %d/%d" % [tr("mp_host_lobby_players"), player_map.size(), max_players]

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
