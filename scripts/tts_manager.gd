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
var _pending_segments: Array[Dictionary] = []
var _pending_version: int = 0

## Track latest request ID to allow interrupting the worker thread (main thread only).
var _current_version: int = 0


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
	
	for lang_code in Config.LANG_CODES:
		var target_lang := lang_code
		if target_lang == "auto":
			target_lang = Config.get_effective_ui_language()
			
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
		warm_up(Config.get_effective_ui_language(), TranslationServer.translate("app_title"))
	else:
		warm_up(Config.get_effective_ui_language())  # Silent whisper for subsequent refreshes


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
	var lang: String = lang_override if not lang_override.is_empty() else Config.get_effective_learning_language()
	var segment := _make_segment(text, lang, rate, volume)
	if segment.is_empty():
		return

	_current_version += 1
	
	# Stop OS speech immediately on the main thread for snappy UI response
	DisplayServer.tts_stop()

	_mutex.lock()
	_pending_segments = [segment]
	_pending_version = _current_version
	_mutex.unlock()

	_semaphore.post()


## Queue multiple speech segments in order. Each segment can specify:
## {"text": String, "lang": String, "rate": float, "volume": float, "pause_ms": int}
func speak_segments(segments: Array[Dictionary]) -> void:
	var prepared_segments: Array[Dictionary] = []
	for segment in segments:
		var text := String(segment.get("text", ""))
		var lang := String(segment.get("lang", ""))
		if lang.is_empty():
			lang = Config.get_effective_learning_language()
		var prepared := _make_segment(
			text,
			lang,
			float(segment.get("rate", 1.0)),
			float(segment.get("volume", 70.0)),
			int(segment.get("pause_ms", 400))
		)
		if not prepared.is_empty():
			prepared_segments.append(prepared)
	if prepared_segments.is_empty():
		return

	_current_version += 1
	DisplayServer.tts_stop()

	_mutex.lock()
	_pending_segments = prepared_segments
	_pending_version = _current_version
	_mutex.unlock()

	_semaphore.post()


## Stops any ongoing or pending speech immediately.
func stop() -> void:
	_current_version += 1
	DisplayServer.tts_stop()
	
	_mutex.lock()
	_pending_segments.clear()
	_pending_version = _current_version
	_mutex.unlock()
	
	_semaphore.post() # Wake worker to see the empty text and newer version


## Primes the TTS engine to reduce initial latency (especially on Android TV).
## Speaks provided text at reduced volume to wake up the OS voice service.
func warm_up(lang: String, text: String = "") -> void:
	if text.strip_edges().is_empty():
		return
	speak(text, 1.0, lang, 40.0)


# ── Speech Segment Helpers ───────────────────────────────────────────────────

func _make_segment(
	text: String,
	lang: String,
	rate: float = 1.0,
	volume: float = 70.0,
	pause_ms: int = 400
) -> Dictionary:
	var processed_text := text.strip_edges().to_lower()
	if processed_text.is_empty():
		return {}

	# For single letters in specific languages, adding a period often helps the engine
	# just speak the letter name instead of identifying the case.
	if processed_text.length() == 1 and lang in ["el", "cs"]:
		processed_text += "."

	return {
		"text": processed_text,
		"lang": lang,
		"rate": rate,
		"volume": volume,
		"pause_ms": pause_ms,
	}


func _is_interrupted(local_version: int) -> bool:
	_mutex.lock()
	var interrupted := _pending_version > local_version
	_mutex.unlock()
	return interrupted


# ── Worker Thread ────────────────────────────────────────────────────────────

## Runs in a background thread. Waits for semaphore posts, then speaks.
func _worker_loop() -> void:
	while true:
		_semaphore.wait()

		var segments: Array[Dictionary] = []

		_mutex.lock()
		if _exit_flag:
			_mutex.unlock()
			break

		segments = _pending_segments.duplicate(true)
		var local_version: int = _pending_version
		_pending_segments.clear()
		_mutex.unlock()

		for segment in segments:
			if _exit_flag or _is_interrupted(local_version):
				break

			var text := String(segment.get("text", ""))
			var lang := String(segment.get("lang", ""))
			var rate := float(segment.get("rate", 1.0))
			var volume := float(segment.get("volume", 70.0))
			var pause_ms := int(segment.get("pause_ms", 400))
			if text.is_empty():
				continue

			# Wait for voice scan to complete before resolving voice ID.
			while not tts_ready:
				OS.delay_msec(50)
				if _exit_flag or _is_interrupted(local_version):
					break
			if _exit_flag or _is_interrupted(local_version):
				break

			var final_voice_id := get_voice(lang)

			DisplayServer.tts_stop()
			
			# Force natural pauses by splitting text into separate utterances
			# which tells the OS TTS engine to take a breath between them.
			var formatted_text = text.replace(".", ".|").replace("!", "!|").replace("?", "?|").replace("\n", " |")
			var parts = formatted_text.split("|")
			
			for part in parts:
				var clean_part = part.strip_edges()
				if clean_part.is_empty():
					continue

				# INTERRUPT CHECK: Before starting speech
				var interrupted = _is_interrupted(local_version)
				
				if interrupted or _exit_flag:
					break
					
				# Send ONLY one sentence to the OS to avoid its internal queueing problems
				DisplayServer.tts_speak(clean_part, final_voice_id, int(volume), 1.0, rate, 0, false)
				
				# Wait a moment for the OS engine to physically start processing
				OS.delay_msec(100)
				
				# Polling loop: block this background thread until this specific sentence is finished
				while DisplayServer.tts_is_speaking() and not _exit_flag:
					interrupted = _is_interrupted(local_version)
					
					if interrupted:
						break
					OS.delay_msec(50)
					
				# If we were interrupted while speaking, abort entire block
				if interrupted or _exit_flag:
					break
					
				# Force a clean, deliberate pause between sentences naturally
				var remaining_pause_ms := pause_ms
				while remaining_pause_ms > 0 and not _exit_flag:
					interrupted = _is_interrupted(local_version)
					
					if interrupted:
						break
						
					OS.delay_msec(50)
					remaining_pause_ms -= 50
					
				if interrupted or _exit_flag:
					break
