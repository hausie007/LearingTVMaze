extends Control

@onready var play_btn: Button = %PlayButton
@onready var settings_btn: Button = %SettingsButton
@onready var title_label: Label = %Title

# ── Quit Dialog ──────────────────────────────────────────────────────────────
var _quit_dialog: CanvasLayer = null
var _quit_no_button: Button = null

func _ready() -> void:
	play_btn.pressed.connect(_on_play_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	
	# Localize UI
	title_label.text = tr("app_title")
	play_btn.text = tr("play")
	settings_btn.text = tr("settings")
	
	# Pre-select Play button for TV D-pad
	play_btn.grab_focus()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _quit_dialog and _quit_dialog.visible:
			_hide_quit_dialog()
		else:
			_show_quit_dialog()
		get_viewport().set_input_as_handled()

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/settings_menu.tscn")

func _show_quit_dialog() -> void:
	if not _quit_dialog:
		_create_quit_dialog()
	
	_quit_dialog.visible = true
	if _quit_no_button:
		_quit_no_button.grab_focus() # Safer default

func _hide_quit_dialog() -> void:
	if _quit_dialog:
		_quit_dialog.visible = false
	play_btn.grab_focus()

func _create_quit_dialog() -> void:
	_quit_dialog = CanvasLayer.new()
	_quit_dialog.layer = 100
	add_child(_quit_dialog)
	
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.anchors_preset = Control.PRESET_FULL_RECT
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_quit_dialog.add_child(overlay)
	
	var center := CenterContainer.new()
	center.anchors_preset = Control.PRESET_FULL_RECT
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.17, 0.22)
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_right = 20
	style.corner_radius_bottom_left = 20
	style.content_margin_left = 60
	style.content_margin_right = 60
	style.content_margin_top = 40
	style.content_margin_bottom = 40
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 40)
	panel.add_child(vbox)
	
	var lbl := Label.new()
	lbl.text = tr("quit_confirm")
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 48)
	vbox.add_child(lbl)
	
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 50)
	vbox.add_child(hbox)
	
	var yes_btn := _create_dialog_button(tr("yes"), Color(0.8, 0.3, 0.3))
	yes_btn.pressed.connect(func(): get_tree().quit())
	hbox.add_child(yes_btn)
	
	_quit_no_button = _create_dialog_button(tr("no"), Color(0.3, 0.6, 0.4))
	_quit_no_button.pressed.connect(_hide_quit_dialog)
	hbox.add_child(_quit_no_button)

func _create_dialog_button(txt: String, focus_color: Color) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.custom_minimum_size = Vector2(250, 100)
	btn.add_theme_font_size_override("font_size", 36)
	
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.25, 0.3, 0.35)
	normal.corner_radius_top_left = 10
	normal.corner_radius_top_right = 10
	normal.corner_radius_bottom_right = 10
	normal.corner_radius_bottom_left = 10
	btn.add_theme_stylebox_override("normal", normal)
	
	var focus := StyleBoxFlat.new()
	focus.bg_color = focus_color
	focus.border_width_left = 3
	focus.border_width_top = 3
	focus.border_width_right = 3
	focus.border_width_bottom = 3
	focus.border_color = Color.WHITE
	focus.corner_radius_top_left = 10
	focus.corner_radius_top_right = 10
	focus.corner_radius_bottom_right = 10
	focus.corner_radius_bottom_left = 10
	btn.add_theme_stylebox_override("focus", focus)
	btn.add_theme_stylebox_override("hover", focus)
	
	return btn
