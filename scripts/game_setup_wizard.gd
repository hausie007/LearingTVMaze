## game_setup_wizard.gd
## ---------------------------------------------------------------------------
## Unified game setup wizard — replaces main_menu, mode_selection, and host_setup.
##
## Three collapsible steps:
##   Step 1: Mission type (Find Exit, Follow Trail, etc.) + Theme & Maze Size
##   Step 2: Pickup type (Numbers, Words, Letters, Just Maze) + Language
##   Step 3: Start action (Solo, +Chaser, Together, vs Chaser) + contextual settings
##
## Each confirmed step collapses to a summary row. Clicking a collapsed row
## re-expands that step. Pressing a Step 3 card starts the game.
## ---------------------------------------------------------------------------
extends Control

const MissionCatalog := preload("res://scripts/mission_catalog.gd")
const LogoTexture := preload("res://images/lm_paper_horizontal.png")

const CARD_GAP := 42

# Step 3 action card IDs
const ACTION_SOLO := "solo"
const ACTION_SOLO_CHASER := "solo_chaser"
const ACTION_COOP := "coop"
const ACTION_VERSUS := "versus"



const PICKUP_CARD_ICONS = MissionCatalog.PICKUP_CARD_ICONS
const PICKUP_CARD_TITLE_KEYS = MissionCatalog.PICKUP_CARD_TITLE_KEYS
const PICKUP_CARD_SUBTITLE_KEYS = MissionCatalog.PICKUP_CARD_SUBTITLE_KEYS

@onready var center_container: CenterContainer = $CenterContainer

# ── Layout nodes ────────────────────────────────────────────────────────────
var _main_vbox: VBoxContainer = null
var _top_spacer: Control = null
var _logo: TextureRect = null
var _logo_step_spacer: Control = null

var _step1: WizardStep = null  # Mission
var _step2: WizardStep = null  # Pickup
var _step3: WizardStep = null  # Action



# Step 1 settings (Theme, Maze Size)
var _theme_button: Button = null
var _theme_title: Label = null
var _theme_left: Label = null
var _theme_right: Label = null
var _maze_size_button: Button = null
var _maze_size_title: Label = null
var _maze_size_left: Label = null
var _maze_size_right: Label = null
var _theme_preview_container: Control = null
var _theme_preview: CharacterPreview = null
var _theme_backplate: Panel = null

# Step 2 settings (Language)
var _lang_button: Button = null
var _lang_left: Label = null
var _lang_right: Label = null

# Step 3 settings (Chaser Speed, Character)
var _chaser_speed_button: Button = null
var _chaser_speed_left: Label = null
var _chaser_speed_right: Label = null
var _chaser_speed_row: HBoxContainer = null
var _chaser_speed_label: Label = null  # the text label in the row
var _character_button: Button = null
var _character_left: Label = null
var _character_right: Label = null
var _character_row: HBoxContainer = null
var _character_preview_container: Control = null
var _character_preview: CharacterPreview = null
var _character_backplate: Panel = null


# ── State ────────────────────────────────────────────────────────────────────
var _current_step: int = 1
var _selected_mission: String = MissionCatalog.DEFAULT_MISSION
var _selected_pickup: String = MissionCatalog.DEFAULT_PICKUP
var _selected_action: String = ACTION_SOLO

var _themes: Array[String] = []
var _theme_idx: int = 0
var _theme_preview_loader: ThemeLoader = null
var _maze_size_idx: int = 0
var _lang_idx: int = 0
var _chaser_speed_idx: int = 1
var _character_catalog: Array[Dictionary] = []
var _character_idx: int = 0


var _input_locked: bool = true


# OLED burn-in protection for the idle setup/home screen.
var _oled_guard: OledIdleGuard = null

# ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	Input.warp_mouse(Vector2(-1, -1))
	_initialize_state()
	_build_layout()
	_update_all_labels()
	_apply_dpad_layout()
	_apply_responsive_layout()
	_configure_navigation()


	if Config != null and not Config.on_screen_controls_changed.is_connected(_on_controls_changed):
		Config.on_screen_controls_changed.connect(_on_controls_changed)

	_step1.focus_selected_card()
	get_tree().create_timer(0.2).timeout.connect(func(): _input_locked = false)

	# OLED: home/setup screen is a menu — release the wake lock.
	DisplayServer.screen_set_keep_on(false)

	# OLED idle guard: dim after 5 min, reload scene after 10 min.
	_oled_guard = OledIdleGuard.new()
	_oled_guard.name = "WizardOledGuard"
	add_child(_oled_guard)
	_oled_guard.idle_tier_1.connect(_on_oled_tier1)
	_oled_guard.idle_tier_2.connect(_on_oled_tier2)
	_oled_guard.idle_reset.connect(_on_oled_reset)
	_oled_guard.start(300.0, 600.0)




# ── OLED Idle Callbacks ───────────────────────────────────────────────────────

## Called after 5 min of home-screen idle: dim the entire wizard and D-pad.
func _on_oled_tier1() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.25, 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if DPad and DPad.visible:
		DPad.dim(0.05, 4.0)


## Called after 10 min of home-screen idle: reload the scene to reset any animations.
func _on_oled_tier2() -> void:
	get_tree().reload_current_scene()


## Called when a deliberate input is detected — restore full brightness.
func _on_oled_reset() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if DPad:
		DPad.undim(0.3)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_apply_dpad_layout()
		_apply_responsive_layout()
		_configure_navigation()

func _on_controls_changed(_new_mode: int) -> void:
	_apply_dpad_layout()
	_apply_responsive_layout()
	_configure_navigation()

# ── State Initialization ─────────────────────────────────────────────────────

