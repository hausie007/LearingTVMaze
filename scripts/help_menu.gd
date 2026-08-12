class_name HelpMenu
extends Control

## Displays a kid-friendly slideshow explaining the game mechanics.
## Uses existing textures and simple UI shapes so help cards stay lightweight.

const SLIDES = [
	{"title": "help_card_01_title", "text": "help_card_01_text", "type": "overview"},
	{"title": "help_card_02_title", "text": "help_card_02_text", "type": "play_now"},
	{"title": "help_card_03_title", "text": "help_card_03_text", "type": "custom_game"},
	{"title": "help_card_04_title", "text": "help_card_04_text", "type": "maze_sizes"},
	{"title": "help_card_05_title", "text": "help_card_05_text", "type": "worlds"},
	{"title": "help_card_06_title", "text": "help_card_06_text", "type": "numbers"},
	{"title": "help_card_07_title", "text": "help_card_07_text", "type": "letters"},
	{"title": "help_card_08_title", "text": "help_card_08_text", "type": "word_voice"},
	{"title": "help_card_09_title", "text": "help_card_09_text", "type": "clean_maze"},
	{"title": "help_card_10_title", "text": "help_card_10_text", "type": "chaser"},
	{"title": "help_card_14_title", "text": "help_card_14_text", "type": "traps"},
	{"title": "help_card_11_title", "text": "help_card_11_text", "type": "center_race"},
	{"title": "help_card_12_title", "text": "help_card_12_text", "type": "multiplayer"},
	{"title": "help_card_13_title", "text": "help_card_13_text", "type": "phone_controller"},
]

const ICON_NUMBERS := "res://images/icons/i_numbers.png"
const ICON_WORDS := "res://images/icons/i_words.png"
const ICON_LETTERS := "res://images/icons/i_letters.png"
const ICON_CHASER := "res://images/icons/i_with_chaser.png"
const ICON_PLAYERS := "res://images/icons/i_play_together2.png"
const ICON_PLAY_NOW := "res://images/icons/i_play_now.png"
const ICON_ADVENTURE := "res://images/icons/i_your_adventure.png"
const ICON_EXIT := "res://images/icons/i_find_the_exit.png"
const ICON_RACE := "res://images/icons/i_race_to_the_center.png"
const ICON_JOIN := "res://images/icons/i_join_game.png"
const ICON_MAZE := "res://images/icons/i_just_maze.png"
const HOME_SYMBOL := "🏠"

var _current_slide: int = 0
var _theme: ThemeLoader = null
var _anim_time: float = 0.0

@onready var _visual_container: CenterContainer = %VisualContainer
@onready var _icon_rect: TextureRect = %IconRect
@onready var _title_label: Label = %TitleLabel
@onready var _text_label: Label = %TextLabel
@onready var _fineprint_label: Label = %FineprintLabel
@onready var _fineprint_margin: MarginContainer = %FineprintMargin
@onready var _page_label: Label = %PageLabel
@onready var _back_btn: Button = %BackButton
@onready var _left_btn: Button = %LeftButton
@onready var _right_btn: Button = %RightButton


func _ready() -> void:
	_theme = Config.theme

	_back_btn.pressed.connect(_on_back_pressed)
	_left_btn.pressed.connect(_on_left_pressed)
	_right_btn.pressed.connect(_on_right_pressed)

	_back_btn.focus_mode = Control.FOCUS_ALL
	_left_btn.focus_mode = Control.FOCUS_ALL
	_right_btn.focus_mode = Control.FOCUS_ALL
	_style_navigation_buttons()
	UIHelpers.apply_medium(_fineprint_label)

	if is_layout_rtl():
		_left_btn.text = ">"
		_right_btn.text = "<"

	_update_slide()
	_apply_layout_shift()
	call_deferred("_focus_next_button")


