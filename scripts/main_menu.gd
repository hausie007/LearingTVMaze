extends Control

@onready var play_btn: Button = %PlayButton
@onready var settings_btn: Button = %SettingsButton
@onready var help_btn: Button = %HelpButton
@onready var title_banner: TextureRect = %Title

# ── Quit Dialog ──────────────────────────────────────────────────────────────
var _quit_dialog: CanvasLayer = null
var _quit_no_button: Button = null

# Prevent "leaked" Back button presses from previous scene
var _input_locked: bool = true

func _ready() -> void:
	# Warp mouse off-screen to prevent phantom hover highlights on TV
	Input.warp_mouse(Vector2(-1, -1))
	
	play_btn.pressed.connect(_on_play_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	help_btn.pressed.connect(_on_help_pressed)
	
	# Localize UI
	# title_banner is an image now, so no tr("app_title")
	play_btn.text = tr("play")
	settings_btn.text = tr("settings")
	help_btn.text = tr("help")
	
	# Apply global dynamic styles to existing editor-built buttons
	UIHelpers.apply_style_to_button(play_btn, UIColors.BLUE)
	UIHelpers.apply_style_to_button(settings_btn, UIColors.YELLOW)
	UIHelpers.apply_style_to_button(help_btn, UIColors.YELLOW)
	
	# Pre-select Play button for TV D-pad
	play_btn.call_deferred("grab_focus")
	
	# Release input lock after a short delay
	get_tree().create_timer(0.2).timeout.connect(func(): _input_locked = false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if not _input_locked:
			if _quit_dialog and _quit_dialog.visible:
				_hide_quit_dialog()
			else:
				_show_quit_dialog()

func _input(event: InputEvent) -> void:
	if _input_locked: return
	
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

func _on_help_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/help_menu.tscn")

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
	overlay.color = UIColors.OVERLAY
	overlay.anchors_preset = Control.PRESET_FULL_RECT
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_quit_dialog.add_child(overlay)
	
	var center := CenterContainer.new()
	center.anchors_preset = Control.PRESET_FULL_RECT
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = UIColors.BG_DARK
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_right = 20
	style.corner_radius_bottom_left = 20
	style.content_margin_left = 60
	style.content_margin_right = 60
	style.content_margin_top = 40
	style.content_margin_bottom = 40
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.border_color = UIColors.BLUE
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
	
	var yes_btn := _create_dialog_button(tr("yes"), UIColors.YELLOW)
	yes_btn.pressed.connect(func(): get_tree().quit())
	hbox.add_child(yes_btn)
	
	_quit_no_button = _create_dialog_button(tr("no"), UIColors.BLUE)
	_quit_no_button.pressed.connect(_hide_quit_dialog)
	hbox.add_child(_quit_no_button)

func _create_dialog_button(txt: String, focus_color: Color) -> Button:
	return UIHelpers.create_styled_button(txt, 250, 100, focus_color, 36)
