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

const MissionCatalog := preload("res://scripts/mission_catalog.gd")
const ReleaseVersionInfoScript := preload("res://scripts/release_version_info.gd")

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

## On-Screen Controls size.
enum ControllerSize {
	NORMAL = 0,
	LARGE = 1,
}

# Domain constants — aliases to MissionCatalog (single source of truth).
const STYLE_PATH = MissionCatalog.STYLE_PATH
const STYLE_NEXT_SYMBOL = MissionCatalog.STYLE_NEXT_SYMBOL
const STYLE_RACE = MissionCatalog.STYLE_RACE

const TRAINING_NONE = MissionCatalog.TRAINING_NONE
const TRAINING_NUMBERS = MissionCatalog.TRAINING_NUMBERS
const TRAINING_LETTERS = MissionCatalog.TRAINING_LETTERS
const TRAINING_WORDS = MissionCatalog.TRAINING_WORDS

const MISSION_FIND_EXIT = MissionCatalog.MISSION_FIND_EXIT
const MISSION_FOLLOW_TRAIL = MissionCatalog.MISSION_FOLLOW_TRAIL
const MISSION_FIND_NEXT = MissionCatalog.MISSION_FIND_NEXT
const MISSION_RACE_MIDDLE = MissionCatalog.MISSION_RACE_MIDDLE

const ROLE_COLLECTOR = MissionCatalog.ROLE_COLLECTOR
const ROLE_CHASER = MissionCatalog.ROLE_CHASER
const ROLE_RACER = MissionCatalog.ROLE_RACER

const TRAP_CONFUSION_MOVES := 5
const TRAP_INPUT_LOCKOUT_SEC := 0.5

const LAST_SESSION_SINGLE_PLAYER := "single_player"
const LAST_SESSION_MULTIPLAYER_HOST := "multiplayer_host"


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

## Translation keys for on-screen controls sizes. Indices match ControllerSize enum values.
const CONTROLLER_SIZE_KEYS: Array[String] = ["controller_size_normal", "controller_size_large"]


# ─────────────────────────────────────────────────────────────────────────────
#  PERSISTENCE & SETTINGS LOGIC
# ─────────────────────────────────────────────────────────────────────────────

const SAVE_PATH := "user://settings.cfg"
const PRIVACY_POLICY_URL := "https://sites.google.com/view/learning-maze-privacy-policy/"
const ANDROID_PACKAGE_ID := "com.hauzirek.learningmaze"
const PLAY_STORE_URL := "https://play.google.com/store/apps/details?id=com.hauzirek.learningmaze"

## Current game mode. See GameMode enum.
var game_mode: GameMode = GameMode.WORDS

## Product-level game style. Phase 2/3 only implements STYLE_PATH.
var game_style: String = STYLE_PATH

## Product-level mission selected by the setup UI.
var mission_id: String = MISSION_FOLLOW_TRAIL

## Transient setup handoff from the mission-first home screen.
var selected_mission_id: String = MISSION_FOLLOW_TRAIL
var selected_theme_dir: String = "thiefs"
var is_multiplayer_host: bool = false
var show_join_list_on_home: bool = false
var join_status_override: String = ""

func get_release_version_label() -> String:
	var packaged_label := _packaged_release_version_label()
	if not packaged_label.is_empty():
		return packaged_label

	var android_label := _android_release_version_label()
	if not android_label.is_empty():
		return android_label

	var export_label := _export_preset_release_version_label()
	if not export_label.is_empty():
		return export_label

	var project_version := _variant_to_clean_string(ProjectSettings.get_setting("application/config/version", ""))
	var project_build := _variant_to_clean_string(ProjectSettings.get_setting("application/config/build", ""))
	return _format_release_version(project_version, project_build)

func _packaged_release_version_label() -> String:
	return ReleaseVersionInfoScript.read_packaged_label()

func _android_release_version_label() -> String:
	if OS.get_name() != "Android":
		return ""

	var activity = _android_activity()
	if activity == null:
		return ""

	var package_manager = activity.call("getPackageManager")
	if package_manager == null:
		return ""

	var package_name := _variant_to_clean_string(activity.call("getPackageName"))
	if package_name.is_empty():
		return ""

	var package_info = package_manager.call("getPackageInfo", package_name, 0)
	if package_info == null:
		return ""

	var version_name := _java_member_string(package_info, "versionName")
	var version_code := _java_member_string(package_info, "versionCode")
	return _format_release_version(version_name, version_code)

