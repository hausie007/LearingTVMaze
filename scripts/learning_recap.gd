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
const CONTEXT_MARKER := "__LEARNING_RECAP_CONTEXT__"

## Numbers in the grammatical form a sentence needs, keyed by language.
## Czech "do padesáti", not "do padesát" — the ending belongs to the sentence
## rather than to the number, so it cannot be spliced on afterwards.
const NUMBER_FORMS_PATH := "res://data/number_forms.json"
static var _number_forms: Dictionary = {}
static var _number_forms_loaded: bool = false


## The number as this language says it after "counted to". Falls back to the
## digits, which is correct for every language that does not inflect here and
## is what the reader did before this existed.
static func number_in_frame(lang: String, value: String, case_name: String = "to") -> String:
	if not _number_forms_loaded:
		_number_forms_loaded = true
		if FileAccess.file_exists(NUMBER_FORMS_PATH):
			var file := FileAccess.open(NUMBER_FORMS_PATH, FileAccess.READ)
			if file != null:
				var json := JSON.new()
				if json.parse(file.get_as_text()) == OK:
					var data = json.get_data()
					if data is Dictionary:
						_number_forms = data.get("languages", {})
				else:
					push_warning("LearningRecap: %s is not valid JSON" % NUMBER_FORMS_PATH)
	var forms: Dictionary = _number_forms.get(lang, {})
	var cases: Dictionary = forms.get(case_name, {})
	return String(cases.get(value, value))


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
	var intro_args: Array = [CONTEXT_MARKER, LAST_MARKER] if show_language else [LAST_MARKER]
	var segments: Array[Dictionary] = []
	# The number inside the frame belongs to the frame: it is spoken in the UI
	# language and in whatever form that sentence governs. The learning-language
	# numbers follow after it, as the sequence.
	_append_marked(segments, _fmt(intro_key, intro_args), _marks(
		show_language, learning_context, ui_lang,
		[[LAST_MARKER, number_in_frame(ui_lang, last_value), ui_lang]]))
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
	var segments: Array[Dictionary] = []
	# Marked whether or not the boundary letters are in the UI language. The
	# result is identical when they are, and it keeps the framing as its own
	# segments, which is the only form a recording can match.
	if values.size() == 1:
		var key := "recap_tts_found_letter_lang" if show_language else "recap_tts_found_letter"
		var args: Array = [CONTEXT_MARKER, FIRST_MARKER] if show_language else [FIRST_MARKER]
		_append_marked(segments, _fmt(key, args), _marks(
			show_language, learning_context, ui_lang, [[FIRST_MARKER, first_value, boundary_lang]]))
	else:
		var key := "recap_tts_found_letters_lang" if show_language else "recap_tts_found_letters"
		var args: Array = [CONTEXT_MARKER, FIRST_MARKER, LAST_MARKER] if show_language else [FIRST_MARKER, LAST_MARKER]
		_append_marked(segments, _fmt(key, args), _marks(
			show_language, learning_context, ui_lang,
			[[FIRST_MARKER, first_value, boundary_lang], [LAST_MARKER, last_value, boundary_lang]]))
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
		recap_args = [CONTEXT_MARKER, TARGET_MARKER] if show_language else [TARGET_MARKER]
	else:
		recap_key = "recap_word_lang" if show_language else "recap_word"
		recap_args = [CONTEXT_MARKER, TARGET_MARKER] if show_language else [TARGET_MARKER]
	var segments: Array[Dictionary] = []
	_append_marked(segments, _fmt(recap_key, recap_args), _marks(
		show_language, learning_context, ui_lang, [[TARGET_MARKER, display_word, learning_lang]]))
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


## Split a formatted template around every value substituted into it, so that
## what remains between them is pure template text.
##
## This is what lets the framing be recorded. A sentence with the value still
## inside it — "You counted to 7" — matches nothing in a pack, because a pack
## holds "You counted to" and the number separately. It also lets the framing
## and the values come from different languages, which is the normal case.
##
## `marks` is an ordered array of [marker, value, language], in the order the
## markers appear in the text.
static func _append_marked(segments: Array[Dictionary], text: String, marks: Array) -> void:
	var rest := text
	for mark in marks:
		var parts := _split_once(rest, String(mark[0]))
		_append_ui_segment(segments, String(parts.get("before", "")), 90)
		segments.append(_segment(String(mark[1]), String(mark[2]), 0.78, 110))
		rest = String(parts.get("after", ""))
	_append_ui_segment(segments, rest, 170)


## The language name, when the recap names one, is itself a value rather than
## part of the framing — "in Czech" is spoken in the language of the menu and
## belongs in the pack as its own clip.
static func _marks(show_language: bool, context: String, ui_lang: String, rest: Array) -> Array:
	var marks: Array = []
	if show_language:
		marks.append([CONTEXT_MARKER, context, ui_lang])
	marks.append_array(rest)
	return marks


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


## The first and last letter the child actually collected.
##
## These used to be looked up in the UI language's alphabet by index, so that
## the sentence could be monolingual. That is not a translation, it is a
## renaming: a Czech menu with English content collected A B C D and reported
## "A to Č", because Č is the fourth letter of the Czech alphabet. There is no
## sense in which the child collected Č.
##
## A collected letter is a fact about the game, not a slot in the reader's
## alphabet. It is reported as it was collected, in the language it was
## collected in, and the framing around it stays in the UI language.
static func _letter_boundary(values: Array[String]) -> Dictionary:
	var ui_lang := Config.get_effective_ui_language()
	var learning_lang := Config.get_effective_learning_language()
	return {
		"first": values[0],
		"last": values[values.size() - 1],
		"tts_lang": learning_lang,
		"learning_context": _language_context_in_ui(learning_lang),
		"show_language": learning_lang != ui_lang,
	}




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
