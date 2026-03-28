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

signal tts_status_changed

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

## 0 = Off, 1 = Slow, 2 = Medium, 3 = Fast
var chaser_level: int = 1

## Moves per second for the Chaser. Read-only, based on chaser_level.
var chaser_speed: float:
	get:
		match chaser_level:
			2: return 1.0 # Medium
			3: return 1.5 # Fast
			_: return 0.65 # Slow (default)

const LANGUAGES: Array[String] = ["auto", "en", "cs", "de", "es", "fr", "pt", "vi", "tr", "it", "pl"]
const SUPPORTED_LANGS: Array[String] = ["en", "cs", "de", "es", "fr", "pt", "vi", "tr", "it", "pl"]

## Transient: the active word + emoji for the current Words-mode round.
## Format: {"word": "CAT", "emoji": "🐱"}  — NOT persisted.
var current_word: Dictionary = {}

## Cache of language codes that have at least one TTS voice installed.
var _installed_tts_langs: Array[String] = []

## Map of language codes to their first available voice ID.
var _tts_voice_cache: Dictionary = {}

var _is_first_boot: bool = true

## Whether the TTS scan has completed at least once.
var tts_ready: bool = false

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
var color_floor: Color = Color("#1A1C23")       # Brand dark

## Wall / background colour.
var color_wall: Color = Color("#EEEEEE")        # Brand light grey

## Start cell floor colour (Sky blue tint).
var color_start: Color = Color("#1188FF").lerp(Color("#1A1C23"), 0.7)

## End cell floor colour (Yellow accent tint).
var color_end: Color = Color("#FFCC00").lerp(Color("#1A1C23"), 0.7)


# ─────────────────────────────────────────────────────────────────────────────
#  LIFECYCLE & SAVE/LOAD
# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	load_settings()
	TranslationServer.set_locale(get_effective_language())
	
	# Perform full TTS scan synchronously to ensure correct voice is ready before any sounds play
	refresh_tts_cache()

## Synchronously scan for available TTS voices for all supported languages.
## Includes a retry mechanism for Android/Google TV as the voice service can be slow to bind.
func refresh_tts_cache() -> void:
	tts_ready = false
	tts_status_changed.emit()
	
	var attempts := 0
	var max_attempts := 10
	var all_voices: Array = []
	
	while attempts < max_attempts:
		all_voices = DisplayServer.tts_get_voices()
		if not all_voices.is_empty():
			break
		
		attempts += 1
		# Wait 200ms before retrying on Android (TV engine cold start)
		OS.delay_msec(200)
	
	if all_voices.is_empty():
		push_warning("TTS: No voices found after %d attempts. Initialization aborted." % max_attempts)
		tts_ready = true # Allow system to proceed (to system defaults) but log warning
		return

	var new_langs: Array[String] = []
	var new_cache: Dictionary = {}
	
	for lang_code in LANGUAGES:
		var target_lang := lang_code
		if target_lang == "auto":
			target_lang = get_effective_language()
			
		var target_prefix := target_lang.to_lower() + "_"
		var target_dash_prefix := target_lang.to_lower() + "-"
		
		var found_voice_id := ""
		for v in all_voices:
			var v_lang: String = v.get("language", "").to_lower()
			if v_lang == target_lang.to_lower() or v_lang.begins_with(target_prefix) or v_lang.begins_with(target_dash_prefix):
				found_voice_id = v.get("id", "")
				break
		
		if not found_voice_id.is_empty():
			new_langs.append(lang_code)
			new_cache[lang_code] = found_voice_id
	
	_installed_tts_langs = new_langs
	_tts_voice_cache = new_cache
	tts_ready = true
	tts_status_changed.emit()
	
	# Announce app title ONLY on first boot to confirm readiness
	if _is_first_boot:
		_is_first_boot = false
		warm_up_tts(TranslationServer.translate("app_title"))
	else:
		warm_up_tts() # Silent whisper for subsequent refreshes

## Quick retrieval of cached voice ID.
func get_tts_voice(lang_code: String) -> String:
	var exact_id = _tts_voice_cache.get(lang_code, "")
	if not exact_id.is_empty():
		return exact_id
	
	# Best-effort fallback: Search all cached IDs for anything matching the prefix
	if not lang_code.is_empty():
		var prefix := lang_code.to_lower() + "_"
		var dash_prefix := lang_code.to_lower() + "-"
		for k in _tts_voice_cache.keys():
			if k.to_lower().begins_with(prefix) or k.to_lower().begins_with(dash_prefix):
				return _tts_voice_cache[k]
				
	return ""

## Instantaneous cached check for voice availability.
func is_tts_available(lang_code: String) -> bool:
	return _installed_tts_langs.has(lang_code)

## Primes the TTS engine to reduce latency.
func warm_up_tts(text: String = "") -> void:
	if text.strip_edges().is_empty():
		return
	TTS.warm_up(get_effective_language(), text)

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("Game", "game_mode", game_mode)
	config.set_value("Game", "difficulty", difficulty)
	config.set_value("Game", "language", language)
	config.set_value("Game", "voice_hints", voice_hints)
	config.set_value("Game", "chaser_level", chaser_level)
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
		chaser_level   = config.get_value("Game", "chaser_level", 1)
		theme_dir_name = config.get_value("Theme", "dir_name", theme_dir_name)

## Return the effective language code, resolving "auto" from OS locale.
func get_effective_language() -> String:
	if language != "auto":
		if language in SUPPORTED_LANGS:
			return language
		return "en"
	
	# Auto-detect from OS (True system source)
	var os_lang := OS.get_locale_language().to_lower().split("_")[0]
	if os_lang in SUPPORTED_LANGS:
		return os_lang
	
	# Secondary auto-detect from TranslationServer 
	var locale := TranslationServer.get_locale().split("_")[0].to_lower()
	if locale in SUPPORTED_LANGS:
		return locale
		
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
		var file_name: String = dir.get_next()
		while file_name != "":
			if dir.current_is_dir() and not file_name.begins_with("."):
				if not out_list.has(file_name):
					out_list.append(file_name)
			file_name = dir.get_next()
