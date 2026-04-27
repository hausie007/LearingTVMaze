extends Control

const MissionCatalog := preload("res://scripts/mission_catalog.gd")
const CharacterCatalog := preload("res://scripts/multiplayer/character_catalog.gd")
const LogoTexture := preload("res://images/lm_horizontal.png")

const MP_GREEN := PlayerSlotPanel.MP_GREEN
const MP_GREEN_BORDER := PlayerSlotPanel.MP_GREEN_BORDER
const SLOT_EMPTY_COLOR := PlayerSlotPanel.SLOT_EMPTY_COLOR
const SLOT_EMPTY_BG := PlayerSlotPanel.SLOT_EMPTY_BG

@onready var center_container: CenterContainer = $CenterContainer
@onready var network_debug_label: Label = %NetworkDebugLabel

# ── Layout nodes ────────────────────────────────────────────────────────────
var _main_vbox: VBoxContainer = null
var _top_spacer: Control = null
var _logo: TextureRect = null
var _logo_bread_spacer: Control = null
var _breadcrumb1: Button = null   # Mission • Theme • Maze Size
var _breadcrumb2: Button = null   # Pickup • Language • Action mode + badge
var _bread_players_spacer: Control = null
var _players_row: HBoxContainer = null   # Combined: slots + button
var _slots_row: HBoxContainer = null
var _start_button: Button = null
var _banner_panel: PanelContainer = null

var _slot_nodes: Array[Dictionary] = []  # [{vbox, preview, label, is_filled}]
var _pulse_tween: Tween = null

var _last_lobby_state: Dictionary = {}

func _ready() -> void:
	Input.warp_mouse(Vector2(-1, -1))
	if network_debug_label != null:
		network_debug_label.visible = false

	_build_layout()

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
	_apply_responsive_layout()
	_start_button.call_deferred("grab_focus")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		var viewport: Viewport = get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
		NetworkManager.leave_session()
		get_tree().change_scene_to_file(Scenes.HOME)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_apply_dpad_layout()
		_apply_responsive_layout()

func _on_controls_changed(_new_mode: int) -> void:
	_apply_dpad_layout()
	_apply_responsive_layout()

# ── Layout Building ─────────────────────────────────────────────────────────

func _build_layout() -> void:
	for child in center_container.get_children():
		center_container.remove_child(child)
		child.queue_free()

	_main_vbox = VBoxContainer.new()
	_main_vbox.name = "LobbyVBox"
	_main_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	_main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main_vbox.custom_minimum_size = Vector2(1500, 0)
	_main_vbox.add_theme_constant_override("separation", 10)
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

	# Logo → Breadcrumbs spacer
	_logo_bread_spacer = Control.new()
	_logo_bread_spacer.name = "LogoBreadSpacer"
	_logo_bread_spacer.custom_minimum_size = Vector2(0, 4)
	_main_vbox.add_child(_logo_bread_spacer)

	# Breadcrumb 1: Mission • Theme • Maze Size
	_breadcrumb1 = _build_breadcrumb_row()
	_main_vbox.add_child(_breadcrumb1)

	# Breadcrumb 2: Pickup • Language • Action mode (with badge)
	_breadcrumb2 = _build_breadcrumb_row()
	_main_vbox.add_child(_breadcrumb2)

	# Breadcrumbs → Players row spacer
	_bread_players_spacer = Control.new()
	_bread_players_spacer.name = "BreadPlayersSpacer"
	_bread_players_spacer.custom_minimum_size = Vector2(0, 24)
	_main_vbox.add_child(_bread_players_spacer)

	# Combined row: [Slots] ── [Start Button]
	_players_row = HBoxContainer.new()
	_players_row.name = "PlayersRow"
	_players_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_players_row.add_theme_constant_override("separation", 0)
	_players_row.custom_minimum_size = Vector2(0, 160)
	_main_vbox.add_child(_players_row)

	# Slots sub-row (inside the combined row)
	_slots_row = HBoxContainer.new()
	_slots_row.name = "SlotsRow"
	_slots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_slots_row.add_theme_constant_override("separation", 32)
	_players_row.add_child(_slots_row)

	# Separator between slots and button
	var slot_btn_gap := Control.new()
	slot_btn_gap.name = "SlotBtnGap"
	slot_btn_gap.custom_minimum_size = Vector2(48, 0)
	_players_row.add_child(slot_btn_gap)

	# Start Game button (green, inside the combined row)
	_start_button = Button.new()
	_start_button.text = tr("mp_waiting_for_players")
	_start_button.disabled = true
	_start_button.custom_minimum_size = Vector2(380, 68)
	_start_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_start_button.add_theme_font_size_override("font_size", 30)
	UIHelpers.apply_style_to_button(_start_button, MP_GREEN)
	# Disabled style: outline only (dark bg, bright green border, readable text)
	var disabled_style := UIHelpers.create_rounded_stylebox(UIColors.BG_DARK, MP_GREEN_BORDER, 12, 2)
	_start_button.add_theme_stylebox_override("disabled", disabled_style)
	_start_button.add_theme_color_override("font_disabled_color", Color(0.6, 0.8, 0.6))
	_start_button.pressed.connect(_on_start_now_pressed)
	_players_row.add_child(_start_button)

	# "How to Join" banner
	var banner_spacer := Control.new()
	banner_spacer.custom_minimum_size = Vector2(0, 24)
	_main_vbox.add_child(banner_spacer)

	_build_join_banner()

