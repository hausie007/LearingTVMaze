# Learning Maze — developer guide

How to work on this game without breaking the two things that are hard to get back: a four-year-old's ability to play it, and a clean Google Play Families record.

**Code conventions live in [`coding_rules.md`](coding_rules.md).** This document covers everything else — who the game is for, how it works, what the content rules are, and what must never change.

---

## 1. Who this is for, and why it constrains everything

The primary player is a **four-year-old who cannot read**. Secondary is a 6–8 year old learning letters and words. The declared Play Console audience is **Ages 5 & under, Ages 6–8**, and Google treats "5 and under" as including children in most locales.

Three consequences that decide most design arguments:

- **Nothing may depend on reading.** Every concept must survive as picture, colour, sound or animation. Text is a bonus channel, never the only one.
- **Nothing may punish.** No timers, no lives, no score loss, no game-over, no progress reset. Failure states offer "Try Again" or "Easier".
- **Nothing may frighten.** Detailed in §5. This is a policy constraint as well as a design one.

The primary platform is **Android TV / Google TV with a D-pad**, not a phone. Touch is secondary. See `coding_rules.md` §4.

---

## 2. Game mechanics

### Core loop

The player steers a character through a maze from a start cell to an end cell. Optional collectibles are placed along the solution path and must be gathered in order. Each collected item is spoken aloud by the device's text-to-speech.

### Game modes — `Config.GameMode`

| Mode | Behaviour |
|---|---|
| `NORMAL` | Maze only, no collectibles |
| `NUMBERS` | Numbered collectibles, gathered in sequence |
| `LETTERS` | Alphabetical collectibles |
| `WORDS` | The letters of a word, gathered in order, spoken when complete |

### Play styles — `MissionCatalog`

`STYLE_PATH`, `STYLE_NEXT_SYMBOL`, `STYLE_RACE`. Roles are `ROLE_COLLECTOR`, `ROLE_CHASER`, `ROLE_RACER`. Never redeclare these strings — see `coding_rules.md` §1.

### Difficulty and grid size

Seven levels, `Config.DIFFICULTY_SIZES`:

```
0 Very Easy      5 × 4        4 Very Hard    20 × 12
1 Easy           7 × 6        5 Insane       26 × 13
2 Medium         9 × 8        6 Unbelievable 36 × 15
3 Hard          13 × 10
```

`Config.cell_size` is 120 px. Difficulty is also the word-difficulty tier — see §4.

### The chaser

Optional, off by default in effect (`ChaserLevel.OFF` … `TURBO`). It grants a head start computed by `MissionCatalog.calculate_head_start_steps()`, and deliberately runs slack. It can be driven by a second human player instead of the AI.

**The chaser must never feel like a threat.** Contact restarts the attempt; it does not harm, penalise or end anything.

### Maze generation

`maze_generator.gd` builds the solution path with a **randomised depth-first walk** from bottom-left to top-right, then fills remaining cells. The ordered solution path is `MazeData.main_path_coords`.

**This matters for content:** `collectible_spawner.gd` places one collectible per non-space character along that path. If a word has more letters than the path has usable cells, two letters land on the same cell. The 5×4 grid yields only **six usable cells in roughly 20% of generations**, which is why tier-0 words are capped at six letters. See §4.

---

## 3. Themes

Nine themes live in `themes/<name>/`, each with a `manifest.json`. One is active at a time; the Paper theme is the default on a fresh install.

### How assets resolve — follow `theme_loader.gd`, not the folder listing

This trips people up. Resolution order per slot:

1. `assets.<slot>` in `manifest.json`, else the naming-convention default (`player.png`, `chaser.png`, …)
2. Then the **top-level block** (`"player"`, `"chaser"`, `"collectible"`, `"background"`) — if it has a `frames` array, those files are what animate

The single texture and the frame list are **both used, by different screens**:

| Consumer | Uses |
|---|---|
| Chase gameplay (`chaser.gd`) | `chaser_frames` — the animator overrides the single texture |
| Race-mode robot (`game_manager.gd`) | `chaser_texture` — no animator |
| Help / tutorial portraits (`help_menu.gd`) | `chaser_texture` |
| Theme picker, character catalog | `chaser_frames` |

So a theme can ship a friendly animated chaser and still display something else in Race mode. **When auditing a theme, resolve both.**

Theme folders accumulate superseded art. Unreferenced files live in `_unused_assets/`, which carries a `.gdignore` so Godot's filesystem skips it entirely.

### Hard rules

