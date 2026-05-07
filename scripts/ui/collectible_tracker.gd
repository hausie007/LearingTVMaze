## collectible_tracker.gd
## ---------------------------------------------------------------------------
## Collectible tracker for the in-game HUD.
##
## Same visual style as the original word display: dim grey labels that
## light up yellow with a pop animation on collection.
##
## Numbers/Letters: page-based sliding window. Shows a page of 9 items.
## Only shifts when ALL visible items are collected, jumping forward by
## (window_size - 1) to keep one overlap item for visual continuity.
## ---------------------------------------------------------------------------
class_name CollectibleTracker
extends MarginContainer


# ── Configuration ────────────────────────────────────────────────────────────

## Numbers/Letters: page size.
const NUM_LETTER_WINDOW: int = 9

## Current-target highlight color (bright white-gold to stand out).
const CURRENT_TARGET_COLOR := Color(1.0, 0.95, 0.7)

## Pulse animation — large pump so it's impossible to miss.
const PULSE_SCALE_MAX: float = 1.3
const PULSE_DURATION: float = 0.45

## Ellipsis uses the same dim color as uncollected letters (no extra fade).
const ELLIPSIS_ALPHA: float = 1.0

## Delay before shifting the page after the last item is collected.
const SLIDE_DELAY: float = 0.45

## Fade duration for the page shift.
const SLIDE_FADE_DURATION: float = 0.18

## Spacing between labels.
const LABEL_SEPARATION: int = 14
const OUTER_SEPARATION: int = 6
const WORD_EMOJI_WIDTH: float = 100.0
const WORD_MIN_WINDOW: int = 3


# ── State ────────────────────────────────────────────────────────────────────

var _sequence: Array[String] = []
var _learning_type: String = ""
var _word_emoji: String = ""
var _current_index: int = 0
var _collected_count: int = 0
var _max_visible: int = NUM_LETTER_WINDOW

## The start index of the current page/window.
var _window_start: int = 0

## Accent color for collected items (default yellow, overridden per-player in race mode).
var _collected_color: Color = UIColors.YELLOW

## Override the default font size (0 = use automatic sizing).
var font_size_override: int = 0

## The container for label nodes.
var _label_row: HBoxContainer = null
var _ellipsis_left: Label = null
var _ellipsis_right: Label = null
var _emoji_label: Label = null

## Cached label references for efficient updates.
var _labels: Array[Label] = []
## Map: label position in row → sequence index
var _label_indices: Array[int] = []

## Active pulse tween on the current target.
var _pulse_tween: Tween = null

## Pending delayed slide timer.
var _slide_timer: SceneTreeTimer = null

## Coalesces resize-driven word layout rebuilds.
var _word_fit_rebuild_queued: bool = false

## Optional external width budget. Used by the HUD because the tracker's own
## minimum size can be made too wide by the labels it already created.
var _available_width_limit: float = 0.0


# ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	add_theme_constant_override("margin_bottom", 16)
	_ensure_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _learning_type == "words":
		_queue_word_fit_rebuild()


func _ensure_layout() -> void:
	if _label_row == null:
		_build_layout()


# ── Public API ───────────────────────────────────────────────────────────────

## Configure the tracker with a full sequence and its type.
func setup(sequence: Array[String], learning_type: String, word_emoji: String = "") -> void:
	_ensure_layout()
	_sequence = sequence
	_learning_type = learning_type
	_word_emoji = word_emoji
	_current_index = 0
	_collected_count = 0
	_window_start = 0
	_cancel_pending_slide()
	# Update ellipsis sizes to match any font override.
	if font_size_override > 0:
		if _ellipsis_left != null:
			_ellipsis_left.add_theme_font_size_override("font_size", font_size_override)
		if _ellipsis_right != null:
			_ellipsis_right.add_theme_font_size_override("font_size", font_size_override)
	_compute_max_visible()
	_rebuild_labels_instant()
	_queue_word_fit_rebuild()


## Update the tracker to reflect new collection state.
func update_progress(current_index: int, collected_count: int) -> void:
	if current_index == _current_index and collected_count == _collected_count:
		return
	var old_collected := _collected_count
	_current_index = current_index
	_collected_count = collected_count

	# Check if the page needs to shift: all visible items are now collected.
	var window_end := _window_start + _max_visible - 1  # last visible index
	var needs_page_shift := false

	if _sequence.size() > _max_visible:
		# Page shift when collected_count passes beyond the last visible item.
		if _collected_count > window_end and window_end < _sequence.size() - 1:
			needs_page_shift = true

	if needs_page_shift:
		# Light up collected items in the current page first.
		_light_up_collected(old_collected)
		# Then schedule the page shift.
		_schedule_delayed_slide()
	else:
		# Just update states in place.
		_update_label_states(old_collected)


