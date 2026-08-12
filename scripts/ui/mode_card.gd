extends Button

@onready var icon_label: Label = $MarginContainer/VBox/IconLabel
@onready var title_label: Label = $MarginContainer/VBox/TitleLabel
@onready var subtitle_label: Label = $MarginContainer/VBox/SubtitleLabel

var _preview: CharacterPreview = null
var _image_icon: TextureRect = null
var _icon_font_size: int = 80
var _title_font_size: int = 42
var _subtitle_font_size: int = 24
var _preview_size: Vector2 = Vector2(112, 112)
var _base_normal_style: StyleBox = null
var _selected_normal_style: StyleBoxFlat = null
var _selected: bool = false
var _icon_color: Color = UIColors.PARCHMENT
var _title_color: Color = UIColors.TEXT_PRIMARY
var _normal_subtitle_color: Color = UIColors.TEXT_SECONDARY
var _selected_subtitle_color: Color = UIColors.TEXT_PRIMARY
var _focused: bool = false
var _scale_tween: Tween = null
var _badge_label: Label = null
var _is_horizontal: bool = false
var _hbox: HBoxContainer = null
var _text_vbox: VBoxContainer = null

const SELECTED_SCALE := Vector2(1.10, 1.10)
const FOCUSED_SCALE := Vector2(1.16, 1.16)
const NORMAL_SCALE := Vector2.ONE

func _ready() -> void:
	_base_normal_style = get_theme_stylebox("normal").duplicate()
	_selected_normal_style = _create_selected_style()
	_apply_selection_style()
	_sync_pivot()
	_apply_emphasis(false)
	# Internal focus animation
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	if UIHelpers.is_likely_tv():
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		mouse_entered.connect(grab_focus)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_sync_pivot()

func setup(icon_text: String, title_text: String, subtitle_text: String) -> void:
	# Use call_deferred if icons/labels are not ready
	if not is_node_ready(): await ready
	
	if icon_text.begins_with("res://"):
		icon_label.visible = false
		if _image_icon == null:
			_image_icon = TextureRect.new()
			_image_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			_image_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			$MarginContainer/VBox.add_child(_image_icon)
			$MarginContainer/VBox.move_child(_image_icon, icon_label.get_index())
		var tex := load(icon_text) as Texture2D
		if tex != null:
			_image_icon.texture = tex
		_image_icon.custom_minimum_size = Vector2(0, _icon_font_size * 2.9)
		_image_icon.visible = true
	else:
		if _image_icon != null:
			_image_icon.visible = false
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
		_apply_emphasis(true)

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
	if _image_icon != null and _image_icon.texture != null:
		_image_icon.visible = true
	else:
		icon_label.visible = not icon_label.text.is_empty()

func set_selected(selected: bool, animated: bool = true) -> void:
	if not is_node_ready(): await ready
	_selected = selected
	_apply_selection_style()
	_apply_emphasis(animated)

func set_custom_palette(
	normal_bg: Color,
	normal_border: Color,
	accent_bg: Color,
	accent_border: Color,
	icon_color: Color,
	title_color: Color,
	subtitle_color: Color
) -> void:
	if not is_node_ready(): await ready
	_base_normal_style = _create_card_style(normal_bg, normal_border, 16, 2, 0)
	# Use warm cream border for selected / focus states
	var sel_border := UIColors.SELECTED_BORDER
	_selected_normal_style = _create_card_style(accent_bg, sel_border, 16, 4, 8)
	var focus_style := _create_card_style(accent_bg, sel_border, 16, 5, 12, UIColors.SELECTED_GLOW)
	add_theme_stylebox_override("focus", focus_style)
	add_theme_stylebox_override("hover", focus_style)
	add_theme_stylebox_override("pressed", focus_style)
	_icon_color = icon_color
	_title_color = title_color
	_normal_subtitle_color = subtitle_color
	_selected_subtitle_color = title_color
	_apply_text_sizes()
	_apply_selection_style()

