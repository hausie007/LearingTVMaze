# Themes — content to change

> ⚠️ **BOTH MUST ITEMS ARE DONE — historical record.** Verified by inspecting the sprites on 2026-08-14:
> `themes/castle/c_player.png` now carries a **torch**, not a sword ·
> `themes/karkulka/k_chaser.png` is a **friendly grey wolf** with a closed mouth and round eyes.
> Open theme work, if any, is tracked in [`PROJECT_STATE.md`](PROJECT_STATE.md).
> The resolution notes below (the two-slot `theme_loader.gd` behaviour) are still accurate and useful.

Assets below are the ones the game **actually loads**, resolved by mirroring `theme_loader.gd`:
`assets.<slot>` from `manifest.json`, else the naming-convention default; then the top-level
`player` / `chaser` / `background` / `collectible` block, whose `frames` list overrides.
Files sitting in a theme folder but not reachable by that resolution are ignored — every theme
carries unused leftovers, and several of them look worse than the assets in use.

All sprites render at roughly **40–60 px** on screen, so small-size legibility governs every decision.

---

## Resolution note — two different slots per character

`theme_loader.gd` exposes both a single texture and a frame list, and **different screens use different ones**:

| Consumer | Uses |
|---|---|
| Chase gameplay (`chaser.gd`) | `chaser_frames` — the animator overrides the single texture immediately |
| **Race-mode robot** (`game_manager.gd:975`) | `chaser_texture` — no animator attached |
| **Help / tutorial portraits** (`help_menu.gd`) | `chaser_texture` at 54, 86 and 120 px |
| Theme picker, character catalog | `chaser_frames` |

So a theme can ship a friendly animated chaser and still display a different sprite in Race mode
and the help screens. Only the **cars** theme diverged this way; every other theme resolves both to
the same file.

---

## MUST — weapons and menace (*Ages 5 & under* criteria)

| # | Asset | Size | Change | Quality defect |
|---|---|---|---|---|
| 1 | `themes/castle/c_player.png` | 254×237 | Replace the drawn sword | **Zero semi-transparent pixels** — hard-cut edges, visibly jagged when scaled |
| 2 | `themes/karkulka/k_chaser.png` | 347×347 | Remove bared teeth, open the eyes | None. Edges clean (7.9% soft) |

### Already resolved — no art needed

**`themes/cars`** — the gameplay chaser is `p_chaser_1.png` / `p_chaser_2.png`, a **cheerful smiling
police car** with round friendly eyes, an open smile, no teeth and a clean transparent background.
It was never a problem.

The toothy `chaser_1.png` was reachable only through `chaser_texture`, which surfaces in the
**Race-mode robot** and the **help portraits**. Fixed by pointing `assets.chaser` at
`p_chaser_1.png` — gameplay animation is untouched, and `chaser_1.png` is now unreferenced.

## SHOULD — dark-setting criterion

- **`themes/scary/tile4.png`** — lighten the background, remove the corner cobwebs, replace the
  carved-pumpkin collectible. Google names *backgrounds* explicitly. Forces a promo video
  re-capture, which is why it sits below the MUST items.

## CONSIDER — vocabulary

- Replace the six `HALLOWEEN` entries and the 🎃 emoji (8 entries total) with a plain pumpkin.

## SEPARATE ISSUE — Arcade / Pac-Man

- Recolour the ghost, replace the yellow wedge with a distinct character.
- **Not a Families matter** — Play's Intellectual Property policy, an unrelated surface.

## NOT WORTH CHANGING

Bathroom theme (opt-in, static objects, no bodily function depicted) · spider and bat vocabulary
(standard picture-dictionary content) · masked figure in Treasure Chase · Castle dragon (cute,
no menace) · Ducks fox · Paper one-eyed creature.

## Housekeeping — unreferenced files in theme folders

Not loaded, but `export_filter="all_resources"` ships them all:

| Theme | Unreferenced |
|---|---|
| castle | `c_collectible_0/1.png`, `c_collectible_shield_0/1.png`, `trap.png` |
| karkulka | `k_collectible.png`, `k_collectible0.png`, `k_collectible3.png`, `trap.png` |
| cars | `chaser_1.png`, `chaser_2.png`, `player_1.png`, `start 2.png` |
| thiefs | `t_background_tile_0.png`, `t_background_tile_city.png` |
| poop | `1trap.png`, `trap1.png` |
| arcade | `collectible_1.png` |
| default | `x_trap.png` |

