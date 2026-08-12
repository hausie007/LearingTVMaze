# Studio Voice — iteration 1 design and implementation plan

Status: design proposal, not yet implemented
Date: 2026-08-12
Parent analysis: [`_ideas_/replace_tts_with-real_sounds.md`](replace_tts_with-real_sounds.md)
Scope: **Czech + English, numbers and letters only.** Infrastructure-first.

---

## 0. What iteration 1 delivers

| Delivered | Not delivered |
|---|---|
| Grapheme marking in the word source (`MOU[CH]A`), resolved in one place | Word/phrase clips (P1) |
| A reusable offline generation pipeline (`tools/speech/`) | The other 19 languages' audio |
| Pre-generated clips for `en` and `cs`: numbers 1–50, full alphabets | Help narration, finish recap, boot title, settings preview |
| `SpeechManager` autoload as the single speech entry point | Solo accumulated-prefix speech (stays on TTS) |
| Dedicated `Voice` audio bus and single-slot player | Play Asset Delivery / downloadable packs |
| Three-way setting: Off / Device voice / Studio voice | |

**Clip count for iteration 1: ~168.** 100 numbers (2 × 50) + 68 letters (en 26 + cs 42, or 39 if `Q`/`W`/`X` are excluded — open decision §G.2).
Estimated synthesis cost: **well under USD 1** including retakes. Cost is not a constraint at this scale; the constraint is native review time.

Letter clips are also consumed by **Words mode** character pickups, since those resolve to the same `learning.char.*` keys. So the pilot improves three of four game modes even though no word clips are generated.

### Decisions taken

| Question | Decision |
|---|---|
| Multigraph handling | **Marked inline in the word source with `[` `]`.** No tokenizer, no per-language grapheme lists |
| Czech letter inventory | Full 42-letter Czech alphabet **including `[CH]`** |
| What a letter says | **Letter name** (`á`, `bé`, `cé` / `ay`, `bee`, `see`) — not phoneme |
| English reference accent | **en-US** (Z = "zee") |
| Pipeline scope | **Full pipeline**, narrow content |
| Provider | ElevenLabs, offline only. No API key ever ships in the app. |

---

## Part A — Graphemes by explicit marking

### A.1 Finding: multigraphs are not handled anywhere

Verified against the current code:

| Location | Current behaviour |
|---|---|
| `game_config.gd:690` `get_alphabet_char()` | Explicit strings for `el`, `he`, `uk` only. Everything else falls through to `String.chr(65 + index % 26)` — plain A–Z, **wrapping** past 26 |
| `collectible_spawner.gd:175` | `max_items = 26` for `LETTERS` mode, hardcoded |
| `multiplayer_game_manager.gd:1503` | Same hardcoded `26` |
| `collectible_spawner.gd:142-143` | Tracker values built as `word[i]` — one entry per **codepoint** |
| `collectible_spawner.gd:224-241` | Word collectibles: one per codepoint, skipping exactly `U+0020`; `collect_index` **is** the character index |
| `collectible_spawner.gd:276-283` | `_word_next_index` is a character index, advanced by `+= 1` plus a space-skip loop |
| `collectible.gd:115` | `text_scale := 0.40 if length == 1 else 0.30` — **multi-character values already render correctly** (needed for numbers 10–50) |
| `tts_manager.gd:320` | Appends `.` to single-character text for `el`/`cs` to nudge the engine toward the letter name |

So today Czech letter mode shows plain `A…Z` — no `Á`, `Č`, `Ř`, `Š`, `Ž`, no `CH`. Czech word mode spells `MOUCHA` as six pickups `M·O·U·C·H·A` and hands `C` then `H` to TTS separately. For a Czech reading-readiness game that is simply wrong: `ch` is one letter and one sound.

### A.2 Finding: this is not a Czech-only problem

Scanning the full 3,652-entry corpus for candidate multigraphs:

| Lang | Words containing a candidate | Candidates found |
|---|---:|---|
| `vi` | **105 / 170** | NG×38, NH×32, CH×27, TR×16, TH×8, PH×6, KH×4, GI×3, QU×2 |
| `hu` | **57 / 140** | SZ×22, NY×13, CS×13, GY×13, TY×3, ZS×3, LY×2 |
| `pl` | 46 / 169 | CZ×16, DZ×14, SZ×11, RZ×8, CH×6, DŹ×3, DŻ×1 |
| `nl` | 14 / 165 | IJ×14 |
| `cs` | 8 / 277 | CH×8 |
| `sk` | 6 / 147 | CH×3, DZ×3 |
| `es` | 27 / 207 | LL×17, RR×6, CH×4 — **should not be marked**, see A.3 |
| `de` `fr` `it` `pt` | 64 / 56 / 22 / 22 | SCH, CH, EI, OU, AU, GN, GL, SC, NH, LH — **should not be marked**, see A.3 |
| `da` `el` `en` `fi` `he` `nb` `ro` `sv` `tr` `uk` | 0 | — |

Vietnamese is the largest case at 62% of its vocabulary, not Czech. Hungarian is 41%.

### A.3 Which of these are actually letters

The scan surfaces *candidates*; most must be rejected. The test is whether the multigraph is a letter of the language's alphabet, not merely a sound spelled with two characters.

| Mark | Language | Reason |
|---|---|---|
| **Yes** | `cs` | `CH` is the 15th letter of the 42-letter Czech alphabet |
| **Yes** | `sk` | `CH`, `DZ`, `DŽ` are letters of the 46-letter Slovak alphabet |
| **Yes** | `hu` | 8 digraphs + the `DZS` trigraph are letters of the 44-letter Hungarian alphabet |
| **Yes** | `vi` | `CH GH GI KH NG NGH NH PH QU TH TR` are taught as letters in Vietnamese *quốc ngữ* |
| **Author's call** | `nl` | `IJ` is capitalised as a unit (`IJsland`) but sorts as I+J. Contested |
| **Author's call** | `pl` | *Dwuznaki* are taught as sound units but are **not** in the 32-letter alphabet |
| **No** | `es` | The RAE removed `CH` and `LL` from the alphabet in 2010 |
| **No** | `de` `fr` `it` `pt` | `SCH`, `OU`, `GN`, `NH` etc. are phonetic spellings, not alphabet letters |

Crucially, **none of this becomes shipped data.** It is a set of decisions made once, by a native reviewer, and recorded directly in the word files as brackets. The game never knows the rules — only the result.

### A.4 The marking syntax

A multigraph is wrapped in `[` `]` in the `word` field. Everything outside brackets is one pickup per codepoint.

```json
{"word": "MOU[CH]A",  "emoji": "🪰"}
{"word": "[CH]LÉB",   "emoji": "🍞"}
{"word": "MA[CS]KA",  "emoji": "🐈"}
{"word": "[TR]A[NG]", "emoji": "📄"}
```

Rules, complete:

1. `[` opens a group, `]` closes it. The enclosed run is **one pickup**, displayed as-is.
2. No nesting, no empty groups, minimum two characters inside.
3. Brackets are **invisible** — they never reach the screen or the speech engine.
4. An unmarked word behaves exactly as today: one pickup per codepoint.
5. Space, apostrophe and hyphen are never collectible (they stay visible in the tracker). This is a global rule, not per-language — no language wants to collect a hyphen.

Collision check: across all 3,652 entries the only non-letter characters are space (1,731), apostrophe (12) and hyphen (12). `[` and `]` appear zero times, so the syntax is free to adopt.

The same syntax works for the alphabet strings in `game_config.gd`, which is what keeps letter mode and word mode consistent:

```gdscript
"cs": "AÁBCČDĎEÉĚFGH[CH]IÍJKLMNŇOÓPQRŘSŠTŤUÚŮVWXYÝZŽ"
```

One syntax, one parser, both call sites.

### A.5 The one place: `GraphemeText`

New file `scripts/grapheme_text.gd`, `class_name GraphemeText`. Roughly 30 lines, pure string functions, no state, no dependencies.

```gdscript
## grapheme_text.gd
## -----------------------------------------------------------------------
## Parses "[]"-marked strings into display graphemes.
## A bracketed run is one grapheme; everything else is one per codepoint.
##
## Usage:
##   GraphemeText.split("MOU[CH]A")  # → ["M", "O", "U", "CH", "A"]
##   GraphemeText.strip("MOU[CH]A")  # → "MOUCHA"
## -----------------------------------------------------------------------

## Split a marked string into ordered display graphemes.
static func split(marked: String) -> PackedStringArray

## Remove markers, yielding the display/speech string.
static func strip(marked: String) -> String

## Validate syntax. Returns "" if valid, else a human-readable error.
static func validate(marked: String) -> String
```