## Override the max visible count.
func set_max_visible(count: int) -> void:
	_max_visible = clampi(count, 3, 50)


## Limit the word tracker to the parent layout's real center-lane budget.
func set_available_width_limit(width: float) -> void:
	var next_width := maxf(width, 0.0)
	if is_equal_approx(_available_width_limit, next_width):
		return
	_available_width_limit = next_width
	if _learning_type == "words":
		_queue_word_fit_rebuild()


# ── Window Calculation ───────────────────────────────────────────────────────

## Get the visible indices for the current page.
func _get_current_page() -> Array[int]:
	var result: Array[int] = []
	if _sequence.size() <= _max_visible:
		# Everything fits — no paging needed.
		for i in range(_sequence.size()):
			result.append(i)
		return result
	var end := mini(_window_start + _max_visible, _sequence.size())
	for i in range(_window_start, end):
		result.append(i)
	return result


## Advance the page: shift by (window_size - 1) for overlap continuity.
func _advance_page() -> void:
	if _sequence.size() <= _max_visible:
		return
	var shift := _max_visible - 1
	_window_start = mini(_window_start + shift, _sequence.size() - _max_visible)
	_window_start = maxi(_window_start, 0)


# ── Layout ───────────────────────────────────────────────────────────────────

func _build_layout() -> void:
	var outer := HBoxContainer.new()
	outer.anchors_preset = Control.PRESET_FULL_RECT
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.alignment = BoxContainer.ALIGNMENT_CENTER
	outer.add_theme_constant_override("separation", 6)
	add_child(outer)

	_emoji_label = Label.new()
	_emoji_label.add_theme_font_override("font", UIHelpers.get_emoji_font())
	_emoji_label.add_theme_font_size_override("font_size", 76)
	_emoji_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_emoji_label.visible = false
	outer.add_child(_emoji_label)

	var spacer_after_emoji := Control.new()
	spacer_after_emoji.custom_minimum_size.x = 12
	spacer_after_emoji.visible = false
	outer.add_child(spacer_after_emoji)
	_emoji_label.set_meta("spacer", spacer_after_emoji)

	_ellipsis_left = Label.new()
	_ellipsis_left.text = "…"
	_ellipsis_left.add_theme_font_size_override("font_size", 68)
	_ellipsis_left.add_theme_color_override("font_color", Color(UIColors.TEXT_DIM, ELLIPSIS_ALPHA))
	_ellipsis_left.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ellipsis_left.visible = false
	outer.add_child(_ellipsis_left)

	_label_row = HBoxContainer.new()
	_label_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_label_row.add_theme_constant_override("separation", LABEL_SEPARATION)
	outer.add_child(_label_row)

	_ellipsis_right = Label.new()
	_ellipsis_right.text = "…"
	_ellipsis_right.add_theme_font_size_override("font_size", 68)
	_ellipsis_right.add_theme_color_override("font_color", Color(UIColors.TEXT_DIM, ELLIPSIS_ALPHA))
	_ellipsis_right.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ellipsis_right.visible = false
	outer.add_child(_ellipsis_right)


func _compute_max_visible() -> void:
	if _learning_type != "words":
		_max_visible = NUM_LETTER_WINDOW
		return

	if _sequence.is_empty():
		_max_visible = 0
		return

	var avail := _available_width_for_words()
	if _estimated_word_tracker_width(_sequence.size(), false) <= avail:
		_max_visible = _sequence.size()
		return

	var largest_page := mini(_sequence.size(), NUM_LETTER_WINDOW)
	for count in range(largest_page, WORD_MIN_WINDOW - 1, -1):
		if _estimated_word_tracker_width(count, true) <= avail:
			_max_visible = count
			return

	_max_visible = mini(_sequence.size(), WORD_MIN_WINDOW)


# ── Build / Rebuild ──────────────────────────────────────────────────────────

## Instant rebuild — no animation. Used on initial setup.
func _rebuild_labels_instant() -> void:
	_kill_pulse()
	_clear_labels()

	if _sequence.is_empty():
		_ellipsis_left.visible = false
		_ellipsis_right.visible = false
		_set_emoji_visible(false)
		return

	# Emoji
	if not _word_emoji.is_empty() and _learning_type == "words":
		_set_emoji_visible(true)
		_emoji_label.text = _word_emoji
	else:
		_set_emoji_visible(false)

	var visible_indices := _get_current_page()
	if visible_indices.is_empty():
		_ellipsis_left.visible = false
		_ellipsis_right.visible = false
		return

	_update_ellipsis(visible_indices)
	_create_labels(visible_indices)
	_start_pulse()


