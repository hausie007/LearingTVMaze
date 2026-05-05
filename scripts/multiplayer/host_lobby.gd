extends Control

const MissionCatalog := preload("res://scripts/mission_catalog.gd")
const LogoTexture := preload("res://images/lm_paper_horizontal.png")
const ModeCardScene := preload("res://scenes/ui/mode_card.tscn")

const MP_GREEN := PlayerSlotPanel.MP_GREEN
const MP_GREEN_BORDER := PlayerSlotPanel.MP_GREEN_BORDER
const SLOT_EMPTY_COLOR := PlayerSlotPanel.SLOT_EMPTY_COLOR
const SLOT_EMPTY_BG := PlayerSlotPanel.SLOT_EMPTY_BG
const JOIN_CARD_NAME_COLOR := Color("#63B7FF")

@onready var center_container: CenterContainer = $CenterContainer
@onready var network_debug_label: Label = %NetworkDebugLabel

# ── Layout nodes ────────────────────────────────────────────────────────────
var _main_vbox: VBoxContainer = null
var _top_spacer: Control = null
var _logo: TextureRect = null
var _unified_card: PanelContainer = null
var _condensed_title: Label = null
var _slots_row: HBoxContainer = null
var _start_button: Button = null
var _banner_panel: PanelContainer = null

var _slot_nodes: Array[Dictionary] = []  # [{vbox, preview, label, is_filled}]
var _pulse_tween: Tween = null

var _last_lobby_state: Dictionary = {}

# OLED burn-in protection
var _oled_guard: OledIdleGuard = null

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

	# OLED: lobby is a static waiting screen — keep the display wake-lock OFF
	# so the system can enter Ambient Mode if the host leaves it unattended.
	DisplayServer.screen_set_keep_on(false)

	# OLED idle guard: dim overlay after 3 min, go home after 5 min.
	_oled_guard = OledIdleGuard.new()
	_oled_guard.name = "HostLobbyOledGuard"
	add_child(_oled_guard)
	_oled_guard.idle_tier_1.connect(_on_oled_tier1)
	_oled_guard.idle_tier_2.connect(_on_oled_tier2)
	_oled_guard.idle_reset.connect(_on_oled_reset)
	_oled_guard.start(180.0, 300.0)

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

	# Spacer before Unified Card
	var card_spacer := Control.new()
	card_spacer.custom_minimum_size = Vector2(0, 16)
	_main_vbox.add_child(card_spacer)

	# Unified Card
	_unified_card = PanelContainer.new()
	_unified_card.name = "UnifiedCard"
	var card_style := UIHelpers.create_rounded_stylebox(UIColors.CARD_NEUTRAL_ALT, UIColors.CARD_BORDER_SOFT, 16, 2)
	card_style.content_margin_left = 32
	card_style.content_margin_right = 32
	card_style.content_margin_top = 24
	card_style.content_margin_bottom = 32
	_unified_card.add_theme_stylebox_override("panel", card_style)
	_unified_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_main_vbox.add_child(_unified_card)

	var card_vbox := VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 24)
	card_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_unified_card.add_child(card_vbox)

	# Condensed Title
	_condensed_title = Label.new()
	_condensed_title.name = "CondensedTitle"
	_condensed_title.add_theme_font_size_override("font_size", 28)
	_condensed_title.add_theme_color_override("font_color", UIColors.FOCUS_GOLD)
	_condensed_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_condensed_title.focus_mode = Control.FOCUS_NONE
	card_vbox.add_child(_condensed_title)

	# Slots Row
	_slots_row = HBoxContainer.new()
	_slots_row.name = "SlotsRow"
	_slots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_slots_row.add_theme_constant_override("separation", 48)
	card_vbox.add_child(_slots_row)

	# Start Game Button (Hero Button)
	_start_button = Button.new()
	_start_button.text = tr("mp_waiting_for_players")
	_start_button.custom_minimum_size = Vector2(500, 72)
	_start_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_start_button.focus_mode = Control.FOCUS_ALL
	_start_button.add_theme_font_size_override("font_size", 32)
	UIHelpers.apply_style_to_button(_start_button, MP_GREEN)
	_start_button.pressed.connect(_on_start_now_pressed)
	card_vbox.add_child(_start_button)

	# "How to Join" banner
	var banner_spacer := Control.new()
	banner_spacer.custom_minimum_size = Vector2(0, 24)
	_main_vbox.add_child(banner_spacer)

	_build_join_banner()

