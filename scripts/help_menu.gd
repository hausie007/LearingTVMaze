extends Control

## help_menu.gd
## ---------------------------------------------------------------------------
## Displays a kid-friendly slideshow explaining the game mechanics.
## Uses theme-aware icons and localized strings.
## ---------------------------------------------------------------------------

var _current_slide: int = 0
var _theme: ThemeLoader = null
var _anim_time: float = 0.0

# Slide data: {icon_type: "player"|"finish"|"collectible"|"chaser"|"", text_key: "help_slide_1_text"}
const SLIDES = [
	{"icon": "",            "text": "help_slide_1_text",    "type": "welcome"},
	{"icon": "",            "text": "help_slide_maze_text", "type": "maze"},
	{"icon": "player",      "text": "help_slide_2_text",    "type": "icon"},
	{"icon": "finish",      "text": "help_slide_3_text",    "type": "icon"},
	{"icon": "collectible", "text": "help_slide_4_text",    "type": "collectible"},
	{"icon": "chaser",      "text": "help_slide_5_text",    "type": "icon"},
	{"icon": "settings",    "text": "help_slide_6_text",    "type": "themes"},
]

@onready var _visual_container: CenterContainer = %VisualContainer
@onready var _icon_rect: TextureRect = %IconRect
@onready var _text_label: Label = %TextLabel
@onready var _page_label: Label = %PageLabel
@onready var _left_btn: Button = %LeftButton
@onready var _right_btn: Button = %RightButton

func _ready() -> void:
	# Load cached theme to get icons
	_theme = Config.theme
	
	_left_btn.pressed.connect(_on_left_pressed)
	_right_btn.pressed.connect(_on_right_pressed)
	
	# Disable focus for buttons so D-pad always triggers direct slide transitions
	# without "getting stuck" on a button.
	_left_btn.focus_mode = Control.FOCUS_NONE
	_right_btn.focus_mode = Control.FOCUS_NONE
	
	_update_slide()
	_apply_layout_shift()


func _apply_layout_shift() -> void:
	var center_container = $CenterContainer
	if not center_container: return
	
	var controls_mode = Config.on_screen_controls
	UIHelpers.apply_dpad_layout(center_container, controls_mode)
	
	var panel = get_node_or_null("%Panel")
	var text_label = get_node_or_null("%TextLabel")
	var icon_rect = get_node_or_null("%IconRect")
	
	if panel and text_label:
		if controls_mode != Config.ControlsMode.OFF:
			panel.custom_minimum_size = Vector2(900, 700)
			text_label.custom_minimum_size = Vector2(650, 200)
			text_label.add_theme_font_size_override("font_size", 38)
			if icon_rect: icon_rect.custom_minimum_size = Vector2(250, 250)
		else:
			panel.custom_minimum_size = Vector2(1500, 900)
			text_label.custom_minimum_size = Vector2(1000, 280)
			text_label.add_theme_font_size_override("font_size", 50)
			if icon_rect: icon_rect.custom_minimum_size = Vector2(300, 300)


func _process(delta: float) -> void:
	_anim_time += delta
	_update_animations()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back_pressed()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()
	
	if event.is_action_pressed("ui_left"):
		get_viewport().set_input_as_handled()
		_on_left_pressed()
		
	if event.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		_on_right_pressed()


func _update_slide() -> void:
	var slide = SLIDES[_current_slide]
	
	# 1. Update Text & Page
	_text_label.text = tr(slide.text)
	_page_label.text = "%d / %d" % [_current_slide + 1, SLIDES.size()]
	
	# 2. Cleanup custom visuals
	for child in _visual_container.get_children():
		if child != _icon_rect:
			child.queue_free()
	
	_icon_rect.visible = false
	
	# 3. Update Visuals
	match slide.type:
		"welcome":
			_icon_rect.visible = true
			_icon_rect.texture = load("res://images/lm_icon_new.png")
		"maze":
			_spawn_maze_preview()
		"icon":
			_icon_rect.visible = true
			_update_icon(slide.icon)
		"collectible":
			_spawn_collectible_preview()
		"themes":
			_spawn_themes_preview()
	
	# 4. Arrow Visibility
	var is_first := (_current_slide == 0)
	_left_btn.disabled = is_first
	_left_btn.modulate.a = 0.0 if is_first else 1.0
	
	# Right button stays enabled even on last slide to act as "exit/finish"
	_right_btn.disabled = false
	_right_btn.modulate.a = 1.0
	
	_update_animations()
	
	if Config.voice_hints:
		TTS.speak(tr(slide.text), 0.8, Config.get_effective_ui_language())


