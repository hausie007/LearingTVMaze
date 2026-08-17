# Studio Voice pipeline

## Start here

One command, one language. It works out the order, does everything that is
free and reversible, and stops at the two things that are not — spending money
and listening:

```bash
python3 tools/speech/speech_pipeline.py next en
```

Run it, do what it says, run it again. Repeat until it says the language is
done. You never need to know the other verbs; they are what `next` calls, and
they are documented below for when something goes wrong.

The two stops:

- **money** — `generate` records new clips, `align` finds word boundaries in
  ones already recorded. Both print the cost and both need `--confirm`.
- **ears** — nothing is packed until you have listened. `next` builds the pages
  and tells you which file to mark up.

Listening pages, both rebuilt each run:

| Page | What it is for |
|---|---|
| `build/speech/listen_<locale>/index.html` | every clip, to approve or reject |
| `build/speech/phrases_<locale>/index.html` | each stage of a multi-word phrase, to check the boundaries fall between words |

Both are per locale, so looking at German does not wipe Czech.

Generates the pre-recorded speech the game plays instead of device TTS, offline,
ahead of time. New to this? Read `SETUP.md` first — account, key and choosing a
voice. The design and its rationale are in
`_ideas_/studio_voice_iteration_1_design.md`.

```
extract → plan → generate → process → review → pack → verify
```

**Only `generate` spends money, and only with `--confirm`.** Everything else is
offline, free and safe to run in CI as often as you like. The whole pipeline is
idempotent: re-running it does the work that is missing and nothing else.

## Requirements

Python 3.8+ and, for `process` only, ffmpeg (`brew install ffmpeg`). No
third-party Python packages — deliberately, so this still runs on a clean
machine years from now.

```bash
python3 tools/speech/speech_pipeline.py doctor
```

## The commands

| Command | Does | Network |
|---|---|---|
| `doctor` | Checks tools, sources, profiles and the export guards | no |
| `extract` | Enumerates every clip the catalog wants → `build/speech/desired.jsonl` | no |
| `plan` | Diffs wanted against what exists; reports cost | no |
| `voices` | Lists account and library voices with their IDs | yes, free |
| `generate` | Synthesises missing clips | **yes, billed** |
| `recut` | Re-derives masters from stored sheets with the current guards | no |
| `process` | Trims, levels, encodes to shipping MP3 | no |
| `listen` | Named copies of the clips + a page to review them in | no |
| `review` | Exports a review sheet, then imports the verdicts | no |
| `retake` | Stages named clips to be recorded again, alone | no |
| `pack` | Writes `res://voices/<lang>/` from approved clips only | no |
| `status` | Regenerates `LANGUAGE_STATUS.md` from the repository | no |
| `verify` | The CI gate — run before every commit | no |

Filters on most commands: `--language cs`, `--category char`, `--key
learning.char.ch`, `--limit`, all repeatable.

## A first run

```bash
python3 tools/speech/speech_pipeline.py extract
python3 tools/speech/speech_pipeline.py plan --language cs
# fill in voice_id in data/speech/voice_profiles.json — see SETUP.md
python3 tools/speech/speech_pipeline.py generate --language cs --limit 12   # dry run
python3 tools/speech/speech_pipeline.py generate --language cs --limit 12 --confirm
python3 tools/speech/speech_pipeline.py process --language cs
python3 tools/speech/speech_pipeline.py listen --language cs
open build/speech/listen_cs-CZ/index.html      # decide, then download the CSV
python3 tools/speech/speech_pipeline.py review --import ~/Downloads/review_cs-CZ.csv
python3 tools/speech/speech_pipeline.py pack --language cs
python3 tools/speech/speech_pipeline.py verify
```

`generate` without `--confirm` is always a dry run that prints the clips, the
character count and the estimated cost. Get into the habit of running it that
way first.

## Single clips, or a recording sheet

`synthesis_mode` in each profile decides how a locale is recorded.

**`single`** sends one request per clip. Simple, and wrong for this content. A
letter name is two or three characters, which is no context at all: the model
re-invents the delivery every time, the language detector guesses per request,
and an isolated vowel comes out emotive. The first Czech review rejected eleven
of twelve clips this way — *chá* read as French, letters that sounded like
different speakers, long vowels delivered short.

**`sheet`** asks for the whole alphabet in one breath and cuts it up afterwards.
One performance, one register, one language decision. The cut is a byte offset
into raw PCM, so nothing is decoded and nothing is re-encoded.

```json
"synthesis_mode": "sheet",
"sheet": {
  "separator": ". ",
  "preamble": "",
  "guard_lead_ms": 30,
  "guard_tail_ms": 120,
  "min_gap_ms": 180,
  "min_sound_ms": 60,
  "max_items_per_sheet": 16,
  "cutter_version": 2
}
```

