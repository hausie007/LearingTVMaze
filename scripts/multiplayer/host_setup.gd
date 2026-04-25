extends Control

const ModeCardScene := preload("res://scenes/ui/mode_card.tscn")
const MissionCatalog := preload("res://scripts/mission_catalog.gd")

const MP_GREEN := Color("#2D9B58")
const MP_GREEN_BORDER := Color("#3DC878")

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

@onready var center_container: CenterContainer = $CenterContainer
@onready var status_label: Label = %StatusLabel
@onready var network_debug_label: Label = %NetworkDebugLabel

var _home_vbox: VBoxContainer = null
var _top_spacer: Control = null
var _title_row: HBoxContainer = null
var _title_label: Label = null
var _player_preview: CharacterPreview = null
var _title_cards_spacer: Control = null
var _pickup_row: HBoxContainer = null
var _start_button: Button = null
var _cards_settings_spacer: Control = null
var _settings_vbox: VBoxContainer = null

var _pickup_cards: Dictionary = {}
var _trouble_row: HBoxContainer = null
var _trouble_button: Button = null
var _trouble_left: Label = null
var _trouble_right: Label = null
var _head_start_row: HBoxContainer = null
var _head_start_button: Button = null
var _head_start_left: Label = null
var _head_start_right: Label = null
var _lang_row: HBoxContainer = null
var _lang_button: Button = null
var _lang_left: Label = null
var _lang_right: Label = null
var _character_row: HBoxContainer = null
var _character_button: Button = null
var _character_left: Label = null
var _character_right: Label = null
var _character_preview: CharacterPreview = null
var _role_label: Label = null

var _temp_lang_idx: int = 0
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
	_build_layout()
	if network_debug_label != null:
		network_debug_label.visible = false

	_populate_characters()

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
	else:
		var first_btn := _lang_button
		if first_btn != null:
			first_btn.call_deferred("grab_focus")

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
	# Read chaser from saved state; forced on for missions that require it
	if MissionCatalog.chaser_required(_selected_mission, true):
		_chaser_enabled = true
	else:
		_chaser_enabled = Config.chaser_enabled and MissionCatalog.chaser_allowed(_selected_mission)
	var head_start_idx := MissionCatalog.CHASER_TUNING_LEVELS.find(Config.chaser_level)
	_selected_head_start_idx = head_start_idx if head_start_idx >= 0 else 1
	_temp_lang_idx = Config.LANG_CODES.find(Config.learning_language)
	if _temp_lang_idx < 0:
		_temp_lang_idx = 0
	_normalize_selection()

