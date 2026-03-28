## tts_manager.gd
## ---------------------------------------------------------------------------
## Background-threaded Text-to-Speech manager.
##
## Offloads TTS calls to a worker thread so the main game loop never blocks
## on OS voice synthesis (especially important on Android TV).
##
## Usage:
##   $TTS.speak("hello")
##   $TTS.speak("A", 0.85, "cs")
## ---------------------------------------------------------------------------
extends Node


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
	pass


func _exit_tree() -> void:
	if _thread and _thread.is_alive():
		_mutex.lock()
		_exit_flag = true
		_mutex.unlock()
		_semaphore.post()
		_thread.wait_to_finish()


# ── Public API ───────────────────────────────────────────────────────────────

## Queue text to be spoken. Only the most recent request is kept.
func speak(text: String, rate: float = 1.0, lang_override: String = "", volume: float = 70.0) -> void:
	# (Voice hints check removed to allow Settings menu previews)

	# We no longer resolve voice_id here. 
	# We store the requested language and resolve it in the worker thread
	# after we are sure the config/scan is ready.
	var lang: String = lang_override if not lang_override.is_empty() else Config.get_effective_language()

	_mutex.lock()
	_pending_text = text.to_lower()
	_pending_voice = lang # Overloading this field to store requested lang
	_pending_rate = rate
	_pending_volume = volume
	_mutex.unlock()

	_semaphore.post()


## Primes the TTS engine to reduce initial latency (especially on Android TV).
## Speaks a silent, high-speed character to wake up the OS voice service.
func warm_up(lang: String, text: String = "") -> void:
	# Use provided text (e.g. language name) at normal speed and 40% volume.
	# This serves as audible feedback and reliably primes the OS voice engine.
	var warm_text = text if not text.is_empty() else ". . . . ."
	speak(warm_text, 1.0, lang, 40.0)


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
		lang = _pending_voice # Recover requested lang
		rate = _pending_rate
		volume = _pending_volume
		_pending_text = ""
		_mutex.unlock()

		if not text.is_empty():
			# Wait for Config to be ready (scan complete)
			while not Config.tts_ready:
				OS.delay_msec(50)
				if _exit_flag: return
				
			var final_voice_id := Config.get_tts_voice(lang)
			
			# (Defensive check removed to allow OS system-default fallback for smoother feedback)

			DisplayServer.tts_stop()
			DisplayServer.tts_speak(text, final_voice_id, int(volume), 1.0, rate)
