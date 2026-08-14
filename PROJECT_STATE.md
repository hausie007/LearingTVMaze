# Project state — the ledger

**This file is the single source of truth for what is open.** Read it first in every session.
Update it last. If it disagrees with any other document in this repo, **this file wins** — several
of the older documents describe a state that no longer exists (see §5).

Last verified against the working tree: **2026-08-14** · version **1.2.0 build 79** · tree clean.

## 0. Release state

| Track | Build | Status |
|---|---|---|
| **Production** | **78** | **Live and accepted.** Theme changes and help-screen navigation. *What's new* submitted with it |
| Closed testing | 78 | |
| Internal testing | **79** | Pre-generated TTS work in progress |

**The compliance chapter is closed.** Build 76 was rejected on 25 July 2026; build 78 was accepted
and is live. Play Console shows **no outstanding errors and no open claims**. The privacy policy is
live on Google Sites in its current version and linked from both Console and the game.

The IARC questionnaire was resubmitted with **every answer left exactly as it stood** — including
crude humour Yes — and passed. No external determination was sought and none was needed. Do not
reopen it.

Verification method: git log, `export_presets.cfg`, `data/translations.csv`, direct inspection of
the sprite files, and `speech_pipeline.py status`. Anything not verifiable from the repo is marked
**needs Console** or **needs your eye** rather than assumed.

---

## 1. Blocking

**Nothing.** The app is live on production, Console is clean, and no compliance item is outstanding.

The current workstream is **pre-generated TTS**, riding on internal testing at build 79. With
shipping unblocked, this is the main line of work rather than a detour — the open questions are
in §2.

---

## 2. Open, non-blocking

| Item | Status | Notes |
|---|---|---|
| **Screenshot 3 breadcrumb** | Needs your eye | It read *"Follow the Trail • Scary • Very Large"*. The theme is now titled **Autumn Forest**, so a re-shoot fixes it. Cosmetic — the listing passed review as it stands |
| **`exclude_filter` is empty** | Confirmed open | Godot rewrote `export_presets.cfg` and dropped `exclude_filter="_unused_assets/*"`. Still `""` on lines 10 and 236. `.gdignore` is the primary guard and is intact, so nothing leaks — this is belt-and-braces only |
| **Speech coverage: 5 of 21 languages** | In progress | `cs` and `en` essentially complete; `sk`, `pl`, `de` have alphabet/digraphs only. Run `python3 tools/speech/speech_pipeline.py status` — never trust memory here, `LANGUAGE_STATUS.md` is generated |
| **Mid-phrase word prefixes** | Built, needs one command run | Kept, but no longer as separate clips: the full phrase is played and stopped at a word boundary, so THIS / THIS IS / THIS IS GOOD are three lengths of one reading instead of three readings. The 145 prefix clips are now orphans. **Next action: `python3 tools/speech/speech_pipeline.py align --confirm`, then `process --force --category word` and `pack`.** `align` sends the archived masters back for forced alignment — no synthesis, no clip changes, no approvals disturbed. The stored sheet alignment looked like a free source for the boundaries and is not usable: accurate at a sheet's ends, drifts over a second in the middle, so it would have cut inside words. Product concerns from the earlier note stand — dangling conjunctions, the opening word repeated — but they are now about *when* to narrate, not about audio |

---

## 3. Deferred with a decision already made — do not reopen

| Item | Decision |
|---|---|
| **Autumn Forest art relight** | Built, then **deliberately reverted** (`c365847`) — only the retitle was kept, to protect the existing promo video and screenshots. This was your call and it stands. Do not re-do the art without deciding about the video first |
| **Bathroom (`poop`) theme** | Stays. Opt-in, 1 of 9, ESRB still Everyone, ACB PG is not a disqualifier |
| **Target audience declaration** | Do not touch |
| **IARC questionnaire** | Do not touch. Correct as of 2026-08-06; resubmitting risks making it worse |
| **34 emoji mismatches** | Quality only, no policy bearing. Not worth a session |

---

## 4. Closed — verified done, listed so nobody redoes it

- **Castle player**: sword → **torch**. Friendly round eyes, smiling. Verified by inspecting the sprite.
- **Karkulka chaser**: bared teeth → **friendly grey wolf**, closed mouth, round eyes. Verified.
- **Thieves chaser**: baton → **whistle** (`a4a34d8`). Verified.
- **Theme retitles, all 21 locales**: `thiefs` → *Treasure Chase* · `scary` → *Autumn Forest* · `castle` → *Stone Castle* · `karkulka` → *Little Red*.
- **`themes/scary/pumpkin.png`** deleted (only `pumpkin3.png` remains).
- **Vocabulary**: 3,652 entries across 147 files, 21 languages. 28 fixes removed alcohol and weapon imagery.
- **IARC questionnaire** resubmitted 2026-08-06 with every answer unchanged, including crude humour Yes. All eight ratings held. No external determination sought or needed.
- **Privacy policy** committed to `PRIVACY_POLICY.md`, **published live** on Google Sites, and linked from Play Console and the in-app Settings screen.
- **Build 78 accepted and live on production**, after build 76 was rejected on 25 July 2026. *What's new* submitted with it. Play Console clear of errors and claims.
- **`COMPLIANCE_CHECKLIST.md` ❓ items** — all four resolved to ✅ on 2026-08-14.
- **All previously uncommitted work** (`export_presets.cfg`, `top_menu.gd`, `mode_card.gd`, 21 vocabulary files) is committed. Tree is clean.
- **Tracker reset bug** — HUD skipped `setup()` when the sequence hash matched, so the paging window stayed where the last maze left it. Fixed.
- **English menu TTS fallback** — leading-comma trim asymmetry between the catalog and `speech_manager.gd`. Fixed, plus two guards added.

---

## 5. Documents that are stale — read with care

There are **16 markdown files** in this repo and several describe work that is already finished.
That is the main reason a fresh session (or you, in three weeks) cannot tell what is live.

| File | Status |
|---|---|
| `GAME_MODIFICATION_SPEC.md` | **Largely executed.** Phase 1 done, Phase 2 done, Phase 3 deliberately reverted. Only Phase 4 (store listing) and part of Phase 5 remain. §2 "uncommitted work at handover" is obsolete — tree is clean |
| `themes_todo.md` | **Both MUST items are done** (castle sword, karkulka teeth). The resolution notes about `theme_loader.gd` slots are still valuable and now live in `DEVELOPMENT.md` |
| `COMPLIANCE_CHECKLIST.md` | **Current.** All four ❓ resolved to ✅ on 2026-08-14 |
| `game_specification.md`, `_v2`, `_v3` | Three versions side by side. Consider keeping v3 and archiving the rest |
| `LANGUAGE_STATUS.md` | **Generated** — regenerate, never edit |

---

## 6. How to run a session on this project

1. **Read this file first.** Then state the session's goal in one line and its exit condition.
2. **One goal per session.** Anything else discovered goes into §2 or §7 of this file, not into the current session.
3. **Update this file before you finish.** A session that changed something and didn't touch the ledger has left a trap.

---

## 7. Noticed — parked, not proposed

Append here rather than acting. Nothing in this section is a commitment.

- `add_translations.py`, `add_translations2.py`, `fix_button.py`, `fix_button2.py`, `fix_translations.py`, `patch_wizard.py` sit in the repo root — one-shot scripts, numbered duplicates. Candidates for `tools/` or deletion.
- `Bludiste.aab` and `Bludiste.apk` are committed build artefacts in the root.
