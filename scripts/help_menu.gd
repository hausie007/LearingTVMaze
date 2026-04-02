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
	{"icon": "settings",    "text": "help_slide_6_text",    "type": "icon"},
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
	
	# Focus right button initially
	_right_btn.grab_focus()
	
	_update_slide()


func _process(delta: float) -> void:
	_anim_time += delta
	_update_animations()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()
	
	if event.is_action_pressed("ui_left"):
		get_viewport().set_input_as_handled()
		_on_left_pressed()
		
	if event.is_action_pressed("ui_right") or event.is_action_pressed("ui_accept"):
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
			_icon_rect.texture = load("res://images/lm_icon.png")
		"maze":
			_spawn_maze_preview()
		"icon":
			_icon_rect.visible = true
			_update_icon(slide.icon)
		"collectible":
			_spawn_collectible_preview()
	
	# 4. Arrow Visibility
	_left_btn.disabled = (_current_slide == 0)
	_right_btn.disabled = (_current_slide == SLIDES.size() - 1)
	
	# Keep focus on an active button
	if _right_btn.disabled and _right_btn.has_focus():
		_left_btn.grab_focus()
	elif _left_btn.disabled and _left_btn.has_focus():
		_right_btn.grab_focus()

	_update_animations()


func _update_icon(icon_name: String) -> void:
	match icon_name:
		"player":
			_icon_rect.texture = _theme.player_texture
		"finish":
			_icon_rect.texture = _theme.end_texture
		"chaser":
			_icon_rect.texture = _theme.chaser_texture
		"settings":
			_icon_rect.visible = false


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
	root.custom_minimum_size = Vector2(400, 400)
	_visual_container.add_child(root)
	
	# 1. Base (Theme Image or Procedural Circle)
	if _theme.col_texture:
		var tex_rect := TextureRect.new()
		tex_rect.name = "BaseImage"
		tex_rect.texture = _theme.col_texture
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.size = Vector2(350, 350)
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
		panel.size = Vector2(220, 220)
		panel.position = Vector2(90, 90)
		root.add_child(panel)

	# 2. Identifier Label (Always show "A")
	var label := Label.new()
	label.text = "A"
	label.add_theme_color_override("font_color", _theme.col_text_color if not _theme.col_texture else Color.WHITE)
	label.add_theme_font_size_override("font_size", 140)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Outline for visibility on images
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 12)
	label.size = root.custom_minimum_size
	root.add_child(label)


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
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
