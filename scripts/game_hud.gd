## game_hud.gd
## ---------------------------------------------------------------------------
## Top-bar HUD showing collectible tracker, player icons, and mission text.
##
## Attach to a CanvasLayer child of GameManager. The GameManager calls
## public methods to update displays as the game state changes.
##
## Timer and move counter have been removed from the visual HUD.
## ---------------------------------------------------------------------------
class_name GameHUD
extends CanvasLayer


const HUD_HEIGHT: float = 160.0
const SIDE_LANE_MIN_WIDTH: float = 300.0
const SIDE_LANE_MAX_WIDTH: float = 560.0
const SIDE_LANE_VIEWPORT_FRACTION: float = 0.27

var _desc_label: Label = null
var _word_container: HBoxContainer = null
var _word_letter_labels: Array[Label] = []
var _root_panel: Control = null   # dimmed by OLED guard
var _left_lane: Control = null
var _right_lane: Control = null
var _player_strip: VBoxContainer = null
var _right_player_strip: VBoxContainer = null
var _tracker: CollectibleTracker = null
var _last_tracker_hash: String = ""

## Per-player race trackers (race mode only).
var _race_container: VBoxContainer = null
var _race_trackers: Dictionary = {}  # peer_id -> CollectibleTracker


# ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	layer = 5
	_build_ui()
	if get_viewport() != null and not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)


# ── Public API ───────────────────────────────────────────────────────────────

func update_role(_role_key: String, _color: Color = UIColors.YELLOW) -> void:
	pass


## Unified tracker update. Replaces the old target/word/letter APIs.
func update_tracker(sequence: Array[String], current_index: int, collected_count: int,
					learning_type: String, word_emoji: String = "") -> void:
	if _tracker != null:
		_tracker.visible = true
		# Only rebuild chips when the sequence itself changes.
		var seq_hash := str(sequence) + learning_type + word_emoji
		if seq_hash != _last_tracker_hash:
			_last_tracker_hash = seq_hash
			_tracker.setup(sequence, learning_type, word_emoji)
		_tracker.update_progress(current_index, collected_count)
	# Hide legacy containers when the new tracker is active.
	if _word_container != null:
		_word_container.visible = false
	if _desc_label != null:
		_desc_label.visible = false
	# Hide race trackers when the shared tracker is active.
	if _race_container != null:
		_race_container.visible = false


## ── Race Mode: Per-Player Trackers ──────────────────────────────────────────

## Set up per-player race tracker rows alongside player badges.
## Layout moves sliding trackers to the outer edges next to enlarged badges.
func setup_race_trackers(players: Array[Dictionary], sequence: Array[String],
							learning_type: String) -> void:
	if _player_strip == null or _right_player_strip == null:
		return
		
	# Hide central legacy tracker elements
	if _tracker != null: _tracker.visible = false
	if _desc_label != null: _desc_label.visible = false
	if _word_container != null: _word_container.visible = false
	if _race_container != null: _race_container.visible = false

	# Clear and show outer strips
	for child in _player_strip.get_children():
		child.queue_free()
	for child in _right_player_strip.get_children():
		child.queue_free()
	
	_race_trackers.clear()
	
	var count := players.size()
	if count <= 0:
		_set_side_lanes_visible(false)
		return
		
	_set_side_lanes_visible(true)
	_player_strip.visible = true
	_right_player_strip.visible = count > 1

	for i in range(count):
		var p: Dictionary = players[i]
		var peer_id: int = p.get("peer_id", 0)
		var color: Color = p.get("color", UIColors.YELLOW)
		var is_left := (i % 2 == 0)
		
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if is_left else Control.SIZE_SHRINK_END
		
		# Enlarged badge
		var badge := UIHelpers.build_player_chip(p, count, 1.4)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if is_left else Control.SIZE_SHRINK_END
		var badge_slot := _create_badge_slot(badge, not is_left)
		
		# Tracker
		var font := 48 if count <= 2 else 36
		var max_vis := 7 if count <= 2 else 5
		var tracker := CollectibleTracker.new()
		tracker._collected_color = color
		tracker.font_size_override = font
		tracker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tracker.set_max_visible(max_vis)
		_race_trackers[peer_id] = tracker
		tracker.setup(sequence, learning_type)

		if is_left:
			row.add_child(badge_slot)
			row.add_child(tracker)
			_player_strip.add_child(row)
		else:
			row.add_child(tracker)
			row.add_child(badge_slot)
			_right_player_strip.add_child(row)
			
		# Ensure the tracker's letters grow outwards from the badge.
		# By default it's [A][B][C]. If the badge is on the right, 'C' would be next to it.
		# Flipping layout direction makes it [C][B][A], so 'A' is next to the badge.
		if not is_left:
			if _right_player_strip.is_layout_rtl():
				tracker.layout_direction = Control.LAYOUT_DIRECTION_LTR
			else:
				tracker.layout_direction = Control.LAYOUT_DIRECTION_RTL