func _android_activity() -> Variant:
	if Engine.has_singleton("AndroidRuntime"):
		var runtime = Engine.get_singleton("AndroidRuntime")
		if runtime != null:
			var activity = runtime.call("getActivity")
			if activity != null:
				return activity

	if Engine.has_singleton("GodotAndroid"):
		var bridge = Engine.get_singleton("GodotAndroid")
		if bridge != null:
			var activity = bridge.call("get_activity")
			if activity != null:
				return activity

	if Engine.has_singleton("GodotAndroidBridge"):
		var bridge = Engine.get_singleton("GodotAndroidBridge")
		if bridge != null:
			var activity = bridge.call("get_activity")
			if activity != null:
				return activity

	return null

func _java_member_string(java_object: Variant, member_name: String) -> String:
	if java_object == null:
		return ""
	var value = java_object.get(member_name)
	if value != null:
		return _variant_to_clean_string(value)
	var java_class = java_object.call("getClass")
	if java_class == null:
		return ""
	var field = java_class.call("getField", member_name)
	if field == null:
		return ""
	value = field.call("get", java_object)
	if value == null:
		return ""
	return _variant_to_clean_string(value)

func _export_preset_release_version_label() -> String:
	var export_config := ConfigFile.new()
	var err := export_config.load("res://export_presets.cfg")
	if err != OK:
		return ""

	var version_name := _variant_to_clean_string(export_config.get_value("preset.0.options", "version/name", ""))
	var version_code := _variant_to_clean_string(export_config.get_value("preset.0.options", "version/code", ""))
	return _format_release_version(version_name, version_code)

func _format_release_version(version_name: String, build_code: String) -> String:
	return ReleaseVersionInfoScript.format_label(version_name, build_code)

func _variant_to_clean_string(value: Variant) -> String:
	if value == null:
		return ""
	var text := str(value).strip_edges()
	if text.begins_with("<JavaObject:") and text.contains("\""):
		var first_quote := text.find("\"")
		var last_quote := text.rfind("\"")
		if first_quote >= 0 and last_quote > first_quote:
			return text.substr(first_quote + 1, last_quote - first_quote - 1).strip_edges()
	return text

## Product-level training content selection.
var training_type: String = TRAINING_WORDS

## Whether the current single-player session uses the chaser bot.
var chaser_enabled: bool = false

## Whether the current round gives each human player one drop-once trap.
var traps_enabled: bool = false

## Snapshot of the last actually started game, used by the home-screen Replay card.
var has_last_played_game: bool = false
var last_played_game: Dictionary = {}

## Current player's product role label.
var player_role: String = ROLE_COLLECTOR

## 0 = Very Easy … 6 = Unbelievable. Indices match DIFFICULTY_SIZES and DIFF_KEYS.
var difficulty: int = 1

## Current active theme directory name. "default" is the built-in fallback.
var theme_dir_name: String = "thiefs":
	set(value):
		if theme_dir_name != value:
			theme_dir_name = value
			_theme_cache = null
			ThemeLoader.clear_cache()

## Language code for the UI and system announcements. "auto" = detect from OS.
var ui_language: String = "auto"

## Language code for learning content (word lists, alphabets). "auto" = detect from OS.
var learning_language: String = "auto"

## How collected items and words are read aloud.
##   OFF               silent
##   DEVICE_TTS        the operating system voice — what every install had
##                     before pre-recorded audio existed
##   STUDIO_PREFERRED  the pre-recorded pack for the learning language, falling
##                     back to the device voice per item where a clip is absent
enum VoiceMode { OFF, DEVICE_TTS, STUDIO_PREFERRED }

var voice_mode: VoiceMode = VoiceMode.DEVICE_TTS

## Deprecated: read-only bridge for one release so nothing silently breaks
## while call sites migrate. `verify --strict` keeps it from coming back.
var voice_hints: bool:
	get:
		return voice_mode != VoiceMode.OFF

