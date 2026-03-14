## word_list.gd
## ---------------------------------------------------------------------------
## Helper class to load word lists from JSON data files.
##
## Word lists are stored as JSON arrays in res://data/words/ with naming:
##   words_{lang}_{difficulty}.json
## Each entry: {"word": "CAT", "emoji": "🐱"}
##
## Falls back to English if the requested language file is missing.
## ---------------------------------------------------------------------------
class_name WordList
extends RefCounted


## Cache of shuffled word arrays, keyed by "lang_diff"
static var _shuffled_decks: Dictionary = {}

## Cache of the last word dealt per deck, to prevent back-to-back repeats
static var _last_dealt: Dictionary = {}

## Load and return a random word dictionary for the effective language & difficulty.
## Uses a shuffle-bag approach so words don't repeat until the list is exhausted.
## Prevents the same word from appearing twice in a row across reshuffles.
## Returns {"word": "CAT", "emoji": "🐱"} or an empty dict on failure.
static func get_random_word(lang: String, difficulty: int) -> Dictionary:
	var key := "%s_%d" % [lang, difficulty]
	
	# If deck is missing or empty, load and shuffle a new one
	if not _shuffled_decks.has(key) or _shuffled_decks[key].is_empty():
		var words := _load_word_list(lang, difficulty)
		if words.is_empty():
			return {}
		words.shuffle()
		_shuffled_decks[key] = words
		
	var deck: Array = _shuffled_decks[key]
	var next_word: Dictionary = deck.pop_back()
	
	# If it's the exact same word as the last one dealt, and we have other options, swap it
	if _last_dealt.has(key) and _last_dealt[key].get("word") == next_word.get("word") and deck.size() > 0:
		var alternate: Dictionary = deck.pop_back()
		deck.push_front(next_word) # Put it back somewhere else (front)
		next_word = alternate
		
	_last_dealt[key] = next_word
	return next_word


## Load the full word list array for a language + difficulty.
## Falls back to English if the requested language file is not found.
static func _load_word_list(lang: String, difficulty: int) -> Array:
	var diff_clamped := clampi(difficulty, 0, 3)
	var path := "res://data/words/words_%s_%d.json" % [lang, diff_clamped]
	var actual_lang := lang
	
	if not FileAccess.file_exists(path):
		if lang != "en":
			push_warning("WordList: file not found: %s — falling back to English" % path)
			path = "res://data/words/words_en_%d.json" % diff_clamped
			actual_lang = "en"
			if not FileAccess.file_exists(path):
				push_warning("WordList: English fallback also missing: %s" % path)
				return []
		else:
			push_warning("WordList: file not found: %s" % path)
			return []
	
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("WordList: cannot open: %s" % path)
		return []
	
	var json_text := file.get_as_text()
	var json := JSON.new()
	var err := json.parse(json_text)
	if err != OK:
		push_warning("WordList: JSON parse error in %s: %s" % [path, json.get_error_message()])
		return []
	
	var data = json.get_data()
	if data is Array:
		# Inject the actual language used into each word entry
		for item in data:
			if item is Dictionary:
				item["lang"] = actual_lang
		return data
	
	push_warning("WordList: expected Array in %s" % path)
	return []
