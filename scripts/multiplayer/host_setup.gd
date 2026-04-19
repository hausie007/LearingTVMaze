extends Control

const ModeCardScene := preload("res://scenes/ui/mode_card.tscn")
const MissionCatalog := preload("res://scripts/mission_catalog.gd")

const PICKUP_CARD_ORDER: Array[String] = [
	MissionCatalog.PICKUP_NUMBERS,
	MissionCatalog.PICKUP_WORDS,
	MissionCatalog.PICKUP_LETTERS,
	MissionCatalog.PICKUP_NONE,
]
const PICKUP_CARD_ICONS := {
	"numbers": "123",
	"words": "W",
	"letters": "ABC",
	"none": ">",
}
const PICKUP_CARD_TITLE_KEYS := {
	"numbers": "training_numbers",
	"words": "training_words",
	"letters": "training_letters",
	"none": "pickup_just_maze",
}
const PICKUP_CARD_SUBTITLE_KEYS := {
	"numbers": "pickup_numbers_short",
	"words": "pickup_words_short",
	"letters": "pickup_letters_short",
	"none": "pickup_none_short",
}
const PICKUP_CARD_GAP := 24

@onready var main_vbox: VBoxContainer = $CenterContainer/MainVBox
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

@onready var row_difficulty: HBoxContainer = $CenterContainer/MainVBox/RowDifficulty
@onready var row_theme: HBoxContainer = $CenterContainer/MainVBox/RowTheme
@onready var row_max_players: HBoxContainer = $CenterContainer/MainVBox/RowMaxPlayers
@onready var row_character: HBoxContainer = $CenterContainer/MainVBox/RowCharacter
@onready var status_label: Label = %StatusLabel
@onready var network_debug_label: Label = %NetworkDebugLabel
@onready var start_button: Button = %StartButton

var _goal_label: Label = null
var _pickup_row: HBoxContainer = null
var _pickup_cards: Dictionary = {}
var _trouble_row: HBoxContainer = null
var _trouble_button: Button = null
var _trouble_left: Label = null
var _trouble_right: Label = null
var _head_start_row: HBoxContainer = null
var _head_start_button: Button = null
var _head_start_left: Label = null
var _head_start_right: Label = null

var _character_catalog: Array[Dictionary] = []
var _selected_mission: String = MissionCatalog.MISSION_FIND_EXIT
var _selected_pickup: String = MissionCatalog.PICKUP_NONE
var _selected_difficulty: int = 0
var _selected_max_players: int = 2
var _selected_character_idx: int = 0
var _selected_head_start_idx: int = 1
var _chaser_enabled: bool = false

func _ready() -> void:
	Input.warp_mouse(Vector2(-1, -1))
	_initialize_state()
	_build_setup_layout()
	_localize_ui()
	if network_debug_label != null:
		network_debug_label.visible = false

	_populate_characters()
	_setup_cycling_button(max_players_button, func(dir): _cycle_max_players(dir))
	_setup_cycling_button(character_button, func(dir): _cycle_character(dir))
	_setup_cycling_button(_head_start_button, func(dir): _cycle_head_start(dir))
	_setup_toggle_button(_trouble_button, _toggle_chaser)
	_setup_arrow_visibility(_trouble_button, _trouble_left, _trouble_right)
	start_button.pressed.connect(_on_start_pressed)
	UIHelpers.apply_style_to_button(start_button, UIColors.BLUE)

	NetworkManager.debug_status_changed.connect(_on_network_debug_changed)
	if Config != null and not Config.on_screen_controls_changed.is_connected(_on_controls_changed):
		Config.on_screen_controls_changed.connect(_on_controls_changed)

	_apply_dpad_layout()
	_apply_responsive_layout()
	_update_labels()
	_configure_dpad_navigation()
	var initial_focus := _selected_pickup_button()
	if initial_focus != null:
		initial_focus.call_deferred("grab_focus")

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_apply_dpad_layout()
		_apply_responsive_layout()
		_configure_dpad_navigation()