var _voice_hints_build_67_reset: bool = true

## Chaser speed tier. See ChaserLevel enum.
var chaser_level: ChaserLevel = ChaserLevel.MEDIUM

## Whether to prioritize smooth gameplay over visual effects (disables Glow, Anti-Aliasing).
var performance_mode: bool = true

## Screensaver timeout in seconds. 0 = off, 60 = 1 minute, 300 = 5 minutes, 600 = 10 minutes, 1200 = 20 minutes.
var screensaver_timeout: int = 300:
	set(value):
		if screensaver_timeout != value:
			screensaver_timeout = value
			var idle_mgr = get_node_or_null("/root/IdleManager")
			if idle_mgr != null and idle_mgr.has_method("apply_screensaver_settings"):
				idle_mgr.apply_screensaver_settings()

## Emitted when the on-screen controls mode changes (for D-Pad layout updates).
signal on_screen_controls_changed(new_mode: int)

## Emitted when the on-screen controls size changes (for D-Pad layout updates).
signal controller_size_changed(new_size: int)

## On-Screen Controls preference (-1 = not set/autodetect).
var on_screen_controls: int = -1:
	set(value):
		if on_screen_controls != value:
			on_screen_controls = value
			on_screen_controls_changed.emit(value)

## On-Screen Controls size preference.
var controller_size: int = ControllerSize.NORMAL:
	set(value):
		var clamped := clampi(value, ControllerSize.NORMAL, ControllerSize.LARGE)
		if controller_size != clamped:
			controller_size = clamped
			controller_size_changed.emit(clamped)

## Moves per second for the Chaser. Read-only, based on chaser_level.
var chaser_speed: float:
	get:
		match chaser_level:
			ChaserLevel.MEDIUM: return 1.0
			ChaserLevel.FAST:   return 1.5
			ChaserLevel.TURBO:  return 3.5
			_:                  return 0.65  # Slow (default)

## All language codes including "auto" sentinel. Canonical source for UI cycling.
const LANG_CODES: Array[String] = ["auto", "en", "es", "fr", "de", "it", "pt", "pl", "uk", "nl", "tr", "ro", "cs", "hu", "el", "sv", "da", "fi", "nb", "sk", "he", "vi"]

## Translation keys matching LANG_CODES 1:1. Used by settings and mode-selection UI.
const LANG_KEYS: Array[String] = ["lang_auto", "lang_english", "lang_spanish", "lang_french", "lang_german", "lang_italian", "lang_portuguese", "lang_polish", "lang_ukrainian", "lang_dutch", "lang_turkish", "lang_romanian", "lang_czech", "lang_hungarian", "lang_greek", "lang_swedish", "lang_danish", "lang_finnish", "lang_norwegian", "lang_slovak", "lang_hebrew", "lang_vietnamese"]

## Language codes without "auto" — used for validation and TTS scanning.
const SUPPORTED_LANGS: Array[String] = ["en", "es", "fr", "de", "it", "pt", "pl", "uk", "nl", "tr", "ro", "cs", "hu", "el", "sv", "da", "fi", "nb", "sk", "he", "vi"]

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
	config.set_value("Game", "game_style", game_style)
	config.set_value("Game", "mission_id", mission_id)
	config.set_value("Game", "training_type", training_type)
	config.set_value("Game", "chaser_enabled", chaser_enabled)
	config.set_value("Game", "traps_enabled", traps_enabled)
	config.set_value("Game", "player_role", player_role)
	config.set_value("Game", "difficulty", difficulty)
	config.set_value("Game", "ui_language", ui_language)
	config.set_value("Game", "learning_language", learning_language)
	config.set_value("Game", "voice_mode", int(voice_mode))
	config.set_value("Game", "chaser_level", chaser_level)
	config.set_value("Game", "performance_mode", performance_mode)
	config.set_value("Game", "screensaver_timeout", screensaver_timeout)
	config.set_value("Game", "on_screen_controls", on_screen_controls)
	config.set_value("Game", "controller_size", controller_size)
	config.set_value("Migrations", "voice_hints_build_67_reset", _voice_hints_build_67_reset)
	config.set_value("Theme", "dir_name", theme_dir_name)
	config.set_value("LastGame", "has_last_played_game", has_last_played_game)
	config.set_value("LastGame", "session", last_played_game)
	
	var err := config.save(SAVE_PATH)
	if err != OK:
		push_error("Failed to save settings to %s (Error: %s)" % [SAVE_PATH, err])

