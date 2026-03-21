## tts_manager.gd
## ---------------------------------------------------------------------------
## Background-threaded Text-to-Speech manager.
##
## Offloads TTS calls to a worker thread so the main game loop never blocks
## on OS voice synthesis (especially important on Android TV).
##
## Usage:
##   $TTSManager.speak("hello")
##   $TTSManager.speak("A", 0.85, "cs")
## ---------------------------------------------------------------------------
class_name TTSManager
extends Node


## Background thread and synchronisation primitives.
var _thread: Thread = null
var _mutex: Mutex = null
var _semaphore: Semaphore = null
var _exit_flag: bool = false

## Pending TTS request (only the LATEST request is kept; older ones are dropped).
var _pending_text: String = ""
var _pending_voice: String = ""
var _pending_rate: float = 1.0


# ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	_mutex = Mutex.new()
	_semaphore = Semaphore.new()
	_thread = Thread.new()
	_thread.start(_worker_loop)


func _exit_tree() -> void:
	if _thread and _thread.is_alive():
		_mutex.lock()
		_exit_flag = true
		_mutex.unlock()
		_semaphore.post()
		_thread.wait_to_finish()


# ── Public API ───────────────────────────────────────────────────────────────

## Queue text to be spoken. Only the most recent request is kept.
## `rate` controls speech speed (1.0 = normal).
## `lang_override` forces a specific language; empty = use game language.
func speak(text: String, rate: float = 1.0, lang_override: String = "") -> void:
	if not Config.voice_hints:
		return

	var lang: String = lang_override if not lang_override.is_empty() else Config.get_effective_language()
	var voice_id: String = Config.get_tts_voice(lang)

	_mutex.lock()
	_pending_text = text.to_lower()
	_pending_voice = voice_id
	_pending_rate = rate
	_mutex.unlock()

	_semaphore.post()


# ── Worker Thread ────────────────────────────────────────────────────────────

## Runs in a background thread. Waits for semaphore posts, then speaks.
func _worker_loop() -> void:
	while true:
		_semaphore.wait()

		var text: String = ""
		var voice: String = ""
		var rate: float = 1.0

		_mutex.lock()
		if _exit_flag:
			_mutex.unlock()
			break

		text = _pending_text
		voice = _pending_voice
		rate = _pending_rate
		_pending_text = ""
		_mutex.unlock()

		if not text.is_empty():
			DisplayServer.tts_stop()
			DisplayServer.tts_speak(text, voice, 50, 1.0, rate)
