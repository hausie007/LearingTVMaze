## locale.gd
## ---------------------------------------------------------------------------
## Simple dictionary-based UI localization.
##
## Usage:  Locale.t("key")  →  returns the translated string for the
## effective language from Config.get_effective_language().
## ---------------------------------------------------------------------------
class_name Locale
extends RefCounted

# ── Translation table ────────────────────────────────────────────────────────
# Key → { lang_code → translated_string }
const _T: Dictionary = {
	# ── Main Menu ──
	"app_title":       {"en": "Learning Maze",  "cs": "Učící Bludiště"},
	"play":            {"en": "Play",            "cs": "Hrát"},
	"settings":        {"en": "Settings",        "cs": "Nastavení"},

	# ── Settings labels ──
	"settings_title":  {"en": "Settings",        "cs": "Nastavení"},
	"setting_mode":    {"en": "Game Mode:",      "cs": "Herní mód:"},
	"setting_diff":    {"en": "Difficulty:",      "cs": "Obtížnost:"},
	"setting_lang":    {"en": "Language:",        "cs": "Jazyk:"},
	"setting_theme":   {"en": "Theme:",           "cs": "Téma:"},
	"setting_voice":   {"en": "Voice Hints:",     "cs": "Hlasové nápov.:"},
	"save_return":     {"en": "Save & Return",   "cs": "Uložit"},

	# ── Toggle values ──
	"on":              {"en": "On",               "cs": "Zapnuto"},
	"off":             {"en": "Off",              "cs": "Vypnuto"},

	# ── Game modes ──
	"mode_normal":     {"en": "Normal (Maze Only)", "cs": "Normální (jen bludiště)"},
	"mode_numbers":    {"en": "Numbers",            "cs": "Čísla"},
	"mode_letters":    {"en": "Alphabet",            "cs": "Abeceda"},
	"mode_words":      {"en": "Words",               "cs": "Slova"},

	# ── Difficulties ──
	"diff_very_easy":  {"en": "Very Easy",       "cs": "Velmi snadné"},
	"diff_easy":       {"en": "Easy",            "cs": "Snadné"},
	"diff_medium":     {"en": "Medium",          "cs": "Střední"},
	"diff_hard":       {"en": "Hard",            "cs": "Těžké"},

	# ── Language option names ──
	"lang_auto":       {"en": "Auto",            "cs": "Automaticky"},
	"lang_english":    {"en": "English",         "cs": "English"},
	"lang_czech":      {"en": "Čeština",         "cs": "Čeština"},

	# ── Win screen ──
	"you_win":         {"en": "⭐ YOU WIN! ⭐",  "cs": "⭐ VÝHRA! ⭐"},
	"next_round":      {"en": "Next Round",      "cs": "Další kolo"},
	"challenge_pp":    {"en": "Challenge++",     "cs": "Výzva++"},
	"main_menu":       {"en": "Main Menu",       "cs": "Hlavní menu"},
}


## Look up a translation key for the current effective language.
## Falls back to English if the key or language is missing.
## Named `t()` to avoid collision with Godot's built-in `Object.tr()`.
static func t(key: String) -> String:
	if not _T.has(key):
		push_warning("Locale: unknown key '%s'" % key)
		return key

	var entry: Dictionary = _T[key]
	var lang: String = Config.get_effective_language()

	if entry.has(lang):
		return entry[lang]
	# Fallback to English
	if entry.has("en"):
		return entry["en"]
	return key