---

# Prompts

Each takes the original image as an attachment. Same rule for both: **change what is listed, keep
everything else identical.**

---

## 1 · Castle knight — `themes/castle/c_player.png`

Attach the original. The replacement object matters: **do not use a shield** — this theme's
collectible is `shield_new.png`, so a knight holding one would appear to carry the item the child
is meant to collect.

> I'm attaching a 254×237 PNG game sprite from a children's maze game for ages 4–8 — a cheerful
> cartoon knight, the character the child controls. I need two changes.
>
> **FIX 1 — Replace the sword.**
> The knight holds a raised **sword**. This game is rated for very young children and must not
> depict weapons. Replace it with a **lit torch** — a wooden handle with a warm orange flame — in
> the same raised hand, at the same angle and roughly the same size. A torch suits a castle,
> reads as an adventurer exploring, and removes the weapon entirely.
>
> *(If a torch doesn't read at small size, alternatives in order: a small triangular pennant flag
> on a short pole, a lantern, or an open waving hand. **Do not use a shield.**)*
>
> **FIX 2 — Fix the edge quality.**
> The current image has **hard-cut, jagged, aliased edges** — it contains no semi-transparent
> pixels at all, so the outline stair-steps when scaled. Redraw with **smooth anti-aliased edges**
> against transparency.
>
> **KEEP EVERYTHING ELSE IDENTICAL:**
> - The same cheerful running pose and body proportions
> - The same friendly face and expression
> - The same silver-grey plate armour, the same helmet with the **red plume**, the same gold and
>   blue detailing
> - The same flat cartoon style with clean dark outlines, the same colours
> - The same size and position within the frame
>
> **TECHNICAL:**
> - Output exactly **254×237 pixels**
> - Fully transparent background with **smooth anti-aliased alpha edges** — no white fringe, no
>   stair-stepping, no drop shadow, no ground
> - Displayed at roughly 40–60 px on screen, so it must read clearly when small
>
> **DO NOT:** include a sword, dagger, axe, spear, bow or any other weapon; include a shield;
> change the armour, helmet, plume or face; restyle the artwork; add a background.

---

## 2 · Little Red wolf — `themes/karkulka/k_chaser.png`

Attach the original. Edges are already clean, so only the face changes.

> I'm attaching a 347×347 PNG game sprite from a children's maze game for ages 4–8 — a cartoon
> wolf who playfully chases the player around a maze, in a Little Red Riding Hood theme. I need
> **one change: the face.**
>
> The wolf currently **bares a full set of sharp pointed teeth** and has **narrowed, angry yellow
> eyes**. It reads as threatening, and this game is rated for very young children.
>
> **Change the face to:**
> - A **closed, friendly mouth** — a soft smile or a small open "oh". **No visible teeth**, no
>   fangs, nothing pointed
> - **Large round friendly eyes** with white sclera, dark round pupils and a small white
>   catchlight. Open and warm, not narrowed. Remove the angry lowered eyebrows — slightly cheeky
>   or curious is ideal
> - It should look like a **playful, mischievous storybook wolf** inviting a game of chase, not a
>   predator
>
> **KEEP EVERYTHING ELSE IDENTICAL:**
> - The same grey-and-white fur colours and markings
> - The same body shape, four-legged stance and bushy tail
> - The same head shape and ear position
> - The same flat cartoon style with dark outlines
> - The same size and position within the frame
>
> **TECHNICAL:**
> - Output exactly **347×347 pixels**
> - Fully transparent background with smooth anti-aliased edges — no white fringe, no drop
>   shadow, no ground
> - Displayed at roughly 40–60 px on screen, so the eyes must be large enough to read when small
>
> **DO NOT:** show any teeth or fangs; keep the angry narrowed eyes; change the fur colours, body,
> tail or pose; restyle the artwork; add a background.

---

## Checking results

Send each result back before it goes in. Checks applied:

- exact pixel dimensions preserved
- genuine alpha, white-fringe test over both black and white backgrounds
- edge softness — the proportion of semi-transparent pixels, which distinguishes a smooth edge
  from a jagged one
- opaque-area percentage, to confirm no background survives
- silhouette overlap against the original, so in-game scale and placement are unchanged
- legibility rendered at 60 px and 40 px over the actual theme background