### The cut is decided by the waveform, not by the alignment

The API returns a character alignment, which is enough to *locate* an item and
not enough to *bound* it. Two review rounds established this the hard way. The
reported end time lands before the sound finishes — every clip rejected as
"cropped at the end" still had its last 30 ms at -13 to -17 dBFS, against about
-40 for approved ones. And because the reported end is early, using it to bound
the *next* item's search window opened that window inside the previous word:
hence "too long pause at the beginning", sometimes with a fragment of the letter
before it.

So the sheet is segmented as a whole, at real silence, and the segments are
matched to items in order. The one threshold that has to be right is how much
silence separates two items rather than sitting inside one — and since the
number of items on the sheet is known exactly, that is not guessed. The cutter
sweeps both the silence threshold and the loudness floor, keeps every
combination that yields exactly the expected count, and takes the middle of the
widest working range.

If no combination works, it falls back to cutting at the quietest point between
each pair of items, using alignment only to say roughly where that gap is —
locating a *gap* being far easier than locating a sound. That path cannot hand
the same audio to two items, which the earlier nearest-segment matching could.
Either way the segments are asserted to be ordered and disjoint before anything
is written.

### Re-cutting is free

The sheet audio and its alignment are stored under `voice_masters/sheets/`,
keyed by a hash of the *synthesis* inputs only — voice, model, settings, seed,
text. The guards are deliberately **not** in that hash.

That makes boundary tuning a local loop with no API call and no cost:

```bash
# edit guard_tail_ms in voice_profiles.json
python3 tools/speech/speech_pipeline.py recut --language cs
python3 tools/speech/speech_pipeline.py process --language cs
python3 tools/speech/speech_pipeline.py listen --language cs
```

`recut` never touches the network; if a sheet was never stored it says so and
skips rather than quietly re-recording.

Things worth knowing about sheet mode:

- **A sheet is recorded whole.** You cannot cut one letter out of a reading that
  never happened, so if any member of a group is missing the whole group is
  re-read. At 42 letters for under two cents this is not a problem worth
  optimising.
- **Sheets are chunked to about 16 items**, in evenly sized pieces. Fifty
  numbers in one breath invites the model to trail off, and an uneven split
  would leave the last two letters of the alphabet as their own tiny, differently
  performed sheet.
- **`separator` is the first knob to try** if delivery sounds clipped or the
  intonation is wrong. `". "` gives each item a falling statement contour;
  `", "` gives a list contour, which is more even but rises.
- **The cut is verified before anything is saved.** If the returned alignment
  does not match the text that was sent, the pipeline refuses rather than
  slicing in the wrong place — you are still billed for the request, but you do
  not get 42 masters silently offset by one letter.

### When a sheet cannot be cut correctly

Sheet cutting assumes the pause between two items is longer than any pause
inside one. Usually true, and when it is not, no threshold can save you.

Czech sheet 7 is the worked example. Its gaps were cleanly bimodal — 0.87,
1.04, 0.64, 0.04, 0.99, 0.84, 0.02 … — except that one pause inside
*MÁM RÁD SVÉ RODIČE* ran to 0.59 s while *LETADLO* and *LETADÝLKO* sat only
0.63 s apart. Matching the item count was then only possible by merging those
two words and splitting the phrase to compensate: two errors that cancel in the
arithmetic while every cut between them is a word out of step. Counting cannot
tell a merge from a split.

The answer is not a cleverer parser. It is to stop asking a cutter to resolve an
ambiguous signal, and record those clips on their own instead:

```bash
python3 tools/speech/speech_pipeline.py retake --rejected --language cs
python3 tools/speech/speech_pipeline.py extract
python3 tools/speech/speech_pipeline.py generate --language cs --confirm
```

`retake` bumps a per-key counter in `data/speech/retakes.json`. The counter
enters the spec hash **only for the keys named**, so the clip is re-recorded and
every other approval stands. A retaken clip is always one request on its own —
no sheet, no boundaries to find, and so no boundaries to get wrong.

`--rejected` stages everything currently marked rejected, carrying each
reviewer's note across as the reason.

The trade is the one sheets exist to avoid: a clip recorded alone has no
surrounding context, so its delivery can drift from the rest. For a whole word
that is a small risk. For a two-character letter name it is the original
problem, so prefer re-recording the sheet in that case.

### Pauses inside a clip

`max_internal_silence_ms` shortens silence that has sound on both sides. The
model asked for "ocean wave" left 1.35 s between the two words, which is a clip
that sounds finished while it is still playing. Only interior silence is
touched; the ends are the trimmer's job, and a clip with nothing to shorten
re-encodes byte-identically.

That last property is what makes the setting safe to change: re-encode
everything, then compare, and only the clips that actually moved need another
listen. Changing it on the Czech and English packs altered exactly two clips out
of 735.

