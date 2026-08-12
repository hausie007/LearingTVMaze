# Studio Voice pipeline

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
| `process` | Trims, levels, encodes to shipping MP3 | no |
| `listen` | Named copies of the clips + a page to review them in | no |
| `review` | Exports a review sheet, then imports the verdicts | no |
| `pack` | Writes `res://voices/<lang>/` from approved clips only | no |
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

**`sheet`** asks for the whole alphabet in one breath and cuts it up afterwards,
using the character alignment the API returns. One performance, one register,
one language decision. The cut is a byte offset into raw PCM at the timestamp
the API reported, so nothing is re-encoded and no boundary is guessed.

```json
"synthesis_mode": "sheet",
"sheet": {
  "separator": ". ",
  "preamble": "",
  "guard_lead_ms": 40,
  "guard_tail_ms": 90,
  "max_items_per_sheet": 16
}
```

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

## Adding a language

1. Write `letters_<lang>.json` and `numbers_<lang>.json` — a native speaker
   decides the letter names, not a transliteration.
2. If its alphabet is not plain A–Z, add it to `ALPHABETS` in `game_config.gd`
   using the same `[…]` syntax. `verify` will tell you if the two disagree.
3. Set `enabled: true` for it in `catalog.json` and add a profile for its locale
   in `voice_profiles.json`.
4. `extract`, then `plan`. Nothing is spent until `generate --confirm`.