func _initialize_state() -> void:
	_selected_mission = Config.selected_mission_id
	if not MissionCatalog.mission_ids().has(_selected_mission):
		_selected_mission = Config.mission_id
	if not MissionCatalog.mission_ids().has(_selected_mission):
		_selected_mission = MissionCatalog.MISSION_FIND_EXIT
	_selected_pickup = MissionCatalog.default_pickup(_selected_mission)
	var existing_pickup := MissionCatalog.pickup_for_training(Config.training_type)
	if MissionCatalog.allowed_pickups(_selected_mission).has(existing_pickup):
		_selected_pickup = existing_pickup
	_selected_difficulty = clampi(Config.difficulty, 0, max(0, Config.DIFF_KEYS.size() - 1))
	_chaser_enabled = MissionCatalog.default_chaser_enabled(_selected_mission, true)
	var head_start_idx := MissionCatalog.CHASER_TUNING_LEVELS.find(Config.chaser_level)
	_selected_head_start_idx = head_start_idx if head_start_idx >= 0 else 1
	_normalize_selection()

func _build_setup_layout() -> void:
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.custom_minimum_size = Vector2(0, 0)
	main_vbox.add_theme_constant_override("separation", 12)
	title_label.add_theme_font_size_override("font_size", 52)

	_goal_label = Label.new()
	_goal_label.name = "GoalLabel"
	_goal_label.custom_minimum_size = Vector2(0, 78)
	_goal_label.add_theme_font_size_override("font_size", 30)
	_goal_label.add_theme_color_override("font_color", UIColors.YELLOW)
	_goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_goal_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main_vbox.add_child(_goal_label)
	main_vbox.move_child(_goal_label, title_label.get_index() + 1)

	_pickup_row = HBoxContainer.new()
	_pickup_row.name = "PickupCardRow"
	_pickup_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_pickup_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pickup_row.add_theme_constant_override("separation", PICKUP_CARD_GAP)
	main_vbox.add_child(_pickup_row)
	main_vbox.move_child(_pickup_row, _goal_label.get_index() + 1)
	_build_pickup_cards()

	var trouble := _create_selector_row("setting_trouble")
	_trouble_row = trouble["row"] as HBoxContainer
	_trouble_left = trouble["left"] as Label
	_trouble_button = trouble["button"] as Button
	_trouble_right = trouble["right"] as Label
	main_vbox.add_child(_trouble_row)
	main_vbox.move_child(_trouble_row, _pickup_row.get_index() + 1)

	var head_start := _create_selector_row("setting_head_start")
	_head_start_row = head_start["row"] as HBoxContainer
	_head_start_left = head_start["left"] as Label
	_head_start_button = head_start["button"] as Button
	_head_start_right = head_start["right"] as Label
	main_vbox.add_child(_head_start_row)
	main_vbox.move_child(_head_start_row, _trouble_row.get_index() + 1)

	main_vbox.move_child(row_max_players, _head_start_row.get_index() + 1)
	main_vbox.move_child(row_character, row_max_players.get_index() + 1)
	main_vbox.move_child(row_difficulty, row_character.get_index() + 1)
	row_theme.visible = false
	row_difficulty.visible = false
	difficulty_button.focus_mode = Control.FOCUS_NONE

	for row in [row_max_players, row_character]:
		row.add_theme_constant_override("separation", 44)
		var label := row.get_child(0) as Label
		if label != null:
			label.custom_minimum_size = Vector2(270, 0)
			label.add_theme_font_size_override("font_size", 23)

	for btn in [max_players_button, character_button]:
		btn.custom_minimum_size = Vector2(300, 48)
		btn.add_theme_font_size_override("font_size", 23)

	if start_button != null:
		start_button.visible = true
		start_button.focus_mode = Control.FOCUS_ALL
		start_button.custom_minimum_size = Vector2(520, 72)
		start_button.add_theme_font_size_override("font_size", 32)
		if start_button.get_parent() != null:
			start_button.get_parent().visible = true

