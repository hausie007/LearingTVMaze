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
#  UI LABEL KEYS — Translation keys for enum display values.
#  Centralized here to avoid duplication across menu scripts.
# ─────────────────────────────────────────────────────────────────────────────

## Translation keys for game modes. Indices match GameMode enum values.
const MODE_KEYS: Array[String] = ["mode_normal", "mode_numbers", "mode_letters", "mode_words"]

## Translation keys for difficulty levels. Indices match DIFFICULTY_SIZES.
const DIFF_KEYS: Array[String] = ["diff_very_easy", "diff_easy", "diff_medium", "diff_hard", "diff_very_hard", "diff_insane", "diff_unbelievable"]

## Translation keys for chaser speed tiers. Indices match ChaserLevel enum values.
const CHASER_LEVEL_KEYS: Array[String] = ["chaser_off", "chaser_slow", "chaser_medium", "chaser_fast", "chaser_turbo"]

## Translation keys for on-screen controls modes. Indices match ControlsMode enum values.
const CONTROLS_KEYS: Array[String] = ["controls_off", "controls_left", "controls_right"]


# ─────────────────────────────────────────────────────────────────────────────
#  PERSISTENCE & SETTINGS LOGIC
# ─────────────────────────────────────────────────────────────────────────────

const SAVE_PATH := "user://settings.cfg"

## Current game mode. See GameMode enum.
var game_mode: GameMode = GameMode.WORDS

## 0 = Very Easy … 6 = Unbelievable. Indices match DIFFICULTY_SIZES and DIFF_KEYS.
var difficulty: int = 1

## Current active theme directory name. "default" is the built-in fallback.
var theme_dir_name: String = "thiefs":
	set(value):
		if theme_dir_name != value:
			theme_dir_name = value
			_theme_cache = null

## Language code for the UI and system announcements. "auto" = detect from OS.
var ui_language: String = "auto"

## Language code for learning content (word lists, alphabets). "auto" = detect from OS.
var learning_language: String = "auto"

## Whether to read collected items and words aloud using TTS.
var voice_hints: bool = true

## Chaser speed tier. See ChaserLevel enum.
var chaser_level: ChaserLevel = ChaserLevel.MEDIUM

## Whether to prioritize smooth gameplay over visual effects (disables Glow, Anti-Aliasing).
var performance_mode: bool = true

## Emitted when the on-screen controls mode changes (for D-Pad layout updates).
signal on_screen_controls_changed(new_mode: int)

## On-Screen Controls preference (-1 = not set/autodetect).
var on_screen_controls: int = -1:
	set(value):
		if on_screen_controls != value:
			on_screen_controls = value
			on_screen_controls_changed.emit(value)


## Moves per second for the Chaser. Read-only, based on chaser_level.
var chaser_speed: float:
	get:
		match chaser_level:
			ChaserLevel.MEDIUM: return 1.0
			ChaserLevel.FAST:   return 1.5
			ChaserLevel.TURBO:  return 3.5
			_:                  return 0.65  # Slow (default)

## All language codes including "auto" sentinel. Canonical source for UI cycling.
const LANG_CODES: Array[String] = ["auto", "en", "cs", "de", "es", "fr", "pt", "vi", "tr", "it", "pl", "sv", "nb", "nl", "uk", "fi", "da", "hu", "ro", "el", "sk", "he"]

## Translation keys matching LANG_CODES 1:1. Used by settings and mode-selection UI.
const LANG_KEYS: Array[String] = ["lang_auto", "lang_english", "lang_czech", "lang_german", "lang_spanish", "lang_french", "lang_portuguese", "lang_vietnamese", "lang_turkish", "lang_italian", "lang_polish", "lang_swedish", "lang_norwegian", "lang_dutch", "lang_ukrainian", "lang_finnish", "lang_danish", "lang_hungarian", "lang_romanian", "lang_greek", "lang_slovak", "lang_hebrew"]

## Language codes without "auto" — used for validation and TTS scanning.
const SUPPORTED_LANGS: Array[String] = ["en", "cs", "de", "es", "fr", "pt", "vi", "tr", "it", "pl", "sv", "nb", "nl", "uk", "fi", "da", "hu", "ro", "el", "sk", "he"]

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



# ─────────────────────────────────────────────────────────────────────────────
#  LIFECYCLE & SAVE/LOAD
# ─────────────────────────────────────────────────────────────────────────────

