class_name CharacterCatalog
extends RefCounted

static var _cached_catalog: Array[Dictionary] = []

static func clear_cache() -> void:
	_cached_catalog.clear()

static func build_catalog() -> Array[Dictionary]:
	if not _cached_catalog.is_empty():
		return _cached_catalog.duplicate(true)

	var catalog: Array[Dictionary] = []
	var themes: Array[String] = ThemeLoader.get_available_themes()

	for theme_dir in themes:
		var loader: ThemeLoader = ThemeLoader.get_cached(theme_dir)
		var title: String = loader.get_display_title(theme_dir)
		_append_entries_for_type(catalog, theme_dir, title, "player", loader)
		_append_entries_for_type(catalog, theme_dir, title, "chaser", loader)

	catalog.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("display_name", "")) < String(b.get("display_name", ""))
	)

	_cached_catalog = catalog.duplicate(true)
	return catalog

static func _append_entries_for_type(
	catalog: Array[Dictionary],
	theme_dir: String,
	theme_title: String,
	char_type: String,
	loader: ThemeLoader,
) -> void:
	var frames: Array[Texture2D] = _frames_for(loader, char_type)
	if frames.is_empty():
		return

	var numeral: String = "I" if char_type == "player" else "II"
	catalog.append({
		"id": "%s:%s" % [theme_dir, char_type],
		"theme_dir": theme_dir,
		"theme_title": theme_title,
		"type": char_type,
		"frame_index": 0,
		"display_name": "%s %s" % [theme_title, numeral],
	})

static func _frames_for(loader: ThemeLoader, char_type: String) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	if char_type == "player":
		frames = loader.player_frames.duplicate()
		if frames.is_empty() and loader.player_texture != null:
			frames.append(loader.player_texture)
	else:
		frames = loader.chaser_frames.duplicate()
		if frames.is_empty() and loader.chaser_texture != null:
			frames.append(loader.chaser_texture)
	return frames

static func get_texture_by_id(character_id: String) -> Texture2D:
	var parts := character_id.split(":")
	if parts.size() < 2:
		return null

	var theme_dir := parts[0]
	var char_type := parts[1]
	var frame_index := int(parts[2]) if parts.size() > 2 else 0

	var loader: ThemeLoader = ThemeLoader.get_cached(theme_dir)
	var frames := _frames_for(loader, char_type)
	if frames.is_empty():
		return null

	var clamped := clampi(frame_index, 0, frames.size() - 1)
	return frames[clamped]

static func display_name_for_id(character_id: String) -> String:
	for entry in build_catalog():
		if String(entry.get("id", "")) == character_id:
			return String(entry.get("display_name", character_id))
	return character_id

static func get_preview_data_by_id(character_id: String) -> Dictionary:
	var parts := _split_character_id(character_id)
	if parts.is_empty():
		return {}

	var theme_dir: String = String(parts.get("theme_dir", ""))
	var char_type: String = String(parts.get("type", ""))
	var loader: ThemeLoader = ThemeLoader.get_cached(theme_dir)
	var frames: Array[Texture2D] = _frames_for(loader, char_type)
	if frames.is_empty():
		return {}

	return {
		"frames": frames,
		"fps": loader.player_fps if char_type == "player" else loader.chaser_fps,
	}

static func _split_character_id(character_id: String) -> Dictionary:
	var parts := character_id.split(":")
	if parts.size() < 2:
		return {}

	return {
		"theme_dir": parts[0],
		"type": parts[1],
		"frame_index": int(parts[2]) if parts.size() > 2 else 0,
	}