## Animated rebuild — advance page, fade out old, rebuild, fade in new.
func _rebuild_labels_animated() -> void:
	_cancel_pending_slide()
	_kill_pulse()

	# Advance to the next page.
	_advance_page()

	# Fade out existing labels.
	var fade_tw := create_tween()
	fade_tw.set_parallel(true)
	for child in _label_row.get_children():
		fade_tw.tween_property(child, "modulate:a", 0.0, SLIDE_FADE_DURATION) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	# After fade-out, rebuild and fade in.
	fade_tw.set_parallel(false)
	fade_tw.tween_callback(_do_rebuild_and_fade_in)


func _do_rebuild_and_fade_in() -> void:
	_clear_labels()

	if _sequence.is_empty():
		_ellipsis_left.visible = false
		_ellipsis_right.visible = false
		return

	var visible_indices := _get_current_page()
	if visible_indices.is_empty():
		return

	_update_ellipsis(visible_indices)
	_create_labels(visible_indices)

	# Fade in new labels.
	var fade_in := create_tween()
	fade_in.set_parallel(true)
	for lbl in _labels:
		if lbl == null:
			continue
		lbl.modulate.a = 0.0
		fade_in.tween_property(lbl, "modulate:a", 1.0, SLIDE_FADE_DURATION) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	fade_in.set_parallel(false)
	fade_in.tween_callback(_start_pulse)


# ── Helpers ──────────────────────────────────────────────────────────────────

func _clear_labels() -> void:
	for child in _label_row.get_children():
		child.queue_free()
	_labels.clear()
	_label_indices.clear()


func _update_ellipsis(visible_indices: Array[int]) -> void:
	var first_visible: int = visible_indices[0]
	var last_visible: int = visible_indices[visible_indices.size() - 1]
	_ellipsis_left.visible = first_visible > 0
	_ellipsis_right.visible = last_visible < _sequence.size() - 1


func _create_labels(visible_indices: Array[int]) -> void:
	var total_visible := visible_indices.size()
	var font_size := _font_size_for_count(total_visible)
	var min_w := _min_width_for_count(total_visible)

	# RTL support for words
	if _learning_type == "words":
		var lang: String = Config.current_word.get("lang", "")
		if lang in ["ar", "fa", "he", "ur"]:
			_label_row.layout_direction = Control.LAYOUT_DIRECTION_RTL
		else:
			_label_row.layout_direction = Control.LAYOUT_DIRECTION_LTR

	for seq_idx in visible_indices:
		var text: String = _sequence[seq_idx]

		# Spaces in words
		if text == " ":
			var spacer := Control.new()
			spacer.custom_minimum_size.x = min_w * 0.6
			_label_row.add_child(spacer)
			_labels.append(null)
			_label_indices.append(seq_idx)
			continue

		var lbl := Label.new()
		lbl.text = text
		lbl.add_theme_font_size_override("font_size", font_size)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.custom_minimum_size.x = min_w
		lbl.pivot_offset = Vector2(min_w / 2.0, font_size / 2.0)

		# Color based on state
		if seq_idx < _collected_count:
			lbl.add_theme_color_override("font_color", _collected_color)
		elif seq_idx == _current_index:
			lbl.add_theme_color_override("font_color", _collected_color.lerp(Color.WHITE, 0.6))
		else:
			lbl.add_theme_color_override("font_color", UIColors.TEXT_DIM)

		_label_row.add_child(lbl)
		_labels.append(lbl)
		_label_indices.append(seq_idx)


## Light up newly collected labels in the current page (before shifting).
func _light_up_collected(old_collected: int) -> void:
	for i in range(_labels.size()):
		var lbl := _labels[i]
		if lbl == null:
			continue
		var seq_idx := _label_indices[i]
		if seq_idx >= old_collected and seq_idx < _collected_count:
			lbl.add_theme_color_override("font_color", _collected_color)
			lbl.scale = Vector2.ONE
			var tw := create_tween()
			tw.tween_property(lbl, "scale", Vector2(1.3, 1.3), 0.1) \
				.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			tw.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.15) \
				.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## Schedule the page shift after a delay.
func _schedule_delayed_slide() -> void:
	_cancel_pending_slide()
	_kill_pulse()
	_slide_timer = get_tree().create_timer(SLIDE_DELAY)
	_slide_timer.timeout.connect(_rebuild_labels_animated, CONNECT_ONE_SHOT)


func _cancel_pending_slide() -> void:
	if _slide_timer != null:
		if _slide_timer.timeout.is_connected(_rebuild_labels_animated):
			_slide_timer.timeout.disconnect(_rebuild_labels_animated)
		_slide_timer = null