func _build_breadcrumb_row() -> Button:
	return BreadcrumbRow.create()

func _build_join_banner() -> void:
	_banner_panel = PanelContainer.new()
	_banner_panel.name = "JoinBanner"
	var panel_style := UIHelpers.create_rounded_stylebox(
		Color(UIColors.BG_DARK.r, UIColors.BG_DARK.g, UIColors.BG_DARK.b, 0.85),
		Color(1, 1, 1, 0.12), 14, 1
	)
	panel_style.content_margin_left = 48
	panel_style.content_margin_right = 48
	panel_style.content_margin_top = 30
	panel_style.content_margin_bottom = 30
	_banner_panel.add_theme_stylebox_override("panel", panel_style)
	_banner_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_banner_panel.custom_minimum_size = Vector2(1100, 0)
	_main_vbox.add_child(_banner_panel)

	var banner_vbox := VBoxContainer.new()
	banner_vbox.add_theme_constant_override("separation", 16)
	_banner_panel.add_child(banner_vbox)

	var banner_title := Label.new()
	banner_title.text = tr("mp_how_to_join")
	banner_title.add_theme_font_size_override("font_size", 34)
	banner_title.add_theme_color_override("font_color", UIColors.YELLOW)
	banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_vbox.add_child(banner_title)

	var wifi_name := WiFiHelper.get_wifi_name()
	var wifi_text := ""
	if wifi_name.is_empty():
		wifi_text = tr("mp_wifi_same_as_device")
	else:
		wifi_text = tr("mp_wifi_same_as_device_named") % wifi_name

	# Steps 1, 2, 4 as plain labels
	var plain_steps := [
		tr("mp_join_step_1"),
		tr("mp_join_step_2") % wifi_text,
	]

	for step_text in plain_steps:
		var step_label := Label.new()
		step_label.text = step_text
		step_label.add_theme_font_size_override("font_size", 26)
		step_label.add_theme_color_override("font_color", UIColors.TEXT_SECONDARY)
		step_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		banner_vbox.add_child(step_label)

	# Step 3 with green bold "Play Together"
	var step3 := RichTextLabel.new()
	step3.bbcode_enabled = true
	step3.fit_content = true
	step3.scroll_active = false
	step3.add_theme_font_size_override("normal_font_size", 26)
	step3.add_theme_color_override("default_color", UIColors.TEXT_SECONDARY)
	var green_hex := MP_GREEN_BORDER.to_html(false)
	step3.text = tr("mp_join_step_3") % green_hex
	banner_vbox.add_child(step3)

	# Step 4
	var step4 := Label.new()
	step4.text = tr("mp_join_step_4")
	step4.add_theme_font_size_override("font_size", 26)
	step4.add_theme_color_override("font_color", UIColors.TEXT_SECONDARY)
	step4.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner_vbox.add_child(step4)

