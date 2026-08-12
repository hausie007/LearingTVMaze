## word_list.gd
## ---------------------------------------------------------------------------
## Helper class to load word lists from JSON data files.
##
## Word lists are stored as JSON arrays in res://data/words/ with naming:
##   words_{lang}_{difficulty}.json
## Each entry: {"word": "CAT", "emoji": "🐱"}
##
## The source `word` may carry grapheme markers for letters spelled with more
## than one character — {"word": "MOU[CH]A"}. Those are resolved once, here at
## load time: callers receive a clean `word` ("MOUCHA") plus a `graphemes`
## array (["M","O","U","CH","A"]). See grapheme_text.gd.
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
	# Try the requested language first, scanning downwards from 'difficulty' to 0
	var current_diff := clampi(difficulty, 0, 6)
	
	while current_diff >= 0:
		var path := "res://data/words/words_%s_%d.json" % [lang, current_diff]
		if FileAccess.file_exists(path):
			var file := FileAccess.open(path, FileAccess.READ)
			if file:
				var json_text := file.get_as_text()
				var json := JSON.new()
				if json.parse(json_text) == OK:
					var data = json.get_data()
					if data is Array:
						for item in data:
							if item is Dictionary:
								_resolve_entry(item, lang)
						return data
		
		# Not found at this difficulty, try one step easier
		current_diff -= 1

	# If still not found and we weren't already trying English, fallback to English
	# and repeat the downward scan starting back at the original requested difficulty.
	if lang != "en":
		push_warning("WordList: No list found for %s (up to diff %d). Falling back to English scan." % [lang, difficulty])
		return _load_word_list("en", difficulty)
	
	push_warning("WordList: No word lists found at all for %s up to diff %d." % [lang, difficulty])
	return []


## Normalise one loaded entry, in place.
##
## This is the ONLY place grapheme markers are resolved. Downstream code —
## the HUD, the win screen, both game managers, every speech call — keeps
## reading a clean `word` and never sees a bracket. Only the collectible
## spawner reads `graphemes`.
static func _resolve_entry(item: Dictionary, lang: String) -> void:
	item["lang"] = lang
	var marked := String(item.get("word", ""))
	item["graphemes"] = GraphemeText.split(marked)
	item["word"] = GraphemeText.strip(marked)