**Never rename a theme folder.** `game_config.gd` persists the active theme as `dir_name`, `CharacterCatalog` prefixes character IDs with it, `player_controller.gd` keys the player's legibility outline off `"scary"`, and the multiplayer discovery payload carries it. Renaming breaks saved preferences and desyncs mismatched clients. **Retitle via `data/translations.csv` only** — the row `theme_<folder_name>`.

**Collectibles need a dark glyph panel.** The letter or number is drawn over the collectible in the colour set by `collectible.text-color`. A replacement sprite must keep a dark, roughly circular region for it. Test with a wide glyph (`W`) and a narrow one (`1`).

**Backgrounds must tile seamlessly** where `background.tiled` is true. Verify by measuring opposite-edge RMS difference, not by eye. Image generators cannot do this reliably; the repair is to offset by half the image with wrap, heal the seams that surface, and offset back.

### Colour separation

Every on-screen object needs its own hue band, because they overlap. Before choosing a colour for any sprite, check what the theme already uses — background, walls (`colors.wall`), player, collectible, trap. A chaser that shares the background's hue is invisible; one that shares the player's is confusing.

Targets, measured against the theme background: **hue separation > 100°**, or **luminance contrast > 1.8:1** if separating by brightness instead. Sprites render at roughly **40–60 px** on screen, so silhouette beats detail every time.

---

## 4. Vocabulary

`data/words/words_<lang>_<tier>.json`, **147 files, 21 languages, 7 tiers**. Each entry is `{"word": "...", "emoji": "..."}`.

`word_list.gd` uses a shuffle-bag per language+tier and avoids back-to-back repeats. Missing tiers fall back downwards, then to English.

### Tier = difficulty = word length

Tier index matches the difficulty level, and therefore the grid size. Word length must fit the grid:

| Tier | Typical length (letters, no spaces) | Hard cap |
|---|---|---|
| 0 | 2–4 | **6** — the 5×4 grid guarantees only 6 usable cells |
| 1–2 | 3–7 | comfortable |
| 3–4 | 6–12 | comfortable |
| 5–6 | 11–20 | comfortable |

**Spaces don't count** — `collectible_spawner.gd` skips them. Only tier 0 is genuinely tight; from tier 1 up the path is far longer than any word.

When changing a word, check it against its tier's existing distribution, not just the maximum. A word far above the tier median changes pacing even when it fits.

### Content rules

- **No weapons, alcohol, tobacco, drugs, violence, injury, gambling, sexual, romantic or religious imagery.** Currently zero across all 3,652 entries — keep it that way.
- Scary-adjacent imagery (spiders, bats, pumpkins) exists as ordinary picture-dictionary vocabulary and is acceptable, but do not add more.
- The emoji must match the word in every language. Cross-check a new entry against the same emoji in other languages — that is how genuine errors surface.

### Validation — run before every commit that touches word lists

```bash
cd data/words && python3 -c "
import json,glob
t=0
for f in sorted(glob.glob('words_*.json')):
    d=json.load(open(f,encoding='utf-8')); t+=len(d)
    for e in d: assert 'word' in e and 'emoji' in e and e['emoji'], (f,e)
print('OK', len(glob.glob('words_*.json')), 'files,', t, 'entries')"
```

Also check for duplicates within a language — the same word in two tiers is a bug.

---

## 5. Content and policy adherence

The app has **no ads, no analytics, no SDKs, no accounts, no network calls to any server, and two permissions**. That posture is the strongest asset the project has. Protect it.

### Never do these

| Never | Why |
|---|---|
| Add an advertising, analytics, crash-reporting or attribution SDK | Ends the "no third-party code" position and triggers Families ads requirements |
| Add accounts, sign-in, chat or free-text entry between users | Turns the app into a social app under Families Requirement 7, requiring safety reminders and adult gates |
| Add in-app purchases | Brings the entire Ads & Monetisation section into scope |
| Send anything to a server you operate | Falsifies the privacy policy and the Data safety declaration |
| Request the location permission | Currently makes SSID access *impossible by construction* — a strong claim worth keeping |
| Remove the in-app privacy policy link | It is mandatory: a policy link must appear in Play Console **and** within the app |
| Rename a theme folder | See §3 |
| Drop "Ages 5 & under" from the target audience | It is the accurate declaration; removing it is misrepresentation |

Any one of these requires updating `PRIVACY_POLICY.md`, the Data safety declaration and the IARC questionnaire **before** it ships.

### Art rules for any new or replaced sprite

