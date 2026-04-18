extends Button

@onready var icon_label: Label = $MarginContainer/VBox/IconLabel
@onready var title_label: Label = $MarginContainer/VBox/TitleLabel
@onready var subtitle_label: Label = $MarginContainer/VBox/SubtitleLabel

var _preview: CharacterPreview = null
var _icon_font_size: int = 80
var _title_font_size: int = 42
var _subtitle_font_size: int = 24
var _preview_size: Vector2 = Vector2(112, 112)
var _base_normal_style: StyleBox = null
var _selected_normal_style: StyleBoxFlat = null
var _selected: bool = false

func _ready() -> void:
	_base_normal_style = get_theme_stylebox("normal").duplicate()
	_selected_normal_style = _create_selected_style()
	_apply_selection_style()
	# Internal focus animation
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	mouse_entered.connect(grab_focus)

func setup(icon_text: String, title_text: String, subtitle_text: String) -> void:
	# Use call_deferred if icons/labels are not ready
	if not is_node_ready(): await ready
	
	icon_label.text = icon_text
	icon_label.visible = not icon_text.is_empty()
	title_label.text = title_text
	subtitle_label.text = subtitle_text
	subtitle_label.visible = not subtitle_text.is_empty()
	_apply_text_sizes()
	if _preview != null:
		_preview.visible = false

func configure_compact(icon_size: int, title_size: int, subtitle_size: int, preview_size: Vector2 = Vector2(72, 72)) -> void:
	_icon_font_size = icon_size
	_title_font_size = title_size
	_subtitle_font_size = subtitle_size
	_preview_size = preview_size
	if is_node_ready():
		_apply_text_sizes()
		if _preview != null:
			_preview.custom_minimum_size = _preview_size

func set_character_preview(frames: Array[Texture2D], fps: float) -> void:
	if not is_node_ready(): await ready
	if _preview == null:
		_preview = CharacterPreview.new()
		_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		$MarginContainer/VBox.add_child(_preview)
		$MarginContainer/VBox.move_child(_preview, 0)

	_preview.custom_minimum_size = _preview_size
	icon_label.visible = false
	_preview.visible = true
	_preview.set_character(frames, fps)

func clear_character_preview() -> void:
	if _preview == null:
		return
	_preview.clear()
	_preview.visible = false
	icon_label.visible = not icon_label.text.is_empty()

func set_selected(selected: bool) -> void:
	if not is_node_ready(): await ready
	_selected = selected
	_apply_selection_style()

func _apply_text_sizes() -> void:
	icon_label.add_theme_font_size_override("font_size", _icon_font_size)
	title_label.add_theme_font_size_override("font_size", _title_font_size)
	subtitle_label.add_theme_font_size_override("font_size", _subtitle_font_size)
	$MarginContainer/VBox.add_theme_constant_override("separation", max(8, int(float(_subtitle_font_size) * 0.55)))
	subtitle_label.custom_minimum_size.y = maxf(28.0, float(_subtitle_font_size) * 2.0)
	icon_label.clip_text = true
	title_label.clip_text = true
	subtitle_label.clip_text = true

func _create_selected_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = UIColors.BLUE
	style.corner_radius_top_left = 15
	style.corner_radius_top_right = 15
	style.corner_radius_bottom_right = 15
	style.corner_radius_bottom_left = 15
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.border_color = Color.WHITE
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 8
	return style

func _apply_selection_style() -> void:
	if _base_normal_style == null or _selected_normal_style == null:
		return
	add_theme_stylebox_override("normal", _selected_normal_style if _selected else _base_normal_style)
	subtitle_label.add_theme_color_override("font_color", Color.WHITE if _selected else UIColors.TEXT_SUBTITLE)

func _on_focus_entered() -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(subtitle_label, "theme_override_colors/font_color", Color(1.0, 1.0, 1.0, 1.0), 0.1)
	z_index = 1

func _on_focus_exited() -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE)
	tween.tween_property(subtitle_label, "theme_override_colors/font_color", Color.WHITE if _selected else UIColors.TEXT_SUBTITLE, 0.1)
	z_index = 0