func _apply_layout_shift() -> void:
	var center_container = $CenterContainer
	if not center_container:
		return

	var controls_mode = Config.on_screen_controls
	UIHelpers.apply_dpad_layout(center_container, controls_mode)

	if controls_mode != Config.ControlsMode.OFF:
		center_container.offset_left = 0
		center_container.offset_right = 0

	var panel: Control = get_node_or_null("%Panel")
	var visual_container: Control = get_node_or_null("%VisualContainer")
	var title_label: Label = get_node_or_null("%TitleLabel")
	var text_label: Label = get_node_or_null("%TextLabel")
	var fineprint_label: Label = get_node_or_null("%FineprintLabel")
	var icon_rect: TextureRect = get_node_or_null("%IconRect")
	var vbox: VBoxContainer = get_node_or_null("CenterContainer/Panel/MainVBox/ContentMargin/VBox")
	var main_vbox: VBoxContainer = get_node_or_null("CenterContainer/Panel/MainVBox")
	var content_margin: MarginContainer = get_node_or_null("CenterContainer/Panel/MainVBox/ContentMargin")
	var fineprint_margin: MarginContainer = _fineprint_margin
	var nav_margin: MarginContainer = get_node_or_null("CenterContainer/Panel/MainVBox/NavMargin")
	var nav_bar: HBoxContainer = get_node_or_null("CenterContainer/Panel/MainVBox/NavMargin/NavBar")

	if panel == null or text_label == null or title_label == null:
		return

	if controls_mode != Config.ControlsMode.OFF:
		panel.custom_minimum_size = Vector2(1280, 820)
		if main_vbox:
			main_vbox.add_theme_constant_override("separation", 8)
		if content_margin:
			content_margin.add_theme_constant_override("margin_left", 42)
			content_margin.add_theme_constant_override("margin_top", 24)
			content_margin.add_theme_constant_override("margin_right", 42)
			content_margin.add_theme_constant_override("margin_bottom", 0)
		if fineprint_margin:
			fineprint_margin.custom_minimum_size = Vector2(0, 48)
			fineprint_margin.add_theme_constant_override("margin_left", 42)
			fineprint_margin.add_theme_constant_override("margin_top", 0)
			fineprint_margin.add_theme_constant_override("margin_right", 42)
			fineprint_margin.add_theme_constant_override("margin_bottom", 6)
		if nav_margin:
			nav_margin.add_theme_constant_override("margin_left", 42)
			nav_margin.add_theme_constant_override("margin_right", 42)
			nav_margin.add_theme_constant_override("margin_bottom", 16)
		if nav_bar:
			nav_bar.add_theme_constant_override("separation", 18)
		if visual_container:
			visual_container.custom_minimum_size = Vector2(0, 190)
		title_label.custom_minimum_size = Vector2(900, 56)
		title_label.add_theme_font_size_override("font_size", 40)
		text_label.custom_minimum_size = Vector2(900, 290)
		text_label.add_theme_font_size_override("font_size", 33)
		if fineprint_label:
			fineprint_label.custom_minimum_size = Vector2(900, 40)
			fineprint_label.add_theme_font_size_override("font_size", 17)
		if icon_rect:
			icon_rect.custom_minimum_size = Vector2(210, 210)
		if vbox:
			vbox.add_theme_constant_override("separation", 14)
		_resize_nav_buttons(Vector2(112, 76), Vector2(176, 76), 50, 28)
	else:
		panel.custom_minimum_size = Vector2(1500, 900)
		if main_vbox:
			main_vbox.add_theme_constant_override("separation", 8)
		if content_margin:
			content_margin.add_theme_constant_override("margin_left", 52)
			content_margin.add_theme_constant_override("margin_top", 36)
			content_margin.add_theme_constant_override("margin_right", 52)
			content_margin.add_theme_constant_override("margin_bottom", 0)
		if fineprint_margin:
			fineprint_margin.custom_minimum_size = Vector2(0, 56)
			fineprint_margin.add_theme_constant_override("margin_left", 52)
			fineprint_margin.add_theme_constant_override("margin_top", 0)
			fineprint_margin.add_theme_constant_override("margin_right", 52)
			fineprint_margin.add_theme_constant_override("margin_bottom", 8)
		if nav_margin:
			nav_margin.add_theme_constant_override("margin_left", 52)
			nav_margin.add_theme_constant_override("margin_right", 52)
			nav_margin.add_theme_constant_override("margin_bottom", 20)
		if nav_bar:
			nav_bar.add_theme_constant_override("separation", 26)
		if visual_container:
			visual_container.custom_minimum_size = Vector2(0, 280)
		title_label.custom_minimum_size = Vector2(1000, 66)
		title_label.add_theme_font_size_override("font_size", 46)
		text_label.custom_minimum_size = Vector2(1000, 300)
		text_label.add_theme_font_size_override("font_size", 39)
		if fineprint_label:
			fineprint_label.custom_minimum_size = Vector2(1000, 44)
			fineprint_label.add_theme_font_size_override("font_size", 20)
		if icon_rect:
			icon_rect.custom_minimum_size = Vector2(300, 300)
		if vbox:
			vbox.add_theme_constant_override("separation", 18)
		_resize_nav_buttons(Vector2(130, 86), Vector2(190, 86), 58, 32)


