## pause_dialog.gd
## ---------------------------------------------------------------------------
## Reusable in-game pause dialog shown when the Back button is pressed during
## the maze. Confirms whether the player wants to return to the main menu.
##
## Emitted signals:
##   confirmed — user pressed "Yes" (wants to leave)
##   cancelled — user pressed "No" (wants to stay)
## ---------------------------------------------------------------------------
class_name PauseDialog
extends CanvasLayer


signal confirmed
signal cancelled


var _no_button: Button = null
var _center_container: CenterContainer = null


func _init() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _ready() -> void:
	_build_ui()


## Show the dialog and grab focus on "No" (safer default for children).
func show_dialog() -> void:
	if _center_container and is_instance_valid(Config):
		UIHelpers.apply_dpad_layout(_center_container, Config.on_screen_controls)
	
	visible = true
	if _no_button:
		_no_button.grab_focus()


## Hide the dialog.
func hide_dialog() -> void:
	visible = false


# ── UI Construction ──────────────────────────────────────────────────────────

func _build_ui() -> void:
	var overlay := ColorRect.new()
	overlay.color = UIColors.OVERLAY
	overlay.anchors_preset = Control.PRESET_FULL_RECT
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var center := CenterContainer.new()
	center.anchors_preset = Control.PRESET_FULL_RECT
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	_center_container = center

	var panel := PanelContainer.new()
	var style: StyleBoxFlat = UIHelpers.create_rounded_stylebox(
		UIColors.BG_DARK, UIColors.BLUE, 20, 4
	)
	style.content_margin_left = 60
	style.content_margin_right = 60
	style.content_margin_top = 40
	style.content_margin_bottom = 40
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 30)
	panel.add_child(vbox)

	var lbl := Label.new()
	lbl.text = tr("quit_confirm")
	lbl.add_theme_font_size_override("font_size", 42)
	lbl.add_theme_color_override("font_color", UIColors.TEXT_PRIMARY)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)

	var yes_btn: Button = UIHelpers.create_styled_button(tr("yes"), 200, 80, UIColors.BLUE)
	yes_btn.pressed.connect(func(): confirmed.emit())
	hbox.add_child(yes_btn)

	_no_button = UIHelpers.create_styled_button(tr("no"), 200, 80, UIColors.YELLOW)
	_no_button.pressed.connect(func(): cancelled.emit())
	hbox.add_child(_no_button)