func _build_layout() -> void:
	# Clear existing scene children from CenterContainer
	for child in center_container.get_children():
		center_container.remove_child(child)
		child.queue_free()

	# Main VBox — fills entire viewport like main menu
	_home_vbox = VBoxContainer.new()
	_home_vbox.name = "HostSetupHome"
	_home_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	_home_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_home_vbox.add_theme_constant_override("separation", 18)
	center_container.add_child(_home_vbox)

	# Top spacer
	_top_spacer = Control.new()
	_top_spacer.name = "TopSpacer"
	_top_spacer.custom_minimum_size = Vector2(0, 60)
	_home_vbox.add_child(_top_spacer)

	# Title row: [PlayerPreview] [Title]
	_title_row = HBoxContainer.new()
	_title_row.name = "TitleRow"
	_title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_title_row.add_theme_constant_override("separation", 20)
	_home_vbox.add_child(_title_row)

	_player_preview = CharacterPreview.new()
	_player_preview.name = "PlayerPreview"
	_player_preview.custom_minimum_size = Vector2(72, 72)
	_player_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_player_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_title_row.add_child(_player_preview)

	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.add_theme_font_size_override("font_size", 62)
	_title_label.add_theme_color_override("font_color", UIColors.YELLOW)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_row.add_child(_title_label)

	# Spacer between title and cards
	_title_cards_spacer = Control.new()
	_title_cards_spacer.name = "TitleCardsSpacer"
	_title_cards_spacer.custom_minimum_size = Vector2(0, 18)
	_home_vbox.add_child(_title_cards_spacer)

	# Pickup card row
	_pickup_row = HBoxContainer.new()
	_pickup_row.name = "PickupRow"
	_pickup_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_pickup_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pickup_row.add_theme_constant_override("separation", 48)
	_home_vbox.add_child(_pickup_row)
	_build_pickup_cards()

	# Action button row: [Host Game] — centered below cards, green
	var action_spacer := Control.new()
	action_spacer.name = "ActionSpacer"
	action_spacer.custom_minimum_size = Vector2(0, 10)
	_home_vbox.add_child(action_spacer)

	var action_row := HBoxContainer.new()
	action_row.name = "ActionRow"
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_home_vbox.add_child(action_row)

	_start_button = Button.new()
	_start_button.text = tr("setup_host_game")
	_start_button.custom_minimum_size = Vector2(320, 68)
	_start_button.add_theme_font_size_override("font_size", 30)
	UIHelpers.apply_style_to_button(_start_button, MP_GREEN)
	var mp_normal := UIHelpers.create_rounded_stylebox(UIColors.BG_DARK, MP_GREEN_BORDER, 12, 2)
	_start_button.add_theme_stylebox_override("normal", mp_normal)
	_start_button.pressed.connect(_on_start_pressed)
	action_row.add_child(_start_button)

	# Spacer between action button and settings
	_cards_settings_spacer = Control.new()
	_cards_settings_spacer.name = "CardsSettingsSpacer"
	_cards_settings_spacer.custom_minimum_size = Vector2(0, 56)
	_home_vbox.add_child(_cards_settings_spacer)

	# Settings block
	_settings_vbox = VBoxContainer.new()
	_settings_vbox.name = "SettingsBlock"
	_settings_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_settings_vbox.add_theme_constant_override("separation", 12)
	_home_vbox.add_child(_settings_vbox)

	# Language row (always visible — first to avoid shift when toggling chaser)
	var lang := _create_selector_row("setting_learning_lang")
	_lang_row = lang["row"] as HBoxContainer
	_lang_left = lang["left"] as Label
	_lang_button = lang["button"] as Button
	_lang_right = lang["right"] as Label
	_lang_button.pressed.connect(func(): _cycle_lang(1))
	_setup_cycling(_lang_button, _cycle_lang)
	_setup_arrow_visibility(_lang_button, _lang_left, _lang_right)
	_settings_vbox.add_child(_lang_row)

	# Character row (with preview in the extras slot)
	var character := _create_selector_row("mp_host_you")
	_character_row = character["row"] as HBoxContainer
	_character_left = character["left"] as Label
	_character_button = character["button"] as Button
	_character_right = character["right"] as Label
	_character_button.pressed.connect(func(): _cycle_character(1))
	_setup_cycling(_character_button, _cycle_character)
	_setup_arrow_visibility(_character_button, _character_left, _character_right)
	_character_preview = CharacterPreview.new()
	_character_preview.name = "CharacterPreview"
	_character_preview.custom_minimum_size = Vector2(56, 56)
	_character_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_character_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var char_extras := character["extras"] as HBoxContainer
	char_extras.add_child(_character_preview)
	_settings_vbox.add_child(_character_row)

	# Role description — standalone label between character and trouble
	_role_label = Label.new()
	_role_label.name = "RoleLabel"
	_role_label.add_theme_font_size_override("font_size", 24)
	_role_label.add_theme_color_override("font_color", UIColors.TEXT_SUBTITLE)
	_role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_role_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_role_label.custom_minimum_size = Vector2(0, 32)
	_settings_vbox.add_child(_role_label)

	# Trouble row
	var trouble := _create_selector_row("setting_trouble")
	_trouble_row = trouble["row"] as HBoxContainer
	_trouble_left = trouble["left"] as Label
	_trouble_button = trouble["button"] as Button
	_trouble_right = trouble["right"] as Label
	_trouble_button.pressed.connect(_toggle_chaser)
	_setup_toggle_cycling(_trouble_button, _toggle_chaser)
	_setup_arrow_visibility(_trouble_button, _trouble_left, _trouble_right)
	_settings_vbox.add_child(_trouble_row)

	# Head start row
	var head_start := _create_selector_row("setting_head_start")
	_head_start_row = head_start["row"] as HBoxContainer
	_head_start_left = head_start["left"] as Label
	_head_start_button = head_start["button"] as Button
	_head_start_right = head_start["right"] as Label
	_head_start_button.pressed.connect(func(): _cycle_head_start(1))
	_setup_cycling(_head_start_button, _cycle_head_start)
	_setup_arrow_visibility(_head_start_button, _head_start_left, _head_start_right)
	_settings_vbox.add_child(_head_start_row)

