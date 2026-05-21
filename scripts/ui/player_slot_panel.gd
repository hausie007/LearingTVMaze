## player_slot_panel.gd
## ---------------------------------------------------------------------------
## Shared multiplayer player slot management.
##
## Provides:
## - Slot creation, filling, emptying, and clearing
## - Filled/empty frame styling with pulse animation
## - Character preview application (centralized from 3 copies)
## - Peer ID ordering (host first)
##
## Usage:
##   var slots := PlayerSlotPanel.new()
##   parent.add_child(slots)
##   slots.update_slots(config_dict, players_dict)
## ---------------------------------------------------------------------------
class_name PlayerSlotPanel
extends HBoxContainer

## Multiplayer green palette — single source of truth.
const MP_GREEN := UIColors.MP_GREEN
const MP_GREEN_BORDER := UIColors.MP_GREEN_BORDER
const SLOT_EMPTY_COLOR := UIColors.SLOT_EMPTY_COLOR
const SLOT_EMPTY_BG := UIColors.SLOT_EMPTY_BG

var _slot_nodes: Array[Dictionary] = []
var _pulse_tween: Tween = null


func _init() -> void:
	name = "PlayerSlots"
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 36)


## Update all player slots based on config and player map.
## Rebuilds slots if max_players changed.
func update_slots(cfg: Dictionary, player_map: Dictionary) -> void:
	var max_players := int(cfg.get("max_players", 2))
	if _slot_nodes.size() != max_players:
		clear_slots()
		for i in range(max_players):
			_create_slot(i)
	var peer_ids := ordered_peer_ids(player_map)
	for i in range(max_players):
		if i < peer_ids.size():
			var peer_id: int = peer_ids[i]
			var info := player_map[peer_id] as Dictionary
			_fill_slot(i, info)
		else:
			_empty_slot(i)
	_update_pulse_animation()


## Get the slot node dictionaries for external sizing.
func get_slot_nodes() -> Array[Dictionary]:
	return _slot_nodes


## Clear all slots and stop pulse animation.
func clear_slots() -> void:
	for slot in _slot_nodes:
		var vbox := slot["vbox"] as Control
		if is_instance_valid(vbox):
			vbox.queue_free()
	_slot_nodes.clear()
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
		_pulse_tween = null


## Order peer IDs with host first.
static func ordered_peer_ids(player_map: Dictionary) -> Array[int]:
	var peer_ids: Array[int] = []
	for key in player_map.keys():
		peer_ids.append(int(key))
	peer_ids.sort()
	if peer_ids.has(NetworkManager.HOST_PEER_ID):
		peer_ids.erase(NetworkManager.HOST_PEER_ID)
		peer_ids.push_front(NetworkManager.HOST_PEER_ID)
	return peer_ids


## Apply a character's preview frames to a CharacterPreview node.
## Centralized from 3 copies (host_lobby, join_flow, host_setup).
static func apply_character_preview(character_id: String, preview: CharacterPreview) -> void:
	if preview == null:
		return
	var preview_data: Dictionary = CharacterCatalog.get_preview_data_by_id(character_id)
	var frames_data: Array = preview_data.get("frames", [])
	var frames: Array[Texture2D] = []
	for item in frames_data:
		if item is Texture2D:
			frames.append(item)
	var fps: float = float(preview_data.get("fps", 1.0))
	if not frames.is_empty():
		preview.set_character(frames, fps)
	else:
		var fallback: Texture2D = CharacterCatalog.get_texture_by_id(character_id)
		if fallback != null:
			preview.set_character([fallback], 1.0)
		else:
			preview.clear()


# ── Internal ─────────────────────────────────────────────────────────────────