## Update colors/animations when the page stays the same.
func _update_label_states(old_collected: int) -> void:
	_kill_pulse()

	for i in range(_labels.size()):
		var lbl := _labels[i]
		if lbl == null:
			continue
		var seq_idx := _label_indices[i]

		if seq_idx < _collected_count:
			lbl.add_theme_color_override("font_color", _collected_color)
			if seq_idx >= old_collected:
				lbl.scale = Vector2.ONE
				var tw := create_tween()
				tw.tween_property(lbl, "scale", Vector2(1.3, 1.3), 0.1) \
					.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
				tw.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.15) \
					.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		elif seq_idx == _current_index:
			lbl.add_theme_color_override("font_color", _collected_color.lerp(Color.WHITE, 0.6))
		else:
			lbl.add_theme_color_override("font_color", UIColors.TEXT_DIM)

	_start_pulse()


func _start_pulse() -> void:
	var target_label_idx := _label_indices.find(_current_index)
	if target_label_idx < 0 or target_label_idx >= _labels.size():
		return
	var lbl := _labels[target_label_idx]
	if lbl == null:
		return

	_kill_pulse()
	lbl.scale = Vector2.ONE
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(lbl, "scale", Vector2(PULSE_SCALE_MAX, PULSE_SCALE_MAX), PULSE_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(lbl, "scale", Vector2(1.0, 1.0), PULSE_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _kill_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
		_pulse_tween = null


# ── Sizing ───────────────────────────────────────────────────────────────────

func _font_size_for_count(count: int) -> int:
	if font_size_override > 0:
		return font_size_override
	if _learning_type == "words":
		if count > 24:
			return 42
		elif count > 16:
			return 52
	return 68


func _min_width_for_count(count: int) -> int:
	if font_size_override > 0:
		# Scale width proportionally to font size.
		return int(float(font_size_override) * 0.85)
	if _learning_type == "words":
		if count > 24:
			return 38
		elif count > 16:
			return 48
	return 60


func _set_emoji_visible(vis: bool) -> void:
	if _emoji_label != null:
		_emoji_label.visible = vis
		var spacer = _emoji_label.get_meta("spacer", null)
		if spacer != null:
			spacer.visible = vis


func _queue_word_fit_rebuild() -> void:
	if _word_fit_rebuild_queued or _sequence.is_empty():
		return
	_word_fit_rebuild_queued = true
	call_deferred("_rebuild_for_current_word_width_if_needed")


func _rebuild_for_current_word_width_if_needed() -> void:
	_word_fit_rebuild_queued = false
	if _learning_type != "words" or _sequence.is_empty():
		return

	var old_max_visible := _max_visible
	var old_window_start := _window_start
	_compute_max_visible()
	_clamp_window_start()
	if _max_visible != old_max_visible or _window_start != old_window_start:
		_rebuild_labels_instant()


func _clamp_window_start() -> void:
	if _sequence.size() <= _max_visible:
		_window_start = 0
		return
	_window_start = clampi(_window_start, 0, _sequence.size() - _max_visible)


func _available_width_for_words() -> float:
	if _available_width_limit > 1.0:
		return _available_width_limit
	if size.x > 1.0:
		return size.x
	var parent_control := get_parent() as Control
	if parent_control != null and parent_control.size.x > 1.0:
		return parent_control.size.x
	if get_viewport() != null:
		return get_viewport_rect().size.x - 200.0
	return 1920.0 - 200.0


func _estimated_word_tracker_width(visible_count: int, include_paging_chrome: bool) -> float:
	if visible_count <= 0:
		return 0.0

	var width := 0.0
	if not _word_emoji.is_empty():
		width += WORD_EMOJI_WIDTH

	width += _widest_word_page_width(visible_count)

	if include_paging_chrome and _sequence.size() > visible_count:
		var ellipsis_width := _ellipsis_width_for_count(visible_count)
		width += (ellipsis_width * 2.0) + (float(OUTER_SEPARATION) * 2.0)

	return width


func _widest_word_page_width(visible_count: int) -> float:
	var min_w := float(_min_width_for_count(visible_count))
	var widest := 0.0
	var max_start := maxi(_sequence.size() - visible_count, 0)

	for start in range(max_start + 1):
		var end := mini(start + visible_count, _sequence.size())
		var page_width := 0.0
		for i in range(start, end):
			if _sequence[i] == " ":
				page_width += min_w * 0.6
			else:
				page_width += min_w
		if end > start:
			page_width += float(end - start - 1) * float(LABEL_SEPARATION)
		widest = maxf(widest, page_width)

	return widest


func _ellipsis_width_for_count(visible_count: int) -> float:
	var font_size := _font_size_for_count(visible_count)
	return maxf(float(font_size) * 0.65, 36.0)