func _build_pickup_cards() -> void:
	for pickup_id in PICKUP_CARD_ORDER:
		var card := ModeCardScene.instantiate() as Button
		card.custom_minimum_size = Vector2(280, 220)
		card.pivot_offset = Vector2(140, 110)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.call("configure_compact", 52, 30, 19)
		card.pressed.connect(_select_pickup.bind(pickup_id))
		card.focus_entered.connect(_select_pickup_from_focus.bind(pickup_id))
		_pickup_row.add_child(card)
		_pickup_cards[pickup_id] = card

func _create_selector_row(label_key: String) -> Dictionary:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size = Vector2(0, 52)

	var label := Label.new()
	label.custom_minimum_size = Vector2(270, 0)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", UIColors.TEXT_SUBTITLE)
	label.text = tr(label_key)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)

	var container := HBoxContainer.new()
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_theme_constant_override("separation", 12)
	row.add_child(container)

	var left := _create_arrow_label()
	container.add_child(left)

	var button := Button.new()
	button.custom_minimum_size = Vector2(300, 48)
	button.add_theme_font_size_override("font_size", 23)
	UIHelpers.apply_style_to_button(button, UIColors.YELLOW)
	container.add_child(button)

	var right := _create_arrow_label()
	right.text = ">"
	container.add_child(right)

	return {"row": row, "left": left, "button": button, "right": right}

func _create_arrow_label() -> Label:
	var label := Label.new()
	label.custom_minimum_size = Vector2(34, 0)
	label.add_theme_color_override("font_color", UIColors.YELLOW)
	label.add_theme_font_size_override("font_size", 36)
	label.text = "<"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		var viewport: Viewport = get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
		_go_back()

func _localize_ui() -> void:
	title_label.text = tr(MissionCatalog.mission_title_key(_selected_mission))
	max_players_label.text = tr("mp_host_max_players")
	character_label.text = tr("mp_host_character")
	start_button.text = tr("setup_host_game")
	status_label.text = ""

func _apply_dpad_layout() -> void:
	if center_container != null and Config != null:
		UIHelpers.apply_dpad_layout(center_container, Config.on_screen_controls)

func _on_controls_changed(_new_mode: int) -> void:
	_apply_dpad_layout()
	_apply_responsive_layout()
	_configure_dpad_navigation()

func _setup_toggle_button(btn: Button, callback: Callable) -> void:
	if btn == null:
		return
	btn.pressed.connect(callback)
	btn.gui_input.connect(func(event: InputEvent):
		if event.is_pressed() and (event.is_action("ui_left") or event.is_action("ui_right")):
			var viewport: Viewport = get_viewport()
			callback.call()
			if viewport != null:
				viewport.set_input_as_handled()
	)
	UIHelpers.apply_style_to_button(btn, UIColors.YELLOW)

func _setup_arrow_visibility(btn: Button, left: Label, right: Label) -> void:
	if btn == null or left == null or right == null:
		return
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

func _setup_cycling_button(btn: Button, cycle_func: Callable) -> void:
	if btn == null:
		return

	var base_name: String = btn.name.replace("Button", "")
	var left_arrow: Label = get_node_or_null("%%%sLeftArrow" % base_name)
	var right_arrow: Label = get_node_or_null("%%%sRightArrow" % base_name)
	if btn == _head_start_button:
		left_arrow = _head_start_left
		right_arrow = _head_start_right

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

func _populate_characters() -> void:
	_character_catalog = CharacterCatalog.build_catalog()
	_selected_character_idx = 0

func _cycle_difficulty(dir: int) -> void:
	if Config.DIFF_KEYS.is_empty():
		return
	_selected_difficulty = (_selected_difficulty + dir + Config.DIFF_KEYS.size()) % Config.DIFF_KEYS.size()
	_update_labels()

func _cycle_max_players(dir: int) -> void:
	var options := MissionCatalog.max_players_options(_selected_mission, _chaser_enabled)
	var idx := options.find(_selected_max_players)
	idx = 0 if idx < 0 else idx
	_selected_max_players = int(options[(idx + dir + options.size()) % options.size()])
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

