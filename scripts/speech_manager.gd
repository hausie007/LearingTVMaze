## speech_manager.gd  —  autoload `Speech`
## ---------------------------------------------------------------------------
## The only speech API the game calls. Everything that used to reach for
## TTS.speak() now asks here instead, and this decides what actually happens.
##
## Three settings, and the resolution order for each:
##
##   OFF               nothing, immediately
##   DEVICE_TTS        the operating system voice, exactly as before
##   STUDIO_PREFERRED  the pre-recorded clip for this key and language
##                       -> device TTS with the same text and rate
##                         -> silence
##
## Fallback is per item, not per language. That matters most in the finish
## recap, which is one piece of narration built from two languages: an
## introduction in the UI language and the collected letters or numbers in the
## learning language. Either may have a pack, both may, or neither — and the
## sentence has to come out in order regardless. So a recap plays as a queue,
## each segment resolved on its own, switching between recordings and the
## device voice mid-sentence without the child hearing a seam.
##
## Two rules that matter more than they look:
##
##   The maze never waits for speech. Every call here returns immediately.
##   The newest request wins. A child collecting two letters quickly hears the
##   second, not a backlog — matching what tts_manager.gd already does.
##
## tts_manager.gd is unchanged and still does the hard parts of the fallback
## path: voice scanning, threading, interruption. It is a backend now.
## ---------------------------------------------------------------------------
extends Node

## Bus the voice player runs on, so hint volume can move independently of
## sound effects later, and music can duck against it.
const VOICE_BUS := "Voice"

## Where a language pack lives once packed by tools/speech.
const PACK_DIR := "res://voices"

## Clips are small — a few kilobytes — but a child can cross a maze quickly.
## Keep the recent ones decoded and let the rest go.
const CACHE_LIMIT := 24

## Rates handed to the TTS fallback, kept identical to the values the call
## sites used before this existed, so turning Studio off changes nothing.
const RATE_ITEM := 0.85
const RATE_WORD := 0.7

## How long to wait for the OS voice to actually start before giving up on it
## and moving to the next segment. The engine needs a moment: tts_manager
## allows itself half a second for the same handshake.
const TTS_START_GRACE_SEC := 1.2

## How long the engine must stay quiet before a segment counts as finished.
const TTS_SILENCE_DEBOUNCE_SEC := 0.35

## Upper bound on one segment, so a stuck engine cannot strand the recap.
const TTS_SEGMENT_TIMEOUT_SEC := 20.0

## Packs stay loaded per language, because a recap needs the UI language and
## the learning language at the same time and they are rarely the same one.
var _packs: Dictionary = {}

var _player: AudioStreamPlayer = null
var _cache: Dictionary = {}
var _cache_order: Array[String] = []

var _warned_missing: Dictionary = {}

# ── Recap queue state ────────────────────────────────────────────────────────
var _queue: Array[Dictionary] = []
var _queue_at: int = 0
var _queue_version: int = 0
var _waiting_for: String = ""      ## "", "clip", "tts"
var _wait_elapsed: float = 0.0
var _silence_elapsed: float = 0.0
var _tts_has_started: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)

	_player = AudioStreamPlayer.new()
	_player.name = "VoicePlayer"
	_player.bus = VOICE_BUS if AudioServer.get_bus_index(VOICE_BUS) != -1 else "Master"
	_player.max_polyphony = 1
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_player.finished.connect(_on_clip_finished)
	add_child(_player)


# ── Public API: single utterances ────────────────────────────────────────────

## Speak one collected letter, shown as `display` — "A", or "CH" for a
## multi-character letter. Call sites pass what the child sees and stay
## ignorant of clip keys.
func speak_grapheme(display: String, lang: String = "") -> void:
	var language := _language_or_default(lang)
	_speak(_char_key(language, display), language, display, RATE_ITEM)


## Speak a collected number.
func speak_number(value: int, lang: String = "") -> void:
	var language := _language_or_default(lang)
	_speak("learning.number.%03d" % value, language, str(value), RATE_ITEM)


## Speak whatever was just collected, given exactly the text on the tile.
## Deciding here rather than at the call sites means a value that is not a
## number cannot end up asking for learning.number.000 — the fallback text
## also stays the original string rather than a parsed and reprinted one.
func speak_item(display: String, lang: String = "") -> void:
	if display.is_valid_int():
		speak_number(display.to_int(), lang)
	else:
		speak_grapheme(display, lang)


