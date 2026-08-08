# Themes — content to change

Sprite work required for Google Play Families compliance, plus the quality defects found alongside it.
All sprites render at roughly **40–60 px** on screen, so small-size legibility governs every decision.

---

## MUST — weapons and menace (*Ages 5 & under* criteria)

| # | Asset | Size | Change | Quality defect found |
|---|---|---|---|---|
| 1 | `themes/cars/chaser_1.png` | 767×767 | Remove bared teeth, open the narrowed eyes | **Dark red-lit scene baked into the sprite.** 53.4% fully opaque vs 35–47% for every other chaser — renders as a dark block, not a cut-out character |
| 2 | `themes/castle/c_player.png` | 254×237 | Replace the drawn sword | **Zero semi-transparent pixels** — edges are hard-cut and visibly jagged when scaled |
| 3 | `themes/karkulka/k_chaser.png` | 347×347 | Remove bared teeth, open the eyes | None. Edges are clean (7.9% soft) |

## SHOULD — dark-setting criterion

- **`themes/scary/tile4.png`** — lighten the background, remove the corner cobwebs, replace the carved-pumpkin collectible. Google names *backgrounds* explicitly. Forces a promo video re-capture, which is why it sits below the MUST items.

## CONSIDER — vocabulary

- Replace the six `HALLOWEEN` entries and the 🎃 emoji (8 entries total) with a plain pumpkin. Cheap; removes the only thread tying vocabulary to the theme imagery.

## SEPARATE ISSUE — Arcade / Pac-Man

- Recolour the ghost, replace the yellow wedge with a distinct character.
- **Not a Families matter** — this is Play's Intellectual Property policy, an unrelated surface. Worth doing on its own merits; should not delay the work above.

## NOT WORTH CHANGING

Bathroom theme (opt-in, static objects, no bodily function depicted) · spider and bat vocabulary (standard picture-dictionary content) · masked figure in Treasure Chase · Castle dragon (cute, no menace).

---

# Prompts

Each prompt takes the original image as an attachment. All three follow the same rule: **change what is listed, keep everything else identical.**

---

## 1 · Cars chaser — `themes/cars/chaser_1.png`

Attach the original. This is the largest of the three changes because the background has to come out as well as the face.

> I'm attaching a 767×767 PNG game sprite from a children's maze game for ages 4–8. It's a cartoon police car that playfully chases the player around a maze. I need it fixed in two ways.
>
> **FIX 1 — Remove the background completely.**
> The image currently has a scene painted into it: a dark road, smoke clouds, and a red and blue glow behind the car. All of that must go. I need **only the car itself on a fully transparent background** — no road, no smoke, no glow, no shadow, no backdrop of any kind. Every other sprite in this game is a clean cut-out character and this one is not.
>
> **FIX 2 — Make the face friendly instead of aggressive.**
> The car currently has a wide mouth full of **sharp pointed teeth** and **narrowed, angry eyes**. This frightens small children. Change it to:
> - A **closed, simple, friendly mouth** — a soft smile or a small neutral curve. **No teeth at all**, nothing pointed
> - **Large round friendly eyes** with white sclera, dark round pupils and a small white catchlight. Open and cheerful, not narrowed, not angry. Remove the angry eyebrow shapes entirely
> - The car should look **cheerful and eager**, like a friendly cartoon police car playing a game of tag
>
> **KEEP EVERYTHING ELSE IDENTICAL:**
> - The same police car design, shape and three-quarter viewing angle
> - The same black-and-white livery, the gold star badge on the door, the red and blue light bar on the roof
> - The same painterly cartoon style, the same colours, the same wheels and body detailing
> - **The car must stay at the same size and position within the 767×767 frame as it is now**, so its scale in the game does not change
>
> **TECHNICAL:**
> - Output exactly **767×767 pixels**
> - **Genuine alpha transparency** around the car, with smooth anti-aliased edges — no white fringe, no grey halo, no checkerboard, no matte
> - It is displayed at roughly 40–60 px on screen, so it must read clearly when small: bold shapes, clear silhouette, large visible eyes
>
> **DO NOT:** keep any teeth, keep any part of the background, add a drop shadow or ground, change the car's design or colours, or restyle the artwork.