func _process(delta: float) -> void:
	_anim_time += delta
	_update_animations()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()


func _update_slide() -> void:
	var slide: Dictionary = SLIDES[_current_slide]
	var title_key := String(slide.get("title", ""))
	var text_key := String(slide.get("text", ""))
	var slide_type := String(slide.get("type", ""))
	var has_network_note := _slide_has_network_note(slide_type)
	var text := tr(text_key)

	_title_label.text = "%s*" % tr(title_key) if has_network_note else tr(title_key)
	_text_label.text = text
	_fineprint_label.visible = has_network_note
	_fineprint_label.text = tr("help_multiplayer_network_note") if has_network_note else ""
	_page_label.text = "%d / %d" % [_current_slide + 1, SLIDES.size()]

	_clear_visuals()

	match slide_type:
		"overview":
			_spawn_overview_visual()
		"play_now":
			_spawn_play_now_visual()
		"custom_game":
			_spawn_custom_game_visual()
		"maze_sizes":
			_spawn_maze_sizes_visual()
		"worlds":
			_spawn_worlds_visual()
		"numbers":
			_spawn_numbers_visual()
		"letters":
			_spawn_letters_visual()
		"word_voice":
			_spawn_word_voice_visual()
		"clean_maze":
			_spawn_clean_maze_visual()
		"chaser":
			_spawn_chaser_visual()
		"traps":
			_spawn_traps_visual()
		"center_race":
			_spawn_center_race_visual()
		"multiplayer":
			_spawn_multiplayer_visual()
		"phone_controller":
			_spawn_phone_controller_visual()
		_:
			_show_icon(_theme_player_texture(), 260)

	var is_first := (_current_slide == 0)
	var is_last := (_current_slide == SLIDES.size() - 1)
	var focus_owner: Control = get_viewport().gui_get_focus_owner() if get_viewport() != null else null
	_set_nav_button_enabled(_left_btn, not is_first)
	_set_nav_button_enabled(_right_btn, not is_last)

	_configure_navigation_focus()
	if is_last:
		call_deferred("_focus_home_button")
	elif is_first and focus_owner == _left_btn:
		_right_btn.grab_focus()
	elif focus_owner == null:
		_focus_default_nav()

	_update_animations()

	# Keep small network caveats visual-only; TTS reads the child-facing slide text.
	if Config.voice_mode != Config.VoiceMode.OFF:
		# Help narration is long, mixed and rarely heard twice; it stays on the
		# device voice, so the key never resolves and always falls through.
		Speech.speak_key("ui.help.slide", Config.get_effective_ui_language(), text, 0.8)


func _slide_has_network_note(slide_type: String) -> bool:
	return slide_type == "multiplayer" or slide_type == "phone_controller"


func _clear_visuals() -> void:
	for child in _visual_container.get_children():
		if child != _icon_rect:
			child.queue_free()
	_icon_rect.visible = false


func _update_animations() -> void:
	var maze_node = _visual_container.get_node_or_null("MazePreview")
	if maze_node and _theme:
		if _theme.bg_frames.size() > 1:
			var idx := int(_anim_time * _theme.bg_fps) % _theme.bg_frames.size()
			maze_node.bg_texture = _theme.bg_frames[idx]
		else:
			maze_node.bg_texture = _theme.bg_texture
		maze_node.queue_redraw()

	if not _icon_rect.visible or _theme == null:
		return

	var slide: Dictionary = SLIDES[_current_slide]
	var frames: Array[Texture2D] = []
	var fps := 5.0

	match String(slide.get("type", "")):
		"worlds", "overview", "phone_controller":
			frames = _theme.player_frames
			fps = _theme.player_fps
		"chaser":
			frames = _theme.chaser_frames
			fps = _theme.chaser_fps

	if frames.size() > 1:
		var idx := int(_anim_time * fps) % frames.size()
		_icon_rect.texture = frames[idx]