func _initialize_state() -> void:
	_selected_mission = Config.selected_mission_id
	if not MissionCatalog.mission_ids().has(_selected_mission):
		_selected_mission = Config.mission_id
	if not MissionCatalog.mission_ids().has(_selected_mission):
		_selected_mission = MissionCatalog.DEFAULT_MISSION

	# Restore pickup from config
	_selected_pickup = MissionCatalog.default_pickup(_selected_mission)
	var existing_pickup := MissionCatalog.pickup_for_training(Config.training_type)
	if MissionCatalog.allowed_pickups(_selected_mission).has(existing_pickup):
		_selected_pickup = existing_pickup

	_themes = ThemeLoader.get_available_themes()
	_theme_idx = _themes.find(Config.theme_dir_name)
	if _theme_idx < 0:
		_theme_idx = 0
	_maze_size_idx = clampi(Config.difficulty, 0, max(0, Config.DIFF_KEYS.size() - 1))
	_lang_idx = Config.LANG_CODES.find(Config.learning_language)
	if _lang_idx < 0:
		_lang_idx = 0
	_character_catalog = CharacterCatalog.build_catalog()
	_character_idx = 0
	var target_char_id := Config.theme_dir_name + ":player"
	for i in range(_character_catalog.size()):
		if String(_character_catalog[i].get("id", "")) == target_char_id:
			_character_idx = i
			break
	# Restore chaser speed from config
	var saved_level: int = int(Config.chaser_level)
	var level_idx := MissionCatalog.CHASER_TUNING_LEVELS.find(saved_level)
	_chaser_speed_idx = level_idx if level_idx >= 0 else 1

# ── Layout Building ──────────────────────────────────────────────────────────

func _build_layout() -> void:
	for child in center_container.get_children():
		center_container.remove_child(child)
		child.queue_free()

	_main_vbox = VBoxContainer.new()
	_main_vbox.name = "WizardVBox"
	_main_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	_main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main_vbox.custom_minimum_size = Vector2(1500, 0)
	_main_vbox.add_theme_constant_override("separation", 12)
	center_container.add_child(_main_vbox)

	# Top spacer
	_top_spacer = Control.new()
	_top_spacer.name = "TopSpacer"
	_top_spacer.custom_minimum_size = Vector2(0, 16)
	_main_vbox.add_child(_top_spacer)

	# Logo
	_logo = TextureRect.new()
	_logo.name = "AppLogo"
	_logo.texture = LogoTexture
	_logo.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.clip_contents = false
	_logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_main_vbox.add_child(_logo)

	_logo_step_spacer = Control.new()
	_logo_step_spacer.name = "LogoStepSpacer"
	_logo_step_spacer.custom_minimum_size = Vector2(0, 4)
	_main_vbox.add_child(_logo_step_spacer)

	# Step 1: Mission
	_step1 = WizardStep.new()
	_step1.name = "Step1_Mission"
	_step1.setup_cards(_build_mission_card_data())
	_step1.select_card(_selected_mission)
	_step1.set_step_title(tr("step1_title"))
	_step1.card_confirmed.connect(_on_step1_confirmed)
	_step1.expand_requested.connect(_on_step1_expand_requested)
	_step1.card_focus_changed.connect(_on_step1_card_focus_changed)
	_main_vbox.add_child(_step1)
	_apply_step1_card_styles()
	_build_step1_settings()

	# Step 2: Pickup
	_step2 = WizardStep.new()
	_step2.name = "Step2_Pickup"
	_step2.set_step_title(tr("step2_title"))
	_step2.card_confirmed.connect(_on_step2_confirmed)
	_step2.expand_requested.connect(_on_step2_expand_requested)
	_step2.card_focus_changed.connect(_on_step2_card_focus_changed)
	_main_vbox.add_child(_step2)
	_build_step2_settings()

	# Step 3: Start Action
	_step3 = WizardStep.new()
	_step3.name = "Step3_Action"
	_step3.set_step_title(tr("step3_title"))
	_step3.card_confirmed.connect(_on_step3_confirmed)
	_step3.expand_requested.connect(_on_step3_expand_requested)
	_step3.card_focus_changed.connect(_on_step3_card_focus_changed)
	_main_vbox.add_child(_step3)
	_build_step3_settings()

	# Start at Step 1
	_step1.activate(false)
	_step2.hide_step(false)
	_step3.hide_step(false)
	_current_step = 1

	# Character preview is now part of the step3 extras container.

# ── Card Data Builders ───────────────────────────────────────────────────────

func _build_mission_card_data() -> Array[Dictionary]:
	var data: Array[Dictionary] = []
	for mission in MissionCatalog.missions():
		data.append({
			"id": String(mission.get("id", "")),
			"icon": String(mission.get("icon", "?")),
			"title": tr(String(mission.get("title_key", ""))),
			"subtitle": tr(String(mission.get("subtitle_key", "")))
		})
	return data

func _build_pickup_card_data() -> Array[Dictionary]:
	var data: Array[Dictionary] = []
	var allowed := MissionCatalog.allowed_pickups(_selected_mission)
	for pickup_id in [MissionCatalog.PICKUP_NUMBERS, MissionCatalog.PICKUP_WORDS, MissionCatalog.PICKUP_LETTERS, MissionCatalog.PICKUP_NONE]:
		if allowed.has(pickup_id):
			data.append({
				"id": pickup_id,
				"icon": String(PICKUP_CARD_ICONS.get(pickup_id, "?")),
				"title": tr(String(PICKUP_CARD_TITLE_KEYS.get(pickup_id, ""))),
				"subtitle": tr(String(PICKUP_CARD_SUBTITLE_KEYS.get(pickup_id, "")))
			})
	return data