func _update_icon(icon_name: String) -> void:
	match icon_name:
		"player":
			_icon_rect.texture = _theme.player_texture
		"finish":
			_icon_rect.texture = _theme.end_texture
		"chaser":
			_icon_rect.texture = _theme.chaser_texture


func _update_animations() -> void:
	var slide = SLIDES[_current_slide]
	
	# 1. Backgrounds in Maze
	var maze_node = _visual_container.get_node_or_null("MazePreview")
	if maze_node:
		if _theme.bg_frames.size() > 1:
			var idx = int(_anim_time * _theme.bg_fps) % _theme.bg_frames.size()
			maze_node.bg_texture = _theme.bg_frames[idx]
			maze_node.queue_redraw()
		else:
			maze_node.bg_texture = _theme.bg_texture
			maze_node.queue_redraw()
			
	# 2. Icon animations
	if _icon_rect.visible:
		var frames: Array[Texture2D] = []
		var fps: float = 5.0
		
		match slide.icon:
			"player":
				frames = _theme.player_frames
				fps = _theme.player_fps
			"chaser":
				frames = _theme.chaser_frames
				fps = _theme.chaser_fps
			"collectible":
				frames = _theme.col_frames
				fps = _theme.col_fps
		
		if frames.size() > 1:
			var idx = int(_anim_time * fps) % frames.size()
			_icon_rect.texture = frames[idx]


func _spawn_maze_preview() -> void:
	var maze_script = load("res://scripts/help_maze_preview.gd")
	var maze_node = Control.new()
	maze_node.name = "MazePreview"
	maze_node.set_script(maze_script)
	maze_node.theme_loader = _theme
	maze_node.custom_minimum_size = Vector2(640, 320)
	_visual_container.add_child(maze_node)
	maze_node.bg_texture = _theme.bg_texture


func _spawn_collectible_preview() -> void:
	# Centered container for the whole collectible (Image + Label)
	var root := Control.new()
	root.name = "ColPreview"
	root.custom_minimum_size = Vector2(300, 300)
	_visual_container.add_child(root)
	
	# 1. Base (Theme Image or Procedural Circle)
	if _theme.col_texture:
		var tex_rect := TextureRect.new()
		tex_rect.name = "BaseImage"
		tex_rect.texture = _theme.col_texture
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.size = Vector2(250, 250)
		tex_rect.position = Vector2(25, 25)
		root.add_child(tex_rect)
	else:
		var panel := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = _theme.col_color
		style.corner_radius_top_left = 60
		style.corner_radius_top_right = 60
		style.corner_radius_bottom_right = 60
		style.corner_radius_bottom_left = 60
		panel.add_theme_stylebox_override("panel", style)
		panel.size = Vector2(180, 180)
		panel.position = Vector2(60, 60)
		root.add_child(panel)

	# 2. Identifier Label (Always show "A")
	var label := Label.new()
	label.text = "A"
	label.add_theme_color_override("font_color", _theme.col_text_color if not _theme.col_texture else Color.WHITE)
	label.add_theme_font_size_override("font_size", 100)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Outline for visibility on images
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 12)
	label.size = root.custom_minimum_size
	root.add_child(label)


func _spawn_themes_preview() -> void:
	var hbox = HBoxContainer.new()
	hbox.name = "ThemesPreview"
	hbox.add_theme_constant_override("separation", 30)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_visual_container.add_child(hbox)
	
	var available = ThemeLoader.get_available_themes()
	var others: Array[String] = []
	for t in available:
		if t != Config.theme_dir_name:
			others.append(t)
			
	others.shuffle()
	var count = min(3, others.size())
	
	if count == 0:
		# Fallback if no other themes installed
		var tex_rect = TextureRect.new()
		tex_rect.texture = load("res://images/lm_icon_new.png")
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.custom_minimum_size = Vector2(180, 180)
		hbox.add_child(tex_rect)
		return
	
	for i in range(count):
		var t_name = others[i]
		var loader = ThemeLoader.new()
		loader.load_theme(t_name)
		
		# Pick randomly between player and chaser
		var tex = loader.player_texture
		if loader.chaser_texture and randf() > 0.5:
			tex = loader.chaser_texture
			
		# Fallback to default icon if theme is totally missing player/chaser
		if not tex: tex = load("res://images/lm_icon_new.png")
			
		var tex_rect = TextureRect.new()
		tex_rect.texture = tex
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.custom_minimum_size = Vector2(180, 180)
		hbox.add_child(tex_rect)


func _on_left_pressed() -> void:
	if _current_slide > 0:
		_current_slide -= 1
		_update_slide()


func _on_right_pressed() -> void:
	if _current_slide < SLIDES.size() - 1:
		_current_slide += 1
		_update_slide()
	else:
		_on_back_pressed()


func _on_back_pressed() -> void:
	TTS.stop()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