func _build_join_banner() -> void:
	# Main HBox: [BannerVBox] [QrColumn]
	# The join card lives inside BannerVBox, next to the steps (not the title)
	var main_hbox := HBoxContainer.new()
	main_hbox.name = "BannerHBox"
	main_hbox.add_theme_constant_override("separation", 48)
	main_hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	main_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main_vbox.add_child(main_hbox)

	# ── Left column: title + [steps | card] ──────────────────────────────────
	var banner_vbox := VBoxContainer.new()
	banner_vbox.name = "BannerVBox"
	banner_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	banner_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	banner_vbox.custom_minimum_size.x = 0
	banner_vbox.add_theme_constant_override("separation", 12)
	main_hbox.add_child(banner_vbox)

	var banner_title := Label.new()
	banner_title.name = "BannerTitle"
	banner_title.text = tr("mp_how_to_join")
	banner_title.add_theme_font_size_override("font_size", 44)
	banner_title.add_theme_color_override("font_color", UIColors.YELLOW)
	banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	banner_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	banner_title.custom_minimum_size.x = 0
	banner_vbox.add_child(banner_title)

	# Inner HBox: [steps] [join card]
	# Card is beside the steps only — it doesn't reach the title level
	var steps_card_hbox := HBoxContainer.new()
	steps_card_hbox.name = "StepsCardHBox"
	steps_card_hbox.add_theme_constant_override("separation", 22)
	steps_card_hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	steps_card_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	banner_vbox.add_child(steps_card_hbox)

	# Steps VBox (expands horizontally, card stays at shrink width)
	var steps_vbox := VBoxContainer.new()
	steps_vbox.name = "StepsVBox"
	steps_vbox.add_theme_constant_override("separation", 10)
	steps_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	steps_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	steps_vbox.custom_minimum_size.x = 0
	steps_card_hbox.add_child(steps_vbox)

	var wifi_name := WiFiHelper.get_wifi_name()
	var wifi_suffix := " (%s)" % wifi_name if not wifi_name.is_empty() else ""
	var join_card_title := tr("menu_join_game")
	var join_card_name_color := JOIN_CARD_NAME_COLOR.to_html(false)

	# Step 1 — RichTextLabel for [b]Learning Maze[/b] bold rendering
	var step1 := RichTextLabel.new()
	step1.name = "Step1Label"
	step1.bbcode_enabled = true
	step1.text = tr("mp_join_step_phone")
	step1.add_theme_font_override("normal_font", UIHelpers.get_font_at_weight(UIHelpers.WEIGHT_MEDIUM))
	step1.add_theme_font_override("bold_font", UIHelpers.get_font_at_weight(UIHelpers.WEIGHT_BOLD))
	step1.add_theme_font_size_override("normal_font_size", 35)
	step1.add_theme_font_size_override("bold_font_size", 35)
	step1.add_theme_color_override("default_color", UIColors.TEXT_SECONDARY)
	step1.fit_content = true
	step1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	step1.scroll_active = false
	step1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	step1.custom_minimum_size.x = 0
	steps_vbox.add_child(step1)

	var step2 := Label.new()
	step2.name = "Step2Label"
	step2.text = tr("mp_join_step_wifi") % wifi_suffix
	step2.add_theme_font_size_override("font_size", 35)
	step2.add_theme_color_override("font_color", UIColors.TEXT_SECONDARY)
	step2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	step2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	step2.custom_minimum_size.x = 0
	steps_vbox.add_child(step2)

	var step3 := RichTextLabel.new()
	step3.name = "Step3Label"
	step3.bbcode_enabled = true
	step3.text = tr("mp_join_step_open_card") % [join_card_name_color, join_card_title]
	step3.add_theme_font_override("normal_font", UIHelpers.get_font_at_weight(UIHelpers.WEIGHT_MEDIUM))
	step3.add_theme_font_override("bold_font", UIHelpers.get_font_at_weight(UIHelpers.WEIGHT_BOLD))
	step3.add_theme_font_size_override("normal_font_size", 35)
	step3.add_theme_font_size_override("bold_font_size", 35)
	step3.add_theme_color_override("default_color", UIColors.TEXT_SECONDARY)
	step3.fit_content = true
	step3.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	step3.scroll_active = false
	step3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	step3.custom_minimum_size.x = 0
	steps_vbox.add_child(step3)

	# Step 4 — RichTextLabel for bold "control the player on this screen"
	var step4 := RichTextLabel.new()
	step4.name = "Step4Label"
	step4.bbcode_enabled = true
	step4.text = tr("mp_join_step_control")
	step4.add_theme_font_override("normal_font", UIHelpers.get_font_at_weight(UIHelpers.WEIGHT_MEDIUM))
	step4.add_theme_font_override("bold_font", UIHelpers.get_font_at_weight(UIHelpers.WEIGHT_BOLD))
	step4.add_theme_font_size_override("normal_font_size", 35)
	step4.add_theme_font_size_override("bold_font_size", 35)
	step4.add_theme_color_override("default_color", UIColors.TEXT_SECONDARY)
	step4.fit_content = true
	step4.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	step4.scroll_active = false
	step4.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	step4.custom_minimum_size.x = 0
	steps_vbox.add_child(step4)

	# Join card — compact reference preview beside the steps.
	var join_card: Button = ModeCardScene.instantiate() as Button
	join_card.name = "JoinGameCard"
	join_card.call("setup",
		"res://images/icons/i_join_game.png",
		tr("menu_join_game"),
		""
	)
	join_card.call("configure_compact", 34, 22, 0, Vector2(42, 42))
	join_card.call("set_custom_palette",
		UIColors.CARD_BLUE_DARK, UIColors.CARD_BORDER_SOFT,
		UIColors.UI_BLUE, UIColors.BLUE_ACCENT,
		UIColors.BLUE_ACCENT, UIColors.TEXT_PRIMARY, UIColors.TEXT_SECONDARY
	)
	join_card.custom_minimum_size = Vector2(250, 280)
	join_card.focus_mode = Control.FOCUS_NONE
	join_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	join_card.size_flags_horizontal = Control.SIZE_SHRINK_END
	join_card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	steps_card_hbox.add_child(join_card)

	# ── Right: QR code column ─────────────────────────────────────────────────
	var qr_vbox := VBoxContainer.new()
	qr_vbox.name = "QrVBox"
	qr_vbox.add_theme_constant_override("separation", 10)
	qr_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	qr_vbox.custom_minimum_size.x = 260
	qr_vbox.size_flags_horizontal = Control.SIZE_SHRINK_END
	qr_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	main_hbox.add_child(qr_vbox)

	# "Don't have the app?" above the QR
	var no_app_label := Label.new()
	no_app_label.name = "NoAppLabel"
	no_app_label.text = tr("mp_banner_no_app")
	no_app_label.add_theme_font_size_override("font_size", 26)
	no_app_label.add_theme_color_override("font_color", UIColors.TEXT_SECONDARY)
	no_app_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	no_app_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	qr_vbox.add_child(no_app_label)

	# QR image
	var qr_rect := TextureRect.new()
	qr_rect.name = "QrRect"
	qr_rect.texture = preload("res://images/qr_playstore.png")
	qr_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	qr_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	qr_rect.custom_minimum_size = Vector2(220, 220)
	qr_vbox.add_child(qr_rect)

	# "Scan to Download" below the QR
	var qr_title := Label.new()
	qr_title.name = "QrTitleLabel"
	qr_title.text = tr("mp_banner_qr_title")
	qr_title.add_theme_font_size_override("font_size", 24)
	qr_title.add_theme_color_override("font_color", UIColors.TEXT_SECONDARY)
	qr_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qr_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	qr_vbox.add_child(qr_title)


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

	if _condensed_title != null:
		_condensed_title.text = "%s\n%s" % [summary1, summary2]

