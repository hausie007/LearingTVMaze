## grapheme_text.gd
## ---------------------------------------------------------------------------
## Parses "[]"-marked strings into display graphemes.
##
## Some languages spell a single letter with two or three characters — Czech
## CH, Hungarian CS/GY/SZ, Slovak DZ, Vietnamese NGH. Those must be collected,
## displayed and spoken as ONE item, not as separate characters.
##
## Rather than infer them from per-language rules (which get it wrong on words
## like Polish MARZNĄĆ = mar-znąć, not ma-rz-nąć), the dictionary author marks
## them explicitly in the source word:
##
##   "MOU[CH]A"  →  M · O · U · CH · A
##
## A bracketed run is one grapheme; everything outside brackets is one grapheme
## per character. An unmarked word behaves exactly as it always has.
##
## Usage:
##   GraphemeText.split("MOU[CH]A")     # → ["M", "O", "U", "CH", "A"]
##   GraphemeText.strip("MOU[CH]A")     # → "MOUCHA"
##   GraphemeText.validate("MOU[CHA")   # → "unclosed '[' at 3"
##
## The same syntax is used for the alphabet strings in game_config.gd, so
## Letters mode and Words mode can never disagree about what a letter is.
## ---------------------------------------------------------------------------
class_name GraphemeText
extends RefCounted


## Opening and closing grapheme markers.
const OPEN := "["
const CLOSE := "]"

## Characters that stay visible in a word but are never spawned as collectibles.
## Global rule — no language collects a hyphen. U+0020 is always included.
const SEPARATORS := [" ", "'", "-"]


## Split a marked string into ordered display graphemes.
## Malformed input degrades gracefully rather than throwing: the game must
## never fail to spawn a maze because a word file has a typo. Use validate()
## at build time to catch those properly.
static func split(marked: String) -> PackedStringArray:
	var out := PackedStringArray()
	var length := marked.length()
	var i := 0
	while i < length:
		var ch := marked[i]
		if ch == OPEN:
			var close_at := marked.find(CLOSE, i + 1)
			if close_at == -1:
				# Unclosed group — take the remainder literally, minus the marker.
				for c in marked.substr(i + 1):
					out.append(c)
				break
			var group := marked.substr(i + 1, close_at - i - 1)
			if not group.is_empty():
				out.append(group)
			i = close_at + 1
		elif ch == CLOSE:
			# Stray closing marker — ignore it.
			i += 1
		else:
			out.append(ch)
			i += 1
	return out


## Remove markers, yielding the string to display and to speak.
static func strip(marked: String) -> String:
	if not marked.contains(OPEN) and not marked.contains(CLOSE):
		return marked
	return marked.replace(OPEN, "").replace(CLOSE, "")


## Return the starting character offset of each grapheme within strip(marked).
## Lets callers translate a grapheme index back into a character index, which
## is what substring-based speech of a partial word needs.
static func char_starts(graphemes: PackedStringArray) -> PackedInt32Array:
	var starts := PackedInt32Array()
	var offset := 0
	for g in graphemes:
		starts.append(offset)
		offset += g.length()
	return starts


## True if this grapheme is displayed but never collected.
static func is_separator(grapheme: String) -> bool:
	return grapheme in SEPARATORS


## Validate marker syntax. Returns "" when valid, else a human-readable error.
## Intended for the pre-commit word-list check and the speech pipeline, not
## for the hot path.
static func validate(marked: String) -> String:
	var depth := 0
	var group_start := -1
	var group_len := 0
	var i := 0
	while i < marked.length():
		var ch := marked[i]
		if ch == OPEN:
			if depth > 0:
				return "nested '%s' at %d" % [OPEN, i]
			depth = 1
			group_start = i
			group_len = 0
		elif ch == CLOSE:
			if depth == 0:
				return "unmatched '%s' at %d" % [CLOSE, i]
			if group_len < 2:
				return "group at %d must contain at least 2 characters" % group_start
			depth = 0
		elif depth == 1:
			group_len += 1
		i += 1
	if depth != 0:
		return "unclosed '%s' at %d" % [OPEN, group_start]
	return ""