func _build_action_card_data() -> Array[Dictionary]:
	var data: Array[Dictionary] = []
	var chaser_allowed := MissionCatalog.chaser_allowed(_selected_mission)
	var chaser_forced_off := MissionCatalog.chaser_forced_off(_selected_mission)
	var chaser_required_mp := MissionCatalog.chaser_required(_selected_mission, true)

	# Single player options (skip in multiplayer-host context)
	if not Config.is_multiplayer_host:
		data.append({"id": ACTION_SOLO, "icon": "res://images/icons/i_play_alone.png", "title": tr("start_alone"), "subtitle": tr("start_alone_desc"), "group": "sp", "badge": "🔵 " + tr("badge_1_player")})
		if chaser_allowed and not chaser_forced_off:
			data.append({"id": ACTION_SOLO_CHASER, "icon": "res://images/icons/i_with_chaser.png", "title": tr("start_with_chaser"), "subtitle": tr("start_with_chaser_desc"), "group": "sp", "badge": "🔵 " + tr("badge_1_player")})

	# Multiplayer options — dynamic player count
	var mp_options_coop := MissionCatalog.max_players_options(_selected_mission, false)
	var mp_options_chaser := MissionCatalog.max_players_options(_selected_mission, true)
	var coop_badge := _player_count_badge(mp_options_coop)
	var chaser_badge := _player_count_badge(mp_options_chaser)

	if not chaser_required_mp:
		data.append({"id": ACTION_COOP, "icon": "res://images/icons/i_play_together2.png", "title": tr("start_together"), "subtitle": tr("start_together_desc"), "group": "mp", "badge": coop_badge})
	if chaser_allowed and not chaser_forced_off:
		data.append({"id": ACTION_VERSUS, "icon": "res://images/icons/i_runner_vs_chaser.png", "title": tr("start_vs_chaser"), "subtitle": tr("start_vs_chaser_desc"), "group": "mp", "badge": chaser_badge})

	return data

func _player_count_badge(options: Array[int]) -> String:
	if options.is_empty():
		return "🟢 " + tr("badge_2_players")
	var mn: int = int(options[0])
	var mx: int = int(options[options.size() - 1])
	if mn == mx:
		return "🟢 %d %s" % [mn, tr("badge_players_word")]
	return "🟢 %d-%d %s" % [mn, mx, tr("badge_players_word")]

## Apply orange-red palette to the competitive "Race to the Middle" card in Step 1.
func _apply_step1_card_styles() -> void:
	var race_card: Button = _step1._cards.get(MissionCatalog.MISSION_RACE_MIDDLE, null) as Button
	if race_card != null:
		race_card.call("set_custom_palette",
			UIColors.CARD_ORANGE_RED_DARK, UIColors.CARD_BORDER_SOFT,
			UIColors.UI_ORANGE_RED, UIColors.RED_ACCENT,
			UIColors.RED_ACCENT, UIColors.TEXT_PRIMARY, UIColors.TEXT_SECONDARY
		)

## Apply semantic palette to multiplayer cards and badges to all Step 3 cards.
## Also set player/chaser preview icons from the selected theme.
func _apply_step3_card_styles(action_data: Array[Dictionary]) -> void:
	var theme_dir := _themes[_theme_idx] if _theme_idx < _themes.size() else "default"

	for data in action_data:
		var id := String(data.get("id", ""))
		var group := String(data.get("group", ""))
		var badge_text := String(data.get("badge", ""))
		var card: Button = _step3._cards.get(id, null) as Button
		if card == null:
			continue

		# Apply badge
		if not badge_text.is_empty():
			var badge_color := UIColors.UI_GREEN if group == "mp" else UIColors.UI_BLUE
			card.call("set_badge", badge_text, badge_color)

		# Apply green palette to all multiplayer cards (coop and versus alike)
		if group == "mp":
			card.call("set_custom_palette",
				UIColors.CARD_GREEN_DARK, UIColors.CARD_BORDER_SOFT,
				UIColors.UI_GREEN, UIColors.GREEN_ACCENT,
				UIColors.GREEN_ACCENT, UIColors.TEXT_PRIMARY, UIColors.TEXT_SECONDARY
			)

		# Theme character previews are no longer applied here.

func _apply_theme_preview_to_card(card: Button, character_id: String) -> void:
	var preview_data: Dictionary = CharacterCatalog.get_preview_data_by_id(character_id)
	var frames_data: Array = preview_data.get("frames", [])
	var frames: Array[Texture2D] = []
	for item in frames_data:
		if item is Texture2D:
			frames.append(item)
	var fps: float = float(preview_data.get("fps", 1.0))
	if not frames.is_empty():
		card.call("set_character_preview", frames, fps)

# ── Settings Builders ────────────────────────────────────────────────────────

func _build_step1_settings() -> void:
	var settings := _step1.get_settings_area()

	var settings_row := HBoxContainer.new()
	settings_row.alignment = BoxContainer.ALIGNMENT_CENTER
	settings_row.add_theme_constant_override("separation", 22)
	settings.add_child(settings_row)

	var selector_vbox := VBoxContainer.new()
	selector_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	selector_vbox.add_theme_constant_override("separation", 12)
	settings_row.add_child(selector_vbox)

	var theme_row := _create_selector_row("setting_theme")
	selector_vbox.add_child(theme_row)
	_theme_title = theme_row.get_meta("title") as Label
	_theme_left = theme_row.get_meta("left") as Label
	_theme_button = theme_row.get_meta("button") as Button
	_theme_right = theme_row.get_meta("right") as Label
	_theme_button.pressed.connect(func(): _cycle_theme(1))
	_setup_cycling(_theme_button, _cycle_theme)
	_setup_arrow_visibility(_theme_button, _theme_left, _theme_right)

	var maze_row := _create_selector_row("setting_diff")
	selector_vbox.add_child(maze_row)
	_maze_size_title = maze_row.get_meta("title") as Label
	_maze_size_left = maze_row.get_meta("left") as Label
	_maze_size_button = maze_row.get_meta("button") as Button
	_maze_size_right = maze_row.get_meta("right") as Label
	_maze_size_button.pressed.connect(func(): _cycle_maze_size(1))
	_setup_cycling(_maze_size_button, _cycle_maze_size)
	_setup_arrow_visibility(_maze_size_button, _maze_size_left, _maze_size_right)

	_theme_preview_container = Control.new()
	_theme_preview_container.name = "ThemePreviewContainer"
	_theme_preview_container.clip_contents = false
	settings_row.add_child(_theme_preview_container)

	# Parchment backplate — paper-cutout backing behind the character sprite
	_theme_backplate = _create_parchment_backplate()
	_theme_preview_container.add_child(_theme_backplate)

	_theme_preview = CharacterPreview.new()
	_theme_preview.name = "ThemePreview"
	_theme_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_theme_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_theme_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_theme_preview_container.add_child(_theme_preview)

