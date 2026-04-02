## tts_manager.gd
## ---------------------------------------------------------------------------
## Background-threaded Text-to-Speech manager.
##
## Owns the full TTS lifecycle:
##   1. Voice scanning & caching (which languages have voices installed).
##   2. Background-threaded speech so the main loop never blocks.
##   3. Engine warm-up to reduce first-use latency on Android TV.
##
## Registered as Autoload singleton "TTS".
##
## Usage:
##   TTS.speak("hello")
##   TTS.speak("A", 0.85, "cs")
##   TTS.is_available("en")   # → true if an English voice is installed
## ---------------------------------------------------------------------------
extends Node


# ── Signals ──────────────────────────────────────────────────────────────────

## Emitted when the TTS voice scan completes or voice availability changes.
signal status_changed


# ── Voice Scanning State ─────────────────────────────────────────────────────

## Whether the TTS scan has completed at least once.
var tts_ready: bool = false

## Cache of language codes that have at least one TTS voice installed.
var _installed_tts_langs: Array[String] = []

## Map of language codes to their first available voice ID.
var _tts_voice_cache: Dictionary = {}

var _is_first_boot: bool = true


# ── Background Thread State ─────────────────────────────────────────────────

## Background thread and synchronisation primitives.
var _thread: Thread = null
var _mutex: Mutex = Mutex.new()
var _semaphore: Semaphore = Semaphore.new()
var _exit_flag: bool = false

## Pending TTS request (only the LATEST request is kept; older ones are dropped).
var _pending_text: String = ""
var _pending_voice: String = ""
var _pending_rate: float = 1.0
var _pending_volume: float = 70.0


# ── Lifecycle ────────────────────────────────────────────────────────────────

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_thread = Thread.new()
	_thread.start(_worker_loop)


func _ready() -> void:
	# Perform initial TTS voice scan (non-blocking)
	refresh_cache()


func _exit_tree() -> void:
	if _thread and _thread.is_alive():
		_mutex.lock()
		_exit_flag = true
		_mutex.unlock()
		_semaphore.post()
		_thread.wait_to_finish()


# ── Public API: Voice Scanning ───────────────────────────────────────────────

## Asynchronously scan for available TTS voices for all supported languages.
## Uses a non-blocking retry mechanism for Android/Google TV where the voice
## service can be slow to bind on cold start.
func refresh_cache() -> void:
	tts_ready = false
	status_changed.emit()
	
	var max_attempts := 10
	var all_voices: Array = []
	
	for attempt in range(max_attempts):
		all_voices = DisplayServer.tts_get_voices()
		if not all_voices.is_empty():
			break
		# Non-blocking wait — yields to the engine so UI stays responsive
		await get_tree().create_timer(0.2).timeout
	
	if all_voices.is_empty():
		push_warning("TTS: No voices found after %d attempts. Initialization aborted." % max_attempts)
		tts_ready = true  # Allow system to proceed but log warning
		status_changed.emit()
		return

	var new_langs: Array[String] = []
	var new_cache: Dictionary = {}
	
	for lang_code in Config.LANGUAGES:
		var target_lang := lang_code
		if target_lang == "auto":
			target_lang = Config.get_effective_language()
			
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
	status_changed.emit()
	
	# Announce app title ONLY on first boot to confirm readiness
	if _is_first_boot:
		_is_first_boot = false
		warm_up(Config.get_effective_language(), TranslationServer.translate("app_title"))
	else:
		warm_up(Config.get_effective_language())  # Silent whisper for subsequent refreshes


## Quick retrieval of cached voice ID for a given language code.
func get_voice(lang_code: String) -> String:
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
func is_available(lang_code: String) -> bool:
	return _installed_tts_langs.has(lang_code)


# ── Public API: Speech ───────────────────────────────────────────────────────

## Queue text to be spoken. Only the most recent request is kept.
func speak(text: String, rate: float = 1.0, lang_override: String = "", volume: float = 70.0) -> void:
	var lang: String = lang_override if not lang_override.is_empty() else Config.get_effective_language()

	_mutex.lock()
	_pending_text = text.to_lower()
	_pending_voice = lang  # Store requested lang; resolved in worker thread
	_pending_rate = rate
	_pending_volume = volume
	_mutex.unlock()

	_semaphore.post()


## Primes the TTS engine to reduce initial latency (especially on Android TV).
## Speaks provided text at reduced volume to wake up the OS voice service.
func warm_up(lang: String, text: String = "") -> void:
	if text.strip_edges().is_empty():
		return
	speak(text, 1.0, lang, 40.0)


# ── Worker Thread ────────────────────────────────────────────────────────────

## Runs in a background thread. Waits for semaphore posts, then speaks.
func _worker_loop() -> void:
	while true:
		_semaphore.wait()

		var text: String = ""
		var lang: String = ""
		var rate: float = 1.0
		var volume: float = 70.0

		_mutex.lock()
		if _exit_flag:
			_mutex.unlock()
			break

		text = _pending_text
		lang = _pending_voice
		rate = _pending_rate
		volume = _pending_volume
		_pending_text = ""
		_mutex.unlock()

		if not text.is_empty():
			# Wait for voice scan to complete before resolving voice ID
			while not tts_ready:
				OS.delay_msec(50)
				if _exit_flag: return
				
			var final_voice_id := get_voice(lang)

			DisplayServer.tts_stop()
			DisplayServer.tts_speak(text, final_voice_id, int(volume), 1.0, rate)