### Encoded bytes are not the same as changed audio

MP3 files encoded on different machines differ in a handful of header bytes
while the audio is identical — a macOS LAME build and a Linux one disagree about
what to write there, not about the samples. Comparing file hashes after
re-processing elsewhere therefore reports every clip as changed.

Compare durations, or run the master through the processing chain and see
whether its length moves. `pack` records the hash of whatever it copies, so the
shipped manifest is always self-consistent regardless.

## Listening to what came back

Shipped clips are named by content hash — `clips/c8/c81f3a9b2e40.mp3` — so that
`a` and `A` cannot collide on a case-insensitive filesystem and no Android path
carries a non-ASCII character. Correct for the pack, useless for a person.

`listen` solves that. It writes a throwaway folder under `build/speech/` with
the clips copied out in alphabet order under readable names, plus an
`index.html` that plays them and records verdicts:

```bash
python3 tools/speech/speech_pipeline.py listen --language cs
open build/speech/listen_cs-CZ/index.html
```

The page shows what each clip is *supposed* to say — the glyph the child sees,
the generation text, the duration, and any flag `process` raised. Click a row to
hear it; <kbd>A</kbd> approves, <kbd>R</kbd> rejects and advances, <kbd>space</kbd>
replays. "Play all" runs the set back to back, which is how a level or accent
inconsistency actually reveals itself.

Decisions survive a page reload. When you are done, download the CSV and import
it. The folder is disposable — regenerate it whenever, nothing depends on it.

Listen on the television, not a laptop. A laptop speaker flatters these clips
and hides exactly the failure that matters: final consonants disappearing at
three metres.

## Files

Checked in — the inputs, and the record of what was approved:

```
data/speech/
  catalog.json          what to generate: languages, categories, formats, budgets
  letters_<lang>.json   ordered alphabet: id, display glyph, spoken name
  numbers_<lang>.json   1–50, written out in the language
  voice_profiles.json   voice, model and settings per locale — NEVER a key
  pronunciations/       per-locale corrections to the spoken text
  reviews/              who approved which take, and when
```

Not checked in — reproducible, large, or both:

```
build/speech/           desired.jsonl, plan.json, review sheets
voice_masters/raw/      the lossless masters from the provider
voice_masters/processed/  encoded clips awaiting review
voice_masters/generation_ledger.jsonl   append-only: every request ever made
```

Shipped:

```
voices/<lang>/manifest.json
voices/<lang>/clips/7f/7f47f13c9f2a.mp3
```

Both `build/` and `voice_masters/` carry a `.gdignore` so Godot never imports or
exports them, and `verify` fails if either goes missing. Masters must not reach
the AAB.

## How it decides what to regenerate

Every clip carries two hashes.

**`spec_hash`** covers everything that decides how the synthesised master
sounds: the spoken text, locale, model, voice, voice settings, seed,
pronunciation dictionaries and master format. Change any of them and the clip is
`missing` again and must be re-synthesised.

**`render_hash`** is `spec_hash` plus the processing chain and the shipped
codec. Change the bitrate or the loudness target and the clip is re-encoded from
the archived master — no network, no cost.

That split is the reason masters are kept: deciding in Phase 6 that 32 kbps is
too low costs nothing but CPU.

Review approval is bound to `spec_hash`, so it applies to the exact take that
was heard. Edit a letter name and its approval does not carry over to the new
recording. That is intentional and should not be worked around.

## What `verify` checks

- Language sets agree across `game_config.gd`, `project.godot`,
  `translations.csv`, the word filenames and `catalog.json`, and every language
  has all seven difficulty tiers.
- Every word file parses, has an emoji, and has valid `[…]` markers; near
  duplicates that differ only by markers are flagged.
- `letters_<lang>.json`'s `alphabet_string` matches `game_config.gd`'s alphabet
  exactly — same letters, same order. This is what keeps a clip attached to the
  right pickup.
- Numbers cover the declared range and are written out, not left as digits.
- No file in the repo contains anything key-shaped.
- `build/` and `voice_masters/` still have their `.gdignore`.
- Every shipped manifest points at files that exist and hash as recorded.
- With `--strict`: no gameplay code calls `TTS.speak()` directly. Leave this off
  until Phase 5 introduces `SpeechManager`; today it correctly reports the seven
  call sites still to migrate.

## Vocabulary words

The `word` category reads every `data/words/words_<lang>_*.json` tier and takes
**only the `word` field**. The emoji is a picture hint on screen and never
reaches a recording.

- Grapheme markers are stripped, so `MOU[CH]A` is recorded as *moucha*.
- Text is sent lowercase. An all-capitals word invites the model to spell it
  out letter by letter.