func _spawn_overview_visual() -> void:
	var root := VBoxContainer.new()
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 14)
	_visual_container.add_child(root)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	root.add_child(row)

	row.add_child(_create_icon_tile(ICON_NUMBERS, "1 2 3", UIColors.CARD_BLUE_DARK))
	row.add_child(_create_icon_tile(ICON_WORDS, "A B C", UIColors.CARD_GREEN_DARK))
	row.add_child(_create_icon_tile(ICON_CHASER, tr("mp_role_chaser"), UIColors.CARD_ORANGE_RED_DARK))
	row.add_child(_create_icon_tile(ICON_PLAYERS, tr("help_visual_together"), UIColors.CARD_YELLOW_DARK))

	var player := _create_texture_rect(_theme_player_texture(), Vector2(90, 90))
	root.add_child(player)


func _spawn_play_now_visual() -> void:
	var root := VBoxContainer.new()
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 18)
	_visual_container.add_child(root)

	var button_panel := _create_panel(UIColors.CARD_YELLOW_DARK, UIColors.HEADING_YELLOW, 22, Vector2(420, 86))
	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 18)
	button_panel.add_child(button_row)
	button_row.add_child(_create_texture_rect(load(ICON_PLAY_NOW) as Texture2D, Vector2(58, 58)))
	button_row.add_child(_create_label(tr("help_card_02_title"), 38, UIColors.HEADING_YELLOW, Vector2(240, 70)))
	root.add_child(button_panel)

	var path := HBoxContainer.new()
	path.alignment = BoxContainer.ALIGNMENT_CENTER
	path.add_theme_constant_override("separation", 12)
	root.add_child(path)
	path.add_child(_create_number_tile("1"))
	path.add_child(_create_arrow_label())
	path.add_child(_create_number_tile("2"))
	path.add_child(_create_arrow_label())
	path.add_child(_create_number_tile("3"))
	path.add_child(_create_arrow_label())
	path.add_child(_create_texture_rect(_theme_finish_texture(), Vector2(78, 78)))


func _spawn_custom_game_visual() -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	_visual_container.add_child(row)

	var size_label := tr("help_visual_size")
	row.add_child(_create_symbol_tile(_first_visual_letter(size_label), size_label, UIColors.CARD_BLUE_DARK))
	row.add_child(_create_icon_tile(ICON_NUMBERS, tr("help_visual_collect"), UIColors.CARD_GREEN_DARK))
	row.add_child(_create_icon_tile(ICON_CHASER, tr("mp_role_chaser"), UIColors.CARD_ORANGE_RED_DARK))
	row.add_child(_create_icon_tile(ICON_PLAYERS, tr("badge_players_word"), UIColors.CARD_YELLOW_DARK))


func _spawn_maze_sizes_visual() -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	_visual_container.add_child(row)

	row.add_child(_create_mini_maze_panel(Vector2i(4, 3), Vector2(132, 108), tr("diff_easy")))
	row.add_child(_create_mini_maze_panel(Vector2i(6, 4), Vector2(172, 124), tr("diff_medium")))
	row.add_child(_create_mini_maze_panel(Vector2i(8, 5), Vector2(218, 144), tr("diff_hard")))


func _spawn_worlds_visual() -> void:
	var root := VBoxContainer.new()
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 12)
	_visual_container.add_child(root)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	root.add_child(row)

	var shown := 0
	var available := ThemeLoader.get_available_themes()
	for theme_name in available:
		var loader := ThemeLoader.get_cached(theme_name)
		if loader == null:
			continue
		var tex := loader.player_texture if loader.player_texture != null else _theme_player_texture()
		row.add_child(_create_texture_card(tex, Vector2(120, 120), loader.color_floor))
		shown += 1
		if shown >= 3:
			break

	while shown < 3:
		row.add_child(_create_texture_card(_theme_player_texture(), Vector2(120, 120), UIColors.CARD_BLUE_DARK))
		shown += 1

	var portraits := HBoxContainer.new()
	portraits.alignment = BoxContainer.ALIGNMENT_CENTER
	portraits.add_theme_constant_override("separation", 8)
	root.add_child(portraits)
	portraits.add_child(_create_texture_rect(_theme_player_texture(), Vector2(54, 54)))
	portraits.add_child(_create_texture_rect(_theme_chaser_texture(), Vector2(54, 54)))
	portraits.add_child(_create_texture_rect(_theme_finish_texture(), Vector2(54, 54)))


func _spawn_numbers_visual() -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	_visual_container.add_child(row)
	row.add_child(_create_number_tile("1"))
	row.add_child(_create_arrow_label())
	row.add_child(_create_number_tile("2"))
	row.add_child(_create_arrow_label())
	row.add_child(_create_number_tile("3"))
	row.add_child(_create_arrow_label())
	row.add_child(_create_number_tile("4"))