## Set a player-count badge in the top-left corner of the card.
## Pass empty text to hide.
func set_badge(badge_text: String, _badge_color: Color = UIColors.FOCUS_GOLD) -> void:
	if not is_node_ready(): await ready
	if badge_text.is_empty():
		if _badge_label != null:
			_badge_label.visible = false
		return
	if _badge_label == null:
		_badge_label = Label.new()
		_badge_label.name = "BadgeLabel"
		_badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_badge_label)
	_badge_label.text = badge_text
	_badge_label.add_theme_font_size_override("font_size", 23)
	_badge_label.add_theme_color_override("font_color", UIColors.TEXT_PRIMARY)
	_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Position in top-left corner
	_badge_label.position = Vector2(12, 8)
	_badge_label.size = Vector2(220, 32)
	_badge_label.visible = true
	UIHelpers.apply_semibold(_badge_label)

func _apply_text_sizes() -> void:
	if _is_horizontal:
		_apply_horizontal_sizes()
		return
		
	icon_label.add_theme_font_size_override("font_size", _icon_font_size)
	if _image_icon != null:
		_image_icon.custom_minimum_size = Vector2(0, _icon_font_size * 2.9)
	title_label.add_theme_font_size_override("font_size", _title_font_size)
	subtitle_label.add_theme_font_size_override("font_size", _subtitle_font_size)
	icon_label.add_theme_color_override("font_color", _icon_color)
	title_label.add_theme_color_override("font_color", _title_color)
	# Font weights: SemiBold for titles, Medium for subtitles
	UIHelpers.apply_semibold(title_label)
	UIHelpers.apply_medium(subtitle_label)
	$MarginContainer/VBox.add_theme_constant_override("separation", max(6, int(float(_subtitle_font_size) * 0.45)))
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	# Force labels to allow shrinking horizontally. Godot autowrap labels 
	# get stuck at their max expanded width otherwise.
	title_label.custom_minimum_size.x = 10
	subtitle_label.custom_minimum_size.x = 10
	icon_label.custom_minimum_size.x = 10
	title_label.size.x = 0
	subtitle_label.size.x = 0
	icon_label.size.x = 0
	
	# Always reserve height for 2 lines so wrapping titles don't shift the icon
	title_label.custom_minimum_size.y = maxf(34.0, ceilf(float(_title_font_size) * 2.6))
	subtitle_label.custom_minimum_size.y = maxf(20.0, float(_subtitle_font_size) * 1.4)
	icon_label.clip_text = true
	title_label.clip_text = false
	subtitle_label.clip_text = false

func _create_selected_style() -> StyleBoxFlat:
	return _create_card_style(UIColors.UI_BLUE, UIColors.SELECTED_BORDER, 16, 4, 8)