func _build_step2_settings() -> void:
	var settings := _step2.get_settings_area()
	var lang_row := _create_selector_row("setting_learning_lang")
	settings.add_child(lang_row)
	_lang_left = lang_row.get_meta("left") as Label
	_lang_button = lang_row.get_meta("button") as Button
	_lang_right = lang_row.get_meta("right") as Label
	_lang_button.pressed.connect(func(): _cycle_lang(1))
	_setup_cycling(_lang_button, _cycle_lang)
	_setup_arrow_visibility(_lang_button, _lang_left, _lang_right)

func _build_step3_settings() -> void:
	var settings := _step3.get_settings_area()

	# Character row FIRST (visible only when MP action is focused)
	_character_row = _create_selector_row("choose_your_player")
	settings.add_child(_character_row)
	_character_left = _character_row.get_meta("left") as Label
	_character_button = _character_row.get_meta("button") as Button
	_character_right = _character_row.get_meta("right") as Label
	_character_button.pressed.connect(func(): _cycle_character(1))
	_setup_cycling(_character_button, _cycle_character)
	_setup_arrow_visibility(_character_button, _character_left, _character_right)

	# Character preview — embedded directly in the row's 'extras' container
	_character_preview_container = Control.new()
	_character_preview_container.name = "CharPreviewOverlay"
	_character_preview_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_character_preview_container.clip_contents = false
	_character_preview_container.visible = false

	# Parchment backplate for character preview
	_character_backplate = _create_parchment_backplate()
	_character_preview_container.add_child(_character_backplate)

	_character_preview = CharacterPreview.new()
	_character_preview.name = "CharPreview"
	_character_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_character_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_character_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_character_preview_container.add_child(_character_preview)
	
	var extras := _character_row.get_meta("extras") as Container
	if extras != null:
		extras.add_child(_character_preview_container)

	# Chaser speed/delay row (visible only when chaser action is focused)
	_chaser_speed_row = _create_selector_row("setting_chaser_speed")
	settings.add_child(_chaser_speed_row)
	_chaser_speed_label = _chaser_speed_row.get_child(0) as Label  # first child is the label
	_chaser_speed_left = _chaser_speed_row.get_meta("left") as Label
	_chaser_speed_button = _chaser_speed_row.get_meta("button") as Button
	_chaser_speed_right = _chaser_speed_row.get_meta("right") as Label
	_chaser_speed_button.pressed.connect(func(): _cycle_chaser_speed(1))
	_setup_cycling(_chaser_speed_button, _cycle_chaser_speed)
	_setup_arrow_visibility(_chaser_speed_button, _chaser_speed_left, _chaser_speed_right)


# ── Step Transition Handlers ─────────────────────────────────────────────────

func _on_step1_confirmed(mission_id: String) -> void:


	_selected_mission = mission_id
	Config.selected_mission_id = mission_id

	# Normalize pickup for this mission
	var allowed := MissionCatalog.allowed_pickups(mission_id)
	if not allowed.has(_selected_pickup):
		_selected_pickup = MissionCatalog.default_pickup(mission_id)

	# Build step 2 cards and collapse step 1
	_step2.setup_cards(_build_pickup_card_data())
	_step2.select_card(_selected_pickup)

	var theme_name := _themes[_theme_idx] if _theme_idx < _themes.size() else "default"
	var loader := ThemeLoader.get_cached(theme_name)
	var theme_display := loader.get_display_title(theme_name) if loader != null else theme_name
	var maze_display := tr(Config.DIFF_KEYS[_maze_size_idx])
	_step1.collapse(tr(MissionCatalog.mission_title_key(mission_id)) + "  •  " + theme_display + "  •  " + maze_display)

	# Auto-skip step 2 if only one pickup option
	if allowed.size() == 1:
		_selected_pickup = String(allowed[0])
		_on_step2_confirmed(_selected_pickup)
		return

	_step2.activate()
	_step3.hide_step(false)
	_current_step = 2
	_update_step2_labels()
	call_deferred("_post_step_transition", 2)

func _on_step2_confirmed(pickup_id: String) -> void:
	_selected_pickup = pickup_id

	# Build step 3 cards and collapse step 2
	var action_data := _build_action_card_data()
	_step3.setup_cards(action_data)
	_step3.select_card(_selected_action)
	_apply_step3_card_styles(action_data)

	# Default character to current theme's player
	var theme_dir := _themes[_theme_idx] if _theme_idx < _themes.size() else "default"
	var target_char := theme_dir + ":player"
	for i in range(_character_catalog.size()):
		if String(_character_catalog[i].get("id", "")) == target_char:
			_character_idx = i
			break
	_update_step3_labels()

	var pickup_display := tr(String(PICKUP_CARD_TITLE_KEYS.get(pickup_id, "pickup_just_maze")))
	var lang_display := ""
	if pickup_id != MissionCatalog.PICKUP_NONE:
		var ui_idx := Config.LANG_CODES.find(Config.ui_language)
		if ui_idx < 0: ui_idx = 0
		lang_display = "  •  " + Config.get_lang_display_name(_lang_idx, true, ui_idx)
	_step2.collapse(pickup_display + lang_display)

	# Auto-skip step 3 if only one action
	if action_data.size() == 1:
		_selected_action = String(action_data[0].get("id", ACTION_SOLO))
		_on_step3_confirmed(_selected_action)
		return

	_step3.activate()
	_current_step = 3
	_update_step3_settings_visibility()
	call_deferred("_post_step_transition", 3)

