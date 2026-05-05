## learning_recap.gd
## ---------------------------------------------------------------------------
## Builds the short learning recap shown and spoken on maze completion.
## Keeps the visible text and segmented TTS payload in one place so solo and
## multiplayer finish screens stay consistent.
## ---------------------------------------------------------------------------
class_name LearningRecap
extends RefCounted


const TYPE_NUMBERS := "numbers"
const TYPE_LETTERS := "letters"
const TYPE_WORDS := "words"
const TARGET_MARKER := "__LEARNING_RECAP_TARGET__"
const FIRST_MARKER := "__LEARNING_RECAP_FIRST__"
const LAST_MARKER := "__LEARNING_RECAP_LAST__"


static func build(game_mode: int, sequence: Array[String], word: String = "", word_lang: String = "") -> Dictionary:
	var values := _clean_sequence(sequence)
	if values.is_empty():
		return {}

	match game_mode:
		Config.GameMode.NUMBERS:
			return _build_numbers(values)
		Config.GameMode.LETTERS:
			return _build_letters(values)
		Config.GameMode.WORDS:
			return _build_word(values, word, word_lang)
		_:
			return {}


static func _build_numbers(values: Array[String]) -> Dictionary:
	var last_value := values[values.size() - 1]
	var sequence_text := ", ".join(PackedStringArray(values))
	var learning_lang := Config.get_effective_learning_language()
	var ui_lang := Config.get_effective_ui_language()
	var learning_context := _language_context_in_ui(learning_lang)
	var show_language := learning_lang != ui_lang
	var text_key := "recap_numbers_lang" if show_language else "recap_numbers"
	var text_args: Array = [learning_context, last_value, sequence_text] if show_language else [last_value, sequence_text]
	return {
		"type": TYPE_NUMBERS,
		"text": _fmt(text_key, text_args),
		"tts_segments": _number_segments(values, learning_context, show_language),
	}


static func _build_letters(values: Array[String]) -> Dictionary:
	var boundary := _letter_boundary(values)
	var first_value := String(boundary.get("first", values[0]))
	var last_value := String(boundary.get("last", values[values.size() - 1]))
	var show_language := bool(boundary.get("show_language", false))
	var learning_context := String(boundary.get("learning_context", ""))
	var sequence_text := ", ".join(PackedStringArray(values))
	var key := ""
	var args: Array = []
	if values.size() == 1:
		key = "recap_letter_single_lang" if show_language else "recap_letter_single"
		args = [learning_context, first_value, sequence_text] if show_language else [first_value, sequence_text]
	else:
		key = "recap_letters_lang" if show_language else "recap_letters"
		args = [learning_context, first_value, last_value, sequence_text] if show_language else [first_value, last_value, sequence_text]
	return {
		"type": TYPE_LETTERS,
		"text": _fmt(key, args),
		"tts_segments": _letter_segments(values, boundary),
	}


static func _build_word(values: Array[String], word: String, word_lang: String) -> Dictionary:
	var display_word := word.strip_edges()
	if display_word.is_empty():
		display_word = "".join(PackedStringArray(values))
	var ui_lang := Config.get_effective_ui_language()
	var learning_lang := word_lang if not word_lang.is_empty() else Config.get_effective_learning_language()
	var learning_context := _language_context_in_ui(learning_lang)
	var show_language := learning_lang != ui_lang
	var is_phrase := _has_inner_space(display_word)
	var key := ""
	var args: Array = []
	if is_phrase:
		key = "recap_phrase_lang" if show_language else "recap_phrase"
		args = [learning_context, display_word] if show_language else [display_word]
	else:
		key = "recap_word_lang" if show_language else "recap_word"
		args = [learning_context, display_word] if show_language else [display_word]
	return {
		"type": TYPE_WORDS,
		"text": _fmt(key, args),
		"tts_segments": _word_segments(values, display_word, learning_lang, learning_context, show_language, is_phrase),
	}