# ── Lobby Updates ───────────────────────────────────────────────────────────

func _on_lobby_updated(state: Dictionary) -> void:
	_last_lobby_state = state.duplicate(true)
	var cfg: Dictionary = state.get("config", {}) as Dictionary
	var player_map: Dictionary = state.get("players", {}) as Dictionary

	# Ensure host is collector when chaser is enabled, avoid infinite recursion
	if multiplayer.is_server():
		if bool(cfg.get("rotate_roles_after_round", true)) != false:
			NetworkManager.set_rotate_roles_after_round(false)
		var chaser_on := bool(cfg.get("chaser_enabled", false))
		if chaser_on and int(cfg.get("collector_peer_id", -1)) != NetworkManager.HOST_PEER_ID:
			NetworkManager.set_collector_peer_id(NetworkManager.HOST_PEER_ID)

	_update_breadcrumbs(cfg)
	_update_player_slots(cfg, player_map)
	_update_broadcast_state(cfg, player_map)

func _update_breadcrumbs(cfg: Dictionary) -> void:
	# Breadcrumb 1: Mission • Theme • Maze Size
	var mission_id := String(cfg.get("mission_id", MissionCatalog.MISSION_FOLLOW_TRAIL))
	var mission_title := String(cfg.get("mission_title", tr(MissionCatalog.mission_title_key(mission_id))))
	var theme_title := String(cfg.get("theme_title", ""))
	var diff_key := String(cfg.get("difficulty_key", "diff_easy"))

	var summary1 := "%s  •  %s  •  %s" % [mission_title, theme_title, tr(diff_key)]
	var summary_label_1 := _breadcrumb1.get_meta("summary") as Label
	if summary_label_1 != null:
		summary_label_1.text = summary1

	# Breadcrumb 2: Pickup • Language • Action mode
	var pickup_title := String(cfg.get("training_type_title", ""))
	var training := String(cfg.get("training_type", NetworkManager.TRAINING_WORDS))
	if training == NetworkManager.TRAINING_NONE:
		pickup_title = tr("pickup_none")
	elif pickup_title.is_empty():
		pickup_title = tr(MissionCatalog.pickup_title_key(MissionCatalog.pickup_for_training(training)))

	var chaser_enabled := bool(cfg.get("chaser_enabled", false))
	var action_text := tr("start_vs_chaser") if chaser_enabled else tr("start_together")

	# Language display
	var lang_text := ""
	if training != NetworkManager.TRAINING_NONE:
		var ui_idx := Config.LANG_CODES.find(Config.ui_language)
		if ui_idx < 0: ui_idx = 0
		var lang_idx := Config.LANG_CODES.find(Config.learning_language)
		if lang_idx < 0: lang_idx = 0
		lang_text = "  •  " + Config.get_lang_display_name(lang_idx, true, ui_idx)

	# Player count tag — derive range from mission catalog
	var chaser_on := bool(cfg.get("chaser_enabled", false))
	var player_options := MissionCatalog.max_players_options(mission_id, chaser_on)
	var players_tag := ""
	if player_options.size() <= 1:
		var n := int(player_options[0]) if not player_options.is_empty() else 2
		players_tag = "%d %s" % [n, tr("badge_players_word")]
	else:
		var mn := int(player_options[0])
		var mx := int(player_options[player_options.size() - 1])
		players_tag = "%d-%d %s" % [mn, mx, tr("badge_players_word")]

	var summary2 := "%s%s  •  %s  •  🟢 %s" % [pickup_title, lang_text, action_text, players_tag]
	var summary_label_2 := _breadcrumb2.get_meta("summary") as Label
	if summary_label_2 != null:
		summary_label_2.text = summary2