func _on_step3_confirmed(action_id: String) -> void:
	_selected_action = action_id
	_persist_state()
	match action_id:
		ACTION_SOLO:
			_start_single_player(false)
		ACTION_SOLO_CHASER:
			_start_single_player(true)
		ACTION_COOP:
			_start_multiplayer(false)
		ACTION_VERSUS:
			_start_multiplayer(true)

func _on_step1_expand_requested() -> void:
	_go_back_to_step(1)

func _on_step2_expand_requested() -> void:
	_go_back_to_step(2)

func _on_step3_expand_requested() -> void:
	pass  # Step 3 is never collapsed (it's the final step)

## Smart back: skip steps that were auto-skipped (only 1 option).
func _go_back_smart() -> void:
	var target := _current_step - 1
	# Skip step 2 if it only has 1 pickup option (it was auto-skipped)
	if target == 2:
		var allowed := MissionCatalog.allowed_pickups(_selected_mission)
		if allowed.size() <= 1:
			target = 1
	_go_back_to_step(target)

func _go_back_to_step(target: int) -> void:
	if target >= _current_step:
		return
	# Hide all steps after target
	if target <= 2:
		_step3.hide_step()

		if _character_preview_container != null:
			_character_preview_container.visible = false
	if target <= 1:
		_step2.hide_step()
	# Re-expand target
	match target:
		1:
			_step1.activate()
		2:
			_step2.activate()
	_current_step = target
	call_deferred("_post_step_transition", target)

func _post_step_transition(step: int) -> void:
	_configure_navigation()
	_apply_responsive_layout()
	match step:
		1: _step1.focus_selected_card()
		2: _step2.focus_selected_card()
		3: _step3.focus_selected_card()

func _on_step1_card_focus_changed(_card_id: String) -> void:
	_configure_navigation()

func _on_step2_card_focus_changed(_card_id: String) -> void:
	_update_step2_labels(_card_id)
	_configure_navigation()

func _on_step3_card_focus_changed(_card_id: String) -> void:
	_update_step3_settings_visibility()
	_configure_navigation()
	# Show/hide MP hint
	var is_mp := _card_id == ACTION_COOP or _card_id == ACTION_VERSUS

# ── Game Start Logic ──────────────────────────────────────────────────────────

func _start_single_player(with_chaser: bool) -> void:
	Config.learning_language = Config.LANG_CODES[_lang_idx]
	Config.difficulty = _maze_size_idx
	Config.theme_dir_name = _themes[_theme_idx] if _theme_idx < _themes.size() else "default"
	var speed_level: int = MissionCatalog.CHASER_TUNING_LEVELS[_chaser_speed_idx] if with_chaser else Config.ChaserLevel.OFF
	Config.configure_single_player_session(
		MissionCatalog.style_for_mission(_selected_mission),
		MissionCatalog.training_for_pickup(_selected_pickup),
		with_chaser,
		speed_level,
		_selected_mission,
	)
	Config.save_settings()
	# Player is starting a game — restore the display wake lock.
	DisplayServer.screen_set_keep_on(true)
	UIHelpers.go_to_scene_with_loading(get_tree(), Scenes.GAME)


func _start_multiplayer(with_chaser: bool) -> void:
	Config.learning_language = Config.LANG_CODES[_lang_idx]
	Config.difficulty = _maze_size_idx
	Config.theme_dir_name = _themes[_theme_idx] if _theme_idx < _themes.size() else "default"

	var style := MissionCatalog.style_for_mission(_selected_mission)
	var training := MissionCatalog.training_for_pickup(_selected_pickup)
	var mission_title := tr(MissionCatalog.mission_title_key(_selected_mission))
	var pickup_title := tr(MissionCatalog.pickup_title_key(_selected_pickup))
	var chaser_level: int = MissionCatalog.CHASER_TUNING_LEVELS[_chaser_speed_idx] if with_chaser else Config.ChaserLevel.OFF
	var difficulty := clampi(_maze_size_idx, 0, max(0, Config.DIFF_KEYS.size() - 1))

	var character_id := ""
	if not _character_catalog.is_empty() and _character_idx < _character_catalog.size():
		character_id = String(_character_catalog[_character_idx].get("id", ""))

	var max_players := 2
	var player_options := MissionCatalog.max_players_options(_selected_mission, with_chaser)
	if not player_options.is_empty():
		max_players = int(player_options[player_options.size() - 1])

	var config: Dictionary = {
		"difficulty": difficulty,
		"difficulty_key": Config.DIFF_KEYS[difficulty],
		"mission_id": _selected_mission,
		"mission_title": mission_title,
		"mission_goal_key": MissionCatalog.goal_key(_selected_mission, _selected_pickup, with_chaser, true),
		"role_summary_key": MissionCatalog.role_summary_key(_selected_mission, with_chaser),
		"game_style": style,
		"game_style_title": mission_title,
		"training_type": training,
		"training_type_title": pickup_title,
		"chaser_enabled": with_chaser and style != NetworkManager.STYLE_RACE,
		"chaser_level": chaser_level,
		"rotate_roles_after_round": false,
		"theme_dir": Config.theme_dir_name,
		"theme_title": _theme_display_name(),
		"max_players": max_players,
		"character_id": character_id,
	}

	Config.difficulty = difficulty
	Config.save_settings()
	NetworkManager.configure_host(config)
	var err: int = NetworkManager.start_host()
	if err != OK:
		push_error("Failed to start host: %d" % err)
		return
	get_tree().change_scene_to_file(Scenes.HOST_LOBBY)

