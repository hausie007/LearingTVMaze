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
## Fallback is per item, not per language. A Studio language with one missing
## word speaks that one word through TTS and everything else from the pack, so
## a partial pack is useful the day it lands.
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
const CACHE_LIMIT := 16

## Rates handed to the TTS fallback, kept identical to the values the call
## sites used before this existed, so turning Studio off changes nothing.
const RATE_ITEM := 0.85
const RATE_WORD := 0.7

var _manifest: Dictionary = {}
var _manifest_lang: String = ""
var _char_keys: Dictionary = {}
var _word_keys: Dictionary = {}

var _player: AudioStreamPlayer = null
var _cache: Dictionary = {}
var _cache_order: Array[String] = []

var _warned_missing: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_player = AudioStreamPlayer.new()
	_player.name = "VoicePlayer"
	_player.bus = VOICE_BUS if AudioServer.get_bus_index(VOICE_BUS) != -1 else "Master"
	_player.max_polyphony = 1
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_player)


# ── Public API ───────────────────────────────────────────────────────────────

## Speak one collected letter, shown as `display` — "A", or "CH" for a
## multi-character letter. Call sites pass what the child sees and stay
## ignorant of clip keys.
func speak_grapheme(display: String, lang: String = "") -> void:
	var language := _language_or_default(lang)
	_load_pack(language)
	var key: String = _char_keys.get(display.to_upper(), "")
	_speak(key, language, display, RATE_ITEM)


## Speak a collected number.
func speak_number(value: int, lang: String = "") -> void:
	var language := _language_or_default(lang)
	_load_pack(language)
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
	_load_pack(language)
	var key: String = _word_keys.get(text.strip_edges().to_upper(), "")
	_speak(key, language, text, RATE_WORD)


## Speak by semantic key, for callers that already know one.
func speak_key(key: String, lang: String, fallback_text: String, rate: float = 1.0) -> void:
	var language := _language_or_default(lang)
	_load_pack(language)
	_speak(key, language, fallback_text, rate)


## Ordered narration — the finish recap. No recordings exist for these; they
## are composed at runtime from mixed languages. Passed straight to TTS.
func speak_segments(segments: Array[Dictionary]) -> void:
	if Config.voice_mode == Config.VoiceMode.OFF:
		return
	stop()
	TTS.speak_segments(segments)


## Stop anything playing or queued, from either backend.
func stop() -> void:
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


## True when a recording exists for this key in this language.
func has_clip(key: String, lang: String = "") -> bool:
	var language := _language_or_default(lang)
	_load_pack(language)
	return _manifest.get("items", {}).has(key)


## Per-category coverage for a language: "complete", "partial" or "none".
## The settings screen reads this to decide whether to offer Studio voice.
func coverage(lang: String = "") -> Dictionary:
	var language := _language_or_default(lang)
	_load_pack(language)
	return _manifest.get("coverage", {}).duplicate()


## True when every category this language declares is fully recorded.
func is_complete(lang: String = "") -> bool:
	var cover := coverage(lang)
	if cover.is_empty():
		return false
	for state in cover.values():
		if String(state) != "complete":
			return false
	return true


## True when a language has enough of a pack to be worth offering at all.
## Numbers and letters are what every mode uses; words are a bonus.
func has_pack(lang: String = "") -> bool:
	var cover := coverage(lang)
	return String(cover.get("number", "none")) == "complete" \
		and String(cover.get("char", "none")) == "complete"


## Decode the clip for a key now, so the first frame of playback is not also
## the first disk read. The next collectible is always known in advance.
func prefetch_grapheme(display: String, lang: String = "") -> void:
	if display.is_empty() or Config.voice_mode != Config.VoiceMode.STUDIO_PREFERRED:
		return
	var language := _language_or_default(lang)
	_load_pack(language)
	_stream_for(String(_char_keys.get(display.to_upper(), "")))


func prefetch_number(value: int, lang: String = "") -> void:
	if Config.voice_mode != Config.VoiceMode.STUDIO_PREFERRED:
		return
	_load_pack(_language_or_default(lang))
	_stream_for("learning.number.%03d" % value)


# ── Resolution ───────────────────────────────────────────────────────────────

func _speak(key: String, lang: String, fallback_text: String, rate: float) -> void:
	match Config.voice_mode:
		Config.VoiceMode.OFF:
			return
		Config.VoiceMode.DEVICE_TTS:
			_speak_with_tts(fallback_text, rate, lang)
		Config.VoiceMode.STUDIO_PREFERRED:
			if not key.is_empty() and _play(key):
				return
			_note_missing(key, lang)
			_speak_with_tts(fallback_text, rate, lang)


func _speak_with_tts(text: String, rate: float, lang: String) -> void:
	if text.strip_edges().is_empty():
		return
	if _player != null:
		_player.stop()
	TTS.speak(text, rate, lang)


func _play(key: String) -> bool:
	var stream := _stream_for(key)
	if stream == null:
		return false
	# Latest wins: stop whatever is playing rather than letting hints queue up.
	TTS.stop()
	_player.stream = stream
	_player.play()
	return true


func _stream_for(key: String) -> AudioStream:
	if key.is_empty():
		return null
	if _cache.has(key):
		_cache_order.erase(key)
		_cache_order.append(key)
		return _cache[key]

	var item: Dictionary = _manifest.get("items", {}).get(key, {})
	if item.is_empty():
		return null
	var path: String = "%s/%s/%s" % [PACK_DIR, _manifest_lang, String(item.get("asset", ""))]
	if not ResourceLoader.exists(path):
		push_warning("Speech: %s is in the manifest but %s is missing" % [key, path])
		return null
	var stream := ResourceLoader.load(path) as AudioStream
	if stream == null:
		return null

	_cache[key] = stream
	_cache_order.append(key)
	while _cache_order.size() > CACHE_LIMIT:
		_cache.erase(_cache_order.pop_front())
	return stream


# ── Pack loading ─────────────────────────────────────────────────────────────

func _language_or_default(lang: String) -> String:
	return lang if not lang.is_empty() else Config.get_effective_learning_language()


## Load a language's manifest, once, and only when that language is played.
## A missing or broken pack is not an error: it means this language has no
## recordings yet, and every key will fall through to TTS.
func _load_pack(lang: String) -> void:
	if lang == _manifest_lang:
		return

	_manifest = {}
	_char_keys.clear()
	_word_keys.clear()
	_cache.clear()
	_cache_order.clear()
	_warned_missing.clear()
	_manifest_lang = lang

	var path := "%s/%s/manifest.json" % [PACK_DIR, lang]
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Speech: cannot open %s" % path)
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("Speech: %s is not valid JSON — falling back to device TTS" % path)
		return
	var data = json.get_data()
	if not (data is Dictionary) or not data.has("items"):
		push_warning("Speech: %s has no items — falling back to device TTS" % path)
		return
	_manifest = data

	# The manifest already records what each clip shows on screen, so the
	# lookup from a displayed letter or word to its key is built from that
	# rather than re-deriving slugs the build pipeline invented.
	for key in _manifest["items"]:
		var display := String(_manifest["items"][key].get("display_text", "")).to_upper()
		if display.is_empty():
			continue
		if key.begins_with("learning.char."):
			_char_keys[display] = key
		elif key.begins_with("learning.word."):
			_word_keys[display] = key


func _note_missing(key: String, lang: String) -> void:
	# One warning per key per pack, or a maze of missing clips floods the log.
	if key.is_empty() or _warned_missing.has(key):
		return
	_warned_missing[key] = true
	print_verbose("Speech: no clip for %s (%s), using device TTS" % [key, lang])