static func _number_segments(values: Array[String], learning_context: String, show_language: bool) -> Array[Dictionary]:
	var ui_lang := Config.get_effective_ui_language()
	var learning_lang := Config.get_effective_learning_language()
	var last_value := values[values.size() - 1]
	var intro_key := "recap_tts_counted_to_lang" if show_language else "recap_tts_counted_to"
	var intro_args: Array = [learning_context, last_value] if show_language else [last_value]
	var segments: Array[Dictionary] = [
		_segment(_fmt(intro_key, intro_args), ui_lang, 0.82, 180),
	]
	for value in values:
		segments.append(_segment(value, learning_lang, 0.78, 90))
	return segments


static func _letter_segments(values: Array[String], boundary: Dictionary) -> Array[Dictionary]:
	var ui_lang := Config.get_effective_ui_language()
	var learning_lang := Config.get_effective_learning_language()
	var boundary_lang := String(boundary.get("tts_lang", learning_lang))
	var first_value := String(boundary.get("first", values[0]))
	var last_value := String(boundary.get("last", values[values.size() - 1]))
	var learning_context := String(boundary.get("learning_context", ""))
	var show_language := bool(boundary.get("show_language", false))
	var boundary_is_ui := boundary_lang == ui_lang
	var segments: Array[Dictionary] = []
	if values.size() == 1:
		if boundary_is_ui:
			var key := "recap_tts_found_letter_lang" if show_language else "recap_tts_found_letter"
			var args: Array = [learning_context, first_value] if show_language else [first_value]
			segments.append(_segment(_fmt(key, args), ui_lang, 0.82, 180))
		else:
			var key := "recap_tts_found_letter_lang" if show_language else "recap_tts_found_letter"
			var args: Array = [learning_context, FIRST_MARKER] if show_language else [FIRST_MARKER]
			_append_one_marker_segments(segments, _fmt(key, args), FIRST_MARKER, first_value, boundary_lang)
	else:
		if boundary_is_ui:
			var key := "recap_tts_found_letters_lang" if show_language else "recap_tts_found_letters"
			var args: Array = [learning_context, first_value, last_value] if show_language else [first_value, last_value]
			segments.append(_segment(_fmt(key, args), ui_lang, 0.82, 180))
		else:
			var key := "recap_tts_found_letters_lang" if show_language else "recap_tts_found_letters"
			var args: Array = [learning_context, FIRST_MARKER, LAST_MARKER] if show_language else [FIRST_MARKER, LAST_MARKER]
			_append_two_marker_segments(segments, _fmt(key, args), FIRST_MARKER, first_value, LAST_MARKER, last_value, boundary_lang)
	for value in values:
		segments.append(_segment(value, learning_lang, 0.78, 90))
	return segments


static func _word_segments(
	values: Array[String],
	display_word: String,
	learning_lang: String,
	learning_context: String,
	show_language: bool,
	is_phrase: bool
) -> Array[Dictionary]:
	var ui_lang := Config.get_effective_ui_language()
	var recap_key := ""
	var recap_args: Array = []
	if is_phrase:
		recap_key = "recap_phrase_lang" if show_language else "recap_phrase"
		recap_args = [learning_context, TARGET_MARKER] if show_language else [TARGET_MARKER]
	else:
		recap_key = "recap_word_lang" if show_language else "recap_word"
		recap_args = [learning_context, TARGET_MARKER] if show_language else [TARGET_MARKER]
	var segments: Array[Dictionary] = []
	_append_one_marker_segments(segments, _fmt(recap_key, recap_args), TARGET_MARKER, display_word, learning_lang)
	for value in values:
		segments.append(_segment(value, learning_lang, 0.78, 90))
	segments.append(_segment(display_word, learning_lang, 0.76, 220))
	return segments


static func _clean_sequence(sequence: Array[String]) -> Array[String]:
	var values: Array[String] = []
	for raw_value in sequence:
		var value := raw_value.strip_edges()
		if not value.is_empty():
			values.append(value)
	return values