## Speak a complete vocabulary word or phrase.
## A partial word — the prefix narration mid-phrase — has no recording and
## falls through to TTS, which is the intended behaviour, not an oversight.
func speak_word(text: String, lang: String = "") -> void:
	var language := _language_or_default(lang)
	_speak(_word_key(language, text), language, text, RATE_WORD)


## Speak a fixed piece of interface text — a language name in settings, the
## app title. Resolved by its text, like everything else, so a caller passes
## what it would have spoken and needs to know nothing about clip keys.
func speak_ui(text: String, lang: String = "", rate: float = 0.95) -> void:
	var language := lang if not lang.is_empty() else Config.get_effective_ui_language()
	_speak(_ui_key(language, text), language, text, rate)


## Speak by semantic key, for callers that already know one.
func speak_key(key: String, lang: String, fallback_text: String, rate: float = 1.0) -> void:
	_speak(key, _language_or_default(lang), fallback_text, rate)


## Stop anything playing or queued, from either backend.
func stop() -> void:
	_queue.clear()
	_queue_at = 0
	_queue_version += 1
	_waiting_for = ""
	set_process(false)
	if _player != null:
		_player.stop()
	TTS.stop()


## Prime the OS voice. Skipped when the pack covers this language, since the
## fallback would not be reached — but not skipped when coverage is partial.
func warm_up(lang: String, text: String = "") -> void:
	if Config.voice_mode == Config.VoiceMode.OFF:
		return
	if Config.voice_mode == Config.VoiceMode.STUDIO_PREFERRED and is_complete(lang):
		return
	TTS.warm_up(lang, text)


# ── Public API: ordered narration ────────────────────────────────────────────

## Speak segments in order, each resolved on its own.
##
## A segment is the shape tts_manager already understands —
## {text, lang, rate, volume, pause_ms} — plus an optional "key" for callers
## that know the recording they want. Without a key the text is matched
## against the pack for that segment's language, so a recap of collected
## letters plays the recorded letters and speaks its introduction with the
## device voice, in one sentence, without either side knowing about the other.
##
## Adding recordings for the introductions later is then a data change: give
## the segment a key like "ui.recap.counted_to" and it resolves. Nothing here
## needs to know.
func speak_segments(segments: Array) -> void:
	if Config.voice_mode == Config.VoiceMode.OFF or segments.is_empty():
		return

	stop()
	_queue_version += 1
	var version := _queue_version

	for segment in segments:
		if not (segment is Dictionary):
			continue
		var text := String(segment.get("text", "")).strip_edges()
		if text.is_empty():
			continue
		var lang := _language_or_default(String(segment.get("lang", "")))
		var step := {
			"text": text,
			"lang": lang,
			"rate": float(segment.get("rate", 1.0)),
			"volume": float(segment.get("volume", 70.0)),
			"pause_ms": int(segment.get("pause_ms", 400)),
			"stream": null,
		}
		if Config.voice_mode == Config.VoiceMode.STUDIO_PREFERRED:
			var key := String(segment.get("key", ""))
			if key.is_empty():
				key = _resolve_key(lang, text)
			if not key.is_empty():
				step["stream"] = _stream_for(lang, key)
		# Nothing recorded and no voice installed for this language: skip it
		# rather than stand in silence waiting for speech that cannot happen.
		if step["stream"] == null and TTS.tts_ready and not TTS.is_available(lang):
			continue
		_queue.append(step)

	if _queue.is_empty():
		return
	_queue_at = 0
	_advance(version)


# ── Public API: availability ─────────────────────────────────────────────────

## True when a recording exists for this key in this language.
func has_clip(key: String, lang: String = "") -> bool:
	var pack := _pack(_language_or_default(lang))
	return pack.get("items", {}).has(key)


## Per-category coverage for a language: "complete", "partial" or "none".
func coverage(lang: String = "") -> Dictionary:
	var cover: Dictionary = _pack(_language_or_default(lang)).get("coverage", {})
	return cover.duplicate()


## True when every category this language declares is fully recorded.
func is_complete(lang: String = "") -> bool:
	var cover := coverage(lang)
	if cover.is_empty():
		return false
	for state in cover.values():
		if String(state) != "complete":
			return false
	return true


## Coverage of the spoken interface text, separate from the learning content:
## a pack can have every letter and no menu speech, or the reverse.
func has_ui(lang: String = "") -> bool:
	return String(coverage(lang).get("ui", "none")) == "complete"


