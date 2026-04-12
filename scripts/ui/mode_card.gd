extends Button

@onready var icon_label: Label = $MarginContainer/VBox/IconLabel
@onready var title_label: Label = $MarginContainer/VBox/TitleLabel
@onready var subtitle_label: Label = $MarginContainer/VBox/SubtitleLabel

func _ready() -> void:
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
	tween.tween_property(subtitle_label, "theme_override_colors/font_color", UIColors.TEXT_SUBTITLE, 0.1)
	z_index = 0