static func _segment(text: String, lang: String, rate: float, pause_ms: int) -> Dictionary:
	return {
		"text": text,
		"lang": lang,
		"rate": rate,
		"pause_ms": pause_ms,
	}


static func _append_one_marker_segments(
	segments: Array[Dictionary],
	text: String,
	marker: String,
	value: String,
	value_lang: String
) -> void:
	var parts := _split_once(text, marker)
	_append_ui_segment(segments, String(parts.get("before", "")), 90)
	segments.append(_segment(value, value_lang, 0.78, 120))
	_append_ui_segment(segments, String(parts.get("after", "")), 170)


static func _append_two_marker_segments(
	segments: Array[Dictionary],
	text: String,
	first_marker: String,
	first_value: String,
	second_marker: String,
	second_value: String,
	value_lang: String
) -> void:
	var first_parts := _split_once(text, first_marker)
	var second_parts := _split_once(String(first_parts.get("after", "")), second_marker)
	_append_ui_segment(segments, String(first_parts.get("before", "")), 90)
	segments.append(_segment(first_value, value_lang, 0.78, 90))
	_append_ui_segment(segments, String(second_parts.get("before", "")), 90)
	segments.append(_segment(second_value, value_lang, 0.78, 90))
	_append_ui_segment(segments, String(second_parts.get("after", "")), 170)


static func _append_ui_segment(segments: Array[Dictionary], text: String, pause_ms: int) -> void:
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		return
	segments.append(_segment(trimmed, Config.get_effective_ui_language(), 0.82, pause_ms))


static func _split_once(text: String, marker: String) -> Dictionary:
	var marker_index := text.find(marker)
	if marker_index < 0:
		return {"before": text, "after": ""}
	return {
		"before": text.substr(0, marker_index),
		"after": text.substr(marker_index + marker.length()),
	}


static func _fmt(key: String, args: Array) -> String:
	return _tr(key) % args


static func _tr(key: String) -> String:
	return TranslationServer.translate(key)


static func _letter_boundary(values: Array[String]) -> Dictionary:
	var ui_lang := Config.get_effective_ui_language()
	var learning_lang := Config.get_effective_learning_language()
	var ui_family := _alphabet_family(ui_lang)
	var learning_family := _alphabet_family(learning_lang)
	var use_ui_letters := ui_family == learning_family
	var first_index := 0
	var last_index := values.size() - 1
	var first_value := Config.get_alphabet_char(first_index, ui_lang) if use_ui_letters else values[0]
	var last_value := Config.get_alphabet_char(last_index, ui_lang) if use_ui_letters else values[values.size() - 1]
	return {
		"first": first_value,
		"last": last_value,
		"tts_lang": ui_lang if use_ui_letters else learning_lang,
		"learning_context": _language_context_in_ui(learning_lang),
		"show_language": learning_lang != ui_lang,
	}


static func _alphabet_family(lang: String) -> String:
	match lang:
		"el":
			return "greek"
		"he":
			return "hebrew"
		"uk":
			return "ukrainian"
		_:
			return "latin"


static func _language_name_in_ui(lang: String) -> String:
	var idx := Config.LANG_CODES.find(lang)
	if idx >= 0 and idx < Config.LANG_KEYS.size():
		return _tr(Config.LANG_KEYS[idx])
	return lang


static func _language_context_in_ui(lang: String) -> String:
	var idx := Config.LANG_CODES.find(lang)
	if idx >= 0 and idx < Config.LANG_KEYS.size():
		var context_key := Config.LANG_KEYS[idx].replace("lang_", "lang_in_")
		var context_value := _tr(context_key)
		if context_value != context_key:
			return context_value
	return _language_name_in_ui(lang)


static func _has_inner_space(text: String) -> bool:
	for i in range(text.length()):
		if text[i] == " ":
			return true
	return false