Derived from Google's *Ages 5 & under* guidance, which lists as unsuitable: *"Depict scary, dark settings or characters in danger (think scary animals, monsters, music, backgrounds)"* and *"Depict violence, fighting, weapons, crude humor…"*.

- **No weapons.** Includes swords, guns, batons, clubs — on players as well as chasers.
- **No bared teeth, fangs, claws, or narrowed angry eyes.** Round eyes with visible pupils read as *character*; hollow voids and slits read as *menace*. This single change is the cheapest way to make a sprite friendly.
- **No dark, gloomy or high-contrast-menacing backgrounds.** Google names backgrounds explicitly.
- **Transparent background on every sprite**, opaque only on background tiles. Check the opaque-pixel percentage — a sprite far above its peers usually has a scene baked in.
- **Smooth anti-aliased alpha edges.** Zero semi-transparent pixels means hard-cut edges that stair-step when scaled.
- **No trademark-adjacent designs.** Aesthetic genres are fine; specific characters are not.

### When changing a sprite, preserve what the store shows

The promo video and screenshots show specific themes. A sprite change that keeps the **silhouette** (alpha channel) and **palette** intact does not invalidate marketing footage; a redesign does. Measure silhouette IoU against the original before assuming.

---

## 6. Documents in this repo

| Document | What it is |
|---|---|
| `coding_rules.md` | **Code conventions.** Read first, before writing any GDScript |
| `DEVELOPMENT.md` | This file — product constraints, mechanics, content and policy rules |
| `COMPLIANCE_CHECKLIST.md` | Current Google Play compliance record, written for an external reader. Update when content changes |
| `PRIVACY_POLICY.md` | Mirror of the published policy. Keep in step with the live page |
| `game_specification_v3.md` | Full functional specification |
| `game_overview.md`, `tester_game_mechanics_overview.md` | Orientation and tester-facing mechanics |
| `testing_scenarios.md` | Manual test scenarios |
| `themes_todo.md` | Outstanding theme work and asset-regeneration prompts |
| `data/words/README.md`, `EMOJI_TODO.md` | Vocabulary structure and outstanding word issues |
| `docs/wizard_architecture.md` | Setup wizard design |
| `docs/painted_raised_maze_*.md` | The painted-wall rendering mode and its texture workflow |
| `themes/*/THEME_*.md`, `*_PROMPT.md` | Per-theme art direction and regeneration prompts |
| `_ideas_/` | Unimplemented proposals. Not commitments — do not treat as spec |

---

## 7. Release process

1. **Commit content and code changes separately.** Vocabulary, art and code should be reviewable independently.
2. **Bump `version/code` and `version/name`** in `export_presets.cfg`, and `data/release_version.txt` to match. Target SDK stays at **36**.
3. **Let Godot reimport** after editing `data/translations.csv` — the compiled `.translation` binaries are build artefacts and must be committed alongside the CSV. Verify the old string is gone from the binary; strings above roughly 13 characters are stored compressed and won't grep.
4. **Export the AAB and verify** — expect permissions `INTERNET`, `VIBRATE`, `DUMP`; native libs `libc++_shared.so`, `libgodot_android.so`; third-party SDKs `NONE`.

   `DUMP` is not a requested permission — it is the `android:permission` attribute protecting `androidx.profileinstaller.ProfileInstallReceiver`. Automated scans misread it.
5. **Enumerate active releases on every track** before submitting. Google reviews all active tracks, not just Production.
6. **Update "What's new."** Describe user-visible improvements. Do not describe compliance work — framing a presentation change as a remedy implies there was something to remedy.
7. **Re-check the IARC questionnaire** if any content changed.

### Pre-submission checklist

- [ ] Word-list validation passes; no duplicates within a language
- [ ] Every `manifest.json` reference and animation frame resolves
- [ ] New sprites: correct size, genuine alpha, no white halo, legible at 40 px
- [ ] Backgrounds still tile seamlessly
- [ ] D-pad navigation works keyboard-only on every changed screen
- [ ] Layout correct at 720p and 1080p
- [ ] Version bumped, target SDK still 36
- [ ] `COMPLIANCE_CHECKLIST.md` updated if content changed
- [ ] Store screenshots still match the current build

---

## 8. Testing

Beyond `testing_scenarios.md`:

- **Test on a TV at three metres.** This is the primary platform, and it is where low-contrast sprites and thin outlines fail.
- **Test with a D-pad only.** No touch, no mouse.
- **Test the smallest grid.** The 5×4 maze is where placement bugs surface.
- **Test with a four-year-old if you can.** Nothing else reveals a confusing icon as fast.