## Update a single racer's progress in race mode.
func update_race_tracker(peer_id: int, current_index: int, collected_count: int) -> void:
	var tracker := _race_trackers.get(peer_id) as CollectibleTracker
	if tracker != null:
		tracker.update_progress(current_index, collected_count)


## Show/hide the player strip for multiplayer modes.
## Each dict: {"character_id": String, "color": Color, "role": String}
func set_players(players: Array[Dictionary]) -> void:
	if _player_strip == null:
		return
	for child in _player_strip.get_children():
		child.queue_free()
	if _right_player_strip != null:
		for child in _right_player_strip.get_children():
			child.queue_free()

	_player_strip.visible = players.size() > 0
	_set_side_lanes_visible(players.size() > 0)
	if _right_player_strip != null:
		_right_player_strip.visible = players.size() > 1

	for i in range(players.size()):
		var chip := UIHelpers.build_player_chip(players[i], players.size(), 1.4)
		if i % 2 == 1 and _right_player_strip != null:
			chip.size_flags_horizontal = Control.SIZE_SHRINK_END
			_right_player_strip.add_child(chip)
		else:
			chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			_player_strip.add_child(chip)


## Update the countdown on the chaser's chip.
func update_chaser_countdown(steps: int) -> void:
	var update_in_strip = func(strip: Control) -> void:
		if strip == null: return
		for chip in strip.get_children():
			var lbl := chip.find_child("ChaserCountdownLabel", true, false) as Label
			if lbl != null:
				if steps > 0:
					lbl.text = tr("hud_chaser_in") % steps
					lbl.visible = true
				else:
					lbl.text = ""
					lbl.visible = false

	update_in_strip.call(_player_strip)
	update_in_strip.call(_right_player_strip)


# ── Backward Compatibility Bridges ──────────────────────────────────────────
# These methods are called by the existing game managers and will continue
# to work until they are migrated to the new update_tracker() API.

func update_target_display(_target: String, _progress_index: int, _total: int) -> void:
	_word_letter_labels.clear()
	for child in _word_container.get_children():
		child.queue_free()

## Rebuild the word display for Words mode. Clears if not applicable.
func update_word_display(word_data: Dictionary, game_mode: int) -> void:
	_word_letter_labels.clear()
	for child in _word_container.get_children():
		child.queue_free()

	if game_mode != Config.GameMode.WORDS or word_data.is_empty():
		return

	var lang: String = word_data.get("lang", "")
	if lang in ["ar", "fa", "he", "ur"]:
		_word_container.layout_direction = Control.LAYOUT_DIRECTION_RTL
	else:
		_word_container.layout_direction = Control.LAYOUT_DIRECTION_LTR

	var emoji: String = word_data.get("emoji", "")
	var word: String = word_data.get("word", "")
	if word.is_empty():
		return

	# Emoji label
	if not emoji.is_empty():
		var emoji_label := Label.new()
		emoji_label.text = emoji
		emoji_label.add_theme_font_override("font", UIHelpers.get_emoji_font())
		emoji_label.add_theme_font_size_override("font_size", 76)
		emoji_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_word_container.add_child(emoji_label)

		var spacer := Control.new()
		spacer.custom_minimum_size.x = 12
		_word_container.add_child(spacer)

	# Letter labels — dimmed by default
	# Dynamic font scaling to fit longer phrases (1920 viewport width)
	var font_size: int = 68
	var min_w: float = 60.0
	
	if word.length() > 24:
		font_size = 42
		min_w = 38.0
	elif word.length() > 16:
		font_size = 52
		min_w = 48.0

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
		lbl.add_theme_color_override("font_color", UIColors.TEXT_DIM)  # Dim Navy
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


func set_mission_description(_desc: String, _enlarge: bool = false) -> void:
	# Textual goals are removed — the collectible tracker is the visual instruction.
	if _desc_label != null:
		_desc_label.visible = false


## Return the HUD height for maze layout calculations.
func get_height() -> float:
	if _root_panel != null:
		return maxf(HUD_HEIGHT, _root_panel.get_combined_minimum_size().y)
	return HUD_HEIGHT