func _build_pickup_cards() -> void:
	for pickup_id in PICKUP_CARD_ORDER:
		var card := ModeCardScene.instantiate() as Button
		card.custom_minimum_size = Vector2(300, 230)
		card.pivot_offset = Vector2(150, 115)
		card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card.call("configure_compact", 52, 30, 19)
		card.pressed.connect(_on_card_pressed.bind(pickup_id))
		card.focus_entered.connect(_select_pickup_from_focus.bind(pickup_id))
		_pickup_row.add_child(card)
		_pickup_cards[pickup_id] = card

func _on_card_pressed(pickup_id: String) -> void:
	if not MissionCatalog.allowed_pickups(_selected_mission).has(pickup_id):
		return
	_selected_pickup = pickup_id
	_on_start_pressed()

func _create_selector_row(label_key: String) -> Dictionary:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 0)
	row.custom_minimum_size = Vector2(0, 68)

	var label := Label.new()
	label.custom_minimum_size = Vector2(245, 0)
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", UIColors.TEXT_SUBTITLE)
	label.text = tr(label_key)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	# Small gap between label and arrows
	var gap1 := Control.new()
	gap1.custom_minimum_size = Vector2(12, 0)
	row.add_child(gap1)

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

	# Fixed-width extras slot — same size for all rows to keep alignment stable
	var extras := HBoxContainer.new()
	extras.custom_minimum_size = Vector2(180, 0)
	extras.add_theme_constant_override("separation", 8)
	extras.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_child(extras)

	return {"row": row, "left": left, "button": button, "right": right, "extras": extras}

func _create_arrow_label() -> Label:
	var label := Label.new()
	label.custom_minimum_size = Vector2(36, 0)
	label.add_theme_color_override("font_color", UIColors.YELLOW)
	label.add_theme_font_size_override("font_size", 38)
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

func _apply_dpad_layout() -> void:
	if center_container != null and Config != null:
		UIHelpers.apply_dpad_layout(center_container, Config.on_screen_controls)

func _on_controls_changed(_new_mode: int) -> void:
	_apply_dpad_layout()
	_apply_responsive_layout()
	_configure_dpad_navigation()

func _setup_toggle_cycling(btn: Button, callback: Callable) -> void:
	if btn == null:
		return
	btn.gui_input.connect(func(event: InputEvent):
		if event.is_pressed() and (event.is_action("ui_left") or event.is_action("ui_right")):
			var viewport: Viewport = get_viewport()
			callback.call()
			if viewport != null:
				viewport.set_input_as_handled()
	)

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

func _setup_cycling(btn: Button, cycle_func: Callable) -> void:
	if btn == null:
		return
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

func _populate_characters() -> void:
	_character_catalog = CharacterCatalog.build_catalog()
	_selected_character_idx = 0
	var target_id := Config.theme_dir_name + ":player"
	for i in range(_character_catalog.size()):
		var cat_id := String(_character_catalog[i].get("id", ""))
		if cat_id == target_id:
			_selected_character_idx = i
			break

func _cycle_lang(dir: int) -> void:
	_temp_lang_idx = (_temp_lang_idx + dir + Config.LANG_CODES.size()) % Config.LANG_CODES.size()
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
	if not player_options.is_empty():
		_selected_max_players = int(player_options[player_options.size() - 1])

func _update_labels() -> void:
	_normalize_selection()
	_update_theme_preview()
	_update_pickup_cards()
	_update_context_rows()

	var num_players := ""
	var options := MissionCatalog.max_players_options(_selected_mission, _chaser_enabled)
	if not options.is_empty():
		if options.size() == 1:
			num_players = str(options[0]) + " players"
		else:
			num_players = str(options[0]) + "-" + str(options[options.size() - 1]) + " players"

	_title_label.text = "Play Together: " + tr(MissionCatalog.mission_title_key(_selected_mission)) + " (" + num_players + ")"

	var ui_idx: int = Config.LANG_CODES.find(Config.ui_language)
	if ui_idx < 0:
		ui_idx = 0
	_lang_button.text = Config.get_lang_display_name(_temp_lang_idx, true, ui_idx)

	if _character_catalog.size() > 0 and _selected_character_idx < _character_catalog.size():
		_character_button.text = String(_character_catalog[_selected_character_idx].get("display_name", ""))
		_update_character_preview()

	# Update role label
	var role_key := MissionCatalog.role_summary_key(_selected_mission, _chaser_enabled)
	_role_label.text = tr(role_key)