- Keys are ASCII slugs of the word — `learning.word.chobotnice`. Where two words
  fold to the same slug, which Czech `KOS` and `KOŠ` both do, a short digest of
  the word is appended rather than letting one silently win.
- A word appearing in two tiers is an error, not a duplicate clip.

Because keys derive from the text, correcting a word's spelling creates a new
key and orphans the old clip. That is the documented trade for not adding an id
field to the word files; `plan` reports the orphan.

Review words separately from letters — they are a different judgement, and 277
of them is its own sitting:

```bash
python3 tools/speech/speech_pipeline.py listen --language cs --category word
```

## Recording the menu and the recap framing later

The finish recap is one piece of narration built from two languages: an
introduction in the UI language, then the collected letters or numbers in the
learning language. Either may have a pack, both may, or neither.

`SpeechManager.speak_segments()` resolves each segment on its own and plays the
result as a queue, switching between recordings and the device voice
mid-sentence. So the mixed case already works today: a Czech child with an
English UI hears an English TTS introduction followed by recorded Czech
letters.

Recording the framing is therefore a data change, not a code change:

1. Give the segment a `key` where it is built — `learning_recap.gd` — such as
   `ui.recap.counted_to`.
2. Add a `ui` category to `catalog.json` with those keys and their text.
3. `extract`, `generate`, `review`, `pack`.

A segment with a `key` that has no recording still falls back to the device
voice, so the keys can be added before the audio exists.

Worth knowing before starting: recap framing is a sentence per phrasing per
language, and the phrasings are formatted with values inside them. Recording
"you counted to seven" as one clip does not scale; the framing has to be split
so the number stays a separate segment, which it already is.

## What goes in a recorded fragment

A recorded fragment has to be something a person would say as one unit, and a
substituted value has to be complete on its own. Getting this wrong is not
audible as a missing recording — it is audible as a stilted one.

Three rounds of the Czech recap established the rule:

- **A preposition cannot be a clip.** It leans on the following word. `v` +
  `angličtině` sounds stitched; `v angličtině` does not. The preposition
  belongs to the value, and the template goes without it.
- **A value must carry its own grammar.** Czech `do` demands the genitive, so
  splicing a citation-form number after it produces `do padesát`, which is
  simply wrong. Record `do padesáti` as one phrase.
- **In some languages there is nothing to separate.** Hungarian marks the same
  idea with a suffix — `ötvenig` — and Turkish with a suffix plus a
  postposition. No amount of care lets those be recorded as two clips.

So `data/number_forms.json` holds the phrase that fills a slot, not "the number
in some case", and a language either composes or does not:

```
cs   template "Napočítali jsme %s"     value "do padesáti"    50 clips
en   template "you counted to %s"      value "50"              0 clips
```

The two halves are one decision. A language that composes must drop the
preposition from its template; a language that does not must keep it. English
records none of these, which is the point — it needs none.

The same rule folded the preposition into `lang_in_*` for the 16 languages
whose recap templates share one, and left the other five alone because they
had nothing stranded to begin with.

## Where a language's letters are defined

In `scripts/game_config.gd`, once:

```gdscript
const ALPHABETS := {           # what LETTERS mode spawns
    "cs": "ABCČDĎEFGH[CH]IJKLMNŇOPQRŘSŠTŤUVWXYZŽ",
}
const WORD_ONLY_LETTERS := {   # only ever seen inside words
    "cs": "ÁÉĚÍÓÚŮÝ",
}
```

`letters_<lang>.json` does not repeat that list. It says how each letter is
pronounced and nothing else — id, display glyph, spoken name — and the pipeline
reads the letters themselves from `game_config.gd`. The game cannot read
`data/speech`, so the definition has to live on the game's side; keeping a
second copy here and asserting the two agreed was a copy that did not need to
exist.

`verify` therefore checks the two halves fit rather than that two lists match:
every letter the game uses has a pronunciation, and no pronunciation names a
letter the game does not use.

Czech is the case that motivated the split. It records 42 letters and spawns
34: the long vowels are wrong to ask a four-year-old to distinguish in an
alphabet lesson, and unavoidable inside words, where Á alone appears in 56 of
the 277 entries.

## Adding a language

1. Add it to `ALPHABETS` in `game_config.gd` using the `[…]` syntax, and to
   `WORD_ONLY_LETTERS` if its words contain letters the alphabet lesson should
   skip. A language absent from both spawns plain A–Z.
2. Write `letters_<lang>.json` and `numbers_<lang>.json` — a native speaker
   decides the letter names, not a transliteration. `verify` names any letter
   you missed.
3. Set `enabled: true` for it in `catalog.json` and add a profile for its locale
   in `voice_profiles.json`.
4. `extract`, then `plan`. Nothing is spent until `generate --confirm`.