## Dim the HUD to the given opacity (animated).
## Call when the player has been idle — reduces burn-in risk for static top bar.
func dim(target_alpha: float = 0.28, duration: float = 2.0) -> void:
	if _root_panel == null:
		return
	var tw := create_tween()
	tw.tween_property(_root_panel, "modulate:a", target_alpha, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Restore the HUD to full opacity.
## Call immediately when the player interacts again.
func undim(duration: float = 0.25) -> void:
	if _root_panel == null:
		return
	var tw := create_tween()
	tw.tween_property(_root_panel, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# ── UI Construction ──────────────────────────────────────────────────────────

func _build_ui() -> void:
	# Background panel spanning full width at the top
	var bg_panel := PanelContainer.new()
	_root_panel = bg_panel
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = UIColors.BG_HUD
	bg_style.content_margin_left = 20
	bg_style.content_margin_right = 20
	bg_style.content_margin_top = 8
	bg_style.content_margin_bottom = 8
	bg_panel.add_theme_stylebox_override("panel", bg_style)
	bg_panel.anchors_preset = Control.PRESET_TOP_WIDE
	bg_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bg_panel.custom_minimum_size.y = HUD_HEIGHT
	add_child(bg_panel)

	# Main HBox: [stable side lane] [Center: tracker + desc] [stable side lane]
	var hbox := HBoxContainer.new()
	hbox.anchors_preset = Control.PRESET_FULL_RECT
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 12)
	bg_panel.add_child(hbox)

	_left_lane = Control.new()
	_left_lane.visible = false
	_left_lane.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_left_lane.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(_left_lane)

	var left_lane_row := HBoxContainer.new()
	left_lane_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	left_lane_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	_left_lane.add_child(left_lane_row)

	# Left: Player Strip (hidden by default — shown in multiplayer)
	_player_strip = VBoxContainer.new()
	_player_strip.visible = false
	_player_strip.add_theme_constant_override("separation", 8)
	_player_strip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_player_strip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left_lane_row.add_child(_player_strip)

	# Center: Container for tracker and descriptions
	var center_vbox := VBoxContainer.new()
	center_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center_vbox.add_theme_constant_override("separation", 8)
	hbox.add_child(center_vbox)
	
	# Tracker (new component)
	_tracker = CollectibleTracker.new()
	_tracker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tracker.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_vbox.add_child(_tracker)

	_right_lane = Control.new()
	_right_lane.visible = false
	_right_lane.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_right_lane.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(_right_lane)

	var right_lane_row := HBoxContainer.new()
	right_lane_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	right_lane_row.alignment = BoxContainer.ALIGNMENT_END
	_right_lane.add_child(right_lane_row)

	# Right: Player Strip for symmetrical layout in 3+ players
	_right_player_strip = VBoxContainer.new()
	_right_player_strip.visible = false
	_right_player_strip.add_theme_constant_override("separation", 8)
	_right_player_strip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_right_player_strip.size_flags_horizontal = Control.SIZE_SHRINK_END
	right_lane_row.add_child(_right_player_strip)
	_update_side_lane_widths()

	# Race mode: per-player tracker rows (hidden by default)
	_race_container = VBoxContainer.new()
	_race_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_race_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_race_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_race_container.add_theme_constant_override("separation", 2)
	_race_container.visible = false
	center_vbox.add_child(_race_container)

	# Legacy word container (backward compat — used until full migration)
	_word_container = HBoxContainer.new()
	_word_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_word_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_word_container.add_theme_constant_override("separation", 4)
	center_vbox.add_child(_word_container)

	_desc_label = Label.new()
	_desc_label.add_theme_font_size_override("font_size", 25)
	_desc_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.custom_minimum_size.x = 400
	_desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_vbox.add_child(_desc_label)



	# ── Player Chip Builder moved to UIHelpers ──

func _create_badge_slot(badge: Control, align_right: bool) -> Control:
	var slot := Control.new()
	slot.set_meta("hud_badge_slot", true)
	slot.custom_minimum_size.x = _side_lane_width()
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_END if align_right else BoxContainer.ALIGNMENT_BEGIN
	slot.add_child(row)
	row.add_child(badge)
	return slot

func _set_side_lanes_visible(show_lanes: bool) -> void:
	if _left_lane != null:
		_left_lane.visible = show_lanes
	if _right_lane != null:
		_right_lane.visible = show_lanes

func _on_viewport_size_changed() -> void:
	_update_side_lane_widths()

func _update_side_lane_widths() -> void:
	var lane_width := _side_lane_width()
	for lane in [_left_lane, _right_lane]:
		if lane != null:
			lane.custom_minimum_size.x = lane_width
	for strip in [_player_strip, _right_player_strip]:
		if strip == null:
			continue
		for row in strip.get_children():
			_update_badge_slot_widths(row, lane_width)

func _update_badge_slot_widths(node: Node, lane_width: float) -> void:
	if node == null:
		return
	var control := node as Control
	if control != null and bool(control.get_meta("hud_badge_slot", false)):
		control.custom_minimum_size.x = lane_width
	for child in node.get_children():
		_update_badge_slot_widths(child, lane_width)

func _side_lane_width() -> float:
	var viewport_width := get_viewport().get_visible_rect().size.x if get_viewport() != null else 1920.0
	return clampf(viewport_width * SIDE_LANE_VIEWPORT_FRACTION, SIDE_LANE_MIN_WIDTH, SIDE_LANE_MAX_WIDTH)