# ── Value Cycling ─────────────────────────────────────────────────────────────

func _cycle_theme(dir: int) -> void:
	if _themes.is_empty(): return
	_theme_idx = (_theme_idx + dir + _themes.size()) % _themes.size()
	Config.theme_dir_name = _themes[_theme_idx]
	_update_all_labels()

func _cycle_maze_size(dir: int) -> void:
	_maze_size_idx = (_maze_size_idx + dir + Config.DIFF_KEYS.size()) % Config.DIFF_KEYS.size()
	_update_all_labels()

func _cycle_lang(dir: int) -> void:
	_lang_idx = (_lang_idx + dir + Config.LANG_CODES.size()) % Config.LANG_CODES.size()
	_update_all_labels()

func _cycle_chaser_speed(dir: int) -> void:
	_chaser_speed_idx = (_chaser_speed_idx + dir + MissionCatalog.CHASER_TUNING_LEVELS.size()) % MissionCatalog.CHASER_TUNING_LEVELS.size()
	_update_step3_labels()

func _cycle_character(dir: int) -> void:
	if _character_catalog.is_empty(): return
	_character_idx = (_character_idx + dir + _character_catalog.size()) % _character_catalog.size()
	_update_step3_labels()

# ── Label Updates ─────────────────────────────────────────────────────────────

func _update_all_labels() -> void:
	_update_step1_labels()
	_update_step2_labels()
	_update_step3_labels()

func _update_step1_labels() -> void:
	if _theme_button != null:
		_theme_button.text = _theme_display_name()
	if _maze_size_button != null:
		_maze_size_button.text = tr(Config.DIFF_KEYS[_maze_size_idx])
	_update_theme_preview()

func _update_step2_labels(focused_pickup: String = "") -> void:
	if _lang_button == null: return
	var ui_idx := Config.LANG_CODES.find(Config.ui_language)
	if ui_idx < 0: ui_idx = 0
	_lang_button.text = Config.get_lang_display_name(_lang_idx, true, ui_idx)
	# Hide language selector if the focused pickup is "only the maze" (no collecting)
	var pickup_to_check := focused_pickup if not focused_pickup.is_empty() else _selected_pickup
	var is_collecting := pickup_to_check != MissionCatalog.PICKUP_NONE
	var lang_row := _lang_button.get_parent() as Control
	if lang_row != null:
		lang_row.visible = is_collecting

func _update_step3_labels() -> void:
	if _chaser_speed_button != null:
		var level := MissionCatalog.CHASER_TUNING_LEVELS[_chaser_speed_idx]
		# Use delay-specific labels when in versus ("Chaser Delay") mode
		var focused_action := _step3.get_focused_card_id() if _step3.get_state() == WizardStep.State.ACTIVE else ""
		var is_versus := focused_action == ACTION_VERSUS
		if is_versus:
			_chaser_speed_button.text = tr(MissionCatalog.head_start_title_key(level))
		else:
			_chaser_speed_button.text = tr(Config.CHASER_LEVEL_KEYS[level])
	if _character_button != null and not _character_catalog.is_empty() and _character_idx < _character_catalog.size():
		_character_button.text = String(_character_catalog[_character_idx].get("display_name", ""))
		_update_character_preview()

func _update_step3_settings_visibility() -> void:
	var focused_action := _step3.get_focused_card_id() if _step3.get_state() == WizardStep.State.ACTIVE else ""
	var is_chaser := focused_action in [ACTION_SOLO_CHASER, ACTION_VERSUS]
	var is_mp := focused_action in [ACTION_COOP, ACTION_VERSUS]
	var is_versus := focused_action == ACTION_VERSUS

	if _chaser_speed_row != null:
		_chaser_speed_row.visible = is_chaser
	# Switch label between "Chaser Speed" (solo) and "Chaser Delay" (versus)
	if _chaser_speed_label != null:
		_chaser_speed_label.text = tr("setting_chaser_delay") if is_versus else tr("setting_chaser_speed")
	if _character_row != null:
		_character_row.visible = is_mp
	# Sync overlay visibility
	if _character_preview_container != null:
		_character_preview_container.visible = is_mp
	if is_mp:
		_resize_character_preview()
	# Refresh chaser button text (speed vs delay labels)
	_update_step3_labels()

func _update_theme_preview() -> void:
	var theme_name := _themes[_theme_idx] if _theme_idx < _themes.size() else "default"
	_theme_preview_loader = ThemeLoader.get_cached(theme_name)
	if _theme_preview_loader != null and _theme_preview != null:
		_theme_preview.set_character(_theme_preview_loader.player_frames, _theme_preview_loader.player_fps)

func _update_character_preview() -> void:
	if _character_preview == null or _character_catalog.is_empty(): return
	var char_id := String(_character_catalog[_character_idx].get("id", ""))
	var preview_data := CharacterCatalog.get_preview_data_by_id(char_id)
	var frames_data: Array = preview_data.get("frames", [])
	var frames: Array[Texture2D] = []
	for item in frames_data:
		if item is Texture2D:
			frames.append(item)
	var fps: float = float(preview_data.get("fps", 1.0))
	if not frames.is_empty():
		_character_preview.set_character(frames, fps)
	_resize_character_preview()

## Resize the character preview container (it's auto-positioned by the HBoxContainer).
func _resize_character_preview() -> void:
	if _character_preview_container == null:
		return
	if not _character_preview_container.visible:
		return
	var short_screen: bool = get_viewport_rect().size.y < 820.0
	var ps: float = 94.0 if short_screen else 124.0
	
	# Keep container height at 0 so it doesn't stretch the row (and therefore the button)
	_character_preview_container.custom_minimum_size = Vector2(ps, 0)
	
	# Manually position the preview to overflow the row height (row is ~68px)
	var row_height := 68.0
	_character_preview.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_character_preview.size = Vector2(ps, ps)
	_character_preview.position = Vector2(0, (row_height - ps) / 2.0)
	
	# Position backplate to match the preview with padding
	if _character_backplate != null:
		_position_backplate(_character_backplate, _character_preview.position, Vector2(ps, ps))


