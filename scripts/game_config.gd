## game_config.gd
## ---------------------------------------------------------------------------
## Central configuration file for all tunable game parameters.
##
## This script is registered as an Autoload singleton ("Config") so every
## other script can access values via `Config.grid_size`, etc.
##
## Settings are persisted to user://settings.cfg and managed via the
## SettingsMenu UI.
## ---------------------------------------------------------------------------
class_name GameConfig
extends Node


# ─────────────────────────────────────────────────────────────────────────────
#  ENUMS
# ─────────────────────────────────────────────────────────────────────────────

## Available game modes controlling what collectibles appear in the maze.
enum GameMode {
	NORMAL  = 0,  ## Maze only — no collectibles
	NUMBERS = 1,  ## Numbered collectibles (1, 2, 3…)
	LETTERS = 2,  ## Alphabetical collectibles (A, B, C…)
	WORDS   = 3,  ## Word letters collected in order
}

## Chaser AI speed tiers.
enum ChaserLevel {
	OFF    = 0,
	SLOW   = 1,
	MEDIUM = 2,
	FAST   = 3,
	TURBO  = 4,
}

## On-Screen Controls configuration.
enum ControlsMode {
	OFF = 0,
	LEFT_HANDED = 1,
	RIGHT_HANDED = 2,
}



# ─────────────────────────────────────────────────────────────────────────────
#  PERSISTENCE & SETTINGS LOGIC
# ─────────────────────────────────────────────────────────────────────────────

const SAVE_PATH := "user://settings.cfg"

## Current game mode. See GameMode enum.
var game_mode: int = GameMode.NUMBERS

## 0 = Very Easy, 1 = Easy, 2 = Medium, 3 = Hard, 4 = Very Hard
var difficulty: int = 1

## Current active theme directory name. "default" is the built-in fallback.
var theme_dir_name: String = "default":
	set(value):
		if theme_dir_name != value:
			theme_dir_name = value
			_theme_cache = null

## Language code for word lists. "auto" = detect from OS. Valid: "auto", "en", "cs", "de"
var language: String = "auto"

## Whether to read collected items and words aloud using TTS.
var voice_hints: bool = true

## Chaser speed tier. See ChaserLevel enum.
var chaser_level: int = ChaserLevel.MEDIUM

## Whether to prioritize smooth gameplay over visual effects (disables Glow, Anti-Aliasing).
var performance_mode: bool = true

## On-Screen Controls preference (-1 = not set/autodetect).
var on_screen_controls: int = -1


## Moves per second for the Chaser. Read-only, based on chaser_level.
var chaser_speed: float:
	get:
		match chaser_level:
			ChaserLevel.MEDIUM: return 1.0
			ChaserLevel.FAST:   return 1.5
			ChaserLevel.TURBO:  return 3.5
			_:                  return 0.65  # Slow (default)

const LANGUAGES: Array[String] = ["auto", "en", "cs", "de", "es", "fr", "pt", "vi", "tr", "it", "pl", "sv", "nb", "nl", "uk", "fi", "da", "hu", "ro", "el"]
const SUPPORTED_LANGS: Array[String] = ["en", "cs", "de", "es", "fr", "pt", "vi", "tr", "it", "pl", "sv", "nb", "nl", "uk", "fi", "da", "hu", "ro", "el"]

## Transient: the active word + emoji for the current Words-mode round.
## Format: {"word": "CAT", "emoji": "🐱"}  — NOT persisted.
var current_word: Dictionary = {}

var theme_dir: String:
	get:
		var res_path := "res://themes/".path_join(theme_dir_name)
		if DirAccess.dir_exists_absolute(res_path):
			return res_path
		
		var user_path := "user://themes/".path_join(theme_dir_name)
		if DirAccess.dir_exists_absolute(user_path):
			return user_path
			
		return "res://themes/default"

var _theme_cache: ThemeLoader = null

var theme: ThemeLoader:
	get:
		if _theme_cache == null:
			_theme_cache = ThemeLoader.new()
			_theme_cache.load_theme()
		return _theme_cache

# Difficulty -> Grid Size mapping
const DIFFICULTY_SIZES: Array[Vector2i] = [
	Vector2i(5, 4),   # Very Easy
	Vector2i(7, 6),   # Easy
	Vector2i(9, 8),   # Medium
	Vector2i(13, 10), # Hard
	Vector2i(20, 12), # Very Hard
	Vector2i(26, 13), # Insane
	Vector2i(36, 15), # Unbelievable
]

## Effective grid dimensions in cells (width × height).
var grid_size: Vector2i:
	get:
		return DIFFICULTY_SIZES[clampi(difficulty, 0, 6)]


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

func _enter_tree() -> void:
	load_settings()
	TranslationServer.set_locale(get_effective_language())

func _ready() -> void:
	# Instantiate Universal Virtual D-Pad Layout
	var dpad_script = load("res://scripts/virtual_dpad.gd")
	if dpad_script:
		var dpad_node = CanvasLayer.new()
		dpad_node.set_script(dpad_script)
		add_child(dpad_node)

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("Game", "game_mode", game_mode)
	config.set_value("Game", "difficulty", difficulty)
	config.set_value("Game", "language", language)
	config.set_value("Game", "voice_hints", voice_hints)
	config.set_value("Game", "chaser_level", chaser_level)
	config.set_value("Game", "performance_mode", performance_mode)
	config.set_value("Game", "on_screen_controls", on_screen_controls)
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
		chaser_level   = config.get_value("Game", "chaser_level", ChaserLevel.SLOW)
		performance_mode = config.get_value("Game", "performance_mode", true)
		on_screen_controls = config.get_value("Game", "on_screen_controls", -1)
		theme_dir_name = config.get_value("Theme", "dir_name", theme_dir_name)
		
	if on_screen_controls == -1:
		if DisplayServer.is_touchscreen_available() or OS.has_feature("mobile"):
			on_screen_controls = ControlsMode.RIGHT_HANDED
		else:
			on_screen_controls = ControlsMode.OFF

## Return the effective language code, resolving "auto" from OS locale.
func get_effective_language() -> String:
	if language != "auto":
		if language in SUPPORTED_LANGS:
			return language
		return "en"
	return get_auto_detected_language()

## Perform true OS/System language auto-detection, ignoring any saved preference.
func get_auto_detected_language() -> String:
	# Auto-detect from OS (True system source)
	var os_lang := OS.get_locale_language().to_lower().split("_")[0]
	if os_lang == "no": os_lang = "nb"
	
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


## Return the N-th character of the alphabet for the given language.
## For 'el' (Greek), it returns Α, Β, Γ...
## For others, it returns A, B, C...
func get_alphabet_char(index: int, lang: String) -> String:
	if lang == "el":
		var greek_alphabet = "ΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩ"
		if index >= 0 and index < greek_alphabet.length():
			return greek_alphabet[index]
		return greek_alphabet[greek_alphabet.length() - 1]
	
	# Default to Latin A-Z
	return String.chr(65 + (index % 26))
