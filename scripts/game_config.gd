## game_config.gd
## ---------------------------------------------------------------------------
## Central configuration file for all tunable game parameters.
##
## This script is registered as an Autoload singleton ("Config") so every
## other script can access values via `Config.grid_size`, etc.
##
## When a proper settings UI is added later, it will read/write these values.
## ---------------------------------------------------------------------------
class_name GameConfig
extends Node


# ─────────────────────────────────────────────────────────────────────────────
#  PERSISTENCE & SETTINGS LOGIC
# ─────────────────────────────────────────────────────────────────────────────

const SAVE_PATH := "user://settings.cfg"

## 0 = Normal, 1 = Numbers, 2 = Letters, 3 = Words
var game_mode: int = 1

## 0 = Very Easy, 1 = Easy, 2 = Medium, 3 = Hard
var difficulty: int = 1

## Current active theme directory name. "default" is the built-in fallback.
var theme_dir_name: String = "default"

## Language code for word lists. "auto" = detect from OS. Valid: "auto", "en", "cs", "de"
var language: String = "auto"

## Whether to read collected items and words aloud using TTS.
var voice_hints: bool = true
const LANGUAGES: Array[String] = ["auto", "en", "cs", "de", "es", "fr", "pt", "vi", "tr", "it", "pl"]
const SUPPORTED_LANGS: Array[String] = ["en", "cs", "de", "es", "fr", "pt", "vi", "tr", "it", "pl"]

## Transient: the active word + emoji for the current Words-mode round.
## Format: {"word": "CAT", "emoji": "🐱"}  — NOT persisted.
var current_word: Dictionary = {}

## Cache of language codes that have at least one TTS voice installed.
var _installed_tts_langs: Array[String] = []

## Map of language codes to their first available voice ID.
var _tts_voice_cache: Dictionary = {}

var theme_dir: String:
	get:
		var res_path := "res://themes/".path_join(theme_dir_name)
		if DirAccess.dir_exists_absolute(res_path):
			return res_path
		
		var user_path := "user://themes/".path_join(theme_dir_name)
		if DirAccess.dir_exists_absolute(user_path):
			return user_path
			
		return "res://themes/default"

# Difficulty -> Grid Size mapping
const DIFFICULTY_SIZES: Array[Vector2i] = [
	Vector2i(5, 4),   # Very Easy
	Vector2i(7, 6),   # Easy
	Vector2i(9, 8),   # Medium
	Vector2i(13, 10), # Hard
	Vector2i(20, 12), # Very Hard
]

## Effective grid dimensions in cells (width × height).
var grid_size: Vector2i:
	get:
		return DIFFICULTY_SIZES[clampi(difficulty, 0, 4)]


# ─────────────────────────────────────────────────────────────────────────────
#  MAZE RENDERING & PLAYER TUNING
# ─────────────────────────────────────────────────────────────────────────────

## Size of one cell in pixels (square).  Affects overall maze scale on screen.
var cell_size: int = 120

## Thickness of wall lines in pixels.
var wall_thickness: int = 6

## Cooldown between successive moves (seconds).
var move_cooldown: float = 0.20

## Duration of the slide tween when the player moves one cell (seconds).
var tween_duration: float = 0.12

## Player square size as a fraction of cell_size (0.0 – 1.0).
var player_scale: float = 0.6

## Player colour.
var player_color: Color = Color(0.25, 0.55, 0.95)  # Friendly blue

## Seconds to wait after winning before generating a new maze.
var restart_delay: float = 2.0


# ─────────────────────────────────────────────────────────────────────────────
#  COLOURS  (visual theme)
# ─────────────────────────────────────────────────────────────────────────────

## Floor colour for normal corridor cells.
var color_floor: Color = Color(0.18, 0.20, 0.25)       # Dark slate

## Wall / background colour.
var color_wall: Color = Color(0.75, 0.78, 0.82)        # Light grey

## Start cell floor colour (pale green, 75% blend with floor so it's very light).
var color_start: Color = Color(0.30, 0.85, 0.40).lerp(color_floor, 0.75)