That is the entire runtime cost of the feature. No tokenizer, no language tables, no Python mirror to drift out of sync.

### A.6 Where it is called — two sites, and only two

**Site 1 — `word_list.gd:65-68`.** This loop already post-processes every loaded entry (it injects `lang`). It becomes:

```gdscript
for item in data:
    if item is Dictionary:
        item["lang"] = lang
        var marked: String = String(item.get("word", ""))
        item["graphemes"] = GraphemeText.split(marked)
        item["word"] = GraphemeText.strip(marked)   # clean display/speech text
```

This is why the change is safe. `Config.current_word["word"]` is read in **17 places** across 5 files — the HUD, the win screen, both game managers, the tracker, the TTS calls. Every one of them keeps receiving a clean `MOUCHA` and needs no edit. Only the spawner reads the new `graphemes` key.

The word never crosses the network (each peer deals locally via `WordList`), so there is no multiplayer sync concern.

**Site 2 — `game_config.gd:690` `get_alphabet_char()`.** The three hardcoded alphabet strings gain per-language siblings, and the function parses them through the same helper, caching the split result per language:

```gdscript
func get_alphabet_char(index: int, lang: String) -> String:
    var alphabet := _alphabet_for(lang)          # PackedStringArray, cached
    if index < 0 or index >= alphabet.size():
        return ""                                 # no more wrapping
    return alphabet[index]

func get_alphabet_length(lang: String) -> int
```

### A.7 Consequential edits

| File | Change |
|---|---|
| `game_config.gd:690-708` | As A.6. **Removes the `% 26` wrap** — returns `""` past the end |
| `collectible_spawner.gd:175` | `max_items` for LETTERS becomes `Config.get_alphabet_length(lang)` instead of `26` |
| `multiplayer_game_manager.gd:1503` | Same |
| `collectible_spawner.gd:224-241` | Iterate `Config.current_word["graphemes"]` instead of `word[i]`; skip space/apostrophe/hyphen. `collect_index` stays the **start character index** of the grapheme, preserving the existing contract with `game_manager.gd` |
| `collectible_spawner.gd:276-283` | Advance `_word_next_index` to the next collectible grapheme's start rather than `+= 1` plus a space-skip loop |
| `collectible_spawner.gd:141-147` | Tracker values come from `graphemes` |
| `multiplayer_game_manager.gd:1517-1539` | Same treatment for race word sequences |
| `collectible_tracker.gd` | None — already takes `Array[String]` |
| `collectible.gd` | None — `:115` already handles multi-character values |
| `learning_recap.gd:251-252` | None — benefits automatically via `get_alphabet_char()` |
| `game_manager.gd:945-949` | None — `substr(0, end)` still works because indices remain character indices into the clean word |

**Two bugs fixed for free.** Removing the `% 26` wrap and the hardcoded `max_items = 26` also fixes Greek repeating `Ω` for the last two slots, Hebrew repeating `ת` for the last four, and Ukrainian never reaching its final seven letters — all noted in the parent analysis §3.1.

**Grid-fit note:** grouping only ever *reduces* pickup count (`MOUCHA` 6 → 5), so it cannot break the tier-0 six-usable-cell constraint in `DEVELOPMENT.md` §4. It does mean the tier length cap should count graphemes rather than characters — which is more correct anyway.

### A.8 Validation

Extend the word-list validation snippet in `CLAUDE.md` and `DEVELOPMENT.md` §4 to:

1. `GraphemeText.validate()` equivalent in Python — balanced brackets, no nesting, no empty or single-character groups.
2. Strip markers **before** the existing duplicate, length and emoji checks, so `MOU[CH]A` and `MOUCHA` are correctly seen as the same word.
3. Assert the expected file/entry counts still hold (`OK 147 files, 3652 entries`).

What validation deliberately does **not** do is verify that a word is marked *correctly* — that would require the per-language tables this design just removed. Correctness is the dictionary author's responsibility, exactly as the emoji-word match already is.

---

## Part B — One-time corpus review

The 3,652 existing entries need a pass to add markers. This is a **content task, not a code task**, and per `DEVELOPMENT.md` §7 it commits separately from code.