## Guards against a settings file written by a newer build, or a hand-edited one.
func _clamp_voice_mode(value: int) -> VoiceMode:
	if value < 0 or value > int(VoiceMode.STUDIO_PREFERRED):
		return VoiceMode.DEVICE_TTS
	return value


func load_settings() -> void:
	var config := ConfigFile.new()
	var should_save_after_load := false
	if config.load(SAVE_PATH) == OK:
		_voice_hints_build_67_reset = bool(config.get_value("Migrations", "voice_hints_build_67_reset", false))
		game_mode      = config.get_value("Game", "game_mode", game_mode)
		game_style     = config.get_value("Game", "game_style", game_style)
		mission_id     = config.get_value("Game", "mission_id", mission_id)
		training_type  = config.get_value("Game", "training_type", training_type)
		chaser_enabled = config.get_value("Game", "chaser_enabled", chaser_enabled)
		traps_enabled  = config.get_value("Game", "traps_enabled", traps_enabled)
		player_role    = config.get_value("Game", "player_role", player_role)
		difficulty     = config.get_value("Game", "difficulty", difficulty)
		ui_language       = config.get_value("Game", "ui_language", "auto")
		learning_language = config.get_value("Game", "learning_language", "auto")
		
		# Migration: if we have an old 'language' setting, migrate it to learning_language
		if config.has_section_key("Game", "language"):
			learning_language = config.get_value("Game", "language", learning_language)
		# Voice setting migration. An existing install must not change behaviour
		# on update: whoever had speech on keeps the device voice they already
		# had, and Studio voice is something they opt into. Only a fresh install
		# has no opinion, and it gets the same device voice.
		if config.has_section_key("Game", "voice_mode"):
			voice_mode = _clamp_voice_mode(int(config.get_value("Game", "voice_mode", int(voice_mode))))
		elif config.has_section_key("Game", "voice_hints"):
			voice_mode = VoiceMode.DEVICE_TTS if bool(config.get_value("Game", "voice_hints", true)) \
				else VoiceMode.OFF
			should_save_after_load = true
		if not _voice_hints_build_67_reset:
			voice_mode = VoiceMode.DEVICE_TTS
			_voice_hints_build_67_reset = true
			should_save_after_load = true
		chaser_level   = config.get_value("Game", "chaser_level", ChaserLevel.SLOW)
		performance_mode = config.get_value("Game", "performance_mode", true)
		screensaver_timeout = config.get_value("Game", "screensaver_timeout", 300)
		on_screen_controls = config.get_value("Game", "on_screen_controls", -1)
		controller_size = int(config.get_value("Game", "controller_size", ControllerSize.NORMAL))
		theme_dir_name = config.get_value("Theme", "dir_name", theme_dir_name)
		has_last_played_game = bool(config.get_value("LastGame", "has_last_played_game", false))
		var loaded_last: Variant = config.get_value("LastGame", "session", {})
		last_played_game = loaded_last.duplicate(true) if loaded_last is Dictionary else {}
		has_last_played_game = has_last_played_game and has_replayable_last_game()

	_apply_session_compatibility()
		
	if on_screen_controls == -1:
		if UIHelpers.is_likely_tv():
			on_screen_controls = ControlsMode.OFF
		elif DisplayServer.is_touchscreen_available() or OS.has_feature("mobile"):
			on_screen_controls = ControlsMode.RIGHT_HANDED
		else:
			on_screen_controls = ControlsMode.OFF

	if should_save_after_load:
		save_settings()