## Create a parchment backplate Panel for behind character preview icons.
func _create_parchment_backplate() -> Panel:
	var backplate := Panel.new()
	backplate.name = "ParchmentBackplate"
	backplate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(UIColors.PARCHMENT.r, UIColors.PARCHMENT.g, UIColors.PARCHMENT.b, 0.95)
	style.set_corner_radius_all(18)
	style.set_border_width_all(2)
	style.border_color = UIColors.PARCHMENT_DARK
	style.shadow_color = Color(0, 0, 0, 0.27)
	style.shadow_size = 5
	backplate.add_theme_stylebox_override("panel", style)
	return backplate


## Position a backplate Panel to cover the given preview rect with ~10px padding.
func _position_backplate(bp: Panel, preview_pos: Vector2, preview_size: Vector2) -> void:
	var pad := 10.0
	bp.position = preview_pos - Vector2(pad, pad)
	bp.size = preview_size + Vector2(pad * 2, pad * 2)

func _theme_display_name() -> String:
	var theme_name := _themes[_theme_idx] if _theme_idx < _themes.size() else "default"
	var loader := ThemeLoader.get_cached(theme_name)
	return loader.get_display_title(theme_name) if loader != null else theme_name

# ── Navigation ────────────────────────────────────────────────────────────────

func _configure_navigation() -> void:
	match _current_step:
		1: _configure_step1_nav()
		2: _configure_step2_nav()
		3: _configure_step3_nav()

func _configure_step1_nav() -> void:
	var cards := _step1.get_card_buttons()
	var selected := _step1.get_selected_card_button()
	var first_setting := _theme_button
	_configure_card_row_nav(cards, null, first_setting)
	var sel_or_last: Control = selected if selected != null else _last_card(cards)
	_configure_single_nav(_theme_button, sel_or_last, _maze_size_button)
	_configure_single_nav(_maze_size_button, _theme_button, null)

func _configure_step2_nav() -> void:
	var cards := _step2.get_card_buttons()
	var collapse1 := _step1.get_collapse_row()
	var selected := _step2.get_selected_card_button()
	var first_setting := _lang_button if _lang_button != null and _lang_button.get_parent().visible else null
	_configure_single_nav(collapse1, null, null)  # Left/Right locked
	collapse1.focus_neighbor_bottom = collapse1.get_path_to(selected if selected != null else cards[0]) if not cards.is_empty() else NodePath()
	_configure_card_row_nav(cards, collapse1, first_setting)
	if _lang_button != null and _lang_button.get_parent().visible:
		_configure_single_nav(_lang_button, selected if selected != null else _last_card(cards), null)

func _configure_step3_nav() -> void:
	var cards := _step3.get_card_buttons()
	var selected := _step3.get_selected_card_button()
	var collapse2 := _step2.get_collapse_row()
	var collapse1 := _step1.get_collapse_row()
	_configure_single_nav(collapse1, null, null)
	collapse1.focus_neighbor_bottom = collapse1.get_path_to(collapse2)
	_configure_single_nav(collapse2, collapse1, null)
	collapse2.focus_neighbor_bottom = collapse2.get_path_to(selected if selected != null else cards[0]) if not cards.is_empty() else NodePath()

	# Cards → settings below
	var first_below := _first_visible_step3_setting()
	_configure_card_row_nav(cards, collapse2, first_below)

	# Settings chain
	var visible_settings: Array[Button] = []
	if _character_row != null and _character_row.visible:
		visible_settings.append(_character_button)
	if _chaser_speed_row != null and _chaser_speed_row.visible:
		visible_settings.append(_chaser_speed_button)
	var sel_or_last: Control = selected if selected != null else _last_card(cards)
	for i in range(visible_settings.size()):
		var above: Control = sel_or_last if i == 0 else visible_settings[i - 1]
		var below: Control = visible_settings[i + 1] if i + 1 < visible_settings.size() else null
		_configure_single_nav(visible_settings[i], above, below)

func _first_visible_step3_setting() -> Control:
	if _character_row != null and _character_row.visible:
		return _character_button
	if _chaser_speed_row != null and _chaser_speed_row.visible:
		return _chaser_speed_button
	return null

func _configure_card_row_nav(cards: Array[Button], above: Control, below: Control) -> void:
	if cards.is_empty(): return
	var is_rtl := is_layout_rtl()
	for i in range(cards.size()):
		var card := cards[i]
		# In RTL, visual left = next index, visual right = previous index
		var left_idx := (i + 1) % cards.size() if is_rtl else (i - 1 + cards.size()) % cards.size()
		var right_idx := (i - 1 + cards.size()) % cards.size() if is_rtl else (i + 1) % cards.size()
		card.focus_neighbor_left = card.get_path_to(cards[left_idx])
		card.focus_neighbor_right = card.get_path_to(cards[right_idx])
		if above != null:
			card.focus_neighbor_top = card.get_path_to(above)
		if below != null:
			card.focus_neighbor_bottom = card.get_path_to(below)

func _configure_single_nav(button: Control, top: Control, bottom: Control) -> void:
	if button == null: return
	button.focus_neighbor_left = button.get_path_to(button)
	button.focus_neighbor_right = button.get_path_to(button)
	if top != null:
		button.focus_neighbor_top = button.get_path_to(top)
	if bottom != null:
		button.focus_neighbor_bottom = button.get_path_to(bottom)


func _last_card(cards: Array[Button]) -> Button:
	return cards[-1] if not cards.is_empty() else null

