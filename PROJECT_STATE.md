# Project state — the ledger

**This file is the single source of truth for what is open.** Read it first in every session.
Update it last. If it disagrees with any other document in this repo, **this file wins** — several
of the older documents describe a state that no longer exists (see §5).

Last verified against the working tree: **2026-08-14** · version **1.2.0 build 79** · tree clean.

Verification method: git log, `export_presets.cfg`, `data/translations.csv`, direct inspection of
the sprite files, and `speech_pipeline.py status`. Anything not verifiable from the repo is marked
**needs Console** or **needs your eye** rather than assumed.

---

## 1. Blocking — this is the ship path

Nothing in the codebase blocks a release. Every remaining blocker is outside the repo.

| # | Item | Where | Notes |
|---|---|---|---|
| 1 | Confirm the privacy policy page is live, titled *"Learning Maze Privacy Policy"*, and serves the current `PRIVACY_POLICY.md` text | Google Sites | Page title was still *Domovská stránka*. This is the only ❓ in Part 5 of the compliance record |
| 2 | Paste the *What's new* release notes | Play Console | 31-locale block was produced; confirm it went in for build 79 |
| 3 | Enumerate which version code is active on production / open / closed / internal | Play Console | Never captured. Needed before any submission |
| 4 | Export the AAB and run the verification script | local | Expect permissions `INTERNET`/`VIBRATE`/`DUMP`, libs `libc++_shared.so`/`libgodot_android.so`, SDKs `NONE`. Script is in `GAME_MODIFICATION_SPEC.md` §8 |

**Estimated total: under an hour.** Three of the four are read-only Console checks.

---

## 2. Open, non-blocking

| Item | Status | Notes |
|---|---|---|
| **Compliance record has 4 stale ❓** | Record is out of date, not the app | The three IARC answers (fear/horror, crime/violence, user interaction) were resolved when the questionnaire was submitted and completed **2026-08-06** — all declared No, crude humour Yes at tier 2, all eight ratings unchanged. `COMPLIANCE_CHECKLIST.md` lines 88–90 still read ❓. Flip them to ✅ with the submission date as evidence |
| **Screenshot 3 breadcrumb** | Needs your eye | It read *"Follow the Trail • Scary • Very Large"*. The theme is now titled **Autumn Forest**, so a re-shoot fixes it. Cosmetic, not a policy gap |
| **`exclude_filter` is empty** | Confirmed open | Godot rewrote `export_presets.cfg` and dropped `exclude_filter="_unused_assets/*"`. Still `""` on lines 10 and 236. `.gdignore` is the primary guard and is intact, so nothing leaks — this is belt-and-braces only |
| **Speech coverage: 5 of 21 languages** | In progress | `cs` and `en` essentially complete; `sk`, `pl`, `de` have alphabet/digraphs only. Run `python3 tools/speech/speech_pipeline.py status` — never trust memory here, `LANGUAGE_STATUS.md` is generated |
| **Mid-phrase word prefixes** | Decision pending | Cumulative prefixes cost 65 (cs) + 80 (en) clips ≈ 14 cents, and cutting them from existing masters is free because the alignment timings are already stored in all 70 sheets. Open question is a **product** one, not a cost one: the accumulated readout ends on dangling conjunctions ("buď odvážný a…") and repeats the opening word up to four times. Leaning toward dropping the mid-phrase feature entirely |

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
- **IARC questionnaire** submitted and completed 2026-08-06, all ratings held.
- **Privacy policy** committed to `PRIVACY_POLICY.md`.
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
| `COMPLIANCE_CHECKLIST.md` | Accurate except the 4 stale ❓ in §2 above |
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