func _spawn_letters_visual() -> void:
	var root := HBoxContainer.new()
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 18)
	_visual_container.add_child(root)
	var word := tr("help_visual_demo_word")
	for letter in _word_letters(word):
		root.add_child(_create_letter_tile(letter))
	root.add_child(_create_arrow_label())
	root.add_child(_create_word_card(word))


func _spawn_word_voice_visual() -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	_visual_container.add_child(row)
	row.add_child(_create_word_card(tr("help_visual_demo_word")))
	row.add_child(_create_speaker_visual())
	row.add_child(_create_speech_bubble(tr("help_visual_speech_local")))
	row.add_child(_create_speech_bubble(tr("help_visual_speech_foreign")))


func _spawn_clean_maze_visual() -> void:
	_spawn_maze_preview(Vector2(640, 300))


func _spawn_chaser_visual() -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	_visual_container.add_child(row)
	row.add_child(_create_texture_rect(_theme_player_texture(), Vector2(120, 120)))
	row.add_child(_create_countdown_visual())
	row.add_child(_create_texture_rect(_theme_chaser_texture(), Vector2(120, 120)))


func _spawn_traps_visual() -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	_visual_container.add_child(row)

	var trap_panel := _create_panel(UIColors.CARD_BLUE_DARK, UIColors.BLUE, 18, Vector2(160, 160))
	trap_panel.add_child(_create_texture_rect(_theme_trap_texture(), Vector2(122, 122)))
	row.add_child(trap_panel)

	row.add_child(_create_arrow_label())

	var status := VBoxContainer.new()
	status.alignment = BoxContainer.ALIGNMENT_CENTER
	status.add_theme_constant_override("separation", 0)
	var player := _create_texture_rect(_theme_player_texture(), Vector2(96, 96))
	player.pivot_offset = Vector2(48, 48)
	player.rotation_degrees = 180.0
	status.add_child(player)
	status.add_child(_create_label(str(Config.TRAP_CONFUSION_MOVES), 34, UIColors.HEADING_YELLOW, Vector2(96, 44)))
	row.add_child(status)

	row.add_child(_create_arrow_label())

	var dpad_panel := _create_panel(UIColors.CARD_NEUTRAL_ALT, UIColors.BLUE, 16, Vector2(168, 168))
	dpad_panel.add_child(_create_reversed_dpad_visual())
	row.add_child(dpad_panel)


func _spawn_center_race_visual() -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	_visual_container.add_child(row)
	row.add_child(_create_texture_rect(_theme_player_texture(), Vector2(86, 86)))
	row.add_child(_create_arrow_label())
	row.add_child(_create_icon_tile(ICON_RACE, tr("help_visual_middle"), UIColors.CARD_ORANGE_RED_DARK, Vector2(160, 160)))
	row.add_child(_create_arrow_label("<"))
	row.add_child(_create_texture_rect(_theme_chaser_texture(), Vector2(86, 86)))


func _spawn_multiplayer_visual() -> void:
	var root := HBoxContainer.new()
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 18)
	_visual_container.add_child(root)

	var screen := _create_panel(UIColors.BG_DARK, UIColors.BLUE, 14, Vector2(310, 190))
	var screen_vbox := VBoxContainer.new()
	screen_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	screen_vbox.add_theme_constant_override("separation", 8)
	screen.add_child(screen_vbox)
	screen_vbox.add_child(_create_mini_maze_panel(Vector2i(6, 4), Vector2(220, 108), ""))
	screen_vbox.add_child(_create_label("Wi-Fi", 24, UIColors.HEADING_YELLOW, Vector2(160, 34)))
	root.add_child(screen)

	var players := VBoxContainer.new()
	players.alignment = BoxContainer.ALIGNMENT_CENTER
	players.add_theme_constant_override("separation", 8)
	root.add_child(players)
	players.add_child(_create_icon_tile(ICON_PLAYERS, "2-4", UIColors.CARD_GREEN_DARK, Vector2(128, 128)))
	players.add_child(_create_icon_tile(ICON_JOIN, tr("help_visual_join"), UIColors.CARD_BLUE_DARK, Vector2(128, 128)))