func _update_theme_preview() -> void:
	var loader := ThemeLoader.get_cached(_selected_theme_dir())
	if loader != null and _player_preview != null:
		_player_preview.set_character(loader.player_frames, loader.player_fps)

func _update_character_preview() -> void:
	if _character_preview == null or _character_catalog.is_empty():
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
		_character_preview.set_character(frames, fps)

func _update_pickup_cards() -> void:
	var allowed_pickups := MissionCatalog.allowed_pickups(_selected_mission)
	var visible_count := 0
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
		card.call("set_selected", pickup_id == _selected_pickup, false)
		if allowed:
			visible_count += 1

	# Show card row if at least 1 card is visible
	_pickup_row.visible = visible_count > 0
	_title_cards_spacer.visible = visible_count > 0

func _update_context_rows() -> void:
	var is_collecting := _selected_pickup != MissionCatalog.PICKUP_NONE
	if _lang_row != null:
		_lang_row.visible = is_collecting
		_set_option_button_enabled(_lang_button, is_collecting)

	var chaser_allowed := MissionCatalog.chaser_allowed(_selected_mission)
	var chaser_required := MissionCatalog.chaser_required(_selected_mission, true)
	var chaser_forced_off := MissionCatalog.chaser_forced_off(_selected_mission)
	# Only show trouble row when user has an actual choice
	var user_can_toggle := chaser_allowed and not chaser_required and not chaser_forced_off
	_trouble_row.visible = user_can_toggle
	_set_option_button_enabled(_trouble_button, user_can_toggle)
	# Silently enforce the only valid value when there's no choice
	if chaser_required:
		_chaser_enabled = true
	elif chaser_forced_off or not chaser_allowed:
		_chaser_enabled = false
	_trouble_button.text = tr("trouble_chaser") if _chaser_enabled else tr("trouble_no_chaser")

	_set_option_button_enabled(_head_start_button, _chaser_enabled)
	_head_start_row.visible = _chaser_enabled
	var head_start_level := MissionCatalog.CHASER_TUNING_LEVELS[_selected_head_start_idx]
	_head_start_button.text = tr(MissionCatalog.head_start_title_key(head_start_level)) if _chaser_enabled else tr("trouble_no_chaser")