func _select_pickup(pickup_id: String) -> void:
	if not MissionCatalog.allowed_pickups(_selected_mission).has(pickup_id):
		return
	if _selected_pickup == pickup_id:
		return
	_selected_pickup = pickup_id
	_update_labels()
	_configure_dpad_navigation()

func _select_pickup_from_focus(pickup_id: String) -> void:
	if MissionCatalog.allowed_pickups(_selected_mission).has(pickup_id):
		_select_pickup(pickup_id)

func _cycle_head_start(dir: int) -> void:
	_selected_head_start_idx = (_selected_head_start_idx + dir + MissionCatalog.CHASER_TUNING_LEVELS.size()) % MissionCatalog.CHASER_TUNING_LEVELS.size()
	_update_labels()

func _toggle_chaser() -> void:
	if MissionCatalog.chaser_required(_selected_mission, true):
		return
	if not MissionCatalog.chaser_allowed(_selected_mission):
		return
	_chaser_enabled = not _chaser_enabled
	_normalize_selection()
	_update_labels()
	_configure_dpad_navigation()

func _normalize_selection() -> void:
	if not MissionCatalog.mission_ids().has(_selected_mission):
		_selected_mission = MissionCatalog.MISSION_FIND_EXIT
	var pickups := MissionCatalog.allowed_pickups(_selected_mission)
	if not pickups.has(_selected_pickup):
		_selected_pickup = MissionCatalog.default_pickup(_selected_mission)
	if MissionCatalog.chaser_required(_selected_mission, true):
		_chaser_enabled = true
	if MissionCatalog.chaser_forced_off(_selected_mission):
		_chaser_enabled = false
	var player_options := MissionCatalog.max_players_options(_selected_mission, _chaser_enabled)
	if not player_options.has(_selected_max_players):
		_selected_max_players = int(player_options[0])

func _update_labels() -> void:
	_normalize_selection()
	_update_character_preview()
	_update_pickup_cards()
	_update_context_rows()

	title_label.text = tr(MissionCatalog.mission_title_key(_selected_mission))
	if _character_catalog.size() > 0 and _selected_character_idx < _character_catalog.size():
		character_button.text = String(_character_catalog[_selected_character_idx].get("display_name", ""))

func _update_pickup_cards() -> void:
	var allowed_pickups := MissionCatalog.allowed_pickups(_selected_mission)
	for pickup_id in PICKUP_CARD_ORDER:
		var card := _pickup_cards.get(pickup_id, null) as Button
		if card == null:
			continue
		var allowed := allowed_pickups.has(pickup_id)
		card.visible = allowed
		card.focus_mode = Control.FOCUS_ALL if allowed else Control.FOCUS_NONE
		card.call(
			"setup",
			String(PICKUP_CARD_ICONS.get(pickup_id, "?")),
			tr(String(PICKUP_CARD_TITLE_KEYS.get(pickup_id, "training_words"))),
			tr(String(PICKUP_CARD_SUBTITLE_KEYS.get(pickup_id, "pickup_words_short")))
		)
		card.call("set_selected", pickup_id == _selected_pickup)
	_apply_responsive_layout()

func _update_context_rows() -> void:
	var trouble_visible := MissionCatalog.chaser_allowed(_selected_mission)
	var trouble_required := MissionCatalog.chaser_required(_selected_mission, true)
	_set_option_button_enabled(_trouble_button, trouble_visible and not trouble_required)
	_trouble_row.modulate.a = 1.0 if trouble_visible else 0.45
	_trouble_button.text = tr("trouble_chaser") if _chaser_enabled else tr("trouble_no_chaser")

	_set_option_button_enabled(_head_start_button, _chaser_enabled)
	_head_start_row.modulate.a = 1.0 if _chaser_enabled else 0.45
	var head_start_level := MissionCatalog.CHASER_TUNING_LEVELS[_selected_head_start_idx]
	_head_start_button.text = tr(MissionCatalog.head_start_title_key(head_start_level)) if _chaser_enabled else tr("trouble_no_chaser")

	var player_options := MissionCatalog.max_players_options(_selected_mission, _chaser_enabled)
	var exact_two := player_options.size() == 1
	max_players_button.disabled = false
	max_players_button.focus_mode = Control.FOCUS_ALL
	max_players_left_arrow.visible = not exact_two
	max_players_right_arrow.visible = not exact_two
	max_players_button.text = tr("players_2_only") if exact_two else str(_selected_max_players)

	var goal_key := MissionCatalog.goal_key(_selected_mission, _selected_pickup, _chaser_enabled, true)
	_goal_label.text = tr(goal_key)
	_goal_label.visible = false