func configure_single_player_session(
	style: String,
	training: String,
	use_chaser: bool,
	chaser_speed_level: int,
	mission: String = "",
	use_traps: bool = false,
) -> void:
	game_style = style if [STYLE_PATH, STYLE_NEXT_SYMBOL, STYLE_RACE].has(style) else STYLE_PATH
	training_type = training if [TRAINING_NONE, TRAINING_NUMBERS, TRAINING_LETTERS, TRAINING_WORDS].has(training) else TRAINING_WORDS
	mission_id = mission if [MISSION_FIND_EXIT, MISSION_FOLLOW_TRAIL, MISSION_FIND_NEXT, MISSION_RACE_MIDDLE].has(mission) else MissionCatalog.mission_from_config(game_style, training_type)
	player_role = ROLE_RACER if game_style == STYLE_RACE else ROLE_COLLECTOR
	game_mode = game_mode_for_training(training_type) as GameMode
	chaser_enabled = use_chaser and game_style != STYLE_RACE
	chaser_level = clampi(chaser_speed_level, ChaserLevel.SLOW, ChaserLevel.TURBO) as ChaserLevel if chaser_enabled else ChaserLevel.OFF
	traps_enabled = use_traps

func remember_last_single_player_session() -> void:
	last_played_game = {
		"kind": LAST_SESSION_SINGLE_PLAYER,
		"game_style": game_style,
		"training_type": training_type,
		"mission_id": mission_id,
		"chaser_enabled": chaser_enabled,
		"chaser_level": int(chaser_level),
		"traps_enabled": traps_enabled,
		"difficulty": difficulty,
		"theme_dir_name": theme_dir_name,
		"learning_language": learning_language,
	}
	has_last_played_game = true

func remember_last_multiplayer_host_session(host_config: Dictionary) -> void:
	if host_config.is_empty():
		return
	var replay_config := host_config.duplicate(true)
	last_played_game = {
		"kind": LAST_SESSION_MULTIPLAYER_HOST,
		"host_config": replay_config,
		"difficulty": int(replay_config.get("difficulty", difficulty)),
		"theme_dir_name": String(replay_config.get("theme_dir", theme_dir_name)),
		"learning_language": learning_language,
	}
	has_last_played_game = true

func has_replayable_last_game() -> bool:
	if last_played_game.is_empty():
		return false
	var kind := String(last_played_game.get("kind", ""))
	if kind == LAST_SESSION_SINGLE_PLAYER:
		return _is_valid_single_player_replay(last_played_game)
	if kind == LAST_SESSION_MULTIPLAYER_HOST:
		var host_cfg: Variant = last_played_game.get("host_config", {})
		return host_cfg is Dictionary and not (host_cfg as Dictionary).is_empty()
	return false

func apply_last_single_player_session() -> bool:
	if not has_replayable_last_game():
		return false
	if String(last_played_game.get("kind", "")) != LAST_SESSION_SINGLE_PLAYER:
		return false
	learning_language = String(last_played_game.get("learning_language", learning_language))
	difficulty = clampi(int(last_played_game.get("difficulty", difficulty)), 0, DIFFICULTY_SIZES.size() - 1)
	theme_dir_name = String(last_played_game.get("theme_dir_name", theme_dir_name))
	configure_single_player_session(
		String(last_played_game.get("game_style", STYLE_PATH)),
		String(last_played_game.get("training_type", TRAINING_WORDS)),
		bool(last_played_game.get("chaser_enabled", false)),
		int(last_played_game.get("chaser_level", ChaserLevel.SLOW)),
		String(last_played_game.get("mission_id", MISSION_FOLLOW_TRAIL)),
		bool(last_played_game.get("traps_enabled", false)),
	)
	return true

func get_last_multiplayer_host_config() -> Dictionary:
	if not has_replayable_last_game():
		return {}
	if String(last_played_game.get("kind", "")) != LAST_SESSION_MULTIPLAYER_HOST:
		return {}
	var host_cfg: Variant = last_played_game.get("host_config", {})
	return host_cfg.duplicate(true) if host_cfg is Dictionary else {}

func _is_valid_single_player_replay(session: Dictionary) -> bool:
	return (
		[STYLE_PATH, STYLE_NEXT_SYMBOL, STYLE_RACE].has(String(session.get("game_style", "")))
		and [TRAINING_NONE, TRAINING_NUMBERS, TRAINING_LETTERS, TRAINING_WORDS].has(String(session.get("training_type", "")))
		and [MISSION_FIND_EXIT, MISSION_FOLLOW_TRAIL, MISSION_FIND_NEXT, MISSION_RACE_MIDDLE].has(String(session.get("mission_id", "")))
	)