## True when a language has enough of a pack to be worth offering at all.
## Numbers and letters are what every mode uses; words are a bonus.
func has_pack(lang: String = "") -> bool:
	var cover := coverage(lang)
	return String(cover.get("number", "none")) == "complete" \
		and String(cover.get("char", "none")) == "complete"


## Decode a clip before it is wanted. The next pickup is always known in
## advance, which is the whole of the latency story.
func prefetch_grapheme(display: String, lang: String = "") -> void:
	if display.is_empty() or Config.voice_mode != Config.VoiceMode.STUDIO_PREFERRED:
		return
	var language := _language_or_default(lang)
	_stream_for(language, _char_key(language, display))


func prefetch_number(value: int, lang: String = "") -> void:
	if Config.voice_mode != Config.VoiceMode.STUDIO_PREFERRED:
		return
	_stream_for(_language_or_default(lang), "learning.number.%03d" % value)


# ── Resolution ───────────────────────────────────────────────────────────────

func _speak(key: String, lang: String, fallback_text: String, rate: float) -> void:
	match Config.voice_mode:
		Config.VoiceMode.OFF:
			return
		Config.VoiceMode.DEVICE_TTS:
			_speak_with_tts(fallback_text, rate, lang)
		Config.VoiceMode.STUDIO_PREFERRED:
			if not key.is_empty() and _play(lang, key):
				return
			_note_missing(key, lang)
			_speak_with_tts(fallback_text, rate, lang)


func _speak_with_tts(text: String, rate: float, lang: String) -> void:
	if text.strip_edges().is_empty():
		return
	stop()
	TTS.speak(text, rate, lang)


func _play(lang: String, key: String) -> bool:
	var stream := _stream_for(lang, key)
	if stream == null:
		return false
	stop()
	_player.stream = stream
	_player.play()
	return true


## What a piece of text is, as far as the pack is concerned.
func _resolve_key(lang: String, text: String) -> String:
	if text.is_valid_int():
		return "learning.number.%03d" % text.to_int()
	var as_char := _char_key(lang, text)
	if not as_char.is_empty():
		return as_char
	var as_word := _word_key(lang, text)
	if not as_word.is_empty():
		return as_word
	return _ui_key(lang, text)


func _char_key(lang: String, display: String) -> String:
	return String(_pack(lang).get("_chars", {}).get(display.to_upper(), ""))


func _word_key(lang: String, text: String) -> String:
	return String(_pack(lang).get("_words", {}).get(text.strip_edges().to_upper(), ""))


func _ui_key(lang: String, text: String) -> String:
	return String(_pack(lang).get("_ui", {}).get(_ui_lookup(text), ""))


## Interface text is matched loosely — trailing commas and full stops come and
## go between a translation template and the fragment the recap actually
## speaks, and they should not decide whether a recording is found.
func _ui_lookup(text: String) -> String:
	return text.strip_edges().to_upper().trim_suffix(".").trim_suffix(",").strip_edges()


# ── The recap queue ──────────────────────────────────────────────────────────

func _advance(version: int) -> void:
	if version != _queue_version:
		return
	if _queue_at >= _queue.size():
		_queue.clear()
		_waiting_for = ""
		set_process(false)
		return

	var step: Dictionary = _queue[_queue_at]
	_queue_at += 1

	if step["stream"] != null:
		_waiting_for = "clip"
		_player.stream = step["stream"]
		_player.play()
		return

	# One segment at a time rather than handing tts_manager the whole run:
	# the queue may switch back to a recording after it, and the two backends
	# have no way to wait for each other.
	_waiting_for = "tts"
	_tts_has_started = false
	_wait_elapsed = 0.0
	_silence_elapsed = 0.0
	set_process(true)
	# Must be a typed array: TTS.speak_segments takes Array[Dictionary], and an
	# untyped literal will not pass GDScript's static check.
	var one: Array[Dictionary] = [{
		"text": step["text"],
		"lang": step["lang"],
		"rate": step["rate"],
		"volume": step["volume"],
		"pause_ms": 0,
	}]
	TTS.speak_segments(one)


func _on_clip_finished() -> void:
	if _waiting_for != "clip":
		return
	_waiting_for = ""
	_after_pause()


