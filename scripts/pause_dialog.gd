## pause_dialog.gd
## ---------------------------------------------------------------------------
## Reusable in-game pause dialog shown when the Back button is pressed during
## the maze. Confirms whether the player wants to return to the main menu.
##
## Emitted signals:
##   confirmed — user pressed "Yes" (wants to leave)
##   cancelled — user pressed "No" (wants to stay)
##
## OLED protection:
##   start_idle_animation() — called by GameManager after 30 s of pause idle;
##                            starts a slow border-colour cycling tween.
##   show_idle_warning()    — called by GameManager after 2 min of pause idle;
##                            dims the panel and shows a "Still there?" hint.
##   After 5 min of total idle the dialog auto-navigates home.
## ---------------------------------------------------------------------------
class_name PauseDialog
extends CanvasLayer


signal confirmed
signal cancelled


var _no_button: Button = null
var _center_container: CenterContainer = null
var _panel: PanelContainer = null
var _panel_style: StyleBoxFlat = null
var _idle_hint_label: Label = null

# OLED: track idle animation state
var _hue_tween: Tween = null
var _hue: float = 0.22           # start hue (blue-ish)
var _idle_anim_active: bool = false

# OLED: auto-home guard (5 min total pause idle)
var _auto_home_timer: OledIdleGuard = null


func _init() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _ready() -> void:
	_build_ui()

	# 5-minute guard: if the dialog is still open after 5 min, just go home.
	_auto_home_timer = OledIdleGuard.new()
	_auto_home_timer.name = "PauseAutoHomeGuard"
	add_child(_auto_home_timer)
	_auto_home_timer.idle_tier_1.connect(_on_auto_home_fired)
	# tier_1 is repurposed as the single threshold here; tier_2 is unused.
	_auto_home_timer.tier1_sec = 300.0   # 5 minutes
	_auto_home_timer.tier2_sec = 9999.0  # never


## Show the dialog and grab focus on "No" (safer default for children).
func show_dialog() -> void:
	if _center_container and is_instance_valid(Config):
		UIHelpers.apply_dpad_layout(_center_container, Config.on_screen_controls)

	visible = true
	if _no_button:
		_no_button.grab_focus()

	# Start 5-min auto-home countdown
	if _auto_home_timer:
		_auto_home_timer.reset()
		_auto_home_timer.start()


## Hide the dialog and cancel all OLED idle effects.
func hide_dialog() -> void:
	visible = false
	_stop_idle_effects()
	if _auto_home_timer:
		_auto_home_timer.stop()


# ── OLED Public API ───────────────────────────────────────────────────────────

## Called by GameManager after 30 s of pause idle.
## Starts a slow hue-cycling animation on the panel border — keeps pixels
## shifting without any visible distraction.
func start_idle_animation() -> void:
	if _idle_anim_active or not visible:
		return
	_idle_anim_active = true
	_start_hue_cycle()


## Called by GameManager after 2 min of pause idle.
## Dims the entire dialog to ~25 % opacity and shows the "Still there?" hint.
func show_idle_warning() -> void:
	if not visible:
		return
	# Dim the container
	var tw := create_tween()
	tw.tween_property(_center_container, "modulate:a", 0.25, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Show the idle hint
	if _idle_hint_label:
		_idle_hint_label.visible = true
		var tw2 := create_tween().set_loops()
		tw2.tween_property(_idle_hint_label, "modulate:a", 0.3, 1.4).set_trans(Tween.TRANS_SINE)
		tw2.tween_property(_idle_hint_label, "modulate:a", 1.0, 1.4).set_trans(Tween.TRANS_SINE)


# ── Internal OLED Helpers ─────────────────────────────────────────────────────

func _start_hue_cycle() -> void:
	# Animate _hue from 0→1 (full hue rotation) over ~40 s.
	# _process_border_hue() reads _hue every frame and repaints the border.
	_hue_tween = create_tween().set_loops()
	_hue_tween.tween_property(self, "_hue", 1.0, 40.0).set_trans(Tween.TRANS_LINEAR)
	_hue_tween.tween_callback(func(): _hue = 0.0)
	set_process(true)


func _process(_delta: float) -> void:
	if not _idle_anim_active or _panel_style == null:
		return
	# Apply hue-shifted border colour at low saturation so it's subtle.
	_panel_style.border_color = Color.from_hsv(_hue, 0.55, 0.90, 1.0)


func _stop_idle_effects() -> void:
	_idle_anim_active = false
	set_process(false)
	if _hue_tween:
		_hue_tween.kill()
		_hue_tween = null
	# Restore original panel border colour
	if _panel_style:
		_panel_style.border_color = UIColors.BLUE
	# Restore full opacity
	if _center_container:
		_center_container.modulate.a = 1.0
	if _idle_hint_label:
		_idle_hint_label.visible = false


func _on_auto_home_fired() -> void:
	# 5 minutes of idle while paused → just go home.
	hide_dialog()
	DisplayServer.screen_set_keep_on(false)
	get_tree().change_scene_to_file(Scenes.HOME)


# ── UI Construction ───────────────────────────────────────────────────────────

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

	_panel = PanelContainer.new()
	_panel_style = UIHelpers.create_rounded_stylebox(
		UIColors.CARD_NEUTRAL, UIColors.SELECTED_BORDER, 20, 6
	)
	_panel_style.shadow_color = UIColors.SELECTED_SHADOW
	_panel_style.shadow_size = 12
	_panel_style.content_margin_left = 60
	_panel_style.content_margin_right = 60
	_panel_style.content_margin_top = 40
	_panel_style.content_margin_bottom = 40
	_panel.add_theme_stylebox_override("panel", _panel_style)
	center.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 30)
	_panel.add_child(vbox)

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

	# "Still there?" hint — hidden until tier-2 idle fires
	_idle_hint_label = Label.new()
	_idle_hint_label.text = tr("still_there")
	_idle_hint_label.add_theme_font_size_override("font_size", 28)
	_idle_hint_label.add_theme_color_override("font_color", UIColors.TEXT_SECONDARY)
	_idle_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_idle_hint_label.visible = false
	vbox.add_child(_idle_hint_label)