func _spawn_phone_controller_visual() -> void:
	var root := HBoxContainer.new()
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 26)
	_visual_container.add_child(root)

	var screen := _create_panel(UIColors.BG_DARK, UIColors.BLUE, 14, Vector2(330, 200))
	var screen_vbox := VBoxContainer.new()
	screen_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	screen.add_child(screen_vbox)
	screen_vbox.add_child(_create_mini_maze_panel(Vector2i(7, 4), Vector2(250, 130), ""))
	root.add_child(screen)

	var phone := _create_panel(UIColors.CARD_NEUTRAL_ALT, UIColors.HEADING_YELLOW, 22, Vector2(170, 230))
	var phone_vbox := VBoxContainer.new()
	phone_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	phone_vbox.add_theme_constant_override("separation", 8)
	phone.add_child(phone_vbox)
	phone_vbox.add_child(_create_label(tr("help_visual_collect_numbers"), 18, UIColors.TEXT_PRIMARY, Vector2(140, 32)))
	phone_vbox.add_child(_create_dpad_visual())
	root.add_child(phone)


func _spawn_maze_preview(min_size: Vector2 = Vector2(640, 320)) -> void:
	var maze_script = load("res://scripts/help_maze_preview.gd")
	var maze_node = Control.new()
	maze_node.name = "MazePreview"
	maze_node.set_script(maze_script)
	maze_node.theme_loader = _theme
	maze_node.custom_minimum_size = min_size
	_visual_container.add_child(maze_node)
	maze_node.bg_texture = _theme.bg_texture if _theme != null else null


func _create_icon_tile(path: String, caption: String, color: Color, min_size: Vector2 = Vector2(132, 132)) -> PanelContainer:
	var panel := _create_panel(color, UIColors.CARD_BORDER_SOFT, 16, min_size)
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)
	vbox.add_child(_create_texture_rect(load(path) as Texture2D, Vector2(min_size.x * 0.45, min_size.y * 0.45)))
	vbox.add_child(_create_label(caption, 20, UIColors.TEXT_PRIMARY, Vector2(min_size.x - 16, 30)))
	return panel


func _create_symbol_tile(symbol: String, caption: String, color: Color) -> PanelContainer:
	var panel := _create_panel(color, UIColors.CARD_BORDER_SOFT, 16, Vector2(132, 132))
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)
	vbox.add_child(_create_label(symbol, 54, UIColors.HEADING_YELLOW, Vector2(110, 66)))
	vbox.add_child(_create_label(caption, 20, UIColors.TEXT_PRIMARY, Vector2(116, 30)))
	return panel


func _create_texture_card(texture: Texture2D, min_size: Vector2, color: Color) -> PanelContainer:
	var panel := _create_panel(Color(color.r, color.g, color.b, 0.85), UIColors.CARD_BORDER_SOFT, 18, min_size)
	panel.add_child(_create_texture_rect(texture, min_size * 0.78))
	return panel


func _create_number_tile(value: String) -> PanelContainer:
	return _create_tile(value, 52, UIColors.CARD_BLUE_DARK, UIColors.HEADING_YELLOW, Vector2(82, 82))


func _create_letter_tile(value: String) -> PanelContainer:
	return _create_tile(value, 52, UIColors.CARD_GREEN_DARK, UIColors.TEXT_PRIMARY, Vector2(82, 82))


func _create_word_card(value: String) -> PanelContainer:
	return _create_tile(value, 48, UIColors.CARD_YELLOW_DARK, UIColors.HEADING_YELLOW, Vector2(170, 92))


func _create_tile(value: String, font_size: int, bg_color: Color, text_color: Color, min_size: Vector2) -> PanelContainer:
	var panel := _create_panel(bg_color, UIColors.CARD_BORDER_SOFT, 16, min_size)
	panel.add_child(_create_label(value, font_size, text_color, min_size))
	return panel


func _create_mini_maze_panel(grid: Vector2i, min_size: Vector2, caption: String) -> VBoxContainer:
	var root := VBoxContainer.new()
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 6)

	var maze_panel := _create_panel(UIColors.BG_DARK, UIColors.CARD_BORDER_SOFT, 10, min_size)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	maze_panel.add_child(margin)

	var cells := GridContainer.new()
	cells.columns = grid.x
	cells.add_theme_constant_override("h_separation", 2)
	cells.add_theme_constant_override("v_separation", 2)
	margin.add_child(cells)

	var cell_w := maxf(10.0, (min_size.x - 20.0) / float(grid.x))
	var cell_h := maxf(10.0, (min_size.y - 20.0) / float(grid.y))
	for y in range(grid.y):
		for x in range(grid.x):
			var cell := ColorRect.new()
			cell.custom_minimum_size = Vector2(cell_w, cell_h)
			var on_path := y == grid.y - 1 or x == grid.x - 1 or (x == 1 and y >= 1)
			cell.color = UIColors.PARCHMENT if on_path else UIColors.CARD_BLUE_DARK
			cells.add_child(cell)

	root.add_child(maze_panel)
	if not caption.is_empty():
		root.add_child(_create_label(caption, 18, UIColors.TEXT_SECONDARY, Vector2(min_size.x, 26)))
	return root