func _set_option_button_enabled(button: Button, enabled: bool) -> void:
	if button == null:
		return
	button.disabled = not enabled
	button.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE

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
	return idx >= 0 and idx < _character_catalog.size()

func _selected_theme_dir() -> String:
	if Config.theme_dir_name.is_empty():
		return "default"
	return Config.theme_dir_name

func _selected_theme_title() -> String:
	var loader := ThemeLoader.get_cached(_selected_theme_dir())
	return loader.get_display_title(_selected_theme_dir()) if loader != null else _selected_theme_dir()

func _selected_character_id() -> String:
	if _character_catalog.is_empty():
		return ""
	return String(_character_catalog[_selected_character_idx].get("id", ""))

func _on_start_pressed() -> void:
	status_label.text = ""
	if _character_catalog.is_empty():
		status_label.text = tr("mp_host_start_failed")
		return

	var style := MissionCatalog.style_for_mission(_selected_mission)
	var training := MissionCatalog.training_for_pickup(_selected_pickup)
	var mission_title := tr(MissionCatalog.mission_title_key(_selected_mission))
	var pickup_title := tr(MissionCatalog.pickup_title_key(_selected_pickup))
	var chaser_level := MissionCatalog.CHASER_TUNING_LEVELS[_selected_head_start_idx] if _chaser_enabled else Config.ChaserLevel.OFF
	_selected_difficulty = clampi(Config.difficulty, 0, max(0, Config.DIFF_KEYS.size() - 1))
	var config: Dictionary = {
		"difficulty": _selected_difficulty,
		"difficulty_key": Config.DIFF_KEYS[_selected_difficulty],
		"mission_id": _selected_mission,
		"mission_title": mission_title,
		"mission_goal_key": MissionCatalog.goal_key(_selected_mission, _selected_pickup, _chaser_enabled, true),
		"role_summary_key": MissionCatalog.role_summary_key(_selected_mission, _chaser_enabled),
		"game_style": style,
		"game_style_title": mission_title,
		"training_type": training,
		"training_type_title": pickup_title,
		"chaser_enabled": _chaser_enabled and style != NetworkManager.STYLE_RACE,
		"chaser_level": chaser_level,
		"rotate_roles_after_round": false,
		"theme_dir": _selected_theme_dir(),
		"theme_title": _selected_theme_title(),
		"max_players": _selected_max_players,
		"character_id": _selected_character_id(),
	}

	Config.difficulty = _selected_difficulty
	Config.save_settings()
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
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _apply_responsive_layout() -> void:
	var available_width := _available_setup_width()
	main_vbox.custom_minimum_size.x = available_width
	if _goal_label != null:
		_goal_label.custom_minimum_size = Vector2(available_width, 78)

	var visible_cards := _pickup_card_buttons(true)
	if visible_cards.is_empty():
		return
	var gaps := float(PICKUP_CARD_GAP * max(0, visible_cards.size() - 1))
	var card_width := floorf((available_width - gaps) / float(visible_cards.size()))
	if visible_cards.size() == 1:
		card_width = clampf(card_width, 420.0, 620.0)
	else:
		card_width = clampf(card_width, 240.0, 340.0)
	var card_height := 150.0 if visible_cards.size() == 1 else 230.0
	for card in visible_cards:
		card.custom_minimum_size = Vector2(card_width, card_height)
		card.pivot_offset = Vector2(card_width * 0.5, card_height * 0.5)
		card.call("configure_compact", 52, 30, 19)