## End cell floor colour (pale blue, 75% blend with floor so it's very light).
var color_end: Color = Color(0.25, 0.60, 0.95).lerp(color_floor, 0.75)


# ─────────────────────────────────────────────────────────────────────────────
#  LIFECYCLE & SAVE/LOAD
# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	load_settings()
	TranslationServer.set_locale(get_effective_language())
	
	# Scan for available TTS voices synchronously (it's fast)
	_scan_all_tts_voices()

## Pre-cache voice availability and voice IDs for all supported languages.
func _scan_all_tts_voices() -> void:
	_installed_tts_langs.clear()
	_tts_voice_cache.clear()
	
	# Get ALL voices from the system once
	var all_voices := DisplayServer.tts_get_voices()
	if all_voices.is_empty():
		return
	
	for lang_code in LANGUAGES:
		var target_lang := lang_code
		if target_lang == "auto":
			target_lang = get_effective_language()
			
		# Standardize the target code for prefix matching (e.g. "en")
		var target_prefix := target_lang.to_lower() + "_"
		var target_dash_prefix := target_lang.to_lower() + "-"
		
		# Look for a match among all system voices
		var found_voice_id := ""
		for v in all_voices:
			var v_lang: String = v.get("language", "").to_lower()
			# Exact match (e.g. "cs" == "cs") or prefix match (e.g. "cs" in "cs_CZ" or "cs-CZ")
			if v_lang == target_lang.to_lower() or v_lang.begins_with(target_prefix) or v_lang.begins_with(target_dash_prefix):
				found_voice_id = v.get("id", "")
				break
		
		if not found_voice_id.is_empty():
			if not _installed_tts_langs.has(lang_code):
				_installed_tts_langs.append(lang_code)
			_tts_voice_cache[lang_code] = found_voice_id

## Quick re-scan for external triggers (like entering Settings)
func refresh_tts_cache() -> void:
	_scan_all_tts_voices()

## Quick retrieval of cached voice ID.
func get_tts_voice(lang_code: String) -> String:
	return _tts_voice_cache.get(lang_code, "")

## Instantaneous cached check for voice availability.
func is_tts_available(lang_code: String) -> bool:
	return _installed_tts_langs.has(lang_code)

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("Game", "game_mode", game_mode)
	config.set_value("Game", "difficulty", difficulty)
	config.set_value("Game", "language", language)
	config.set_value("Game", "voice_hints", voice_hints)
	config.set_value("Theme", "dir_name", theme_dir_name)
	
	var err := config.save(SAVE_PATH)
	if err != OK:
		push_error("Failed to save settings to %s (Error: %s)" % [SAVE_PATH, err])

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		game_mode      = config.get_value("Game", "game_mode", game_mode)
		difficulty     = config.get_value("Game", "difficulty", difficulty)
		language       = config.get_value("Game", "language", language)
		voice_hints    = config.get_value("Game", "voice_hints", voice_hints)
		theme_dir_name = config.get_value("Theme", "dir_name", theme_dir_name)

## Return the effective language code, resolving "auto" from OS locale.
func get_effective_language() -> String:
	if language != "auto":
		if language in SUPPORTED_LANGS:
			return language
		return "en"
	
	# Auto-detect from OS (works on Android / Google TV)
	var os_lang := OS.get_locale_language()  # e.g. "cs", "en", "de"
	if os_lang in SUPPORTED_LANGS:
		return os_lang
	return "en"

## Scan available themes dynamically.
func get_available_themes() -> Array[String]:
	var themes: Array[String] = []
	
	# 1. Scan built-in themes
	_scan_theme_dir("res://themes/", themes)
	
	# 2. Scan user-downloaded themes
	_scan_theme_dir("user://themes/", themes)
	
	if themes.is_empty():
		themes.append("default")
		
	return themes

func _scan_theme_dir(path: String, out_list: Array[String]) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
		
	var dir := DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir() and not file_name.begins_with("."):
				if not out_list.has(file_name):
					out_list.append(file_name)
			file_name = dir.get_next()