### B.1 Process

1. **Decide per language** (A.3). Four are clear yes (`cs`, `sk`, `hu`, `vi`), two are the author's call (`nl`, `pl`), the rest are no.
2. **Generate a review worksheet.** A throwaway script in `tools/` scans each accepted language for candidate multigraph substrings and emits a CSV: `file, word, proposed marking, reason`. The candidate list lives in that script only — it is a review aid, never shipped, never loaded by the game.
3. **Native reviewer accepts or rejects each row.** This is where false splits get caught, and it is why no automatic rule is being trusted.
4. **Apply accepted markings** back into the JSON files, preserving key order and formatting.
5. **Run validation**, confirm `OK 147 files, 3652 entries` and that stripped words are unchanged from the pre-review corpus — a byte-level guarantee that the review added markers and nothing else.

### B.2 Scale, and why order matters

| Language | Rows to review | Confidence | When |
|---|---:|---|---|
| `cs` | 8 | High — all 8 verified genuine `ch` | **Iteration 1** |
| `en` | 0 | — | Iteration 1 (nothing to do) |
| `sk` | 6 | High | Next |
| `nl` | 14 | Needs a decision first | Next |
| `pl` | 46 | Needs a decision first; watch `MARZNĄĆ`-class false splits (mar-znąć, not ma-rz-nąć) | Later |
| `hu` | 57 | High, but watch `KÖZSÉGHÁZA`-class boundaries (község-háza, not …ö-zs-é…) | Later |
| `vi` | 105 | High volume; `NGH` must win over `NG`, and syllable-final `NG`/`NH`/`CH` are genuine units | Later |
| `es` `de` `fr` `it` `pt` | 0 | Decided no in A.3 | — |

**Iteration 1 needs exactly 8 words marked.** That is the whole content cost of shipping the mechanism. The remaining 236 rows can land language by language, each as its own reviewable commit, and each is a correctness fix that stands alone regardless of whether Studio voice ever ships for that language.

A useful property of minimal marking: an unmarked corpus behaves exactly as it does today. There is no flag day, no migration, and a half-reviewed language is not broken — it is merely as wrong as it currently is.

---

## Part C — Speech data model

### C.1 Semantic keys

Gameplay never names a file. It names a key:

```
learning.number.001 … learning.number.050
learning.char.<letter_id>          e.g. learning.char.ch, learning.char.z
```

Namespaced for later expansion: `learning.word.<word_id>.full`, `ui.help.<key>`. Reserved now, unused.

Files are content-addressed — `clips/7f/7f47f13c9f2a.mp3`, never `clips/CH.mp3` — which avoids case-insensitive filesystem collisions (`a.mp3` vs `A.mp3`) and non-ASCII filenames on Android.

Letter IDs are stable ASCII slugs declared alongside the spoken text. **Both files now exist**: `data/speech/letters_cs.json` (42 letters) and `data/speech/letters_en.json` (26).

```json
{ "id": "ch",      "display": "CH", "spoken": "chá", "multigraph": true },
{ "id": "u_ring",  "display": "Ů",  "spoken": "ů s kroužkem" },
{ "id": "y_acute", "display": "Ý",  "spoken": "dlouhé ypsilon" }
```

`spoken` is separate from `display` because `Ý` cannot be sent to a TTS API as a bare glyph and be expected to come back as "dlouhé ypsilon" (parent analysis §3.2). English uses pronunciation respellings for the same reason — a lone `A` may be read as the article, and `G` as "gee" rather than "jee".

Each file also carries the marked `alphabet_string` it corresponds to, so `verify` can assert that `game_config.gd`'s alphabet and the speech catalog describe the same 42 letters in the same order. That check passes today: the Czech string parses to exactly the 42 `display` values.

These files are **pipeline input**, not runtime data — the game only ever reads the generated manifest.

### C.2 Source files (checked in)

```
data/speech/
  catalog.json          # what to generate: number range, letter sources, priorities
  letters_cs.json       # id / display / spoken
  letters_en.json
  voice_profiles.json   # per-locale voice id, model id, settings. NO API KEY
  pronunciations/       # spoken-text and IPA overrides
```

`voice_profiles.json`:

```json
{
  "en-US": {
    "provider": "elevenlabs",
    "voice_id": "…",
    "model_id": "eleven_multilingual_v2",
    "language_code": null,
    "settings": {"stability": 0.5, "similarity_boost": 0.75, "speed": 0.9},
    "output_format": "pcm_22050"
  }
}
```

`language_code` is `null` for Multilingual v2, which does not accept it (parent analysis §4.2).

### C.3 Build outputs (git-ignored)

```
build/speech/           # desired.jsonl, plan.json, review.csv, reports/
voice_masters/          # raw/ processed/ generation_ledger.jsonl
```

`voice_masters/` needs **both** a `.gdignore` (so Godot's importer skips it, as `_unused_assets/` already does) and a `.gitignore` entry.

### C.4 Shipped runtime packs

```
res://voices/<lang>/manifest.json
res://voices/<lang>/clips/7f/7f47f13c9f2a.mp3
```

```json
{
  "schema_version": 1, "pack_version": 1,
  "lang": "cs", "locale": "cs-CZ", "voice_profile": "cs-CZ@1",
  "coverage": {"number": "complete", "char": "complete", "word": "none"},
  "counts": {"number": 50, "char": 42},
  "items": {
    "learning.char.ch": {
      "asset": "clips/7f/7f47f13c9f2a.mp3",
      "duration_ms": 610, "sha256": "…",
      "display_text": "CH", "spoken_text": "chá"
    }
  }
}
```

Only `review_status == "approved"` records reach a shipped manifest. `coverage` is per-category, not boolean, so partial rollout stays honest and the settings screen can read it directly.

---

## Part D — Build pipeline (`tools/speech/`)

Consistent with the existing `tools/` folder of Python utilities.

```
extract → plan → generate → process → verify → pack
```

**Only `generate` touches the network or spends credits.** Everything else is safe in CI.

| Command | Does | Network |
|---|---|---|
| `extract` | Reads `catalog.json` + `letters_*.json`. Validates language sets against `SUPPORTED_LANGS`, `project.godot` translations and word filenames. Emits sorted `desired.jsonl` | No |
| `plan` | Diffs desired vs ledger vs clips vs manifests. Emits missing / stale / orphaned / unreviewed, plus character count and USD estimate | No |
| `generate` | Synthesises only selected missing/stale records. `ELEVENLABS_API_KEY` from env | **Yes** |
| `process` | ffmpeg: trim, fade, normalise, encode mono MP3 22.05 kHz 32 kbps, measure | No |
| `verify` | CI gate — see D.2 | No |
| `pack` | Writes `res://voices/<lang>/` from approved records | No |

Filters: `--language`, `--category`, `--priority`, `--max-characters`, `--dry-run`.

**Generation spec hash.** Every record carries `SHA-256(canonical_json(spec))` over normalised `spoken_text`, locale, provider, model id, voice id, API `language_code`, voice settings, seed, pronunciation dictionary versions, master format, and processing version. Change any of them and the asset becomes `stale`; nothing regenerates implicitly and an approved asset is never overwritten in place.

**Generator safety.** API key from environment only; the tool refuses to run if a key appears in any repo file. One clip per request. Bounded concurrency from config, backoff with jitter on 429/5xx. Write temp → validate decodable and non-silent → atomic rename → *then* append to the ledger. `--max-characters` guard defaults low and aborts rather than silently spending.

### D.2 `verify` fails the build if

- a language declared `coverage: complete` is missing keys;
- a manifest references a missing file or a hash mismatch;
- a clip is stereo, wrong rate/codec, silent, clipped, or outside duration bounds;
- a manifest contains a non-approved record;
- any word file has malformed brackets (A.8);
- **a new direct `TTS.speak()` call exists outside `tts_manager.gd`, `speech_manager.gd` and tests.**

---

## Part E — Godot runtime

### E.1 `SpeechManager` autoload

New `scripts/speech_manager.gd`, registered as `Speech` **after** `TTS` and `Config` in `project.godot` autoload order.

`tts_manager.gd` does not change at all in iteration 1 — its interrupt semantics, threading and voice scanning are all still needed for the fallback path. It simply becomes a backend.

```gdscript
func speak_key(key: String, lang: String, fallback_text: String, opts: Dictionary = {}) -> void
func speak_number(value: int, lang: String) -> void
func speak_grapheme(display: String, lang: String) -> void
func speak_segments(segments: Array[Dictionary]) -> void
func stop() -> void
func has_clip(key: String, lang: String) -> bool
func coverage(lang: String) -> Dictionary
```

Resolution in `STUDIO_PREFERRED`:

```
approved clip for (key, lang) in the loaded manifest
  → TTS.speak(fallback_text, rate, lang)      # existing behaviour, unchanged
    → silence
```

`DEVICE_TTS` goes straight to `TTS.speak()`. `OFF` returns immediately. **The maze never waits on speech** — `speak_key` returns immediately in all paths.

Note `speak_grapheme` takes the display string (`"CH"`), which `SpeechManager` maps to `learning.char.ch` via the manifest. Call sites stay ignorant of letter IDs.

### E.2 Manifest loading and playback

- Load only the selected learning language's manifest, lazily and on language change. ~76 items in iteration 1 — one negligible JSON parse.
- Clips are **not** preloaded. `AudioStreamMP3.load_from_file()` on demand, with a 16-entry LRU.
- Prefetch the next expected collectible when the target highlight updates — the next item is always known in advance, which is the whole latency story.
- Missing or corrupt manifest → warn, degrade to `DEVICE_TTS`. Never crash, never block boot.

`project.godot` currently has **no `[audio]` section and no bus layout**. Add `default_bus_layout.tres` with `Master` + a `Voice` child bus. `SpeechManager` owns one `AudioStreamPlayer` on `Voice`, `max_polyphony = 1`, `process_mode = PROCESS_MODE_ALWAYS`. A new hint stops and replaces the previous one — latest wins, matching `tts_manager.gd`'s existing versioning.

### E.3 Settings model and migration

`game_config.gd:266` `var voice_hints: bool = true` becomes:

```gdscript
enum VoiceMode { OFF, DEVICE_TTS, STUDIO_PREFERRED }
var voice_mode: int = VoiceMode.DEVICE_TTS
```

Migration in `load_settings()`, alongside the existing `_voice_hints_build_67_reset` migration:

| Stored | New |
|---|---|
| `voice_mode` present | use it |
| `voice_hints = false` | `OFF` |
| `voice_hints = true` | `DEVICE_TTS` |
| fresh install | `DEVICE_TTS` |

No existing installation changes behaviour; Studio voice is opt-in. Keep `voice_hints` as a computed read-only property for one release so nothing silently breaks, then delete it and let `verify` keep it deleted.

### E.4 Settings UI

`settings_menu.gd:293-324` currently disables the voice button unless **both** UI and learning languages have an installed OS voice. That rule is wrong once Studio voice exists — Studio Czech should work on a device with no Czech OS voice, which is exactly the device where it matters most.

New voice row, using the existing `CyclingSelector` pattern (`coding_rules.md` §2) rather than a toggle:

| Option | Key | Shown when |
|---|---|---|
| Off | `voice_off` | always |
| Device voice | `voice_device` | always; greyed with the existing `tts_missing` warning when no OS voice |
| Studio voice | `voice_studio` | when the learning language pack has `coverage.number == "complete"` |

Availability is reported separately — Studio coverage for the learning language, device TTS for the learning language, device TTS for the UI language. Only the last two gate `Device voice`; neither gates `Studio voice`.

New translation keys: `voice_off`, `voice_device`, `voice_studio`, `voice_studio_partial`. Per `DEVELOPMENT.md` §7 the compiled `.translation` binaries must be reimported and committed alongside the CSV.

Also suppress the spoken app-title warm-up (`tts_manager.gd:193-197`) when Studio coverage is complete; keep the silent warm-up, since the fallback path may still fire.

### E.5 Call sites to migrate

| File:line | Now | Becomes |
|---|---|---|
| `game_manager.gd:332` | `TTS.speak(value_str, 0.85, lang)` | `Speech.speak_grapheme(value_str, lang)` |
| `game_manager.gd:343` | `TTS.speak(value_str, 0.85)` | `speak_number` / `speak_grapheme` by mode |
| `game_manager.gd:939, 960` | word / prefix | `Speech.speak_key("learning.word.…", …)` — no clip yet, falls back automatically |
| `multiplayer_game_manager.gd:645, 648, 949, 1827` | same shapes | same |
| `help_menu.gd:252` | help body | `Speech.speak_key("ui.help.…", …)` — always falls back |
| `win_screen.gd:370` | `TTS.speak_segments()` | `Speech.speak_segments()` — passes through |
| `settings_menu.gd:205, 210` | `TTS.warm_up()` | `Speech.warm_up()` |

Every call site migrates in iteration 1 even where no clip exists, so the broker is the only path from day one and the `verify` grep gate can be switched on immediately.

---

## Part F — Implementation plan

Content and code commit separately per `DEVELOPMENT.md` §7.

### Phase 1 — Grapheme marking (no audio, no network) — ✅ IMPLEMENTED

1. `scripts/grapheme_text.gd` — `split()`, `strip()`, `validate()`.
2. `word_list.gd:65-68` — resolve markers at load (A.6, site 1).
3. `game_config.gd:690` — per-language alphabet strings in the same syntax; `get_alphabet_length()`; drop the `% 26` wrap (A.6, site 2). Add the full 42-letter Czech alphabet.
4. `collectible_spawner.gd` + `multiplayer_game_manager.gd` — grapheme-based spawning; `max_items` from alphabet length.
5. Mark the 8 Czech words (Part B).
6. Extend the validation snippet in `CLAUDE.md` / `DEVELOPMENT.md` §4 (A.8). While there, fix `data/words/README.md`, which still says difficulty 0–4 although the runtime uses 0–6.

**Exit:** Czech letter mode spawns 42 letters including `CH`; `MOUCHA` spawns 5 pickups showing `M O U CH A`; Greek stops repeating `Ω`; Ukrainian reaches all 33 letters; every other language is byte-identical to today.

**This ships alone**, as a correctness release, before any audio exists.

Two things surfaced during implementation that were not in the plan:

- **`learning_recap.gd:248`** named the alphabet boundary using the *UI* language whenever it shared a script family with the learning language. With Czech now at 42 letters and English at 26, a Czech game with an English UI would index past the end of the Latin alphabet. It previously wrapped to a wrong letter; it would now return `""`. Fixed by requiring the UI alphabet to be long enough, otherwise falling back to the letters actually collected.
- **Separators and prefix speech.** Making apostrophe and hyphen non-collectible also made them trigger the mid-word prefix narration, so `TISZA-TÓ` announced "TISZA-" and `L'ARBRE` announced "L'". Added `CollectibleSpawner.has_word_boundary_between()` so only a real space triggers it.

Also noted, not changed: `game_hud.gd` `update_word_display()` and `light_up_letter()` are compatibility bridges with **no callers** — `_word_container` is permanently hidden and the `CollectibleTracker` superseded them. They render correctly regardless (the word they receive is already stripped), but `light_up_letter()` takes a character index and would be wrong if revived. Candidate for deletion under `coding_rules.md` §9.

### Phase 2 — Pipeline, dry-run only

`catalog.json`, `letters_{cs,en}.json`, `voice_profiles.json`; `speech_pipeline.py` with `extract`, `plan`, `verify`; `.gdignore` + `.gitignore` for `voice_masters/`. Run `plan --dry-run` across all 21 languages for a real cost figure and to surface language-set mismatches before spending anything.

**Exit:** a correct ~168-record `desired.jsonl` for `cs`+`en`, zero network calls.

### Phase 3 — A/B sample and voice selection

Generate a small sample per language: 10 numbers including teens and tens; every Czech multigraph and diacritic (`CH`, `Ř`, `Ě`, `Ů`, `Ž`); English confusables (`M`/`N`, `E`/`I`, `Z`). A/B Multilingual v2 against v3 for Czech — `Ř` and the letter name `chá` are the stress test. A/B 22.05 kHz/32 kbps against 44.1 kHz/64 kbps on a TV before committing the catalog to a bitrate.

**Exit:** native `cs` and `en-US` reviewers approve a voice + model + settings profile; codec test passes on the oldest target TV.

### Phase 4 — Full generation and packs

`generate` + `process` for ~168 records. Native review of **every** clip, with a second focused review of the number set and the alphabet set — a systematic error there is heard in every session. `pack` → `res://voices/{en,cs}/`. Measure the AAB delta.

### Phase 5 — Runtime integration

`default_bus_layout.tres`; `speech_manager.gd` + autoload; `VoiceMode` enum + migration + compatibility shim; migrate all call sites (E.5); three-way settings selector + translation keys + `.translation` reimport; enable the `verify` grep gate.

**Exit:** Czech and English gameplay speaks pre-generated numbers and letters fully offline with no OS voice installed; all other languages behave exactly as before.

### Phase 6 — Measure and decide

AAB delta, installed-size delta, pickup-to-audible latency on the oldest target device, peak memory during rapid pickups. That report drives the "all 21 languages, and words?" decision.

### Parallel track — remaining corpus review

`sk` (6) and `nl` (14) next, then `pl` (46), `hu` (57), `vi` (105). Independent of the audio phases; each is a standalone correctness fix.

---

## Part G — Test plan

Per `DEVELOPMENT.md` §8 and the parent analysis §11.3:

- Czech letter mode on a device with **no Czech OS voice installed** — the headline case.
- Fully offline, airplane mode.
- UI language ≠ learning language (English UI, Czech learning).
- Czech word mode on the 5×4 tier-0 grid with a `[CH]` word.
- An unmarked corpus word — must behave exactly as before.
- A deliberately malformed marking (`MOU[CHA`) — validation must catch it at build time, and the runtime must degrade rather than crash.
- Rapid consecutive pickups — latest-wins, no backlog.
- Mid-session learning-language change.
- Learning language with no pack (e.g. `de`) — silent fallback to TTS.
- Corrupted manifest in a dev build — degrade, not crash.
- App pause/resume and scene change during playback.
- Oldest supported Chromecast/Google TV, low-end phone, current phone.
- D-pad only on the new settings selector, at 720p and 1080p.
- Existing installs with `voice_hints` true and false both migrate correctly.

---

## Part H — Open decisions

**Resolved.** The Czech alphabet is settled at **42 letters including `Q`, `W`, `X`** (*kvé*, *dvojité vé*, *iks*) and `[CH]`. Letter names are recorded in `data/speech/letters_cs.json`: *dlouhé á*, *dlouhé í*, *ypsilon*, *dlouhé ypsilon*, *ú s čárkou*, *ů s kroužkem*, *e s háčkem*, and the traditional mixed háček set (`čé`/`ďé`/`ťé` but `eň`/`eř`/`eš`/`žet`). Short vowels are named plainly (`í`, `ú`), consistent with *ypsilon* rather than *tvrdé y*. English is in `data/speech/letters_en.json`, en-US, `Z` = *zee*.

Blocking Phase 3:

1. **Named native reviewers** for `cs` and `en-US`.

Blocking Phase 5:

4. **Does the settings selector say "AI-generated"?** The store listing and privacy material will regardless; the question is only the in-app parent-facing label.
5. **Studio voice default for fresh installs** after QA, or opt-in forever?

Parallel track:

6. **Dutch `IJ`** — mark or not?
7. **Polish *dwuznaki*** — mark or not? Sound units, but not alphabet letters.
8. Acceptable AAB and installed-size increase for all 21 languages.
9. Solo accumulated-prefix speech (`game_manager.gd:942-961`): keep, change to the just-completed lexical word, or remove?

---

## Part I — Risk register

| Risk | Mitigation |
|---|---|
| A word is marked wrong, or a new word is added unmarked | Same class of risk as the existing emoji-word mismatch, and handled the same way: native review, and cross-checking a word against its cognates in other languages. An unmarked word is only as wrong as today |
| Wrong Czech letter names baked into 42 clips | Native teacher review **before** Phase 4; number and alphabet sets get a second focused review |
| Malformed brackets reach a build | `validate()` in the pre-commit word-list check and in `verify` |
| `[` or `]` collides with real content | Verified zero occurrences across all 3,652 entries; validation would catch a future one |
| Vietnamese review (105 words) stalls the programme | Decoupled — `vi` marking is independent of `cs`/`en` audio and of every other language |
| ElevenLabs voice withdrawn from the Voice Library | Prefer an owned Voice Design voice or a perpetual default; ledger records voice + model + settings so a re-record is reproducible |
| AAB accidentally ships `voice_masters/` | `.gdignore` + `.gitignore`, plus a `verify` assertion on export contents |
| Playback latency worse than TTS on old TVs | Prefetch the next collectible; trim encoder leading silence; measure in Phase 6 before scaling |
| Feature drifts back to direct `TTS.speak()` calls | `verify` grep gate enabled in Phase 5 |