func _create_slot(index: int) -> void:
	var slot_vbox := VBoxContainer.new()
	slot_vbox.name = "Slot%d" % index
	slot_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	slot_vbox.add_theme_constant_override("separation", 8)
	slot_vbox.custom_minimum_size = Vector2(130, 150)

	var frame := PanelContainer.new()
	frame.name = "SlotFrame"
	frame.custom_minimum_size = Vector2(110, 110)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slot_vbox.add_child(frame)

	var preview := CharacterPreview.new()
	preview.name = "SlotPreview"
	preview.custom_minimum_size = Vector2(90, 90)
	preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	preview.visible = false
	frame.add_child(preview)

	var label := Label.new()
	label.name = "SlotLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.text = tr("mp_slot_waiting")
	label.add_theme_color_override("font_color", UIColors.TEXT_SECONDARY)
	slot_vbox.add_child(label)

	add_child(slot_vbox)
	_slot_nodes.append({
		"vbox": slot_vbox,
		"frame": frame,
		"preview": preview,
		"label": label,
		"is_filled": false,
	})
	_apply_empty_frame_style(frame)


func _fill_slot(index: int, info: Dictionary) -> void:
	if index >= _slot_nodes.size():
		return
	var slot := _slot_nodes[index]
	var preview := slot["preview"] as CharacterPreview
	var label := slot["label"] as Label
	var frame := slot["frame"] as PanelContainer

	var char_id := String(info.get("character_id", ""))
	apply_character_preview(char_id, preview)
	preview.visible = true

	if bool(info.get("is_host", false)):
		label.text = tr("mp_slot_you")
		label.add_theme_color_override("font_color", UIColors.YELLOW)
	else:
		label.text = CharacterCatalog.display_name_for_id(char_id)
		label.add_theme_color_override("font_color", UIColors.TEXT_PRIMARY)

	_apply_filled_frame_style(frame)
	slot["is_filled"] = true


func _empty_slot(index: int) -> void:
	if index >= _slot_nodes.size():
		return
	var slot := _slot_nodes[index]
	var preview := slot["preview"] as CharacterPreview
	var label := slot["label"] as Label
	var frame := slot["frame"] as PanelContainer

	preview.visible = false
	label.text = tr("mp_slot_waiting")
	label.add_theme_color_override("font_color", UIColors.TEXT_SECONDARY)
	_apply_empty_frame_style(frame)
	slot["is_filled"] = false


func _apply_filled_frame_style(frame: PanelContainer) -> void:
	var style := UIHelpers.create_rounded_stylebox(
		Color(UIColors.BG_DARK.r, UIColors.BG_DARK.g, UIColors.BG_DARK.b, 0.9),
		MP_GREEN_BORDER, 12, 2)
	style.content_margin_left = 10; style.content_margin_right = 10
	style.content_margin_top = 10; style.content_margin_bottom = 10
	frame.add_theme_stylebox_override("panel", style)


func _apply_empty_frame_style(frame: PanelContainer) -> void:
	var style := UIHelpers.create_rounded_stylebox(SLOT_EMPTY_BG, SLOT_EMPTY_COLOR, 12, 2)
	style.content_margin_left = 10; style.content_margin_right = 10
	style.content_margin_top = 10; style.content_margin_bottom = 10
	style.draw_center = true
	frame.add_theme_stylebox_override("panel", style)


func _update_pulse_animation() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
		_pulse_tween = null
	var empty_frames: Array[PanelContainer] = []
	for slot in _slot_nodes:
		if not slot["is_filled"]:
			empty_frames.append(slot["frame"] as PanelContainer)
	if empty_frames.is_empty():
		return
	_pulse_tween = create_tween()
	_pulse_tween.set_loops()
	for frame in empty_frames:
		frame.modulate = Color(1, 1, 1, 1)
	_pulse_tween.tween_method(func(alpha: float):
		for f in empty_frames:
			if is_instance_valid(f): f.modulate.a = alpha
	, 1.0, 0.45, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_method(func(alpha: float):
		for f in empty_frames:
			if is_instance_valid(f): f.modulate.a = alpha
	, 0.45, 1.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
