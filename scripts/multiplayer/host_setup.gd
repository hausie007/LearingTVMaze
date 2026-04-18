extends Control

@onready var center_container: CenterContainer = $CenterContainer
@onready var title_label: Label = %TitleLabel
@onready var difficulty_label: Label = %DifficultyLabel
@onready var difficulty_button: Button = %DifficultyButton
@onready var difficulty_left_arrow: Label = %DifficultyLeftArrow
@onready var difficulty_right_arrow: Label = %DifficultyRightArrow

@onready var theme_label: Label = %ThemeLabel
@onready var theme_button: Button = %ThemeButton
@onready var theme_left_arrow: Label = %ThemeLeftArrow
@onready var theme_right_arrow: Label = %ThemeRightArrow
@onready var theme_preview: CharacterPreview = %ThemePlayerAnchor

@onready var max_players_label: Label = %MaxPlayersLabel
@onready var max_players_button: Button = %MaxPlayersButton
@onready var max_players_left_arrow: Label = %MaxPlayersLeftArrow
@onready var max_players_right_arrow: Label = %MaxPlayersRightArrow

@onready var character_label: Label = %CharacterLabel
@onready var character_button: Button = %CharacterButton
@onready var character_left_arrow: Label = %CharacterLeftArrow
@onready var character_right_arrow: Label = %CharacterRightArrow
@onready var character_preview: CharacterPreview = %CharacterPlayerAnchor

@onready var status_label: Label = %StatusLabel
@onready var network_debug_label: Label = %NetworkDebugLabel
@onready var start_button: Button = %StartButton

var _theme_dirs: Array[String] = []
var _character_catalog: Array[Dictionary] = []
var _selected_difficulty: int = 0
var _selected_theme_idx: int = 0
var _selected_max_players_idx: int = 0
var _selected_character_idx: int = 0
var _theme_preview_loader: ThemeLoader = null
var _last_theme_idx: int = -1

func _ready() -> void:
	Input.warp_mouse(Vector2(-1, -1))
	_localize_ui()
	if network_debug_label != null:
		network_debug_label.visible = false

	_populate_difficulty()
	_populate_themes()
	_populate_max_players()
	_populate_characters()

	_setup_cycling_button(difficulty_button, func(dir): _cycle_difficulty(dir))
	_setup_cycling_button(theme_button, func(dir): _cycle_theme(dir))
	_setup_cycling_button(max_players_button, func(dir): _cycle_max_players(dir))
	_setup_cycling_button(character_button, func(dir): _cycle_character(dir))

	start_button.pressed.connect(_on_start_pressed)

	UIHelpers.apply_style_to_button(start_button, UIColors.BLUE)

	NetworkManager.debug_status_changed.connect(_on_network_debug_changed)
	if Config != null and not Config.on_screen_controls_changed.is_connected(_on_controls_changed):
		Config.on_screen_controls_changed.connect(_on_controls_changed)

	_apply_dpad_layout()
	_update_labels()
	difficulty_button.call_deferred("grab_focus")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		var viewport: Viewport = get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
		_go_back()

func _localize_ui() -> void:
	title_label.text = tr("mp_host_setup_title")
	difficulty_label.text = tr("mp_host_difficulty")
	theme_label.text = tr("mp_host_theme")
	max_players_label.text = tr("mp_host_max_players")
	character_label.text = tr("mp_host_character")
	start_button.text = tr("mp_host_start_game")
	status_label.text = ""

func _apply_dpad_layout() -> void:
	if center_container != null and Config != null:
		UIHelpers.apply_dpad_layout(center_container, Config.on_screen_controls)

func _on_controls_changed(_new_mode: int) -> void:
	_apply_dpad_layout()

func _setup_cycling_button(btn: Button, cycle_func: Callable) -> void:
	if btn == null:
		return

	var base_name: String = btn.name.replace("Button", "")
	var left_arrow: Label = get_node_or_null("%%%sLeftArrow" % base_name)
	var right_arrow: Label = get_node_or_null("%%%sRightArrow" % base_name)

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

	UIHelpers.apply_style_to_button(btn, UIColors.YELLOW)
	if left_arrow:
		left_arrow.add_theme_color_override("font_color", UIColors.YELLOW)
	if right_arrow:
		right_arrow.add_theme_color_override("font_color", UIColors.YELLOW)

func _populate_difficulty() -> void:
	_selected_difficulty = clampi(Config.difficulty, 0, max(0, Config.DIFF_KEYS.size() - 1))

func _populate_themes() -> void:
	_theme_dirs = ThemeLoader.get_available_themes()
	_selected_theme_idx = _theme_dirs.find(Config.theme_dir_name)
	if _selected_theme_idx < 0:
		_selected_theme_idx = 0

func _populate_max_players() -> void:
	_selected_max_players_idx = 0

func _populate_characters() -> void:
	_character_catalog = CharacterCatalog.build_catalog()
	_selected_character_idx = 0

func _cycle_difficulty(dir: int) -> void:
	if Config.DIFF_KEYS.is_empty():
		return
	_selected_difficulty = (_selected_difficulty + dir + Config.DIFF_KEYS.size()) % Config.DIFF_KEYS.size()
	_update_labels()

