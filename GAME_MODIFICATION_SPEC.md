# Learning Maze — implementation spec for compliance changes

> ⚠️ **MOSTLY EXECUTED — historical record. Do not work from this file.**
> Checked against the tree on 2026-08-14 at version 1.2.0 build 79:
> **Phase 1 done** (baton → whistle, Thieves → *Treasure Chase*, unreferenced asset deleted) ·
> **Phase 2 done** (vocabulary fixes committed) ·
> **Phase 3 built then deliberately reverted** in `c365847` — only the retitle to *Autumn Forest* was kept, to protect the promo video ·
> **§2 "uncommitted work at handover" is obsolete** — the tree is clean.
> Only **Phase 4** (store listing) and part of **Phase 5** remain, and both are tracked in
> [`PROJECT_STATE.md`](PROJECT_STATE.md). **Read the ledger, not this file.**
> §1 hard constraints are still valid and worth reading.

Written 6 August 2026. Intended to be executed in a **separate session**, standalone.
App: `com.hauzirek.learningmaze` · Godot 4.6 · repo root `/Documents/Bludiste`

---

## 0. Context — read this first

Version 76 was rejected on 25 July 2026 under *Families Policy Requirements: Families Program Eligibility*. **Google never identified a specific finding**, despite nine days of requests. A full compliance audit was completed on 3 August (see `COMPLIANCE_CHECKLIST.md`) and found **no Families requirement affirmatively failed**. The app is technically exemplary: two permissions, zero SDKs, no trackers, no identifiers, no network calls, no ads.

**Everything in this spec is therefore risk reduction, not defect repair.** None of it is a known violation. The rationale throughout is Google's published *Age 5 and under* guidance, since the app declares that age band:

> "Apps may not be suitable for this age if they: … Depict violence, fighting, **weapons**, crude humor or language … **Depict scary, dark settings** or characters in danger (think scary animals, monsters, music, **backgrounds**)"
> — [Manage target audience and app content settings](https://support.google.com/googleplay/android-developer/answer/9867159)

**Do not treat any item here as urgent.** Phase 1 and 2 are cheap and clearly worthwhile. Phase 3 is a judgement call on art budget.

### Supporting documents in the repo

| File | Contents |
|---|---|
| `COMPLIANCE_CHECKLIST.md` | Full audit: every requirement, status, evidence, prioritised actions |
| `themes/scary/THEME_REDESIGN.md` | Art direction for the Enchanted Forest conversion |
| `themes/thiefs/THEME_NOTES.md` | Baton swap + 10 title options with rationale |
| `data/words/EMOJI_AUDIT_2026-08-03.md` | The 28 emoji fixes already applied |
| `data/words/EMOJI_TODO.md` | Everything still outstanding in the vocabulary |

---

## 1. Hard constraints — breaking these breaks the game

### 1.1 ⛔ Never rename a theme folder

`scripts/game_config.gd:427` persists the active theme as:
```gdscript
config.set_value("Theme", "dir_name", theme_dir_name)
```
and reads it back at line 464. `CharacterCatalog` also builds character IDs with a `<theme_dir>:` prefix.

Renaming `themes/scary/` or `themes/thiefs/` would:
- break the saved theme preference for every existing player,
- invalidate stored `character_id` values carrying the old prefix,
- desync `theme_dir` in the multiplayer discovery payload between mismatched client versions.

**Folder names are never shown to users.** Retitle via translations only. Keep `scary/` and `thiefs/` exactly as they are, misspelling included.

### 1.2 Theme titles come from `data/translations.csv`, not the manifest

`scripts/theme_loader.gd:350-357`:
```gdscript
func get_display_title(fallback_dir_name: String = "") -> String:
    var title_key := ""
    if manifest.has("title_key"): ...
    title_key = "theme_" + fallback_dir_name
```
No manifest currently sets `title_key`, so every theme resolves through the row `theme_<folder_name>` in `data/translations.csv`. **Renaming a theme = editing one CSV row.** No manifest change, no code change.

### 1.3 `thiefs` is the default theme on a fresh install

`scripts/game_config.gd` lines 118 and 252 both default to `"thiefs"`. A reviewer installing the app cold lands in this theme. That is why Phase 1 is first.

### 1.4 Collectible sprites need a dark glyph panel

Collectibles carry the number/letter, drawn in the colour set by `collectible.text-color` in the theme manifest. Any replacement sprite must keep a **dark, roughly circular region** for the glyph to sit on legibly. The current `themes/scary/pumpkin3.png` does this with a black cutout.

### 1.5 Do not change the target audience declaration

"5 and under, 6-8" is accurate — the game is designed for 4+ pre-readers (`game_specification_v3.md` §1, §2, §3.6). Removing "5 and under" would be misrepresentation.

### 1.6 Do not touch the IARC content rating questionnaire

Resubmitted 6 Aug 2026 and verified correct. Crude Humor = **Yes**, tier 2 ("Flatulence…, whimsical depictions of feces…, vomiting") — this is the mildest tier that accurately covers a visible cartoon poop. All other categories = No. Ratings held identical. **Leave it alone.**

---

## 2. State at handover — uncommitted work in the tree

`git status` shows **21 modified vocabulary files** plus new documentation. These are the 28 emoji corrections applied on 3 August (alcohol 🥃 and weapon 🏹🤺 imagery removed, 💩 removed from the French list, a corrupted emoji repaired).

**Commit these before starting new work** so the emoji fixes and the theme work land as separate, reviewable changes.

```
M data/words/words_{cs_1,de_4,de_6,en_0,en_4,en_6,es_1,es_2,fr_1,fr_2,he_2,
                    it_1,nl_2,pl_2,pl_4,pt_3,sk_0,sk_2,sv_1,uk_2,uk_4}.json
?? COMPLIANCE_CHECKLIST.md
?? data/words/EMOJI_AUDIT_2026-08-03.md
?? data/words/EMOJI_TODO.md
```

*(`data/release_version.txt` and `export_presets.cfg` are also modified — check whether that is intentional before committing.)*

---

## 3. Phase 1 — Thieves theme *(highest value, ~1 hour)*

This is the **default theme**. Do this first.

### 1.1 Swap the police baton for a whistle

**File:** `themes/thiefs/t_chaser_0.png`

The cartoon police officer holds a black baton. It is now the only weapon-adjacent object in the game (🏹 and 🤺 were removed from the vocabulary on 3 Aug). Google's Age 5-and-under list names weapons explicitly.

Replace the baton with a **whistle** — instantly reads as "police", suits a chase game better, removes the category entirely.

Fallbacks if a whistle doesn't read at sprite size: a torch, a raised pointing hand, or an empty hand.

**Keep everything else** — same pose, same uniform, same friendly face.

**Acceptance:** no object in the sprite could be described as a weapon.

### 1.2 Retitle "Thieves" → "Treasure Chase"

**File:** `data/translations.csv`, row `theme_thiefs`

Rationale: the assets are already a treasure hunt — a gold coin collectible, a treasure chest finish, a banana-peel trap. Only the player's mask-and-stripes and the word "Thieves" frame it as crime. Cops-and-robbers is not prohibited by any Google policy; this is presentation, not compliance.

**Replacement row** (column order `keys,en,cs,de,es,fr,pt,vi,tr,it,pl,sv,nb,nl,uk,fi,da,hu,ro,el,sk,he`):

```csv
theme_thiefs,Treasure Chase,Hon za pokladem,Schatzjagd,Caza del tesoro,Chasse au trésor,Caça ao tesouro,Săn kho báu,Hazine Avı,Caccia al tesoro,Pogoń za skarbem,Skattjakt,Skattejakt,Schattenjacht,Полювання за скарбами,Aarrejahti,Skattejagt,Kincsvadászat,Vânătoare de comori,Κυνήγι θησαυρού,Hon za pokladom,מרדף אוצר
```

⚠️ **These translations are my best effort and have not been checked by native speakers.** Czech and Slovak are confident; verify the rest, particularly Vietnamese, Hungarian, Greek and Hebrew.

Alternative titles if "Treasure Chase" doesn't appeal — full list with rationale in `themes/thiefs/THEME_NOTES.md`: Coin Chase, Treasure Hunt, Catch Me!, City Chase, Golden Coins.

**Do not change** the player sprite. A masked figure in stripes reads perfectly well as a storybook treasure hunter.

**Acceptance:** theme selector shows the new name in all 21 UI languages; saved preferences still resolve; multiplayer join between two updated clients still works.

### 1.3 Delete unreferenced asset

`themes/thiefs/t_collectible_money_bag.png` — not referenced in `manifest.json` (the live collectible is `t_collectible_0.png`, a gold coin).

---

## 4. Phase 2 — Vocabulary data errors *(~1 hour, no art needed)*

Full detail in `data/words/EMOJI_TODO.md` §A. These are **word** errors, not emoji errors.

| Priority | Lang | File | Word | Action |
|---|---|---|---|---|
| High | pl | `words_pl_4.json` | `STRASZAK` | **Check with a Polish speaker first.** Every other language uses a scarecrow word here; *straszak* commonly means a **cap gun**. If so, replace with `STRACH NA WRÓBLE`. This is the only possible weapon word left in the vocabulary |
| High | da | `words_da_2.json` | `LOSOS` | Czech/Slovak word for salmon sitting in the Danish list. Danish is **LAKS** |
| High | pl | `words_pl_0.json` | `MÓD` | Not a Polish word. `MIÓD` (honey) already exists in `words_pl_2.json` with the same 🍯 — **delete this entry** |
| High | da | `words_da_1.json` | `BOLT` | `BOLD` (ball) already exists in `words_da_2.json` with the same ⚽ — **delete this entry** |
| Medium | fi | `words_fi_5.json` | `LEIKKIKÄÄTE` | Not a Finnish word. Should be `LEIKKIKÄÄ YHDESSÄ` ("play together") to match the other languages |
| Medium | fi | `words_fi_5.json` | `ILONEN LAPSI` | Typo → `ILOINEN LAPSI` (spelled correctly two entries away) |
| Medium | fi | `words_fi_6.json` | `KUU VALAISTAA MEITÄ` | Verb form → `KUU VALAISEE MEITÄ` |
| Medium | de | `words_de_0.json` | `TOP` | Probably `TOPF` (pot) — emoji is 🍲 |
| Low | pl | `words_pl_4.json` | `WOZ STRAŻACKI` | Missing diacritic → `WÓZ STRAŻACKI` |
| Low | sk | `words_sk_0.json` | `LIETAK` | Non-standard spelling; intended word unclear |
| Low | nb | `words_nb_1.json` | `REVE` | Norwegian for fox is `REV` |
| Low | da | `words_da_5.json` | `LEGEFUL HUND` | Not standard Danish; compare NB `LEKEFULL HUND` |

**Validation after editing** — every file must stay valid JSON with the same entry count:

```bash
cd data/words && python3 -c "
import json,glob
t=0
for f in sorted(glob.glob('words_*.json')):
    d=json.load(open(f,encoding='utf-8')); t+=len(d)
    for e in d: assert 'word' in e and 'emoji' in e and e['emoji'], (f,e)
print('OK', len(glob.glob('words_*.json')), 'files,', t, 'entries')"
```
Expected: `OK 147 files, 3654 entries` (fewer if you delete `MÓD` and `BOLT`).

**Optional, P3:** the 34 emoji/word mismatches in `EMOJI_TODO.md` §B. No policy bearing. Worst are `tr GÜVE` (moth shown as butterfly), `cs VÁŽKA` (dragonfly shown as butterfly), `cs KRTEK` (mole shown as beaver).

---

## 5. Phase 3 — Scary theme → Enchanted Forest *(art work; judgement call)*

Full art direction in `themes/scary/THEME_REDESIGN.md`. Summary and order:

**The concept is already right.** A cheerful blue car exploring an enchanted forest of crooked trees. The car and garage-finish are intentional (based on a cartoon) — **do not change them**. Only the *name* and the *palette* say "haunted".

### Step 1 — `tile4.png` background *(highest leverage)*

The darkest asset in the game, and Google's wording names **backgrounds** explicitly.

**Keep the composition.** Same trees, same tiling. Change the lighting only — same forest, different time of day.

- Luminance **+35-45%** — dusk or early morning, not midnight
- Hue shift from deep purple-blue toward **teal-green**
- Trunk hollows currently read as eye sockets → soften, or fill one with a sleeping owl
- Cobwebs → remove or make dewy and sparkling
- Firefly orbs → **more of them**, warm gold `#FFD98A`
- Optional: light shafts through the canopy

**Acceptance:** shown alone with no context, an adult says *"magical forest"*, not *"haunted forest"*.

### Step 2 — `chaser.png` crooked tree

Keep it a living crooked tree. Make it *grumpy*, not *lurking*.

- **Add white sclera and pupils** — single highest-impact change; hollow voids read as menace, eyes read as character
- Mouth → rounded, small, maybe a slight smile
- Claws → **twigs, leaves or buds**
- Silhouette → round the outer edges, upright not crouched
- Add moss, leaves, maybe a perched bird

*Reference feel: the trees in Winnie the Pooh — characterful and a bit cross, never threatening.*

**Note:** the chaser is visible in the promo video as a small magenta sprite and as an icon in the pink "Chase" HUD badge, so this change is visible in marketing too.

### Step 3 — collectible

`pumpkin3.png` (jack-o'-lantern) is the one asset that says Halloween outright, and it appears prominently in the promo video carrying the letters.

Replace with a **glowing toadstool** (ties to the mushrooms already in the background), a hanging lantern, or an acorn. **Must keep a dark circular panel for the glyph** (see constraint 1.4). Update `manifest.json` → `collectible.image`.

### Step 4 — `manifest.json` palette

Current values read neon-haunted-house. Two options, full hex values in `THEME_REDESIGN.md`:

- **Option A "Twilight Glade"** — keeps some mystery: `wall: #A88BFF`, `wall_border: #6B5AA8`
- **Option B "Sunlit Glade"** — safest for 5-and-under: `wall: #7FE3C8`, `wall_border: #3E7C6B`

Keep `player: #38A9FF` (matches the blue car). Drop `glow.strength` from `0.6` → `0.45`.

### Step 5 — declare the chaser explicitly

`themes/scary/manifest.json` is the **only** theme manifest missing `assets.chaser`. It currently works via filename fallback in `theme_loader.gd:150`. Add for consistency:

```json
"assets": {
  "player": "player.png",
  "chaser": "chaser.png",
  "start": "start.png",
  "end": "finish.png",
  "background": "tile4.png",
  "trap": "trap.png"
}
```

### Step 6 — retitle *(do last, after the art matches)*

**File:** `data/translations.csv`, row `theme_scary`

```csv
theme_scary,Enchanted Forest,Zakletý les,Zauberwald,Bosque encantado,Forêt enchantée,Floresta encantada,Khu rừng phép thuật,Büyülü Orman,Bosco incantato,Zaczarowany las,Förtrollad skog,Fortryllet skog,Betoverd bos,Зачарований ліс,Lumottu metsä,Fortryllet skov,Elvarázsolt erdő,Pădurea fermecată,Μαγεμένο δάσος,Zakliaty les,יער קסום
```

⚠️ Same caveat — verify with native speakers. *(Note: `יער קסום` already appears in the Hebrew vocabulary as "enchanted forest", so it is at least self-consistent.)*

### Step 7 — delete `themes/scary/pumpkin.png` (unreferenced)

---

## 6. Phase 4 — Store listing *(Play Console only, no code)*

| # | Action | Why |
|---|---|---|
| 1 | **Re-shoot screenshot 3** — its breadcrumb reads *"Follow the Trail • Scary • Very Large"* | The word "Scary" is currently visible in the store listing of a Families app. Either select a different theme, or re-shoot after Phase 3 so it reads "Enchanted Forest" |
| 2 | **Update "What's new"** — currently reads *"First production release"* at version 75 | Stale. Google's Families policy recommends using this field to announce content or age-targeting changes |
| 3 | *(Only if Phase 3 done)* Re-capture the promo video and screenshots 5 and 8 | The dark forest is currently 2 of 8 screenshots and 100% of the video including the end card |
| 4 | Verify the live feature graphic is the correctly-spelled one | `images/big_banner_1024_500.png` in the repo reads **"LEARNIG MAZE"**. The live Console asset is correct — just don't upload the wrong file |

**Do not change** — these are strong assets: screenshot 6 ("Offline · No ads · No hidden payments · Safe for kids"), screenshot 4 ("Levels from simple to challenging"), the promo video's family framing and "Safe · No Ads · No In-app purchases · No Accounts" end card, and the listing description.

---

## 7. Phase 5 — Housekeeping *(no policy bearing)*

1. `game_specification_v3.md` §4.2 describes the host lobby auto-detecting the WiFi network name. **This was never implemented** and cannot be — reading SSID requires location permission, which the app does not hold. Remove the claim so the spec matches reality.
2. `EMOJI_TODO.md` §B — 34 emoji/word mismatches.
3. `EMOJI_TODO.md` §C — 7 concepts with no suitable emoji (table, rug, mole, dragonfly, submarine, polecat, plum). Documented so nobody re-investigates.

---

## 8. Build and release

1. Commit the existing vocabulary fixes **separately** from the theme work.
2. Bump version code 76 → 77 and version name.
3. Target SDK stays **36** (the reason v76 existed).
4. Export AAB and verify nothing regressed:

```bash
python3 - <<'EOF'
import zipfile,re
z=zipfile.ZipFile("Bludiste.aab")
d=z.read("base/manifest/AndroidManifest.xml")
print("permissions:", sorted(set(s.decode() for s in re.findall(rb'android\.permission\.[A-Z_]+',d))))
print("native libs:", sorted(set(n.split("/")[-1] for n in z.namelist() if n.endswith(".so"))))
sigs=[b'com/google/android/gms',b'firebase',b'crashlytics',b'admob',b'com/facebook',b'com/unity3d']
dex=[n for n in z.namelist() if n.endswith(".dex")]
found={s.decode() for dd in dex for s in sigs if s in z.read(dd)}
print("3rd-party SDKs:", found or "NONE")
EOF
```
Expected: `INTERNET`, `VIBRATE`, `DUMP` *(DUMP is the `android:permission` attribute protecting `androidx.profileinstaller.ProfileInstallReceiver` — not a permission request)*; libs `libc++_shared.so`, `libgodot_android.so`; SDKs `NONE`.

5. **Before submitting**, check `Test and release → Releases overview` and confirm which version code is active on every track. Google reviews all active tracks, and Bundle Explorer previously showed v75 active on *Internal testing* while v76 sat on Production — never explained.

6. In the release notes, state plainly what changed. Something like: *"Theme presentation updates, corrected vocabulary entries in several languages, no changes to gameplay, permissions, SDKs or data handling."*

---

## 9. Explicitly out of scope

- ❌ Renaming any theme folder (constraint 1.1)
- ❌ Changing the target audience declaration (constraint 1.5)
- ❌ Touching the IARC questionnaire (constraint 1.6)
- ❌ Removing the Bathroom theme — it is opt-in, 1 of 9, and the ACB PG it produces is not a disqualifier. ESRB remains **Everyone**, which is what the rejection bullet requires
- ❌ Changing the blue car or garage-finish in the Scary theme — intentional and on-concept
- ❌ Adding any SDK, analytics, ads or network capability
- ❌ Submitting a speculative build "to see what happens"

---

## 10. Acceptance checklist

**Phase 1 — Thieves**
- [ ] Baton replaced with a whistle in `t_chaser_0.png`
- [ ] `theme_thiefs` row updated in `data/translations.csv`, all 21 columns
- [ ] Translations reviewed by native speakers where possible
- [ ] Folder still named `thiefs/`
- [ ] Saved theme preference still resolves after update
- [ ] `t_collectible_money_bag.png` deleted

**Phase 2 — Vocabulary**
- [ ] `pl STRASZAK` checked with a Polish speaker
- [ ] `da LOSOS` → `LAKS`
- [ ] `pl MÓD` and `da BOLT` deleted
- [ ] Three Finnish corrections applied
- [ ] Validation script passes

**Phase 3 — Enchanted Forest**
- [ ] `tile4.png` relit; passes the "magical not haunted" test
- [ ] `chaser.png` has pupils, rounded mouth, twigs instead of claws
- [ ] Collectible replaced, dark glyph panel preserved
- [ ] `manifest.json` palette updated, `glow.strength` → 0.45
- [ ] `assets.chaser` declared
- [ ] `theme_scary` row retitled — **after** the art
- [ ] `pumpkin.png` deleted
- [ ] Checked on a TV at 3 m

**Phase 4 — Store listing**
- [ ] Screenshot 3 no longer shows "Scary"
- [ ] "What's new" updated
- [ ] Correct feature graphic confirmed live

**Build**
- [ ] Vocabulary fixes committed separately
- [ ] Version bumped to 77, target SDK still 36
- [ ] AAB verification script output matches expectations
- [ ] Active tracks enumerated before submitting