func _process(delta: float) -> void:
	if _waiting_for != "tts":
		set_process(false)
		return

	_wait_elapsed += delta
	# tts_manager knows more than the display server does: it also counts the
	# moment between asking the OS to speak and the OS admitting that it has,
	# and any segments still queued behind this one.
	var speaking := TTS.is_busy() or DisplayServer.tts_is_speaking()

	if not _tts_has_started:
		if speaking:
			_tts_has_started = true
			_silence_elapsed = 0.0
		elif _wait_elapsed >= TTS_START_GRACE_SEC:
			# It never started — no voice, or the engine declined. Move on
			# rather than leaving the recap hanging.
			_finish_tts_wait()
		return

	# tts_manager splits a segment on punctuation and speaks the pieces as
	# separate utterances, so even is_busy() dips false in the gap between two
	# of them. Requiring the silence to persist keeps the queue from stepping
	# over the rest of a sentence at its first full stop.
	if speaking:
		_silence_elapsed = 0.0
	else:
		_silence_elapsed += delta
		if _silence_elapsed >= TTS_SILENCE_DEBOUNCE_SEC:
			_finish_tts_wait()
			return

	if _wait_elapsed >= TTS_SEGMENT_TIMEOUT_SEC:
		# Something is wrong — never leave a child staring at a finished maze
		# because speech will not end.
		_finish_tts_wait()


func _finish_tts_wait() -> void:
	_waiting_for = ""
	set_process(false)
	_after_pause()


func _after_pause() -> void:
	var version := _queue_version
	var pause_ms := 0
	if _queue_at > 0 and _queue_at <= _queue.size():
		pause_ms = int(_queue[_queue_at - 1].get("pause_ms", 0))
	if pause_ms <= 0:
		_advance(version)
		return
	get_tree().create_timer(pause_ms / 1000.0).timeout.connect(
		func(): _advance(version)
	)


# ── Pack loading ─────────────────────────────────────────────────────────────

func _language_or_default(lang: String) -> String:
	return lang if not lang.is_empty() else Config.get_effective_learning_language()


## Load a language's manifest once, on first use, and keep it.
## A missing or broken pack is not an error: it means this language has no
## recordings, and every key falls through to the device voice.
func _pack(lang: String) -> Dictionary:
	if _packs.has(lang):
		return _packs[lang]

	var pack := {"items": {}, "coverage": {}, "_chars": {}, "_words": {}, "_ui": {}}
	_packs[lang] = pack

	var path := "%s/%s/manifest.json" % [PACK_DIR, lang]
	if not FileAccess.file_exists(path):
		return pack
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Speech: cannot open %s" % path)
		return pack
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("Speech: %s is not valid JSON — falling back to device TTS" % path)
		return pack
	var data = json.get_data()
	if not (data is Dictionary) or not data.has("items"):
		push_warning("Speech: %s has no items — falling back to device TTS" % path)
		return pack

	pack["items"] = data.get("items", {})
	pack["coverage"] = data.get("coverage", {})

	# The manifest already records what each clip shows on screen, so the
	# lookup from a displayed letter or word to its key is built from that
	# rather than re-deriving the slugs the build pipeline invented.
	for key in pack["items"]:
		var display := String(pack["items"][key].get("display_text", "")).to_upper()
		if display.is_empty():
			continue
		if key.begins_with("learning.char."):
			pack["_chars"][display] = key
		elif key.begins_with("learning.word."):
			pack["_words"][display] = key
		elif key.begins_with("ui."):
			pack["_ui"][_ui_lookup(display)] = key
	return pack


func _stream_for(lang: String, key: String) -> AudioStream:
	if key.is_empty():
		return null
	var cache_id := "%s/%s" % [lang, key]
	if _cache.has(cache_id):
		_cache_order.erase(cache_id)
		_cache_order.append(cache_id)
		return _cache[cache_id]

	var item: Dictionary = _pack(lang).get("items", {}).get(key, {})
	if item.is_empty():
		return null
	var path: String = "%s/%s/%s" % [PACK_DIR, lang, String(item.get("asset", ""))]
	if not ResourceLoader.exists(path):
		push_warning("Speech: %s is in the %s manifest but %s is missing" % [key, lang, path])
		return null
	var stream := ResourceLoader.load(path) as AudioStream
	if stream == null:
		return null

	_cache[cache_id] = stream
	_cache_order.append(cache_id)
	while _cache_order.size() > CACHE_LIMIT:
		_cache.erase(_cache_order.pop_front())
	return stream


func _note_missing(key: String, lang: String) -> void:
	# One warning per key per language, or a maze of missing clips floods the log.
	var id := "%s/%s" % [lang, key]
	if key.is_empty() or _warned_missing.has(id):
		return
	_warned_missing[id] = true
	print_verbose("Speech: no clip for %s (%s), using device TTS" % [key, lang])
