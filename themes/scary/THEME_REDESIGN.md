# "Scary" → "Enchanted Forest" — redesign spec

Written 3 August 2026, as part of the Google Play Families compliance audit.

---

## 1. The concept is already right — the name isn't

The theme's premise is **a cheerful blue car exploring an enchanted forest full of old crooked trees**, one of which comes to life and plays chase. The car and the garage-finish are intentional and on-concept.

The problem is that the folder, the manifest title and the art palette all say **"Scary"**, while the concept says *enchanted*. The theme is currently dressed as a haunted forest when what it wants to be is a magical one.

That distinction matters for compliance. Google's *Age 5 and under* guidance lists as unsuitable:

> "Depict scary, dark settings or characters in danger (think scary animals, monsters, music, **backgrounds**)"

The app declares "5 and under" as a target age group. A theme literally named **Scary**, with a midnight-dark forest background, is the closest thing in the game to that description — even though the underlying idea is entirely benign.

**So this is not damage control. It is making the theme look like what it already is.**

### Important caveat

There is **no evidence Google flagged this theme.** The rejection notice named no content at all. This is a risk identified by reading the game against Google's published criteria, not a finding from Google. The actual rating descriptor ("Mild Crude Humour", ACB PG) comes from the **Bathroom** theme, not this one.

If art budget is tight, do steps **1 and 2** only. They capture most of the benefit.

---

## 2. What to keep

Do not touch these — they are on-concept and age-appropriate:

| Asset | Why keep |
|---|---|
| `player.png` — blue cartoon car | Intentional, central to the concept, cheerful |
| `finish.png` — orange truck in a garage | On-concept destination; reads as "home" |
| `trap.png` — spider web with smiling spider | Already cute. Pastel purple, the spider is smiling, no menace |
| Firefly orbs, toadstools, ancient trees in the background | These are *enchanted forest* staples already present |

---

## 3. Changes, in priority order

### ⭐ Step 1 — `tile4.png` (background) — highest leverage

This is the single darkest asset in the entire game and the one the policy language names directly.

**Keep the composition.** Same trees, same layout, same tiling. Change the lighting only — think *same forest, different time of day*.

| Property | Now | Target |
|---|---|---|
| Overall luminance | Very dark (near-midnight) | Lift **35–45%** — dusk or early morning, not night |
| Hue | Deep purple-blue `#1E1830`-ish | Shift toward **teal-green** `#2E4A47` / `#3B5F63` |
| Tree trunks | Near-black purple, bare | Warmer brown-mauve, add a few leaves or moss |
| Trunk hollows | Read as hollow eye sockets / faces | Soften edges, or fill one with a **sleeping owl** or a glowing lantern — turn the face-suggestion into a friendly detail |
| Cobwebs (corners) | Grey, sparse, spooky | Remove, or make them **dewy and sparkling** |
| Mist | Cold grey ground fog | Warm it, or reduce opacity |
| Firefly orbs | Orange, sparse | Keep and **increase** — more of them, warm gold `#FFD98A`, some with soft bloom |
| New element | — | Optional: soft light shafts through the canopy. Instantly reads "enchanted" |

**Success test:** shown the background alone with no context, an adult should say *"magical forest"* rather than *"haunted forest"*.

### ⭐ Step 2 — `chaser.png` (the crooked tree)

Keep it as a living crooked tree — that is the fun of the theme. Make it a *grumpy* tree rather than a *lurking* one.

| Feature | Now | Target |
|---|---|---|
| Eyes | Hollow black voids | **Add white sclera and pupils.** Single biggest change — voids read as menace, pupils read as character |
| Mouth | Jagged dark gash | Rounded, small, maybe a slight smile or an "oh!" |
| Claws | Sharp curved talons | Turn into **twigs, leaves or buds** — same silhouette, no threat |
| Silhouette | Angular, forward-lunging | Round the outer edges; upright rather than crouched |
| Colour | Dark red-pink `#C2185B`-ish | Warmer bark brown, with green leafy canopy |
| Extras | — | Moss patches, a small bird perched on a branch, or a flower |

**Reference feel:** the trees in *Winnie the Pooh* or the apple trees in early *Wizard of Oz* picture-book adaptations — characterful and a bit cross, never threatening.

### Step 3 — `pumpkin3.png` (collectible)

The jack-o'-lantern is the one asset that says **Halloween** outright.

**Technical constraint:** the collectible carries the number or letter, drawn in `#f6fb36` yellow over a dark cutout region. Any replacement needs the same affordance — a **dark, roughly circular panel** for the glyph to sit on.

Options that satisfy that and fit the concept:

1. **Glowing toadstool** — round red or amber cap, dark underside panel for the glyph. Already present in the background, so it ties together. *Recommended.*
2. **Hanging lantern** — dark glass panel, warm rim glow. Very "enchanted path".
3. **Acorn** — dark cap as the panel.

