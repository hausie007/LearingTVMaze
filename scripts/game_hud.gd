## game_hud.gd
## ---------------------------------------------------------------------------
## Top-bar HUD showing stopwatch, word progress, and move counter.
##
## Attach to a CanvasLayer child of GameManager. The GameManager calls
## public methods to update displays as the game state changes.
## ---------------------------------------------------------------------------
class_name GameHUD
extends CanvasLayer


const HUD_HEIGHT: float = 160.0

var _time_label: Label = null
var _moves_label: Label = null
var _word_container: HBoxContainer = null
var _word_letter_labels: Array[Label] = []


# ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	layer = 5
	_build_ui()


# ── Public API ───────────────────────────────────────────────────────────────

## Update the stopwatch display.
func update_time(elapsed: float) -> void:
	if _time_label:
		var mins: int = int(elapsed) / 60
		var secs: int = int(elapsed) % 60
		_time_label.text = "%02d:%02d" % [mins, secs]


## Update the move counter display.
func update_moves(count: int) -> void:
	if _moves_label:
		_moves_label.text = "%d" % count


## Rebuild the word display for Words mode. Clears if not applicable.
func update_word_display(word_data: Dictionary, game_mode: int) -> void:
	_word_letter_labels.clear()
	for child in _word_container.get_children():
		child.queue_free()

	if game_mode != Config.GameMode.WORDS or word_data.is_empty():
		return

	var emoji: String = word_data.get("emoji", "")
	var word: String = word_data.get("word", "")
	if word.is_empty():
		return

	# Emoji label
	if not emoji.is_empty():
		var emoji_label := Label.new()
		emoji_label.text = emoji
		emoji_label.add_theme_font_size_override("font_size", 96)
		emoji_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_word_container.add_child(emoji_label)

		var spacer := Control.new()
		spacer.custom_minimum_size.x = 12
		_word_container.add_child(spacer)

	# Letter labels — dimmed by default
	# Dynamic font scaling to fit longer phrases (1920 viewport width)
	var font_size: int = 80
	var min_w: float = 72.0
	
	if word.length() > 24:
		font_size = 48
		min_w = 42.0
	elif word.length() > 16:
		font_size = 60
		min_w = 54.0

	for i in range(word.length()):
		if word[i] == " ":
			var spacer := Control.new()
			spacer.custom_minimum_size.x = min_w * 0.6
			_word_container.add_child(spacer)
			_word_letter_labels.append(null) # Placeholder for space
			continue

		var lbl := Label.new()
		lbl.text = word[i]
		lbl.add_theme_font_size_override("font_size", font_size)
		lbl.add_theme_color_override("font_color", Color(0.3, 0.33, 0.4))  # Dim Navy
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.custom_minimum_size.x = min_w
		lbl.pivot_offset = Vector2(min_w / 2.0, font_size / 2.0)
		_word_container.add_child(lbl)
		_word_letter_labels.append(lbl)


## Light up a letter in the word HUD when collected.
func light_up_letter(index: int) -> void:
	if index < 0 or index >= _word_letter_labels.size():
		return

	var lbl: Label = _word_letter_labels[index]
	if not lbl: return # Skip spaces
	lbl.add_theme_color_override("font_color", UIColors.YELLOW)

	# Pop animation
	var tw := create_tween()
	tw.tween_property(lbl, "scale", Vector2(1.3, 1.3), 0.1).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## Return the HUD height for maze layout calculations.
func get_height() -> float:
	return HUD_HEIGHT


# ── UI Construction ──────────────────────────────────────────────────────────

func _build_ui() -> void:
	# Background panel spanning full width at the top
	var bg_panel := PanelContainer.new()
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.12, 0.16, 0.90)
	bg_style.content_margin_left = 20
	bg_style.content_margin_right = 20
	bg_style.content_margin_top = 8
	bg_style.content_margin_bottom = 8
	bg_panel.add_theme_stylebox_override("panel", bg_style)
	bg_panel.anchors_preset = Control.PRESET_TOP_WIDE
	bg_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bg_panel.custom_minimum_size.y = HUD_HEIGHT
	add_child(bg_panel)

	# Main HBox: [Stopwatch] [center word area] [Moves]
	var hbox := HBoxContainer.new()
	hbox.anchors_preset = Control.PRESET_FULL_RECT
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 12)
	bg_panel.add_child(hbox)

	# Left: Stopwatch
	_time_label = Label.new()
	_time_label.text = "00:00"
	_time_label.add_theme_font_size_override("font_size", 64)
	_time_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	_time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_time_label.custom_minimum_size.x = 250
	hbox.add_child(_time_label)

	# Center: Word display area (flexible, fills remaining space)
	_word_container = HBoxContainer.new()
	_word_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_word_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_word_container.add_theme_constant_override("separation", 4)
	hbox.add_child(_word_container)

	# Right: Move counter
	_moves_label = Label.new()
	_moves_label.text = "0"
	_moves_label.add_theme_font_size_override("font_size", 64)
	_moves_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	_moves_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_moves_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_moves_label.custom_minimum_size.x = 200
	hbox.add_child(_moves_label)