func _update_player_slots(cfg: Dictionary, player_map: Dictionary) -> void:
	var max_players := int(cfg.get("max_players", 2))
	var player_count := player_map.size()

	# Update button text and state
	var min_players := 2
	var is_ready := player_count >= min_players

	if is_ready:
		if player_count == 1:
			_start_button.text = tr("mp_start_game_1")
		else:
			_start_button.text = tr("mp_start_game_n") % player_count
		# Filled green style when enabled
		var filled := UIHelpers.create_rounded_stylebox(MP_GREEN.darkened(0.15), MP_GREEN_BORDER, 12, 2)
		var hover := UIHelpers.create_rounded_stylebox(MP_GREEN, MP_GREEN_BORDER, 12, 2)
		var pressed_style := UIHelpers.create_rounded_stylebox(MP_GREEN.darkened(0.3), MP_GREEN_BORDER, 12, 2)
		_start_button.add_theme_stylebox_override("normal", filled)
		_start_button.add_theme_stylebox_override("hover", hover)
		_start_button.add_theme_stylebox_override("pressed", pressed_style)
		_start_button.add_theme_color_override("font_color", Color.WHITE)
		_start_button.add_theme_color_override("font_hover_color", Color.WHITE)
		_start_button.add_theme_color_override("font_pressed_color", Color.WHITE)
	else:
		_start_button.text = tr("mp_waiting_for_players")
		# Outline-only style when disabled (dark bg, green border)
		var outline := UIHelpers.create_rounded_stylebox(UIColors.BG_DARK, MP_GREEN_BORDER, 12, 2)
		_start_button.add_theme_stylebox_override("normal", outline)
		_start_button.add_theme_stylebox_override("hover", outline)
		_start_button.add_theme_stylebox_override("pressed", outline)
		var disabled_color = Color(0.6, 0.8, 0.6)
		_start_button.add_theme_color_override("font_color", disabled_color)
		_start_button.add_theme_color_override("font_hover_color", disabled_color)
		_start_button.add_theme_color_override("font_pressed_color", disabled_color)

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
			_fill_slot(i, peer_id, info)
		else:
			_empty_slot(i)

	_update_pulse_animation()
	_update_navigation()