func _create_speaker_visual() -> PanelContainer:
	var panel := _create_panel(UIColors.CARD_BLUE_DARK, UIColors.BLUE, 18, Vector2(120, 110))
	var label := _create_label(")))", 42, UIColors.HEADING_YELLOW, Vector2(100, 86))
	panel.add_child(label)
	return panel


func _create_speech_bubble(text: String) -> PanelContainer:
	var panel := _create_panel(UIColors.CARD_NEUTRAL_ALT, UIColors.CARD_BORDER_SOFT, 18, Vector2(110, 72))
	panel.add_child(_create_label(text, 22, UIColors.TEXT_PRIMARY, Vector2(96, 58)))
	return panel


func _create_countdown_visual() -> VBoxContainer:
	var root := VBoxContainer.new()
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 4)
	root.add_child(_create_label("3  2  1", 32, UIColors.HEADING_YELLOW, Vector2(160, 54)))
	root.add_child(_create_label(tr("help_visual_head_start"), 20, UIColors.TEXT_SECONDARY, Vector2(150, 30)))
	return root


func _create_dpad_visual() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	var values := ["", "^", "", "<", "o", ">", "", "v", ""]
	for value in values:
		var tile := _create_tile(value, 22, UIColors.BG_DARK, UIColors.TEXT_PRIMARY, Vector2(38, 38))
		tile.modulate.a = 0.35 if value.is_empty() else 1.0
		grid.add_child(tile)
	return grid


func _create_reversed_dpad_visual() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	var values := ["", "v", "", ">", "OK", "<", "", "^", ""]
	for value in values:
		var tile := _create_tile(value, 20, UIColors.BG_DARK, UIColors.TEXT_PRIMARY, Vector2(42, 42))
		tile.modulate.a = 0.35 if value.is_empty() else 1.0
		grid.add_child(tile)
	return grid


func _create_arrow_label(text: String = ">") -> Label:
	return _create_label(text, 30, UIColors.HEADING_YELLOW, Vector2(32, 60))