func prepare_setup_session(mission: String, setup_theme_dir: String, multiplayer_host: bool) -> void:
	selected_mission_id = mission if [MISSION_FIND_EXIT, MISSION_FOLLOW_TRAIL, MISSION_FIND_NEXT, MISSION_RACE_MIDDLE].has(mission) else MissionCatalog.DEFAULT_MISSION
	selected_theme_dir = setup_theme_dir if not setup_theme_dir.is_empty() else theme_dir_name
	is_multiplayer_host = multiplayer_host

func game_mode_for_training(training: String) -> int:
	match training:
		TRAINING_NONE:
			return GameMode.NORMAL
		TRAINING_NUMBERS:
			return GameMode.NUMBERS
		TRAINING_LETTERS:
			return GameMode.LETTERS
		TRAINING_WORDS:
			return GameMode.WORDS
		_:
			return GameMode.WORDS

func training_for_game_mode(mode: int) -> String:
	match mode:
		GameMode.NORMAL:
			return TRAINING_NONE
		GameMode.NUMBERS:
			return TRAINING_NUMBERS
		GameMode.LETTERS:
			return TRAINING_LETTERS
		GameMode.WORDS:
			return TRAINING_WORDS
		_:
			return TRAINING_WORDS

func traps_allowed_for_session(style: String, use_chaser: bool, mission: String = "") -> bool:
	var mission_to_check := mission
	if not [MISSION_FIND_EXIT, MISSION_FOLLOW_TRAIL, MISSION_FIND_NEXT, MISSION_RACE_MIDDLE].has(mission_to_check):
		mission_to_check = MissionCatalog.mission_from_config(style, training_type)
	var style_to_check := MissionCatalog.style_for_mission(mission_to_check)
	if style_to_check == STYLE_RACE:
		return mission_to_check == MISSION_RACE_MIDDLE
	return use_chaser and MissionCatalog.chaser_allowed(mission_to_check) and not MissionCatalog.chaser_forced_off(mission_to_check)

func _apply_session_compatibility() -> void:
	if not [STYLE_PATH, STYLE_NEXT_SYMBOL, STYLE_RACE].has(game_style):
		game_style = STYLE_PATH
	if not [TRAINING_NONE, TRAINING_NUMBERS, TRAINING_LETTERS, TRAINING_WORDS].has(training_type):
		training_type = training_for_game_mode(game_mode)
	if not [MISSION_FIND_EXIT, MISSION_FOLLOW_TRAIL, MISSION_FIND_NEXT, MISSION_RACE_MIDDLE].has(mission_id):
		mission_id = MissionCatalog.mission_from_config(game_style, training_type)
	game_mode = game_mode_for_training(training_type) as GameMode
	if not [ROLE_COLLECTOR, ROLE_CHASER, ROLE_RACER].has(player_role):
		player_role = ROLE_COLLECTOR
	if game_style == STYLE_RACE:
		chaser_enabled = false
		player_role = ROLE_RACER
	if not chaser_enabled:
		chaser_level = ChaserLevel.OFF
	elif chaser_level == ChaserLevel.OFF:
		chaser_level = ChaserLevel.SLOW

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


## Teaching alphabets, in the "[]"-marked grapheme syntax (see grapheme_text.gd).
## A bracketed run is ONE letter: Czech CH is one letter, not a C then an H.
##
## This is what LETTERS mode spawns, which is not the same thing as every
## letter the language writes. Czech omits its long vowels here — asking a
## four-year-old meeting the alphabet to tell Á from A as two collectibles
## teaches the wrong lesson — but Á, Í and the rest still appear constantly
## inside words, so Words mode spawns them and they stay recorded.
## data/speech/letters_cs.json holds both sets and marks which is which.
##
## Languages absent from this table fall back to plain Latin A–Z, which is the
## behaviour every language had before this table existed.
const ALPHABETS: Dictionary = {
	"cs": "ABCČDĎEFGH[CH]IJKLMNŇOPQRŘSŠTŤUVWXYZŽ",
	"de": "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
	"es": "ABCDEFGHIJKLMNÑOPQRSTUVWXYZ",
	"pl": "ABCĆDEFGHIJKLŁMNŃOPRSŚTUWYZŹŻ",
	"sk": "ABCČD[DZ][DŽ]ĎEFGH[CH]IJKLĽMNŇOPQRSŠTŤUVWXYZŽ",
	"el": "ΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩ",
	"he": "אבגדהוזחטיכלמנסעפצקרשת",
	"uk": "АБВГҐДЕЄЖЗИІЇЙКЛМНОПРСТУФХЦЧШЩЬЮЯ",
}