func _update_navigation() -> void:
	if _start_button == null:
		return

	# Determine which slots are focusable
	var focusable_slots: Array[Button] = []
	for slot in _slot_nodes:
		var frame := slot["frame"] as Button
		if frame.focus_mode != Control.FOCUS_NONE:
			focusable_slots.append(frame)

	if focusable_slots.is_empty():
		_start_button.focus_neighbor_top = _start_button.get_path_to(_start_button)
	else:
		_start_button.focus_neighbor_top = _start_button.get_path_to(focusable_slots[0])
		for i in range(focusable_slots.size()):
			var frame = focusable_slots[i]
			frame.focus_neighbor_bottom = frame.get_path_to(_start_button)

			var prev_idx = i - 1 if i > 0 else i
			var next_idx = i + 1 if i < focusable_slots.size() - 1 else i
			frame.focus_neighbor_left = frame.get_path_to(focusable_slots[prev_idx])
			frame.focus_neighbor_right = frame.get_path_to(focusable_slots[next_idx])

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

func _on_network_debug_changed(scope: String, message: String) -> void:
	if network_debug_label != null:
		network_debug_label.text = "Network [%s]: %s" % [scope, message]

func _leave_session() -> void:
	NetworkManager.leave_session()
	NetworkManager.stop_broadcasting()
	var main_scene = load("res://scenes/main_menu.tscn")
	get_tree().change_scene_to_packed(main_scene)

# ── Slot Management ─────────────────────────────────────────────────────────

func _create_slot(index: int) -> void:
	var slot_vbox := VBoxContainer.new()
	slot_vbox.name = "Slot%d" % index
	slot_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	slot_vbox.add_theme_constant_override("separation", 8)
	slot_vbox.custom_minimum_size = Vector2(130, 150)

	# Slot frame
	var frame := Button.new()
	frame.name = "SlotFrame"
	frame.custom_minimum_size = Vector2(110, 110)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	frame.focus_mode = Control.FOCUS_NONE
	slot_vbox.add_child(frame)

	var center := CenterContainer.new()
	center.name = "SlotCenter"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(center)

	# Character preview (hidden when empty)
	var preview := CharacterPreview.new()
	preview.name = "SlotPreview"
	preview.custom_minimum_size = Vector2(90, 90)
	preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.visible = false
	center.add_child(preview)

	# Kick icon (hidden by default)
	var kick_icon := Label.new()
	kick_icon.text = "X"
	kick_icon.name = "KickIcon"
	kick_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kick_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	kick_icon.add_theme_font_size_override("font_size", 84)
	kick_icon.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2, 0.9))
	kick_icon.add_theme_color_override("font_outline_color", Color.WHITE)
	kick_icon.add_theme_constant_override("outline_size", 6)
	kick_icon.visible = false
	center.add_child(kick_icon)

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
		"kick_icon": kick_icon,
		"is_filled": false,
		"peer_id": 0,
	})

	frame.pressed.connect(_on_slot_pressed.bind(index))
	frame.focus_entered.connect(_on_slot_focus_entered.bind(index))
	frame.focus_exited.connect(_on_slot_focus_exited.bind(index))
	frame.pivot_offset = Vector2(55, 55)

	_apply_empty_frame_style(frame)