func _set_option_button_enabled(button: Button, enabled: bool) -> void:
	if button == null:
		return
	button.disabled = not enabled
	button.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE

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
	Config.learning_language = Config.LANG_CODES[_temp_lang_idx]
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
	# Persist current selections so they're restored on return
	Config.learning_language = Config.LANG_CODES[_temp_lang_idx]
	Config.selected_mission_id = _selected_mission
	Config.training_type = MissionCatalog.training_for_pickup(_selected_pickup)
	Config.chaser_enabled = _chaser_enabled
	Config.chaser_level = MissionCatalog.CHASER_TUNING_LEVELS[_selected_head_start_idx] if _chaser_enabled else Config.ChaserLevel.OFF
	Config.save_settings()
	NetworkManager.leave_session()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _apply_responsive_layout() -> void:
	var available_width := _available_setup_width()
	var viewport_height: float = get_viewport_rect().size.y
	var short_screen: bool = viewport_height < 820.0

	if _home_vbox != null:
		_home_vbox.custom_minimum_size = Vector2(available_width, viewport_height)
		_home_vbox.add_theme_constant_override("separation", _home_spacing())

	if _top_spacer != null:
		_top_spacer.custom_minimum_size.y = clampf(viewport_height * 0.0075, 3.0, 8.0)

	if _title_row != null:
		var simulated_logo_width: float = clampf(available_width * (0.52 if short_screen else 0.58), 480.0, 930.0)
		var simulated_logo_height: float = clampf(simulated_logo_width * 0.214, 102.0, 198.0)
		_title_row.custom_minimum_size.y = simulated_logo_height

		if _title_label != null:
			# Multiplayer uses a slightly smaller multiplier because the title is much longer!
			_title_label.add_theme_font_size_override("font_size", int(simulated_logo_height * 0.30))

		var preview_size := simulated_logo_height * 0.45
		if _player_preview != null:
			_player_preview.custom_minimum_size = Vector2(preview_size, preview_size)

	if _title_cards_spacer != null:
		_title_cards_spacer.custom_minimum_size.y = 16.0 if short_screen else 24.0

	if _cards_settings_spacer != null:
		_cards_settings_spacer.custom_minimum_size.y = 20.0 if short_screen else 30.0

	var visible_cards := _pickup_card_buttons(true)
	if not visible_cards.is_empty() and _pickup_row.visible:
		var count: int = visible_cards.size()
		var columns: int = 4 if available_width >= 760.0 else 2

		var mission_gap: int = 48
		if available_width < 1200.0:
			mission_gap = 34
		if available_width < 900.0:
			mission_gap = 24

		var gaps := float(mission_gap * maxi(0, columns - 1))
		var card_width := floorf((available_width - gaps) / float(columns))
		card_width = clampf(card_width, 160.0, 390.0)
		var card_height := clampf(viewport_height * (0.355 if short_screen else 0.335), 260.0, 340.0)

		_pickup_row.add_theme_constant_override("separation", mission_gap)

		for card in visible_cards:
			card.custom_minimum_size = Vector2(card_width, card_height)
			card.pivot_offset = Vector2(card_width * 0.5, card_height * 0.5)

			var icon_size: int = 46 if card_width < 220.0 else (52 if card_width < 270.0 else 58)
			var title_size: int = 24 if card_width < 220.0 else (28 if card_width < 270.0 else 31)
			var subtitle_size: int = 17 if card_width < 250.0 else 19
			card.call("configure_compact", icon_size, title_size, subtitle_size)

	# Responsive action button size
	var action_btn_width: float = clampf(available_width * 0.22, 260.0, 380.0)
	var action_btn_height: float = 62.0 if short_screen else 68.0
	var action_font_size: int = 26 if short_screen else 30
	if _start_button != null:
		_start_button.custom_minimum_size = Vector2(action_btn_width, action_btn_height)
		_start_button.add_theme_font_size_override("font_size", action_font_size)

	# Responsive selector sizes — match main menu
	var selector_width: float = clampf(available_width * 0.32, 380.0, 500.0)
	var selector_height: float = 58.0 if short_screen else 66.0
	var selector_font_size: int = 28 if short_screen else 31

	for btn in [_trouble_button, _head_start_button, _lang_button, _character_button]:
		if btn != null:
			btn.custom_minimum_size = Vector2(selector_width, selector_height)
			btn.add_theme_font_size_override("font_size", selector_font_size)

func _available_setup_width() -> float:
	var viewport_size := get_viewport_rect().size
	var controls_mode := Config.ControlsMode.OFF
	if Config != null:
		controls_mode = Config.on_screen_controls
	var content_rect := UIHelpers.get_content_rect(viewport_size, controls_mode)
	return clampf(content_rect.size.x * 0.985, 760.0, 1640.0)

func _home_spacing() -> int:
	var height: float = get_viewport_rect().size.y
	if height < 650.0:
		return 8
	if height < 820.0:
		return 12
	return 20

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

func _configure_dpad_navigation() -> void:
	var pickup_buttons := _pickup_card_buttons(true)
	var active_lang_btn = _lang_button if _is_focusable(_lang_button) else null

	# Order: cards → start button → lang → character → trouble → head start
	if not pickup_buttons.is_empty() and _pickup_row.visible:
		_configure_card_row_navigation(pickup_buttons, null, _start_button)
	if _start_button != null:
		_configure_single_button_navigation(_start_button, _selected_pickup_button() if _pickup_row.visible else null, active_lang_btn if active_lang_btn != null else _character_button)
	var lang_top: Control = _start_button
	if active_lang_btn != null:
		_configure_single_button_navigation(_lang_button, lang_top, _character_button)
	var char_top = active_lang_btn if active_lang_btn != null else _start_button
	_configure_single_button_navigation(_character_button, char_top, _first_chaser_button())
	if _is_focusable(_trouble_button):
		_configure_single_button_navigation(_trouble_button, _character_button, _next_after_trouble_button())
	if _is_focusable(_head_start_button):
		_configure_single_button_navigation(_head_start_button, _previous_before_head_start_button(), null)

func _first_chaser_button() -> Button:
	if _is_focusable(_trouble_button):
		return _trouble_button
	if _is_focusable(_head_start_button):
		return _head_start_button
	return null

func _next_after_trouble_button() -> Button:
	if _is_focusable(_head_start_button):
		return _head_start_button
	return null

func _previous_before_head_start_button() -> Button:
	if _is_focusable(_trouble_button):
		return _trouble_button
	return _character_button

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