func _update_player_slots(cfg: Dictionary, player_map: Dictionary) -> void:
	var max_players := int(cfg.get("max_players", 2))
	var player_count := player_map.size()

	# Update button text and state
	var min_players := 2
	var is_ready := player_count >= min_players
	_start_button.disabled = not is_ready

	if is_ready:
		if player_count == 1:
			_start_button.text = tr("mp_start_game_1")
		else:
			_start_button.text = tr("mp_start_game_n") % player_count
		# Filled green style when enabled
		var filled := UIHelpers.create_rounded_stylebox(MP_GREEN.darkened(0.15), MP_GREEN_BORDER, 12, 2)
		_start_button.add_theme_stylebox_override("normal", filled)
		_start_button.add_theme_color_override("font_color", Color.WHITE)
	else:
		_start_button.text = tr("mp_waiting_for_players")
		# Outline-only style when disabled (dark bg, green border)
		var outline := UIHelpers.create_rounded_stylebox(UIColors.BG_DARK, MP_GREEN_BORDER, 12, 2)
		_start_button.add_theme_stylebox_override("normal", outline)

	# Rebuild slots only if max_players changed
	var needs_rebuild := _slot_nodes.size() != max_players
	if needs_rebuild:
		_clear_slots()
		for i in range(max_players):
			_create_slot(i)

	# Fill slots with player data
	var peer_ids := _ordered_peer_ids(player_map)
	for i in range(max_players):
		if i < peer_ids.size():
			var peer_id: int = peer_ids[i]
			var info := player_map[peer_id] as Dictionary
			_fill_slot(i, info)
		else:
			_empty_slot(i)

	_update_pulse_animation()