func _on_slot_pressed(index: int) -> void:
	if index >= _slot_nodes.size():
		return

	var slot = _slot_nodes[index]
	if slot["is_filled"]:
		var peer_id = slot["peer_id"] as int
		if peer_id != 0 and peer_id != multiplayer.get_unique_id():
			NetworkManager.kick_player(peer_id)
			if _start_button != null:
				_start_button.grab_focus()
	else:
		_emulate_player_join()

func _on_slot_focus_entered(index: int) -> void:
	if index >= _slot_nodes.size():
		return
	var slot = _slot_nodes[index]
	var frame := slot["frame"] as Button
	create_tween().tween_property(frame, "scale", Vector2(1.1, 1.1), 0.1).set_trans(Tween.TRANS_SINE)
	if slot["is_filled"]:
		var kick_icon := slot["kick_icon"] as Label
		kick_icon.visible = true

func _on_slot_focus_exited(index: int) -> void:
	if index >= _slot_nodes.size():
		return
	var slot = _slot_nodes[index]
	var frame := slot["frame"] as Button
	create_tween().tween_property(frame, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE)
	var kick_icon := slot["kick_icon"] as Label
	kick_icon.visible = false
			
func _emulate_player_join() -> void:
	var prefix = Config.theme_dir_name + ":"
	var used_chars = []
	for p in NetworkManager.players.values():
		used_chars.append(p.get("character_id", ""))
		
	var available = []
	for cat in CharacterCatalog.build_catalog():
		var cid = cat.get("id", "")
		if cid.begins_with(prefix) and not used_chars.has(cid):
			available.append(cid)
			
	if available.is_empty():
		for cat in CharacterCatalog.build_catalog():
			var cid = cat.get("id", "")
			if not used_chars.has(cid):
				available.append(cid)
				
	if not available.is_empty():
		var random_char = available[randi() % available.size()]
		NetworkManager.emulate_remote_player_join(random_char)

func _fill_slot(index: int, peer_id: int, info: Dictionary) -> void:
	if index >= _slot_nodes.size():
		return
	var slot := _slot_nodes[index]
	var preview := slot["preview"] as CharacterPreview
	var label := slot["label"] as Label
	var frame := slot["frame"] as Button

	var char_id := String(info.get("character_id", ""))
	_apply_character_preview(char_id, preview)
	preview.visible = true

	if bool(info.get("is_host", false)):
		label.text = tr("mp_slot_you")
		label.add_theme_color_override("font_color", UIColors.YELLOW)
		frame.focus_mode = Control.FOCUS_NONE
	else:
		label.text = CharacterCatalog.display_name_for_id(char_id)
		label.add_theme_color_override("font_color", UIColors.TEXT_PRIMARY)
		frame.focus_mode = Control.FOCUS_ALL

	_apply_filled_frame_style(frame)
	slot["is_filled"] = true
	slot["peer_id"] = peer_id

func _empty_slot(index: int) -> void:
	if index >= _slot_nodes.size():
		return
	var slot := _slot_nodes[index]
	var preview := slot["preview"] as CharacterPreview
	var label := slot["label"] as Label
	var frame := slot["frame"] as Button

	preview.visible = false
	label.text = tr("mp_slot_waiting")
	label.add_theme_color_override("font_color", UIColors.TEXT_SUBTITLE)
	frame.focus_mode = Control.FOCUS_NONE

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