---

## 2 · Castle knight — `themes/castle/c_player.png`

Attach the original. Note the replacement object matters: **do not use a shield** — this theme's collectible item is already a shield, so a knight holding one would be confusing.

> I'm attaching a 254×237 PNG game sprite from a children's maze game for ages 4–8 — a cheerful cartoon knight who is the character the child controls. I need two changes.
>
> **FIX 1 — Replace the sword.**
> The knight is holding a raised **sword**. This game is rated for very young children and must not depict weapons. Replace the sword with a **lit torch** — a wooden handle with a warm orange flame — held in the same raised hand, at the same angle, at roughly the same size. A torch suits a castle setting, reads clearly as an adventurer exploring, and removes the weapon entirely.
>
> *(If a torch doesn't read well at small size, alternatives in order of preference: a small triangular pennant flag on a short pole, a lantern, or an open waving hand. **Do not use a shield** — a shield is the collectible item in this theme and would be confusing.)*
>
> **FIX 2 — Fix the edge quality.**
> The current image has **hard-cut, jagged, aliased edges** — there are no semi-transparent pixels at all, so the outline looks like stair-steps when scaled. Redraw with **smooth anti-aliased edges** against transparency.
>
> **KEEP EVERYTHING ELSE IDENTICAL:**
> - The same cheerful running pose and body proportions
> - The same friendly face and expression
> - The same silver-grey plate armour, the same helmet with the **red plume**, the same gold and blue detailing
> - The same flat cartoon style with clean dark outlines, the same colours
> - The same size and position within the frame
>
> **TECHNICAL:**
> - Output exactly **254×237 pixels**
> - Fully transparent background with **smooth anti-aliased alpha edges** — no white fringe, no jagged stair-stepping, no drop shadow, no ground
> - Displayed at roughly 40–60 px on screen, so it must read clearly when small
>
> **DO NOT:** include a sword, dagger, axe, spear, bow or any other weapon; include a shield; change the armour, helmet, plume or face; restyle the artwork; add a background.

---

## 3 · Little Red wolf — `themes/karkulka/k_chaser.png`

Attach the original. The lightest of the three — edges are already clean, so only the face changes.

> I'm attaching a 347×347 PNG game sprite from a children's maze game for ages 4–8 — a cartoon wolf who playfully chases the player around a maze, in a Little Red Riding Hood theme. I need **one change: the face.**
>
> The wolf currently **bares a full set of sharp pointed teeth** and has **narrowed, angry yellow eyes**. It reads as threatening, and this game is rated for very young children.
>
> **Change the face to:**
> - A **closed, friendly mouth** — a soft smile or a small open "oh". **No visible teeth**, no fangs, nothing pointed
> - **Large round friendly eyes** with white sclera, dark round pupils and a small white catchlight. Open and warm, not narrowed. Remove the angry lowered eyebrows — a slightly cheeky or curious expression is ideal
> - The wolf should look like a **playful, mischievous storybook wolf** inviting a game of chase, not a predator
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
> - Fully transparent background with smooth anti-aliased edges — no white fringe, no drop shadow, no ground
> - Displayed at roughly 40–60 px on screen, so the eyes must be large and clear enough to read when small
>
> **DO NOT:** show any teeth or fangs; keep the angry narrowed eyes; change the fur colours, body, tail or pose; restyle the artwork; add a background.

---

## Checking results

Send each result back for measurement before it goes in. Checks applied:

- exact pixel dimensions preserved
- genuine alpha, with a white-fringe test over both black and white backgrounds
- edge softness — the proportion of semi-transparent pixels, which is what distinguishes a smooth edge from a jagged one
- opaque-area percentage, to confirm no background survives (target 35–47%, matching the other chasers)
- silhouette overlap against the original, so in-game scale and placement are unchanged
- legibility rendered at 60 px and 40 px over the actual theme background