Update `manifest.json` → `collectible.image` accordingly. `pumpkin.png` is unreferenced and can be deleted.

### Step 4 — colour palette in `manifest.json`

Current values read as neon-haunted-house. Two options:

**Option A — "Twilight Glade"** (keeps some mystery, closer to current)

```json
"colors": {
  "wall": "#A88BFF",
  "wall_glow_factor": 0.8,
  "wall_border": "#6B5AA8",
  "start_cell": "#3E5C6B",
  "end_cell": "#C8873F",
  "player": "#38A9FF",
  "highlight": "#FFD98A66"
}
```

**Option B — "Sunlit Glade"** (safest for the 5-and-under band)

```json
"colors": {
  "wall": "#7FE3C8",
  "wall_glow_factor": 0.7,
  "wall_border": "#3E7C6B",
  "start_cell": "#2F5D52",
  "end_cell": "#C8873F",
  "player": "#38A9FF",
  "highlight": "#FFD98A66"
}
```

Keep `player: #38A9FF` in both — it matches the blue car. Consider dropping `glow.strength` from `0.6` to `0.45`; the strong glow contributes to the neon-spooky feel.

### Step 5 — the rename

Do this **last**, once the art matches, so the name is accurate rather than cosmetic.

**5a. Manifest title.** `theme_loader.gd:350` resolves titles via `title_key` if present, otherwise falls back to `"theme_" + <dir_name>`. So the clean route is a translation key rather than a hardcoded English string:

```json
"title": "Enchanted Forest",
"title_key": "theme_enchanted_forest"
```

Then add `theme_enchanted_forest` to `data/translations.csv` for all 21 locales. Suggested: *Zakletý les* (cs), *Zauberwald* (de), *Bosque Encantado* (es), *Forêt Enchantée* (fr), *Bosco Incantato* (it), *Betoverd Bos* (nl), *Zaczarowany Las* (pl), *Förtrollad Skog* (sv).

**5b. ⚠️ Do NOT rename the folder without a migration.**

`game_config.gd:427` persists the theme as `config.set_value("Theme", "dir_name", theme_dir_name)` and reads it back at line 464. `CharacterCatalog` also builds character IDs with a `theme_dir + ":"` prefix.

Renaming `themes/scary/` → `themes/enchanted/` would therefore:

- break the saved theme preference for every existing player who had it selected,
- invalidate any stored `character_id` carrying the `scary:` prefix,
- and break `theme_dir` in the multiplayer discovery payload between mismatched client versions.

**Options:**

- **Simplest and recommended:** keep the folder named `scary`, change only the displayed title. The folder name is never shown to users.
- If you want the folder renamed for tidiness, add a migration in `game_config.gd` load: if `dir_name == "scary"`, rewrite to `enchanted`, and strip/remap any `scary:` character-ID prefix.

**5c. Also declare the chaser explicitly.** `scary` is the only theme whose manifest omits `assets.chaser` — it currently works purely because `theme_loader.gd:150` falls back to the filename `chaser.png`. Add it for consistency with the other eight themes:

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

---

## 4. What this does and does not achieve

**Does:**

- Removes the only "dark setting" and the only monster-like character from a game that declares "5 and under".
- Removes a theme name that invites a reviewer to go looking for scary content.
- Makes the theme match its own concept, which is a genuine quality improvement independent of policy.

**Does not:**

- Change any content rating. The IARC questionnaire asks about content, not theme names — and the **Bathroom** theme is what drives the current "Mild Crude Humour" descriptor and the Australian PG. This work does not touch that.
- Constitute a response to Google. They have still not identified any content.

---

## 5. Checklist

- [ ] `tile4.png` relit — luminance +35–45%, hue toward teal-green, fireflies increased, cobwebs softened, trunk hollows made friendly
- [ ] `chaser.png` — pupils added, mouth rounded, claws → twigs/leaves, silhouette softened, foliage added
- [ ] Collectible replaced with glowing toadstool (dark panel preserved for the glyph)
- [ ] `manifest.json` — `collectible.image` updated
- [ ] `manifest.json` — palette switched to Option A or B; `glow.strength` → 0.45
- [ ] `manifest.json` — `assets.chaser` declared explicitly
- [ ] `manifest.json` — `title` + `title_key` set
- [ ] `theme_enchanted_forest` added to `data/translations.csv` × 21 locales
- [ ] Folder left as `scary/`, **or** migration added in `game_config.gd`
- [ ] `pumpkin.png` deleted (unreferenced)
- [ ] `player.png` and `finish.png` left untouched — intentional, on-concept
- [ ] Visual check on a TV at 3 m: does it read *magical* rather than *haunted*?
