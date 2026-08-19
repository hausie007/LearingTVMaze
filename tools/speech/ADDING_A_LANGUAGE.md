# Adding a language — what a new session needs to know

Read `CLAUDE.md` and `PROJECT_STATE.md` first. This file is only about
recorded speech.

## The one command

```bash
python3 tools/speech/speech_pipeline.py next <lang>                    # where it stands
python3 tools/speech/speech_pipeline.py next <lang> --go --budget 2.00 # do it
```

`next` works out the order, runs every step that is free and reversible, and
stops at the two that are not: spending money, and listening. It enables a
declared-but-disabled language itself. Nothing else in the tool needs to be
invoked by hand except `retake` and `review --import`.

Cost is about 25–40 cents per language: ~25c synthesis, ~3c audit, ~1c
boundaries. `--budget` is a hard cap, not a prompt.

## State, August 2026

| Language | Where it is |
|---|---|
| `cs` `en` `de` `sk` `pl` `es` | Complete: recorded, approved, packed, playing |
| `pt` | 306 of 307 approved |
| `tr` | One clip retaken (`ile`), otherwise done |
| `vi` | Drafted, needs a voice |
| `it` `nl` `ro` `uk` `el` `hu` `sv` `da` `nb` `fi` `he` | Letter names, numbers, digraphs and voice profiles drafted; need a voice, and a native-speaker review |

Every drafted language carries a `DRAFT` marker in `letters_*.json` and
`numbers_*.json` that must be cleared by a speaker before recording. Use
`tools/speech/REVIEW_PROMPT.md`, one language per conversation.

Word lists exist for every enabled language. A brand-new language would need
~150–290 words with emoji across seven tiers, which is the largest single piece
of work and is not drafted for anything.

## What a language needs before recording

1. A voice_id in `data/speech/voice_profiles.json` — `voices --language <lang>`
   lists candidates and costs nothing. **Set `settings.speed` to 0.7.** The
   default 0.9 made the Portuguese voice read thirteen letter names in 5.68
   seconds, too fast to cut and too fast for a child, and every clip had to be
   re-recorded.
2. Letter names and number words reviewed by a speaker.
3. An entry in `data/number_forms.json` if the language inflects a number after
   "to" — `uk` `el` `fi` `hu` `tr` do; Germanic and Romance ones do not. Not
   blocking: only the finish recap uses it.
4. Carrier words in the profile (`categories.ui` and `retake_carriers`), which
   must be real words of that language.

`ALPHABETS` and `WORD_ONLY_LETTERS` in `scripts/game_config.gd` decide what the
Letters lesson spawns. They are generated from the letter files for the newer
languages; check them for any language you add.

## Failure modes, all of which have already happened

**A wrong clip is either a cutting fault or a text fault, and they need
opposite fixes.** Decide which before acting. The master's duration tells you:
0.13s for a whole word means the cut, not the reading.

- **A short item beginning with a vowel merges into the carrier before it**, so
  the cut lands a segment late and the clip contains its neighbour. Turkish
  `ile` returned `teşekkürler`; Portuguese `oito` returned `t`. Fix: a follower
  and **no leader**. This is the single most common failure.
- **A reading alone ends on an intake of breath**, which the trim cannot remove
  because a breath is well above the silence threshold. Fix: a follower, which
  gives the breath somewhere to go.
- **Short function words cannot be cut from a sheet** — the gaps between items
  are no larger than the gaps inside them. The `ui` category is therefore
  `synthesis_mode: single` in `catalog.json`, for every language. German shipped
  without it once and every clip held the next one's words.
- **A voice that paces erratically** cannot be cut at all. Measure before
  theorising: compare sheet duration and total silence against a language that
  works. Czech takes ~22s over fourteen letters.
- **`sheet.preamble` is not supported** and now raises. The cutter is never told
  about it, so every cut lands one item late.
- **Twelve takes is the limit for one clip.** Slovak `há` failed eleven times
  across sheet, single, single-with-carriers and IPA before the answer turned
  out to be reading it between its own alphabet neighbours: `ef gé [há] í jé`.
  Past that, the voice is the problem, not the request.

## Reviewing

`audit --confirm` force-aligns every clip against the words it should say and
flags the ones that do not fit, for about 3c a language. It runs inside `next`.
Flagged clips arrive at the top of the review page already marked rejected. It
catches wrong words, never a wrong accent, so it flags and never approves.

```
build/speech/listen/<locale>/index.html    every clip
build/speech/phrases/<locale>/index.html   each stage of a multi-word phrase
```

Space plays, `a` approves, `r` rejects. Download the CSV from the page, then
`review --import <file>`. A rejected clip is picked up by `next` automatically
and queued for a fresh take.

## Things not to break

- Never rename a theme folder. Never remove the privacy policy link. Every
  user-visible string goes through `tr()` with a key in `data/translations.csv`
  — 21 languages, all of which need the new string.
- `verify` is the CI gate. Run it before every commit.
- Approvals bind to the recording (`spec_hash`), not the encoding
  (`render_hash`), so changing anything in `processing` re-encodes for free and
  keeps every verdict. Changing text, voice or synthesis settings does not.
- `prune --confirm` clears dead encodings. Do not pass `--masters` — those were
  paid for, and only a handful are genuinely orphaned.