func _available_setup_width() -> float:
	var viewport_size := get_viewport_rect().size
	var controls_mode := Config.ControlsMode.OFF
	if Config != null:
		controls_mode = Config.on_screen_controls
	var content_rect := UIHelpers.get_content_rect(viewport_size, controls_mode)
	return clampf(content_rect.size.x, 760.0, 1400.0)

func _configure_dpad_navigation() -> void:
	var pickup_buttons := _pickup_card_buttons(true)
	_configure_card_row_navigation(pickup_buttons, start_button, _first_context_button())
	if _is_focusable(_trouble_button):
		_configure_single_button_navigation(_trouble_button, _selected_pickup_button(), _next_after_trouble_button())
	if _is_focusable(_head_start_button):
		_configure_single_button_navigation(_head_start_button, _previous_before_head_start_button(), max_players_button)
	_configure_single_button_navigation(max_players_button, _last_context_button(), character_button)
	_configure_single_button_navigation(character_button, max_players_button, start_button)
	_configure_single_button_navigation(start_button, character_button, _selected_pickup_button())

func _configure_card_row_navigation(cards: Array, above: Control, below: Control) -> void:
	var row := _valid_buttons(cards)
	if row.is_empty():
		return
	for i in range(row.size()):
		var card := row[i] as Button
		var left := row[(i - 1 + row.size()) % row.size()] as Button
		var right := row[(i + 1) % row.size()] as Button
		card.focus_neighbor_left = card.get_path_to(left)
		card.focus_neighbor_right = card.get_path_to(right)
		if above != null:
			card.focus_neighbor_top = card.get_path_to(above)
		if below != null:
			card.focus_neighbor_bottom = card.get_path_to(below)

func _configure_single_button_navigation(button: Control, top: Control, bottom: Control) -> void:
	if button == null:
		return
	button.focus_neighbor_left = button.get_path_to(button)
	button.focus_neighbor_right = button.get_path_to(button)
	if top != null:
		button.focus_neighbor_top = button.get_path_to(top)
	if bottom != null:
		button.focus_neighbor_bottom = button.get_path_to(bottom)

func _first_context_button() -> Button:
	if _is_focusable(_trouble_button):
		return _trouble_button
	if _is_focusable(_head_start_button):
		return _head_start_button
	return max_players_button

func _last_context_button() -> Button:
	if _is_focusable(_head_start_button):
		return _head_start_button
	if _is_focusable(_trouble_button):
		return _trouble_button
	return _selected_pickup_button()

func _next_after_trouble_button() -> Button:
	if _is_focusable(_head_start_button):
		return _head_start_button
	return max_players_button

func _previous_before_head_start_button() -> Button:
	if _is_focusable(_trouble_button):
		return _trouble_button
	return _selected_pickup_button()

func _pickup_card_buttons(only_focusable: bool = false) -> Array[Button]:
	var buttons: Array[Button] = []
	for pickup_id in PICKUP_CARD_ORDER:
		var button := _pickup_cards.get(pickup_id, null) as Button
		if button == null:
			continue
		if only_focusable and not _is_focusable(button):
			continue
		buttons.append(button)
	return buttons

func _selected_pickup_button() -> Button:
	var selected := _pickup_cards.get(_selected_pickup, null) as Button
	if _is_focusable(selected):
		return selected
	var buttons := _pickup_card_buttons(true)
	return buttons[0] if not buttons.is_empty() else null

func _is_focusable(button: Control) -> bool:
	if button == null:
		return false
	if button is Button:
		var btn := button as Button
		if btn.disabled:
			return false
	return button.visible and button.focus_mode != Control.FOCUS_NONE

func _valid_buttons(items: Array) -> Array[Button]:
	var result: Array[Button] = []
	for item in items:
		if item is Button and is_instance_valid(item):
			var button := item as Button
			if button.visible:
				result.append(button)
	return result

func _on_network_debug_changed(scope: String, message: String) -> void:
	_set_network_debug(scope, message)

func _set_network_debug(scope: String, message: String) -> void:
	if network_debug_label == null:
		return
	network_debug_label.text = "Network [%s]: %s" % [scope, message]