func _enter_tree() -> void:
	load_settings()
	TranslationServer.set_locale(get_effective_ui_language())
	
	# Extra defense against phantom mouse highlights on TV
	if UIHelpers.is_likely_tv():
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
		Input.warp_mouse(Vector2(-1, -1))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		var ev = InputEventAction.new()
		ev.action = "ui_cancel"
		ev.pressed = true
		Input.parse_input_event(ev)


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("Game", "game_mode", game_mode)
	config.set_value("Game", "difficulty", difficulty)
	config.set_value("Game", "ui_language", ui_language)
	config.set_value("Game", "learning_language", learning_language)
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
		ui_language       = config.get_value("Game", "ui_language", "auto")
		learning_language = config.get_value("Game", "learning_language", "auto")
		
		# Migration: if we have an old 'language' setting, migrate it to learning_language
		if config.has_section_key("Game", "language"):
			learning_language = config.get_value("Game", "language", learning_language)
		voice_hints    = config.get_value("Game", "voice_hints", voice_hints)
		chaser_level   = config.get_value("Game", "chaser_level", ChaserLevel.SLOW)
		performance_mode = config.get_value("Game", "performance_mode", true)
		on_screen_controls = config.get_value("Game", "on_screen_controls", -1)
		theme_dir_name = config.get_value("Theme", "dir_name", theme_dir_name)
		
	if on_screen_controls == -1:
		if UIHelpers.is_likely_tv():
			on_screen_controls = ControlsMode.OFF
		elif DisplayServer.is_touchscreen_available() or OS.has_feature("mobile"):
			on_screen_controls = ControlsMode.RIGHT_HANDED
		else:
			on_screen_controls = ControlsMode.OFF

## Return the effective UI language code.
func get_effective_ui_language() -> String:
	if ui_language != "auto" and ui_language in SUPPORTED_LANGS:
		return ui_language
	return get_auto_detected_language()

## Return the effective Learning language code.
func get_effective_learning_language() -> String:
	if learning_language == "auto":
		return get_effective_ui_language()
	return learning_language


## Format a human-readable display name for a language at the given LANG_CODES index.
##
## For non-"auto" indices, returns the translated language name (e.g., "English").
## For index 0 ("auto"):
##   - is_learning=true:  "Auto (English)" — shows the effective UI language name
##   - is_learning=false: "Auto - english" — shows the auto-detected system language
##
## [ui_lang_idx] is only used when is_learning=true, to determine the effective UI language.
func get_lang_display_name(idx: int, is_learning: bool = false, ui_lang_idx: int = 0) -> String:
	var lang_name = TranslationServer.translate(LANG_KEYS[idx])
	if idx == 0:
		if is_learning:
			# "Auto" for learning means the current UI language
			var ui_effective_idx = ui_lang_idx
			if ui_effective_idx == 0:
				var detected = get_auto_detected_language()
				ui_effective_idx = LANG_CODES.find(detected)
			var ui_name = TranslationServer.translate(LANG_KEYS[ui_effective_idx])
			return TranslationServer.translate("lang_auto") + " (" + ui_name + ")"
		else:
			# "Auto" for UI means "Detected System Lang"
			var detected := get_auto_detected_language()
			var det_idx := LANG_CODES.find(detected)
			if det_idx > 0:
				lang_name += " (" + TranslationServer.translate(LANG_KEYS[det_idx]) + ")"
	return lang_name

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


## Return the N-th character of the alphabet for the given language.
## For 'el' (Greek), it returns Α, Β, Γ...
## For others, it returns A, B, C...
func get_alphabet_char(index: int, lang: String) -> String:
	if lang == "el":
		var greek_alphabet = "ΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩ"
		if index >= 0 and index < greek_alphabet.length():
			return greek_alphabet[index]
		return greek_alphabet[greek_alphabet.length() - 1]
	if lang == "he":
		var hebrew_alphabet = "אבגדהוזחטיכלמנסעפצקרשת"
		if index >= 0 and index < hebrew_alphabet.length():
			return hebrew_alphabet[index]
		return hebrew_alphabet[hebrew_alphabet.length() - 1]
	if lang == "uk":
		var ukrainian_alphabet = "АБВГҐДЕЄЖЗИІЇЙКЛМНОПРСТУФХЦЧШЩЬЮЯ"
		if index >= 0 and index < ukrainian_alphabet.length():
			return ukrainian_alphabet[index]
		return ukrainian_alphabet[ukrainian_alphabet.length() - 1]
	
	# Default to Latin A-Z
	return String.chr(65 + (index % 26))