# ── Responsive Layout ─────────────────────────────────────────────────────────

func _apply_responsive_layout() -> void:
	var viewport_size := get_viewport_rect().size
	var available_width := _available_width()
	var short_screen: bool = viewport_size.y < 820.0

	if _main_vbox != null:
		_main_vbox.custom_minimum_size = Vector2(available_width, viewport_size.y)
		_main_vbox.add_theme_constant_override("separation", _spacing())

	# Deferred logging so we see the exact post-layout state of every single node


	if _top_spacer != null:
		_top_spacer.custom_minimum_size.y = clampf(viewport_size.y * 0.005, 2.0, 8.0)

	if _logo != null:
		var logo_width := clampf(available_width * (0.42 if short_screen else 0.48), 380.0, 780.0)
		_logo.custom_minimum_size = Vector2(logo_width, logo_width * 0.214)

	if _logo_step_spacer != null:
		_logo_step_spacer.custom_minimum_size.y = 6.0 if short_screen else 12.0

	# Card sizing for active step
	_apply_card_sizing(_step1, available_width, viewport_size.y, short_screen)
	_apply_card_sizing(_step2, available_width, viewport_size.y, short_screen)
	_apply_card_sizing(_step3, available_width, viewport_size.y, short_screen)

	# Selector sizing
	var sel_w := clampf(available_width * 0.32, 380.0, 500.0)
	var sel_h: float = 58.0 if short_screen else 66.0
	var sel_fs: int = 28 if short_screen else 31
	for btn in [_theme_button, _maze_size_button, _lang_button, _chaser_speed_button, _character_button]:
		if btn != null:
			btn.custom_minimum_size = Vector2(sel_w, sel_h)
			btn.add_theme_font_size_override("font_size", sel_fs)

	if _theme_preview_container != null:
		var ps: float = 94.0 if short_screen else 124.0
		_theme_preview_container.custom_minimum_size = Vector2(ps, ps)
		if _theme_preview != null:
			_theme_preview.custom_minimum_size = Vector2(ps, ps)
		if _theme_backplate != null:
			_position_backplate(_theme_backplate, Vector2.ZERO, Vector2(ps, ps))

	if _character_preview_container != null and _character_preview_container.visible:
		_resize_character_preview()


	
	# After all cards are resized and elements positioned, force the main container
	# to discard any bloated sizes from the previous layout pass.
	if _main_vbox != null:
		_main_vbox.size = Vector2.ZERO
	

func _apply_card_sizing(step: WizardStep, available_width: float, viewport_height: float, short_screen: bool) -> void:
	if step == null or step.get_state() != WizardStep.State.ACTIVE: return
	var cards := step.get_card_buttons()
	if cards.is_empty(): return
	var count := cards.size()
	var columns: int = count if available_width >= 760.0 else mini(count, 2)
	var space_per_card := available_width / float(columns)
	var gap: int = 48 if space_per_card >= 260.0 else (34 if space_per_card >= 200.0 else 24)
	var gaps := float(gap * maxi(0, columns - 1))
	var card_width := clampf(floorf((available_width - gaps) / float(columns)), 140.0, 390.0)
	var card_height := clampf(viewport_height * (0.30 if short_screen else 0.28), 220.0, 310.0)
	var icon_size: int = 46 if card_width < 220.0 else (52 if card_width < 270.0 else 58)
	var title_size: int = 24 if card_width < 220.0 else (28 if card_width < 270.0 else 31)
	var subtitle_size: int = 17 if card_width < 250.0 else 19
	step.set_card_gap(gap)
	step.set_title_font_size(title_size + 8)

	for card in cards:
		card.custom_minimum_size = Vector2(card_width, card_height)
		card.size = Vector2.ZERO
		card.pivot_offset = Vector2(card_width * 0.5, card_height * 0.5)
		card.call("configure_compact", icon_size, title_size, subtitle_size)


func _apply_dpad_layout() -> void:
	if center_container != null and Config != null:
		UIHelpers.apply_dpad_layout(center_container, Config.on_screen_controls)

func _available_width() -> float:
	var viewport_size := get_viewport_rect().size
	var controls_mode := Config.ControlsMode.OFF
	if Config != null:
		controls_mode = Config.on_screen_controls as Config.ControlsMode
	var content_rect := UIHelpers.get_content_rect(viewport_size, controls_mode)
	return clampf(content_rect.size.x * 0.985, 760.0, 1640.0)

func _spacing() -> int:
	var h := get_viewport_rect().size.y
	if h < 650.0: return 6
	if h < 820.0: return 10
	return 14

# ── Utility ───────────────────────────────────────────────────────────────────

func _create_selector_row(label_key: String) -> HBoxContainer:
	return CyclingSelector.create_row(label_key)

func _create_arrow_label() -> Label:
	return CyclingSelector.create_arrow_label()



func _setup_arrow_visibility(button: Button, left: Label, right: Label) -> void:
	CyclingSelector.setup_arrow_visibility(button, left, right)

func _setup_cycling(button: Button, cycle_func: Callable) -> void:
	CyclingSelector.setup_cycling(button, cycle_func)

func _persist_state() -> void:
	Config.selected_mission_id = _selected_mission
	Config.learning_language = Config.LANG_CODES[_lang_idx]
	Config.difficulty = _maze_size_idx
	Config.theme_dir_name = _themes[_theme_idx] if _theme_idx < _themes.size() else "default"
	Config.training_type = MissionCatalog.training_for_pickup(_selected_pickup)
	Config.save_settings()

# ── Input ─────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if _input_locked: return
	if not event.is_action_pressed("ui_cancel"): return

	if _current_step > 1:
		_go_back_smart()
		get_viewport().set_input_as_handled()
	else:
		# Return to the top-level menu
		get_viewport().set_input_as_handled()
		_persist_state()
		get_tree().change_scene_to_file(Scenes.HOME)