func _apply_filled_frame_style(frame: Button) -> void:
	var style := UIHelpers.create_rounded_stylebox(
		Color(UIColors.BG_DARK.r, UIColors.BG_DARK.g, UIColors.BG_DARK.b, 0.9),
		MP_GREEN_BORDER, 12, 2
	)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	frame.add_theme_stylebox_override("normal", style)
	frame.add_theme_stylebox_override("hover", style)
	frame.add_theme_stylebox_override("pressed", style)
	frame.add_theme_stylebox_override("disabled", style)

	var focus_style := UIHelpers.create_rounded_stylebox(
		Color(UIColors.BG_DARK.r, UIColors.BG_DARK.g, UIColors.BG_DARK.b, 0.9),
		UIColors.FOCUS_GOLD, 12, 6
	)
	focus_style.content_margin_left = 10
	focus_style.content_margin_right = 10
	focus_style.content_margin_top = 10
	focus_style.content_margin_bottom = 10
	frame.add_theme_stylebox_override("focus", focus_style)

func _apply_empty_frame_style(frame: Button) -> void:
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
	frame.add_theme_stylebox_override("normal", style)
	frame.add_theme_stylebox_override("hover", style)
	frame.add_theme_stylebox_override("pressed", style)
	frame.add_theme_stylebox_override("disabled", style)

func _update_pulse_animation() -> void:
	# Kill any existing pulse
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
		_pulse_tween = null

	# Collect empty slot frames for pulsing
	var empty_frames: Array[Button] = []
	for slot in _slot_nodes:
		if not slot["is_filled"]:
			empty_frames.append(slot["frame"] as Button)

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
	if NetworkManager.players.size() >= 2:
		NetworkManager.start_now()

func _on_game_started(_session: Dictionary) -> void:
	# Game is starting — restore the wake lock before handing off to the game scene.
	DisplayServer.screen_set_keep_on(true)
	if _oled_guard:
		_oled_guard.stop()
	get_tree().change_scene_to_file(Scenes.MP_GAME)


## Called after 3 min of lobby idle — dim the whole screen and D-pad.
func _on_oled_tier1() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.30, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if DPad and DPad.visible:
		DPad.dim(0.05, 3.0)


## Called after 5 min of lobby idle — leave and go home.
func _on_oled_tier2() -> void:
	NetworkManager.leave_session()
	get_tree().change_scene_to_file(Scenes.HOME)


## Called on any input — restore brightness.
func _on_oled_reset() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if DPad:
		DPad.undim(0.3)

# ── Layout ──────────────────────────────────────────────────────────────────

func _apply_dpad_layout() -> void:
	if center_container != null and Config != null:
		UIHelpers.apply_dpad_layout(center_container, Config.on_screen_controls)