func _create_panel(bg_color: Color, border_color: Color, radius: int, min_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = min_size
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _create_texture_rect(texture: Texture2D, min_size: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.custom_minimum_size = min_size
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return rect


func _create_label(text: String, font_size: int, color: Color, min_size: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = min_size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", _fit_font_size(text, font_size, min_size.x - 6.0))
	label.add_theme_color_override("font_color", color)
	UIHelpers.apply_semibold(label)
	return label


func _word_letters(word: String) -> Array[String]:
	var letters: Array[String] = []
	for i in range(word.length()):
		letters.append(word.substr(i, 1))
	if is_layout_rtl():
		letters.reverse()
	return letters


func _first_visual_letter(text: String) -> String:
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		return ""
	return trimmed.substr(0, 1).to_upper()


func _fit_font_size(text: String, font_size: int, available_width: float) -> int:
	if text.is_empty() or available_width <= 0.0:
		return font_size

	var font := UIHelpers.get_font_at_weight(UIHelpers.WEIGHT_SEMIBOLD)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size).x
	if width <= available_width:
		return font_size

	var scale := available_width / maxf(width, 1.0)
	return maxi(12, int(floor(float(font_size) * scale)))


func _show_icon(texture: Texture2D, size: int) -> void:
	_icon_rect.visible = true
	_icon_rect.texture = texture
	_icon_rect.custom_minimum_size = Vector2(size, size)


func _theme_player_texture() -> Texture2D:
	if _theme != null and _theme.player_texture != null:
		return _theme.player_texture
	return load("res://images/lm_paper_icon.png") as Texture2D


func _theme_chaser_texture() -> Texture2D:
	if _theme != null and _theme.chaser_texture != null:
		return _theme.chaser_texture
	return load(ICON_CHASER) as Texture2D


func _theme_finish_texture() -> Texture2D:
	if _theme != null and _theme.end_texture != null:
		return _theme.end_texture
	return load(ICON_EXIT) as Texture2D


func _theme_trap_texture() -> Texture2D:
	if _theme != null and _theme.trap_texture != null:
		return _theme.trap_texture
	return load("res://themes/default/trap.png") as Texture2D


func _on_left_pressed() -> void:
	if _current_slide > 0:
		_current_slide -= 1
		_update_slide()


func _on_right_pressed() -> void:
	if _current_slide < SLIDES.size() - 1:
		_current_slide += 1
		_update_slide()


func _on_back_pressed() -> void:
	Speech.stop()
	get_tree().change_scene_to_file(Scenes.HOME)


func _style_navigation_buttons() -> void:
	UIHelpers.apply_style_to_button(_back_btn, UIColors.YELLOW)
	UIHelpers.apply_style_to_button(_left_btn, UIColors.BLUE)
	UIHelpers.apply_style_to_button(_right_btn, UIColors.GREEN)

	_back_btn.text = HOME_SYMBOL
	_back_btn.tooltip_text = tr("main_menu")
	_back_btn.add_theme_font_override("font", UIHelpers.get_emoji_font())
	_back_btn.add_theme_font_size_override("font_size", 42)
	_left_btn.add_theme_font_size_override("font_size", 58)
	_right_btn.add_theme_font_size_override("font_size", 58)
	_page_label.add_theme_color_override("font_color", UIColors.TEXT_SECONDARY)
	UIHelpers.apply_medium(_page_label)


func _resize_nav_buttons(button_size: Vector2, page_size: Vector2, arrow_font_size: int, page_font_size: int) -> void:
	if _back_btn != null:
		_back_btn.custom_minimum_size = button_size
		_back_btn.add_theme_font_size_override("font_size", int(float(arrow_font_size) * 0.78))
	if _left_btn != null:
		_left_btn.custom_minimum_size = button_size
		_left_btn.add_theme_font_size_override("font_size", arrow_font_size)
	if _right_btn != null:
		_right_btn.custom_minimum_size = button_size
		_right_btn.add_theme_font_size_override("font_size", arrow_font_size)
	if _page_label != null:
		_page_label.custom_minimum_size = page_size
		_page_label.add_theme_font_size_override("font_size", page_font_size)


func _set_nav_button_enabled(button: Button, enabled: bool) -> void:
	if button == null:
		return
	button.disabled = not enabled
	button.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	button.mouse_filter = _nav_mouse_filter(enabled)
	button.modulate = Color.WHITE if enabled else Color(1.0, 1.0, 1.0, 0.34)


func _configure_navigation_focus() -> void:
	if _back_btn == null or _left_btn == null or _right_btn == null:
		return

	var focusable: Array[Button] = [_back_btn]
	if not _left_btn.disabled:
		focusable.append(_left_btn)
	if not _right_btn.disabled:
		focusable.append(_right_btn)

	for i in range(focusable.size()):
		var button := focusable[i]
		var visual_left := focusable[mini(focusable.size() - 1, i + 1)] if is_layout_rtl() else focusable[maxi(0, i - 1)]
		var visual_right := focusable[maxi(0, i - 1)] if is_layout_rtl() else focusable[mini(focusable.size() - 1, i + 1)]
		button.focus_neighbor_left = button.get_path_to(visual_left)
		button.focus_neighbor_right = button.get_path_to(visual_right)
		button.focus_neighbor_top = button.get_path_to(button)
		button.focus_neighbor_bottom = button.get_path_to(button)


func _nav_mouse_filter(active: bool) -> int:
	if not active or UIHelpers.is_likely_tv():
		return Control.MOUSE_FILTER_IGNORE
	return Control.MOUSE_FILTER_STOP


func _focus_default_nav() -> void:
	if _current_slide == SLIDES.size() - 1 and _back_btn != null:
		_back_btn.grab_focus()
		return
	if _right_btn != null and not _right_btn.disabled:
		_right_btn.grab_focus()
	elif _left_btn != null and not _left_btn.disabled:
		_left_btn.grab_focus()
	elif _back_btn != null:
		_back_btn.grab_focus()


func _focus_next_button() -> void:
	if _right_btn != null and not _right_btn.disabled:
		_right_btn.grab_focus()


func _focus_home_button() -> void:
	if _back_btn != null:
		_back_btn.grab_focus()