func _cycle_theme(dir: int) -> void:
	if _theme_dirs.is_empty():
		return
	_selected_theme_idx = (_selected_theme_idx + dir + _theme_dirs.size()) % _theme_dirs.size()
	_update_labels()

func _cycle_max_players(dir: int) -> void:
	var options: Array[int] = [2, 3, 4]
	_selected_max_players_idx = (_selected_max_players_idx + dir + options.size()) % options.size()
	_update_labels()

func _cycle_character(dir: int) -> void:
	if _character_catalog.is_empty():
		return

	var next_idx: int = _selected_character_idx
	for _i in range(_character_catalog.size()):
		next_idx = (next_idx + dir + _character_catalog.size()) % _character_catalog.size()
		if _is_character_enabled(next_idx):
			_selected_character_idx = next_idx
			break

	_update_labels()

func _update_labels() -> void:
	_update_theme_preview()
	_update_character_preview()

	if Config.DIFF_KEYS.size() > 0 and _selected_difficulty < Config.DIFF_KEYS.size():
		difficulty_button.text = tr(Config.DIFF_KEYS[_selected_difficulty])

	if _theme_dirs.size() > 0 and _selected_theme_idx < _theme_dirs.size():
		var loader: ThemeLoader = ThemeLoader.get_cached(_theme_dirs[_selected_theme_idx])
		theme_button.text = loader.get_display_title(_theme_dirs[_selected_theme_idx])

	var max_player_values: Array[int] = [2, 3, 4]
	if _selected_max_players_idx >= 0 and _selected_max_players_idx < max_player_values.size():
		max_players_button.text = str(max_player_values[_selected_max_players_idx])

	if _character_catalog.size() > 0 and _selected_character_idx < _character_catalog.size():
		character_button.text = String(_character_catalog[_selected_character_idx].get("display_name", ""))

func _update_theme_preview() -> void:
	if _theme_dirs.is_empty():
		return
	if _selected_theme_idx != _last_theme_idx:
		_last_theme_idx = _selected_theme_idx
		_theme_preview_loader = ThemeLoader.get_cached(_theme_dirs[_selected_theme_idx])
	if theme_preview and _theme_preview_loader:
		theme_preview.set_character(_theme_preview_loader.player_frames, _theme_preview_loader.player_fps)

func _update_character_preview() -> void:
	if character_preview == null or _character_catalog.is_empty():
		return
	var character_id: String = String(_character_catalog[_selected_character_idx].get("id", ""))
	var preview_data: Dictionary = CharacterCatalog.get_preview_data_by_id(character_id)
	var frames_data: Array = preview_data.get("frames", [])
	var frames: Array[Texture2D] = []
	for item in frames_data:
		if item is Texture2D:
			frames.append(item)
	var fps: float = float(preview_data.get("fps", 1.0))
	if not frames.is_empty():
		character_preview.set_character(frames, fps)

func _is_character_enabled(idx: int) -> bool:
	if idx < 0 or idx >= _character_catalog.size():
		return false
	return true

func _selected_theme_dir() -> String:
	if _theme_dirs.is_empty():
		return "default"
	if _selected_theme_idx < 0 or _selected_theme_idx >= _theme_dirs.size():
		return "default"
	return _theme_dirs[_selected_theme_idx]

func _selected_character_id() -> String:
	if _character_catalog.is_empty():
		return ""
	return String(_character_catalog[_selected_character_idx].get("id", ""))

func _selected_max_players() -> int:
	var options: Array[int] = [2, 3, 4]
	if _selected_max_players_idx < 0 or _selected_max_players_idx >= options.size():
		return 2
	return options[_selected_max_players_idx]

func _on_start_pressed() -> void:
	status_label.text = ""
	if _character_catalog.is_empty():
		status_label.text = tr("mp_host_start_failed")
		return

	var config: Dictionary = {
		"difficulty": _selected_difficulty,
		"difficulty_key": Config.DIFF_KEYS[_selected_difficulty],
		"theme_dir": _selected_theme_dir(),
		"theme_title": theme_button.text,
		"max_players": _selected_max_players(),
		"character_id": _selected_character_id(),
	}

	NetworkManager.configure_host(config)
	var err: int = NetworkManager.start_host()
	if err != OK:
		status_label.text = "%s: %d (%s:%d)" % [
			tr("mp_host_start_failed"),
			err,
			NetworkManager.HOST_BIND_IP,
			NetworkManager.GAME_PORT,
		]
		return

	_set_network_debug("host", "Host started")
	get_tree().change_scene_to_file("res://scenes/multiplayer/host_lobby.tscn")

func _go_back() -> void:
	NetworkManager.leave_session()
	get_tree().change_scene_to_file("res://scenes/multiplayer/multiplayer_menu.tscn")

func _on_network_debug_changed(scope: String, message: String) -> void:
	_set_network_debug(scope, message)

func _set_network_debug(scope: String, message: String) -> void:
	if network_debug_label == null:
		return
	network_debug_label.text = "Network [%s]: %s" % [scope, message]