func _create_card_style(bg_color: Color, border_color: Color, corner_radius: int, border_width: int, shadow_sz: int, expand_shadow_color: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_corner_radius_all(corner_radius)
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.border_color = border_color
	# Use warm shadow, with optional glow overlay
	if expand_shadow_color.a > 0.01:
		style.shadow_color = expand_shadow_color
		style.shadow_size = shadow_sz + 4
	else:
		style.shadow_color = UIColors.SELECTED_SHADOW
		style.shadow_size = shadow_sz
	return style

func _apply_selection_style() -> void:
	if _base_normal_style == null or _selected_normal_style == null:
		return
	add_theme_stylebox_override("normal", _selected_normal_style if _selected else _base_normal_style)
	subtitle_label.add_theme_color_override("font_color", _selected_subtitle_color if _selected else _normal_subtitle_color)

func _on_focus_entered() -> void:
	_focused = true
	_apply_selection_style()
	_apply_emphasis(true)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(subtitle_label, "theme_override_colors/font_color", Color(1.0, 1.0, 1.0, 1.0), 0.1)

func _on_focus_exited() -> void:
	_focused = false
	_apply_selection_style()
	_apply_emphasis(true)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(subtitle_label, "theme_override_colors/font_color", _selected_subtitle_color if _selected else _normal_subtitle_color, 0.1)

func _sync_pivot() -> void:
	var pivot_size: Vector2 = size
	if pivot_size.x <= 0.0 or pivot_size.y <= 0.0:
		pivot_size = custom_minimum_size
	if pivot_size.x > 0.0 and pivot_size.y > 0.0:
		pivot_offset = pivot_size * 0.5

func _apply_emphasis(animated: bool) -> void:
	z_index = 2 if _focused else (1 if _selected else 0)

	if _scale_tween != null and _scale_tween.is_valid():
		_scale_tween.kill()

	var target_scale: Vector2 = NORMAL_SCALE
	if _focused:
		target_scale = FOCUSED_SCALE
	elif _selected:
		target_scale = SELECTED_SCALE

	_sync_pivot()

	if animated:
		_scale_tween = create_tween()
		_scale_tween.set_trans(Tween.TRANS_CUBIC)
		_scale_tween.set_ease(Tween.EASE_OUT)
		_scale_tween.tween_property(self, "scale", target_scale, 0.18)
	else:
		scale = target_scale

func set_horizontal_layout() -> void:
	if _is_horizontal:
		return
	_is_horizontal = true
	
	if not is_node_ready(): await ready
	
	var vbox = $MarginContainer/VBox
	vbox.visible = false
	
	$MarginContainer.add_theme_constant_override("margin_left", 24)
	$MarginContainer.add_theme_constant_override("margin_right", 24)
	$MarginContainer.add_theme_constant_override("margin_top", 12)
	$MarginContainer.add_theme_constant_override("margin_bottom", 12)
	
	_hbox = HBoxContainer.new()
	_hbox.name = "HBox"
	_hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	_hbox.add_theme_constant_override("separation", 24)
	_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	$MarginContainer.add_child(_hbox)
	
	_text_vbox = VBoxContainer.new()
	_text_vbox.name = "TextVBox"
	_text_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_text_vbox.add_theme_constant_override("separation", 2)
	_text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	_reparent_children_for_horizontal()
	
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	title_label.custom_minimum_size.y = 0
	subtitle_label.custom_minimum_size.y = 0
	
	_apply_horizontal_sizes()

func _reparent_children_for_horizontal() -> void:
	if not _is_horizontal or _hbox == null or _text_vbox == null:
		return
		
	var vbox = $MarginContainer/VBox
	
	var icon_nodes: Array[Control] = []
	if _preview != null and _preview.get_parent() == vbox:
		icon_nodes.append(_preview)
	if icon_label.get_parent() == vbox:
		icon_nodes.append(icon_label)
	if _image_icon != null and _image_icon.get_parent() == vbox:
		icon_nodes.append(_image_icon)
		
	var text_nodes: Array[Control] = []
	if title_label.get_parent() == vbox:
		text_nodes.append(title_label)
	if subtitle_label.get_parent() == vbox:
		text_nodes.append(subtitle_label)
		
	for node in icon_nodes:
		vbox.remove_child(node)
		_hbox.add_child(node)
		
	if _text_vbox.get_parent() == null:
		_hbox.add_child(_text_vbox)
		
	for node in text_nodes:
		vbox.remove_child(node)
		_text_vbox.add_child(node)

func _apply_horizontal_sizes() -> void:
	var icon_sz := 56
	var title_sz := 28
	var subtitle_sz := 18
	
	icon_label.add_theme_font_size_override("font_size", icon_sz)
	if _image_icon != null:
		_image_icon.custom_minimum_size = Vector2(icon_sz * 1.3, icon_sz * 1.3)
	if _preview != null:
		_preview.custom_minimum_size = Vector2(icon_sz * 1.5, icon_sz * 1.5)
		
	title_label.add_theme_font_size_override("font_size", title_sz)
	subtitle_label.add_theme_font_size_override("font_size", subtitle_sz)
	
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	title_label.custom_minimum_size.x = 10
	subtitle_label.custom_minimum_size.x = 10
	icon_label.custom_minimum_size.x = 10
	title_label.size.x = 0
	subtitle_label.size.x = 0
	icon_label.size.x = 0
	
	title_label.clip_text = false
	subtitle_label.clip_text = false
	
	UIHelpers.apply_semibold(title_label)
	UIHelpers.apply_medium(subtitle_label)