func _apply_responsive_layout() -> void:
	var available_width := _available_width()
	var viewport_height: float = get_viewport_rect().size.y
	var short_screen: bool = viewport_height < 820.0
	var compact_banner: bool = viewport_height < 1120.0

	if _main_vbox != null:
		_main_vbox.custom_minimum_size = Vector2(available_width, viewport_height)
		_main_vbox.add_theme_constant_override("separation", _vbox_spacing())

	if _top_spacer != null:
		_top_spacer.custom_minimum_size.y = clampf(viewport_height * 0.0075, 3.0, 8.0)

	if _logo != null:
		var logo_width: float = clampf(available_width * (0.24 if short_screen else 0.30), 200.0, 500.0)
		var logo_height: float = clampf(logo_width * 0.214, 40.0, 107.0)
		_logo.custom_minimum_size = Vector2(logo_width, logo_height)

	if _unified_card != null:
		_unified_card.custom_minimum_size = Vector2(clampf(available_width * 0.85, 700.0, 1300.0), 0)

	if _condensed_title != null:
		_condensed_title.add_theme_font_size_override("font_size", 24 if short_screen else 28)

	# Slot sizing
	var slot_size: float = 120.0 if short_screen else 140.0
	var frame_size: float = slot_size * 0.9
	var preview_size: float = frame_size * 0.78
	for slot in _slot_nodes:
		var vbox := slot["vbox"] as Control
		vbox.custom_minimum_size = Vector2(slot_size + 20, slot_size + 40)
		var frame := slot["frame"] as Button
		frame.custom_minimum_size = Vector2(frame_size, frame_size)
		var preview := slot["preview"] as CharacterPreview
		preview.custom_minimum_size = Vector2(preview_size, preview_size)
		var label := slot["label"] as Label
		label.add_theme_font_size_override("font_size", 22 if short_screen else 24)

	if _slots_row != null:
		_slots_row.add_theme_constant_override("separation", 32 if short_screen else 48)

	# Start button
	var action_btn_width: float = clampf(available_width * 0.35, 380.0, 520.0)
	var action_btn_height: float = 64.0 if short_screen else 72.0
	var action_font_size: int = 28 if short_screen else 32
	if _start_button != null:
		_start_button.custom_minimum_size = Vector2(action_btn_width, action_btn_height)
		_start_button.add_theme_font_size_override("font_size", action_font_size)

	# Banner — find our named HBox
	var banner_hbox := _main_vbox.get_node_or_null("BannerHBox") as HBoxContainer
	if banner_hbox != null:
		var step_font_size := 26 if short_screen else (30 if compact_banner else 33)
		var title_font_size := 38 if short_screen else (44 if compact_banner else 48)
		var banner_gap := 28 if short_screen else (42 if compact_banner else 56)
		banner_hbox.add_theme_constant_override("separation", banner_gap)
		banner_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var banner_vbox := banner_hbox.get_node_or_null("BannerVBox") as VBoxContainer
		if banner_vbox != null:
			banner_vbox.add_theme_constant_override("separation", 8 if short_screen else 10)

			# Resize title
			var title_lbl := banner_vbox.get_node_or_null("BannerTitle") as Label
			if title_lbl != null:
				title_lbl.add_theme_font_size_override("font_size", title_font_size)
				title_lbl.custom_minimum_size.x = 0

			# Resize steps inside StepsVBox
			var steps_card_hbox := banner_vbox.get_node_or_null("StepsCardHBox") as HBoxContainer
			if steps_card_hbox != null:
				steps_card_hbox.add_theme_constant_override("separation", 16 if short_screen else (22 if compact_banner else 26))
				steps_card_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			var steps_vbox := banner_vbox.get_node_or_null("StepsCardHBox/StepsVBox") as VBoxContainer
			if steps_vbox != null:
				steps_vbox.add_theme_constant_override("separation", 7 if short_screen else (9 if compact_banner else 10))
				steps_vbox.custom_minimum_size.x = 0
				for child in steps_vbox.get_children():
					if child is RichTextLabel:
						child.add_theme_font_size_override("normal_font_size", step_font_size)
						child.add_theme_font_size_override("bold_font_size", step_font_size)
						child.custom_minimum_size.x = 0
					elif child is Label:
						child.add_theme_font_size_override("font_size", step_font_size)
						child.custom_minimum_size.x = 0

			# Resize join card via configure_compact
			var join_card := banner_vbox.get_node_or_null("StepsCardHBox/JoinGameCard") as Button
			if join_card != null:
				var card_width := 214 if short_screen else (250 if compact_banner else 270)
				var card_height := 236 if short_screen else (280 if compact_banner else 310)
				var card_icon := 28 if short_screen else (34 if compact_banner else 38)
				var card_title := 18 if short_screen else (22 if compact_banner else 24)
				var icon_box := Vector2(38, 38) if short_screen else (Vector2(42, 42) if compact_banner else Vector2(48, 48))
				join_card.custom_minimum_size = Vector2(card_width, card_height)
				join_card.size_flags_horizontal = Control.SIZE_SHRINK_END
				join_card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				join_card.call("configure_compact", card_icon, card_title, 0, icon_box)

		var qr_vbox := banner_hbox.get_node_or_null("QrVBox") as VBoxContainer
		if qr_vbox != null:
			var qr_size := 170 if short_screen else (205 if compact_banner else 220)
			qr_vbox.custom_minimum_size.x = qr_size + 42
			qr_vbox.size_flags_horizontal = Control.SIZE_SHRINK_END
			for child in qr_vbox.get_children():
				if child is TextureRect:
					child.custom_minimum_size = Vector2(qr_size, qr_size)
				elif child is Label:
					child.custom_minimum_size.x = qr_size + 42
					child.add_theme_font_size_override("font_size", 19 if short_screen else (22 if compact_banner else 24))


func _available_width() -> float:
	var viewport_size := get_viewport_rect().size
	var controls_mode := Config.ControlsMode.OFF
	if Config != null:
		controls_mode = Config.on_screen_controls as Config.ControlsMode
	var content_rect := UIHelpers.get_content_rect(viewport_size, controls_mode)
	return clampf(content_rect.size.x * 0.985, 760.0, 1760.0)

func _vbox_spacing() -> int:
	var height: float = get_viewport_rect().size.y
	if height < 650.0:
		return 6
	if height < 820.0:
		return 8
	return 12