## Letters that occur inside words but are not part of the alphabet lesson.
## Spawned in WORDS mode, never in LETTERS mode, and recorded either way —
## Czech Á turns up in 56 of the 277 Czech words.
##
## These two tables are the whole definition of a language's letters. The
## speech pipeline reads them from here rather than keeping its own copy, so
## there is one list to edit and nothing to keep in step.
const WORD_ONLY_LETTERS: Dictionary = {
	"cs": "ÁÉĚÍÓÚŮÝ",
	"de": "ÄÖÜß",
	"es": "ÁÉÍÓÚÜ",
	"pl": "ĄĘÓ",
	"sk": "ÁÄÉÍĹŔÓÔÚÝ",
}

const LATIN_BASIC := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

## Cache of split alphabets, keyed by language code.
var _alphabet_cache: Dictionary = {}


## Return the ordered letters of a language's teaching alphabet.
func get_alphabet(lang: String) -> PackedStringArray:
	if _alphabet_cache.has(lang):
		var cached: PackedStringArray = _alphabet_cache[lang]
		return cached
	var marked: String = ALPHABETS.get(lang, LATIN_BASIC)
	var letters := GraphemeText.split(marked)
	_alphabet_cache[lang] = letters
	return letters


## How many letters the language's alphabet has. Callers must use this to size
## Letters mode instead of assuming 26 — Greek has 24, Hebrew 22, Czech 42 and
## Ukrainian 33.
func get_alphabet_length(lang: String) -> int:
	return get_alphabet(lang).size()


## Return the N-th letter of the alphabet for the given language.
## Returns "" past the end. It deliberately does NOT wrap or repeat the final
## letter: callers should ask for get_alphabet_length() items and no more.
func get_alphabet_char(index: int, lang: String) -> String:
	var letters := get_alphabet(lang)
	if index < 0 or index >= letters.size():
		return ""
	return letters[index]


## Returns flag texture(s) and whether it is a split flag.
## Format: {"texture_a": Texture2D, "texture_b": Texture2D, "is_split": bool}
func get_flag_info(lang_code: String) -> Dictionary:
	var effective_code = lang_code
	if effective_code == "auto":
		effective_code = get_auto_detected_language()
	
	var info := {
		"texture_a": null,
		"texture_b": null,
		"is_split": false
	}
	
	match effective_code:
		"en":
			info.texture_a = load("res://assets/flags/gb.png")
			info.texture_b = load("res://assets/flags/us.png")
			info.is_split = true
		"pt":
			info.texture_a = load("res://assets/flags/pt.png")
			info.texture_b = load("res://assets/flags/br.png")
			info.is_split = true
		"es":
			info.texture_a = load("res://assets/flags/es.png")
			info.texture_b = load("res://assets/flags/mx.png")
			info.is_split = true
		"cs":
			info.texture_a = load("res://assets/flags/cz.png")
		"uk":
			info.texture_a = load("res://assets/flags/ua.png")
		"el":
			info.texture_a = load("res://assets/flags/gr.png")
		"sv":
			info.texture_a = load("res://assets/flags/se.png")
		"da":
			info.texture_a = load("res://assets/flags/dk.png")
		"nb":
			info.texture_a = load("res://assets/flags/no.png")
		"he":
			info.texture_a = load("res://assets/flags/il.png")
		"vi":
			info.texture_a = load("res://assets/flags/vn.png")
		_:
			# Default: map code directly if exists
			var path = "res://assets/flags/".path_join(effective_code + ".png")
			if ResourceLoader.exists(path):
				info.texture_a = load(path)
	
	return info