func _update_broadcast_state(cfg: Dictionary, player_map: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var max_players := int(cfg.get("max_players", 2))
	if player_map.size() >= max_players:
		if NetworkManager.is_broadcasting():
			NetworkManager.pause_broadcasting()
	else:
		if not NetworkManager.is_broadcasting():
			NetworkManager.resume_broadcasting()

# ── Slot Management ─────────────────────────────────────────────────────────

func _create_slot(index: int) -> void:
	var slot_vbox := VBoxContainer.new()
	slot_vbox.name = "Slot%d" % index
	slot_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	slot_vbox.add_theme_constant_override("separation", 8)
	slot_vbox.custom_minimum_size = Vector2(130, 150)

	# Slot frame
	var frame := PanelContainer.new()
	frame.name = "SlotFrame"
	frame.custom_minimum_size = Vector2(110, 110)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slot_vbox.add_child(frame)

	# Character preview (hidden when empty)
	var preview := CharacterPreview.new()
	preview.name = "SlotPreview"
	preview.custom_minimum_size = Vector2(90, 90)
	preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	preview.visible = false
	frame.add_child(preview)

	# Label below slot
	var label := Label.new()
	label.name = "SlotLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.text = tr("mp_slot_waiting")
	label.add_theme_color_override("font_color", UIColors.TEXT_SUBTITLE)
	slot_vbox.add_child(label)

	_slots_row.add_child(slot_vbox)
	_slot_nodes.append({
		"vbox": slot_vbox,
		"frame": frame,
		"preview": preview,
		"label": label,
		"is_filled": false,
	})

	_apply_empty_frame_style(frame)

func _fill_slot(index: int, info: Dictionary) -> void:
	if index >= _slot_nodes.size():
		return
	var slot := _slot_nodes[index]
	var preview := slot["preview"] as CharacterPreview
	var label := slot["label"] as Label
	var frame := slot["frame"] as PanelContainer

	var char_id := String(info.get("character_id", ""))
	_apply_character_preview(char_id, preview)
	preview.visible = true

	if bool(info.get("is_host", false)):
		label.text = tr("mp_slot_you")
		label.add_theme_color_override("font_color", UIColors.YELLOW)
	else:
		label.text = CharacterCatalog.display_name_for_id(char_id)
		label.add_theme_color_override("font_color", UIColors.TEXT_PRIMARY)

	_apply_filled_frame_style(frame)
	slot["is_filled"] = true

func _empty_slot(index: int) -> void:
	if index >= _slot_nodes.size():
		return
	var slot := _slot_nodes[index]
	var preview := slot["preview"] as CharacterPreview
	var label := slot["label"] as Label
	var frame := slot["frame"] as PanelContainer

	preview.visible = false
	label.text = tr("mp_slot_waiting")
	label.add_theme_color_override("font_color", UIColors.TEXT_SUBTITLE)

	_apply_empty_frame_style(frame)
	slot["is_filled"] = false

func _clear_slots() -> void:
	for slot in _slot_nodes:
		var vbox := slot["vbox"] as Control
		if is_instance_valid(vbox):
			vbox.queue_free()
	_slot_nodes.clear()
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
		_pulse_tween = null

func _apply_filled_frame_style(frame: PanelContainer) -> void:
	var style := UIHelpers.create_rounded_stylebox(
		Color(UIColors.BG_DARK.r, UIColors.BG_DARK.g, UIColors.BG_DARK.b, 0.9),
		MP_GREEN_BORDER, 12, 2
	)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	frame.add_theme_stylebox_override("panel", style)

func _apply_empty_frame_style(frame: PanelContainer) -> void:
	var style := UIHelpers.create_rounded_stylebox(
		SLOT_EMPTY_BG,
		SLOT_EMPTY_COLOR, 12, 2
	)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	# Dashed border effect via draw_style
	style.draw_center = true
	frame.add_theme_stylebox_override("panel", style)

func _update_pulse_animation() -> void:
	# Kill any existing pulse
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
		_pulse_tween = null

	# Collect empty slot frames for pulsing
	var empty_frames: Array[PanelContainer] = []
	for slot in _slot_nodes:
		if not slot["is_filled"]:
			empty_frames.append(slot["frame"] as PanelContainer)

	if empty_frames.is_empty():
		return

	# Create repeating pulse tween on empty frames
	_pulse_tween = create_tween()
	_pulse_tween.set_loops()

	for frame in empty_frames:
		frame.modulate = Color(1, 1, 1, 1)

	# Pulse: fade to 0.45 then back to 1.0
	_pulse_tween.tween_method(func(alpha: float):
		for f in empty_frames:
			if is_instance_valid(f):
				f.modulate.a = alpha
	, 1.0, 0.45, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_pulse_tween.tween_method(func(alpha: float):
		for f in empty_frames:
			if is_instance_valid(f):
				f.modulate.a = alpha
	, 0.45, 1.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# ── Helpers ─────────────────────────────────────────────────────────────────

func _ordered_peer_ids(player_map: Dictionary) -> Array[int]:
	return PlayerSlotPanel.ordered_peer_ids(player_map)

func _apply_character_preview(character_id: String, preview: CharacterPreview) -> void:
	PlayerSlotPanel.apply_character_preview(character_id, preview)

func _on_peer_disconnected(_peer_id: int) -> void:
	_on_lobby_updated({
		"config": NetworkManager.host_config,
		"players": NetworkManager.players,
	})

func _on_start_now_pressed() -> void:
	NetworkManager.start_now()

func _on_game_started(_session: Dictionary) -> void:
	get_tree().change_scene_to_file(Scenes.MP_GAME)

# ── Layout ──────────────────────────────────────────────────────────────────

func _apply_dpad_layout() -> void:
	if center_container != null and Config != null:
		UIHelpers.apply_dpad_layout(center_container, Config.on_screen_controls)

func _apply_responsive_layout() -> void:
	var available_width := _available_width()
	var viewport_height: float = get_viewport_rect().size.y
	var short_screen: bool = viewport_height < 820.0

	if _main_vbox != null:
		_main_vbox.custom_minimum_size = Vector2(available_width, viewport_height)
		_main_vbox.add_theme_constant_override("separation", _vbox_spacing())

	if _top_spacer != null:
		_top_spacer.custom_minimum_size.y = clampf(viewport_height * 0.0075, 3.0, 8.0)

	if _logo != null:
		var logo_width: float = clampf(available_width * (0.42 if short_screen else 0.48), 380.0, 780.0)
		var logo_height: float = clampf(logo_width * 0.214, 80.0, 166.0)
		_logo.custom_minimum_size = Vector2(logo_width, logo_height)

	if _logo_bread_spacer != null:
		_logo_bread_spacer.custom_minimum_size.y = 4.0 if short_screen else 8.0

	# Breadcrumb sizing
	var bread_font_size := 26 if short_screen else 30
	var bread_height := 42.0 if short_screen else 50.0
	for bread in [_breadcrumb1, _breadcrumb2]:
		if bread == null:
			continue
		bread.custom_minimum_size = Vector2(clampf(available_width * 0.8, 600.0, 1200.0), bread_height)
		var summary := bread.get_meta("summary") as Label
		if summary != null:
			summary.add_theme_font_size_override("font_size", bread_font_size)
		var chevron := bread.get_meta("chevron") as Label
		if chevron != null:
			chevron.add_theme_font_size_override("font_size", bread_font_size - 2)

	if _bread_players_spacer != null:
		_bread_players_spacer.custom_minimum_size.y = 16.0 if short_screen else 28.0

	# Slot sizing
	var slot_size: float = 100.0 if short_screen else 120.0
	var frame_size: float = slot_size * 0.9
	var preview_size: float = frame_size * 0.78
	for slot in _slot_nodes:
		var vbox := slot["vbox"] as Control
		vbox.custom_minimum_size = Vector2(slot_size + 20, slot_size + 40)
		var frame := slot["frame"] as PanelContainer
		frame.custom_minimum_size = Vector2(frame_size, frame_size)
		var preview := slot["preview"] as CharacterPreview
		preview.custom_minimum_size = Vector2(preview_size, preview_size)
		var label := slot["label"] as Label
		label.add_theme_font_size_override("font_size", 20 if short_screen else 22)

	if _slots_row != null:
		_slots_row.add_theme_constant_override("separation", 28 if short_screen else 36)

	if _players_row != null:
		_players_row.custom_minimum_size.y = slot_size + 62

	# Start button (inside the combined row)
	var action_btn_width: float = clampf(available_width * 0.28, 320.0, 460.0)
	var action_btn_height: float = 60.0 if short_screen else 68.0
	var action_font_size: int = 26 if short_screen else 30
	if _start_button != null:
		_start_button.custom_minimum_size = Vector2(action_btn_width, action_btn_height)
		_start_button.add_theme_font_size_override("font_size", action_font_size)

	# Banner
	if _banner_panel != null:
		_banner_panel.custom_minimum_size.x = clampf(available_width * 0.92, 880.0, 1380.0)
		var banner_font_size := 24 if short_screen else 28
		var title_font_size := 30 if short_screen else 34
		var vbox := _banner_panel.get_child(0) as VBoxContainer
		if vbox != null:
			for i in range(vbox.get_child_count()):
				var child := vbox.get_child(i)
				if child is Label:
					if i == 0:
						child.add_theme_font_size_override("font_size", title_font_size)
					else:
						child.add_theme_font_size_override("font_size", banner_font_size)
				elif child is RichTextLabel:
					child.add_theme_font_size_override("normal_font_size", banner_font_size)
					child.add_theme_font_size_override("bold_font_size", banner_font_size)

func _available_width() -> float:
	var viewport_size := get_viewport_rect().size
	var controls_mode := Config.ControlsMode.OFF
	if Config != null:
		controls_mode = Config.on_screen_controls
	var content_rect := UIHelpers.get_content_rect(viewport_size, controls_mode)
	return clampf(content_rect.size.x * 0.985, 760.0, 1640.0)

func _vbox_spacing() -> int:
	var height: float = get_viewport_rect().size.y
	if height < 650.0:
		return 6
	if height < 820.0:
		return 8
	return 12

func _on_network_debug_changed(scope: String, message: String) -> void:
	if network_debug_label == null:
		return
	network_debug_label.text = "Network [%s]: %s" % [scope, message]
