extends Control

const MissionCatalog := preload("res://scripts/mission_catalog.gd")
const ModeCardScene := preload("res://scenes/ui/mode_card.tscn")

@onready var center_container: CenterContainer = $CenterContainer
@onready var title_label: Label = %TitleLabel
@onready var cards_row: HBoxContainer = %CardsRow
@onready var settings_row: HBoxContainer = %SettingsRow
@onready var players_row: HBoxContainer = %PlayersRow
@onready var status_label: Label = %StatusLabel
@onready var network_debug_label: Label = %NetworkDebugLabel
@onready var start_now_button: Button = %StartNowButton

var _last_lobby_state: Dictionary = {}

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
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _localize_ui() -> void:
	title_label.text = "Multiplayer Lobby" # As requested by user
	start_now_button.text = "Start Game" # As requested by user

func _apply_dpad_layout() -> void:
	if center_container != null and Config != null:
		UIHelpers.apply_dpad_layout(center_container, Config.on_screen_controls)

func _on_controls_changed(_new_mode: int) -> void:
	_apply_dpad_layout()

func _on_lobby_updated(state: Dictionary) -> void:
	_last_lobby_state = state.duplicate(true)
	var cfg: Dictionary = state.get("config", {}) as Dictionary
	var player_map: Dictionary = state.get("players", {}) as Dictionary
	
	# Make sure host is collector when chaser is enabled, avoid infinite recursion
	if multiplayer.is_server():
		if bool(cfg.get("rotate_roles_after_round", true)) != false:
			NetworkManager.set_rotate_roles_after_round(false)
		var chaser_on := bool(cfg.get("chaser_enabled", false))
		if chaser_on and int(cfg.get("collector_peer_id", -1)) != NetworkManager.HOST_PEER_ID:
			NetworkManager.set_collector_peer_id(NetworkManager.HOST_PEER_ID)
	
	_build_cards(cfg)
	_build_settings(cfg, player_map)
	_build_players(player_map)

func _build_cards(cfg: Dictionary) -> void:
	for c in cards_row.get_children():
		c.queue_free()
	
	var mission_id := String(cfg.get("mission_id", MissionCatalog.MISSION_FOLLOW_TRAIL))
	var md := MissionCatalog.mission_data(mission_id)
	
	var mode_card = ModeCardScene.instantiate() as Button
	mode_card.custom_minimum_size = Vector2(300, 230)
	mode_card.call("configure_compact", 48, 30, 22)
	mode_card.call("setup", String(md.get("icon", "?")), tr(String(md.get("title_key", ""))), tr(String(md.get("subtitle_key", ""))))
	mode_card.focus_mode = Control.FOCUS_NONE
	cards_row.add_child(mode_card)
	
	var training := String(cfg.get("training_type", NetworkManager.TRAINING_WORDS))
	var pickup_title := String(cfg.get("training_type_title", ""))
	if training == NetworkManager.TRAINING_NONE:
		pickup_title = tr("pickup_none")
	elif pickup_title.is_empty():
		pickup_title = tr(MissionCatalog.pickup_title_key(MissionCatalog.pickup_for_training(training)))
	
	var pickup_icon := "A"
	if training == NetworkManager.TRAINING_NUMBERS:
		pickup_icon = "1"
	elif training == NetworkManager.TRAINING_NONE:
		pickup_icon = "?"
		
	var chaser_enabled := bool(cfg.get("chaser_enabled", false))
	var role_summary := tr(String(cfg.get("role_summary_key", MissionCatalog.role_summary_key(mission_id, chaser_enabled))))
	
	var training_card = ModeCardScene.instantiate() as Button
	training_card.custom_minimum_size = Vector2(300, 230)
	training_card.call("configure_compact", 48, 30, 22)
	training_card.call("setup", pickup_icon, pickup_title, role_summary)
	training_card.focus_mode = Control.FOCUS_NONE
	cards_row.add_child(training_card)

func _build_settings(cfg: Dictionary, player_map: Dictionary) -> void:
	for c in settings_row.get_children():
		c.queue_free()
		
	var diff_val := tr(String(cfg.get("difficulty_key", "diff_easy")))
	var theme_val := String(cfg.get("theme_title", ""))
	var max_players := int(cfg.get("max_players", 2))
	
	var label := Label.new()
	label.text = "%s: %s    |    %s: %s" % [
		tr("mp_host_difficulty"), diff_val, 
		tr("mp_host_theme"), theme_val
	]
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_row.add_child(label)
	
	status_label.text = "%s %d/%d" % [tr("mp_host_lobby_players"), player_map.size(), max_players]

func _build_players(player_map: Dictionary) -> void:
	for c in players_row.get_children():
		c.queue_free()
		
	var peer_ids := _ordered_peer_ids(player_map)
	for peer_id in peer_ids:
		var info := player_map[peer_id] as Dictionary
		var char_id := String(info.get("character_id", ""))
		
		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 10)
		
		var preview := CharacterPreview.new()
		preview.custom_minimum_size = Vector2(100, 100)
		preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_apply_character_preview(char_id, preview)
		vbox.add_child(preview)
		
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 24)
		
		if bool(info.get("is_host", false)):
			label.text = "You"
			label.add_theme_color_override("font_color", UIColors.YELLOW)
		else:
			label.text = CharacterCatalog.display_name_for_id(char_id)
		vbox.add_child(label)
		
		players_row.add_child(vbox)

func _ordered_peer_ids(player_map: Dictionary) -> Array[int]:
	var peer_ids: Array[int] = []
	for key in player_map.keys():
		peer_ids.append(int(key))
	peer_ids.sort()
	if peer_ids.has(NetworkManager.HOST_PEER_ID):
		peer_ids.erase(NetworkManager.HOST_PEER_ID)
		peer_ids.push_front(NetworkManager.HOST_PEER_ID)
	return peer_ids

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
